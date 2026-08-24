#!/usr/bin/env bash
# promote.sh — the ONLY thing allowed to write a Hermes user's vault.
#
# Reads notes the agent staged in $HERMES_HOME/inbox, validates them, files them
# into the vault, commits, pushes, and refreshes the Pinecone index.
#
# Deliberately contains no AI and no cleverness. The smart part of the system
# proposes; this part disposes. When something goes wrong you should be able to
# read this file top to bottom and know exactly what happened.
#
# Two verbs only:
#   inbox/wiki/topics/x/note.md          → CREATE vault/wiki/topics/x/note.md
#   inbox/wiki/topics/x/note.md.append   → APPEND to vault/wiki/topics/x/note.md
# Never delete. Never overwrite. A name collision becomes note-2.md.
#
# Runs on macOS (launchd) and inside WSL2 on Windows (Task Scheduler). Same file.
#
# Exit codes:  0 = fine (including "nothing to do")   1 = something needs a human

set -uo pipefail

# ── configuration ────────────────────────────────────────────────────────────
# All overridable by environment. The launchd plist / Task Scheduler job sets them.

VAULT_ROOT="${VAULT_ROOT:?VAULT_ROOT must be set (e.g. $HOME/Memory/doug-vault)}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
INBOX="${INBOX:-$HERMES_HOME/inbox}"
STATE_FILE="${PROMOTE_STATE:-$HERMES_HOME/promote-state.json}"
LOCK_DIR="${PROMOTE_LOCK:-$HERMES_HOME/.promote.lock}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-hermes}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-hermes@localhost}"
PINECONE_SYNC="${PINECONE_SYNC:-$VAULT_ROOT/scripts/pinecone-sync}"
CONTAINER="${HERMES_CONTAINER:-hermes}"

# Buckets that exist in this vault. Anything else is rejected.
# Read from the vault itself so it stays correct without editing this script.
# (Populated the long way round, not with `mapfile` — macOS still ships bash 3.2.)
VALID_BUCKETS=()
while IFS= read -r _b; do
  [[ -n "$_b" ]] && VALID_BUCKETS+=("$_b")
done < <(find "$VAULT_ROOT/wiki/topics" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)

TODAY="$(date -u +%F)"
NOW="$(date -u +%FT%TZ)"

promoted=0
rejected=0
appended=0
problems=()

# ── helpers ──────────────────────────────────────────────────────────────────

log() { printf '%s  %s\n' "$(date -u +%FT%TZ)" "$*"; }

# Best-effort Telegram ping. Never let a failed notification fail the run.
notify() {
  docker exec "$CONTAINER" hermes send --platform telegram --text "$1" >/dev/null 2>&1 || true
}

# Write the heartbeat the health watchdog reads. Always runs, even on failure.
write_state() {
  local status="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  cat >"$STATE_FILE" <<EOF
{
  "last_run": "$NOW",
  "status": "$status",
  "promoted": $promoted,
  "appended": $appended,
  "rejected": $rejected,
  "vault": "$VAULT_ROOT",
  "index": "${PINECONE_INDEX:-unset}"
}
EOF
}

# Quarantine a staged file, preserving why.
reject() {
  local src="$1" reason="$2"
  local dest="$INBOX/_rejected/$TODAY"
  mkdir -p "$dest"
  mv "$src" "$dest/$(basename "$src")" 2>/dev/null || true
  printf '%s  %s  %s\n' "$NOW" "$(basename "$src")" "$reason" >>"$dest/REASONS.txt"
  rejected=$((rejected + 1))
  problems+=("$(basename "$src"): $reason")
  log "REJECT $(basename "$src") — $reason"
}

# A staged note must carry frontmatter we can file on. The agent writes it;
# this checks it. Validation lives here, not in the model.
validate() {
  local f="$1"

  # Patterns tolerate a trailing \r: on Windows the vault sits on the Windows
  # filesystem and a note edited in a Windows editor comes back CRLF. A bare
  # '^---$' would then silently reject every hand-edited note.
  # Not `head | grep -q`: this script runs under `set -o pipefail`, and grep -q
  # exiting on match can SIGPIPE head into a 141 that reads as "no match" — which
  # here would REJECT a perfectly valid note. Read the line, then test it.
  local first_line
  first_line="$(head -n 1 "$f" 2>/dev/null || true)"
  grep -q '^---[[:space:]]*$' <<<"$first_line" || { echo "no frontmatter"; return 1; }

  local fm
  fm="$(awk 'NR>1 && /^---[[:space:]]*$/{exit} NR>1{print}' "$f")"

  grep -q '^bucket:'  <<<"$fm" || { echo "missing bucket:";  return 1; }
  grep -q '^created:' <<<"$fm" || { echo "missing created:"; return 1; }

  local bucket
  bucket="$(grep -m1 '^bucket:' <<<"$fm" | sed 's/^bucket:[[:space:]]*//; s/[[:space:]]*$//')"

  local ok=0
  for b in "${VALID_BUCKETS[@]}"; do [[ "$b" == "$bucket" ]] && ok=1 && break; done
  [[ $ok -eq 1 ]] || { echo "unknown bucket '$bucket'"; return 1; }

  # Body must have something in it beyond the frontmatter.
  local body_lines
  body_lines="$(awk 'f{print} /^---[[:space:]]*$/{c++} c==2 && !f{f=1}' "$f" | grep -c '[^[:space:]]')"
  [[ "$body_lines" -gt 0 ]] || { echo "empty body"; return 1; }

  return 0
}

# Never overwrite. note.md → note-2.md → note-3.md
unique_path() {
  local target="$1"
  [[ -e "$target" ]] || { echo "$target"; return; }
  local dir base ext n
  dir="$(dirname "$target")"; base="$(basename "$target" .md)"; n=2
  while [[ -e "$dir/$base-$n.md" ]]; do n=$((n + 1)); done
  echo "$dir/$base-$n.md"
}

# ── preflight ────────────────────────────────────────────────────────────────

[[ -d "$VAULT_ROOT/.git" ]] || { log "FATAL: $VAULT_ROOT is not a git repo"; write_state "fatal"; exit 1; }
[[ ${#VALID_BUCKETS[@]} -gt 0 ]] || { log "FATAL: no buckets under $VAULT_ROOT/wiki/topics"; write_state "fatal"; exit 1; }

# One at a time. mkdir is atomic; a stale lock older than an hour is cleared.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  if [[ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +60 2>/dev/null)" ]]; then
    log "clearing stale lock"; rmdir "$LOCK_DIR" 2>/dev/null; mkdir "$LOCK_DIR" 2>/dev/null || exit 0
  else
    log "another run in progress, skipping"; exit 0
  fi
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

mkdir -p "$INBOX" "$INBOX/_rejected" "$INBOX/_promoted"

# ── 1 + 2. validate and file ─────────────────────────────────────────────────

while IFS= read -r -d '' staged; do
  rel="${staged#"$INBOX"/}"

  # Skip our own bookkeeping folders.
  case "$rel" in _rejected/*|_promoted/*) continue ;; esac

  if [[ "$staged" == *.md.append ]]; then
    # APPEND — target must already exist. No frontmatter required on a fragment.
    target="$VAULT_ROOT/${rel%.append}"
    if [[ ! -f "$target" ]]; then
      reject "$staged" "append target does not exist: ${rel%.append}"
      continue
    fi
    { printf '\n'; cat "$staged"; printf '\n'; } >>"$target"
    appended=$((appended + 1))
    log "APPEND ${rel%.append}"

  elif [[ "$staged" == *.md ]]; then
    # CREATE
    if ! reason="$(validate "$staged")"; then
      reject "$staged" "$reason"
      continue
    fi
    target="$(unique_path "$VAULT_ROOT/$rel")"
    mkdir -p "$(dirname "$target")"
    cp "$staged" "$target"
    promoted=$((promoted + 1))
    log "CREATE ${target#"$VAULT_ROOT"/}"

  else
    reject "$staged" "not a .md or .md.append file"
    continue
  fi

  # Park the staged copy; it is deleted from the inbox only after the commit
  # below succeeds, so a git failure never costs a captured thought.
  mkdir -p "$INBOX/_promoted/$TODAY/$(dirname "$rel")"
  mv "$staged" "$INBOX/_promoted/$TODAY/$rel" 2>/dev/null || true

done < <(find "$INBOX" -type f \( -name '*.md' -o -name '*.md.append' \) -print0 2>/dev/null)

# ── 3 + 4 + 5. git: commit BEFORE pull, because the tree is always dirty ─────

cd "$VAULT_ROOT" || { write_state "fatal"; exit 1; }

git_cmd() { git -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" "$@"; }

if [[ -n "$(git status --porcelain)" ]]; then
  git_cmd add -A
  git_cmd commit -q -m "capture $NOW (+${promoted} new, +${appended} appended)" || true
  log "committed ${promoted} new, ${appended} appended"
fi

if git remote get-url origin >/dev/null 2>&1; then
  # `git pull --rebase` refuses to run on unstaged changes — hence commit first.
  if ! git_cmd pull --rebase --autostash -q origin "$GIT_BRANCH" 2>/dev/null; then
    git_cmd rebase --abort 2>/dev/null || true
    branch="hermes-conflict/$(hostname -s)-$(date -u +%s)"
    git_cmd branch "$branch" && git_cmd push -q -u origin "$branch" 2>/dev/null || true
    log "CONFLICT — work parked on $branch, local $GIT_BRANCH left usable"
    notify "Vault sync hit a conflict on $(hostname -s). Nothing is lost — the work is safe on branch $branch, and new notes are still being saved. Someone needs to merge it."
    problems+=("git conflict → $branch")
    write_state "conflict"
    exit 0   # local vault is still fine; captures keep landing
  fi
  git_cmd push -q origin "$GIT_BRANCH" 2>/dev/null || {
    log "push failed (offline?) — commits are safe locally, will retry next run"
    problems+=("push failed")
  }
fi

# Only now is the capture durable. Clear the staging copies older than 7 days.
find "$INBOX/_promoted" -type f -mtime +7 -delete 2>/dev/null || true
find "$INBOX/_promoted" -type d -empty -delete 2>/dev/null || true

# ── 6. refresh the semantic index ────────────────────────────────────────────

if [[ -x "$PINECONE_SYNC" && -n "${PINECONE_INDEX:-}" ]]; then
  if ! VAULT_ROOT="$VAULT_ROOT" "$PINECONE_SYNC" >/dev/null 2>&1; then
    log "pinecone-sync failed — notes are safe, semantic recall is stale"
    problems+=("pinecone-sync failed")
  fi
fi

# ── 7. heartbeat ─────────────────────────────────────────────────────────────

if [[ ${#problems[@]} -gt 0 ]]; then
  write_state "degraded"
  log "done with problems: ${problems[*]}"
  exit 0   # degraded is not fatal; the watchdog reports it
fi

write_state "ok"
[[ $promoted -gt 0 || $appended -gt 0 ]] && log "done: +${promoted} new, +${appended} appended"
exit 0
