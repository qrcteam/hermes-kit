#!/usr/bin/env bash
# install-verify.sh — walk the whole runbook checklist in one command.
#
# Run this ON THEIR MACHINE, on install day, from the host (NOT inside the
# container — half these checks are about things the container cannot see:
# Docker itself, the launchd/Task Scheduler job, the vault's git remote, and
# whether a second gateway is fighting the first).
#
#   bash install-verify.sh          check and report — changes NOTHING
#   bash install-verify.sh --fix    also apply the safe repairs
#
# Without --fix it is strictly read-only: run it as often as you like, at any
# point during an install, and it cannot change the outcome.
#
# --fix applies only repairs that are idempotent, reversible and cannot lose
# data — making a directory, fixing a mode, copying a skill file, loading a
# launchd job, starting a stopped container, setting a config key. Anything that
# needs a human decision, someone's account, an interactive prompt, or the
# container recreated stays report-only BY DESIGN. Notably NOT auto-fixed:
# re-creating the container (mounts are fixed at `docker run`), moving the vault,
# `git init` on the vault, logging in a model, pairing WhatsApp, editing SOUL.md,
# and unloading a competing host gateway — that last one is someone's LaunchAgent
# and the call is theirs, not this script's.
#
# Exit codes:  0 = everything required passed   1 = at least one FAIL
#
# Reading the output:
#   PASS  this is correct
#   FAIL  this is broken or missing — the install is not finished
#   WARN  optional, or not configured yet — fine to ship without, worth knowing
#   SKIP  can't be checked from here (wrong OS, or a prerequisite already failed)
#
# Every FAIL prints the fix underneath it. Nothing here requires you to remember
# anything from the runbook.
#
# NOTE — this checks a CLIENT install. Run it on the operator's own Mac and the
# whole "Memory pipeline" section fails, correctly: on that machine Claude Code
# writes the vault (/end, /ask) and Hermes only reads it, so there is no inbox,
# no promote.sh and no promoter job to find. See docs/07-operator-notes.md.
#
# NATIVE vs DOCKER — the kit's default is Docker: the vault mount is what makes
# "the agent can't write /vault" a KERNEL guarantee, not just a skill convention
# (see 01-architecture.md, "the one rule that shapes everything"). Some installs
# run the gateway natively via launchd instead (no container at all). This
# script detects which one it's looking at and adjusts every check — but native
# mode gets an extra WARN that docker mode never sees: on native, Hermes runs as
# the same OS user as the promoter and the human, so there is no filesystem
# boundary stopping it from writing the vault directly. Only the vault-capture
# skill's own discipline does. That is a real, permanent difference in guarantee
# between the two install shapes, not a bug this script can fix — it can only
# tell you the truth about which one you have.

set -uo pipefail

CONTAINER="${CONTAINER:-hermes}"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
KIT="${KIT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

FIX=0
case "${1:-}" in
  --fix)  FIX=1 ;;
  -h|--help)
    printf 'usage: %s [--fix]\n\n' "$(basename "$0")"
    printf '  (no flag)  check everything and report. Changes nothing.\n'
    printf '  --fix      additionally apply the SAFE repairs — the ones that are\n'
    printf '             idempotent, reversible and cannot lose data. Anything\n'
    printf '             needing a human, an account, or the container recreated\n'
    printf '             stays report-only and is listed as "fix by hand".\n'
    exit 0 ;;
  "") ;;
  *)  printf 'unknown option: %s (try --help)\n' "$1"; exit 2 ;;
esac

pass=0; fail=0; warn=0; skip=0
FAILED_LINES=""
# Newline-delimited "description|||command". A plain string rather than an array
# because `set -u` + bash 3.2 (still what macOS ships) errors on empty-array
# expansion, and this script must run on a stock Mac with nothing installed.
FIXES=""

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; D=$'\033[2m'; B=$'\033[1m'; Z=$'\033[0m'
else
  G=""; R=""; Y=""; D=""; B=""; Z=""
fi

section() { printf '\n%s%s%s\n' "$B" "$1" "$Z"; }
ok()   { printf '  %sPASS%s  %s\n' "$G" "$Z" "$1"; pass=$((pass+1)); }
# bad "<what's wrong>" "<how to fix by hand>" ["<safe command --fix may run>"]
# Only pass a third argument when the command is idempotent, reversible and
# cannot lose data. Everything else stays a hand fix, on purpose.
bad()  { printf '  %sFAIL%s  %s\n' "$R" "$Z" "$1"
         [[ -n "${2:-}" ]] && printf '        %s↳ %s%s\n' "$D" "$2" "$Z"
         if [[ -n "${3:-}" ]]; then
           FIXES="${FIXES}$1|||$3"$'\n'
           (( FIX )) || printf '        %s↳ --fix can repair this one%s\n' "$D" "$Z"
         fi
         fail=$((fail+1)); FAILED_LINES="${FAILED_LINES}  • $1"$'\n'; }
soft() { printf '  %sWARN%s  %s\n' "$Y" "$Z" "$1"
         [[ -n "${2:-}" ]] && printf '        %s↳ %s%s\n' "$D" "$2" "$Z"
         [[ -n "${3:-}" ]] && FIXES="${FIXES}$1|||$3"$'\n'
         warn=$((warn+1)); }
# ⚠️ NEVER `cmd | grep -q` in this file. This script runs under `set -o pipefail`,
# and `grep -q` exits the moment it matches — which SIGPIPEs the writer, making the
# whole pipeline exit 141 EVEN WHEN THE MATCH SUCCEEDED. The result is a check that
# reports FAIL on a perfectly healthy install. It did exactly that for the promoter
# job: "Promoter is NOT scheduled" on a machine where the job was loaded and running.
# Capture first, then match on the variable.
nope() { printf '  %sSKIP%s  %s\n' "$D" "$Z" "$1"; skip=$((skip+1)); }

# `docker inspect` reports Docker Desktop's INTERNAL path for bind mounts, not
# the host path — /host_mnt/Users/... on macOS, /run/desktop/mnt/host/c/... on
# Windows. Test those against the host filesystem and every check silently
# skips. Strip the prefix before touching the path.
host_path() {
  local p="${1:-}"
  p="${p#/host_mnt}"
  p="${p#/run/desktop/mnt/host}"
  printf '%s' "$p"
}

printf '%sHermes install check%s  ·  %s\n' "$B" "$Z" "$(date '+%Y-%m-%d %H:%M')"

# ── Which install shape is this? ─────────────────────────────────────────────
# Detect BEFORE anything else so every later check asks the right question
# instead of assuming Docker and failing every single check on a native box.
MODE=""
native_gw=""
native_job=""
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  container_state="$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || echo missing)"
  [[ "$container_state" == "running" ]] && MODE="docker"
fi
if [[ -z "$MODE" ]]; then
  native_gw="$(pgrep -f 'hermes_cli.main gateway' 2>/dev/null || true)"
  native_job="$(launchctl list 2>/dev/null | grep 'ai\.hermes\.gateway' || true)"
  [[ -n "$native_gw" || -n "$native_job" ]] && MODE="native"
fi

# dex = "run this hermes-facing command wherever the gateway actually lives."
# Docker: inside the container. Native: directly on the host, same as any
# other command — there is no boundary to cross.
dex() {
  if [[ "$MODE" == "docker" ]]; then
    docker exec "$CONTAINER" "$@" 2>/dev/null
  else
    "$@" 2>/dev/null
  fi
}
if [[ "$MODE" == "docker" ]]; then
  HCMD="docker exec $CONTAINER hermes"; HCMD_IT="docker exec -it $CONTAINER hermes"
  RESTART_HINT="docker restart $CONTAINER"
else
  HCMD="hermes"; HCMD_IT="hermes"
  RESTART_HINT="launchctl kickstart -k gui/\$(id -u)/ai.hermes.gateway"
fi

# ── Environment ──────────────────────────────────────────────────────────────
section "Environment"

case "$MODE" in
  docker)
    ok "Docker is running"
    ok "Container '$CONTAINER' is running"
    restart="$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$CONTAINER" 2>/dev/null)"
    [[ "$restart" == "unless-stopped" || "$restart" == "always" ]] \
      && ok "Restart policy is '$restart' — survives a reboot" \
      || soft "Restart policy is '${restart:-none}'" "Without it they must start Docker by hand after every reboot. Re-create with --restart unless-stopped."
    ;;
  native)
    ok "Running native (no Docker container) — the gateway is a host process"
    [[ -n "$native_gw" ]] \
      && ok "Gateway process is running" \
      || bad "launchd shows the gateway job loaded but no process is actually running" "Check the gateway's own error log under ~/.hermes/logs/." "launchctl kickstart -k gui/\$(id -u)/ai.hermes.gateway"
    [[ -n "$native_job" ]] \
      && ok "Gateway is a launchd job — survives logout/reboot" \
      || soft "No launchd job found for the gateway" "It only runs as long as whatever started it stays open. Install a LaunchAgent (see templates/) so it survives a reboot."
    soft "Native install: the vault is NOT kernel-enforced read-only" "Docker's :ro mount is what makes 'the agent can't write the vault' a filesystem guarantee, not a request. On native, Hermes runs as the same OS user as the promoter and the human, so nothing at the OS level stops it from writing the vault directly — only the vault-capture skill's own discipline does. See the vault permissions line under Mounts below for what this install actually has."
    ;;
  *)
    bad "Neither a running Docker container ('$CONTAINER') nor a native gateway process was found" "Docker: check 'docker ps -a' and 'docker info'. Native: check 'launchctl list | grep hermes' and 'pgrep -f hermes_cli.main'."
    printf '\n%sStopping — nothing else can be checked without a running gateway.%s\n' "$R" "$Z"; exit 1 ;;
esac

# ── Mounts — the part that protects their memory ─────────────────────────────
section "Mounts"

if [[ "$MODE" == "docker" ]]; then
  VAULT_SRC="$(host_path "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/vault"}}{{.Source}}{{end}}{{end}}' "$CONTAINER" 2>/dev/null)")"
  VAULT_RW="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/vault"}}{{.RW}}{{end}}{{end}}' "$CONTAINER" 2>/dev/null)"

  if [[ -z "$VAULT_SRC" ]]; then
    bad "No /vault mount on the container" "The agent has no memory at all. Re-create with -v \"\$HOME/Memory/<NAME>-vault:/vault:ro\""
  elif [[ "$VAULT_RW" == "false" ]]; then
    ok "Vault is mounted READ-ONLY  ($VAULT_SRC)"
  else
    bad "Vault is mounted WRITABLE — the agent can destroy their notes" "This is the single most important character in the kit. Re-create the container with :ro on the vault mount."
  fi

  DATA_SRC="$(host_path "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/opt/data"}}{{.Source}}{{end}}{{end}}' "$CONTAINER" 2>/dev/null)")"
  [[ -n "$DATA_SRC" ]] \
    && ok "Data dir mounted read-write  ($DATA_SRC)" \
    || bad "No /opt/data mount" "Config, SOUL.md and the inbox all live there. Re-create with -v \"\$HOME/.hermes:/opt/data\""
else
  # No mount to inspect on native. Find the vault from whatever already knows
  # where it is, most-trustworthy source first: a caller-supplied VAULT_ROOT,
  # then the last real promoter run, then the scheduled job's own config, then
  # (only if nothing else exists) a lone ~/Memory/*-vault directory.
  VAULT_SRC="${VAULT_ROOT:-}"
  if [[ -z "$VAULT_SRC" && -f "$HERMES_HOME/promote-state.json" ]]; then
    VAULT_SRC="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("vault",""))
except Exception: pass' "$HERMES_HOME/promote-state.json" 2>/dev/null || true)"
  fi
  if [[ -z "$VAULT_SRC" ]]; then
    NPLIST="$HOME/Library/LaunchAgents/com.hermeskit.vault-promote.plist"
    [[ -f "$NPLIST" ]] && VAULT_SRC="$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:VAULT_ROOT' "$NPLIST" 2>/dev/null || true)"
  fi
  if [[ -z "$VAULT_SRC" && -d "$HOME/Memory" ]]; then
    found_vaults="$(find "$HOME/Memory" -mindepth 1 -maxdepth 1 -type d -name '*-vault' 2>/dev/null)"
    n="$(printf '%s\n' "$found_vaults" | grep -c . || true)"
    [[ "$n" -eq 1 ]] && VAULT_SRC="$found_vaults"
  fi

  if [[ -z "$VAULT_SRC" || ! -d "$VAULT_SRC" ]]; then
    bad "Could not find the vault" "No promote-state.json, no promoter plist, and no single ~/Memory/*-vault to guess from. Re-run with VAULT_ROOT=<path> bash install-verify.sh"
  else
    ok "Vault found at $VAULT_SRC"
    vperm="$(stat -f '%Sp' "$VAULT_SRC" 2>/dev/null || stat -c '%A' "$VAULT_SRC" 2>/dev/null)"
    case "$vperm" in
      *w*) soft "Vault directory is writable by this user (mode ${vperm:-?})" "Normal for native — see the Environment warning above. If you want an actual write barrier rather than a skill convention, chmod the vault tree read-only by default and have promote.sh toggle it write-able only for its own run." ;;
      *)   ok "Vault directory has no write bit for this user (mode ${vperm:-?}) — a real barrier, not just a skill convention" ;;
    esac
  fi

  DATA_SRC="$HERMES_HOME"
  ok "Data dir (native — no mount, it's just $DATA_SRC)"
fi

# macOS hides Desktop/Documents/Downloads from background jobs, silently.
case "$VAULT_SRC" in
  */Desktop/*|*/Documents/*|*/Downloads/*)
    bad "Vault sits under Desktop/Documents/Downloads" "macOS blocks scheduled jobs from reading these and does it silently — the promoter will appear to work and save nothing. Move it to ~/Memory/ and re-create the container." ;;
  *) [[ -n "$VAULT_SRC" ]] && ok "Vault is outside the TCC-protected folders" ;;
esac

# ── Settings that must not drift ─────────────────────────────────────────────
section "Settings"

if [[ "$MODE" == "docker" ]]; then
  # WAL corruption over a Docker Desktop bind mount (gRPC-FUSE / virtiofs file
  # locking) is a Docker-specific failure mode — it doesn't apply the same way
  # to a native SQLite file sitting on a normal local filesystem, so this check
  # only runs in docker mode.
  jm="$(dex hermes config get database.journal_mode | tr -d '\r\n')"
  [[ "$jm" == "delete" ]] \
    && ok "journal_mode = delete" \
    || bad "journal_mode = '${jm:-unset}' (must be 'delete')" "SQLite's WAL corrupts across a Docker bind mount. Expect 'database disk image is malformed' within a week." "$HCMD config set database.journal_mode delete"
else
  nope "journal_mode check (Docker-bind-mount-specific; not a native failure mode)"
fi

am="$(dex hermes config get approvals.mode | tr -d '\r\n')"
[[ "$am" == "smart" ]] && ok "approvals.mode = smart" \
  || soft "approvals.mode = '${am:-unset}' (expected 'smart')" "$HCMD config set approvals.mode smart" "$HCMD config set approvals.mode smart"

cm="$(dex hermes config get approvals.cron_mode | tr -d '\r\n')"
[[ "$cm" == "deny" ]] && ok "approvals.cron_mode = deny" \
  || soft "approvals.cron_mode = '${cm:-unset}' (expected 'deny')" "Scheduled agent jobs could take actions with nobody awake to approve them." "$HCMD config set approvals.cron_mode deny"

# ── Credentials ──────────────────────────────────────────────────────────────
section "Credentials"

ENVF="$HERMES_HOME/.env"
if [[ ! -f "$ENVF" ]]; then
  bad "No .env at $ENVF" "Runbook step 5 — copy templates/env.template and fill it in."
else
  ok ".env exists"
  perm="$(stat -f '%A' "$ENVF" 2>/dev/null || stat -c '%a' "$ENVF" 2>/dev/null)"
  [[ "$perm" == "600" ]] && ok ".env is mode 600" \
    || soft ".env is mode ${perm:-?} (want 600)" "it holds their bot token." "chmod 600 \"$ENVF\""
  for k in TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS; do
    v="$(grep -m1 "^${k}=" "$ENVF" 2>/dev/null | cut -d= -f2-)"
    [[ -n "$v" ]] && ok "$k is set" || bad "$k is empty or missing" "Without it the bot either won't start or will talk to strangers."
  done
fi

PKEY="$HERMES_HOME/secrets/pinecone.key"
if [[ -f "$PKEY" ]]; then
  ok "Pinecone key present"
  perm="$(stat -f '%A' "$PKEY" 2>/dev/null || stat -c '%a' "$PKEY" 2>/dev/null)"
  [[ "$perm" == "600" ]] || soft "pinecone.key is mode ${perm:-?} (want 600)" "" "chmod 600 \"$PKEY\""
else
  soft "No Pinecone key at $PKEY" "Optional under ~200 notes — recall stays keyword-only until it's added."
fi

hermes_status="$(dex hermes status 2>/dev/null || true)"
if grep -qiE 'provider:.*(subscription|logged|oauth|api)' <<<"$hermes_status"; then
  ok "A model provider is logged in"
else
  auth_ok="$(dex hermes auth list 2>/dev/null | grep -c '←' || echo 0)"
  [[ "${auth_ok:-0}" -gt 0 ]] && ok "A model credential is active" \
    || bad "No model logged in" "$HCMD_IT model   — they must do this on their own account."
fi

# ── The memory pipeline ──────────────────────────────────────────────────────
section "Memory pipeline"

PROMOTE="$HERMES_HOME/promote.sh"
if [[ -x "$PROMOTE" ]]; then ok "promote.sh is installed and executable"
elif [[ -f "$PROMOTE" ]]; then bad "promote.sh is not executable" "" "chmod +x \"$PROMOTE\""
else bad "promote.sh is missing" "Runbook step 5." "cp \"$KIT/promote.sh\" \"$PROMOTE\" && chmod +x \"$PROMOTE\""
fi

[[ -d "$HERMES_HOME/inbox" ]] && ok "Inbox directory exists" \
  || bad "No inbox at $HERMES_HOME/inbox" "the agent stages every note there." "mkdir -p \"$HERMES_HOME/inbox\""

case "$(uname -s)" in
  Darwin)
    launchd_jobs="$(launchctl list 2>/dev/null || true)"
    if grep -q 'vault-promote' <<<"$launchd_jobs"; then
      ok "Promoter is scheduled (launchd job loaded)"
    else
      # `launchctl load` of a MISSING plist exits 0 — so the naive fix reports
      # success while doing nothing. Guard on the file, and prove the job is
      # actually loaded afterwards, or this lies.
      bad "Promoter is NOT scheduled" "Nothing they tell the agent will ever reach the vault. Runbook step 8 — the plist must exist at ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist first." \
        "[ -f \"$HOME/Library/LaunchAgents/com.hermeskit.vault-promote.plist\" ] && launchctl load -w \"$HOME/Library/LaunchAgents/com.hermeskit.vault-promote.plist\" && launchctl list > /tmp/hk-jobs.$$ && grep -q vault-promote /tmp/hk-jobs.$$"
    fi ;;
  *)
    if command -v schtasks >/dev/null 2>&1; then
      schtasks /query /tn "HermesVaultPromote" >/dev/null 2>&1 \
        && ok "Promoter is scheduled (Task Scheduler)" \
        || bad "Promoter task not found in Task Scheduler" "Runbook 03 step 8 — import vault-promote-task.xml."
    else
      nope "Scheduler check (not macOS, no schtasks)"
    fi ;;
esac

# ⚠️ A wrong GIT_BRANCH is INVISIBLE without this check. promote.sh pulls and
# pushes the branch it is handed, so a mismatch means captured notes commit
# locally and never reach GitHub — while the job stays loaded, the heartbeat
# stays "ok", and every other check on this page still passes. It bit a real
# install on 2026-08-23 whose vault was on `master` against a template that
# defaulted to `main`, and the comment sitting directly above that default was
# not enough to prevent it. Hence a check rather than better prose.
PLIST="$HOME/Library/LaunchAgents/com.hermeskit.vault-promote.plist"
if [[ "$(uname -s)" == "Darwin" && -f "$PLIST" && -n "$VAULT_SRC" && -d "$VAULT_SRC/.git" ]]; then
  want_branch="$(git -C "$VAULT_SRC" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  got_branch="$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:GIT_BRANCH' "$PLIST" 2>/dev/null)"
  if [[ -z "$got_branch" ]]; then
    soft "Promoter has no GIT_BRANCH set (promote.sh will assume 'main')" \
      "The vault is on '$want_branch'. If that is not main, notes will never push."
  elif [[ "$got_branch" == "<BRANCH>" ]]; then
    bad "Promoter GIT_BRANCH is still the <BRANCH> placeholder" "Notes will commit locally and never reach GitHub." \
      "Set it to '$want_branch' in $PLIST, then: launchctl unload \"$PLIST\" && launchctl load -w \"$PLIST\""
  elif [[ "$got_branch" == "$want_branch" ]]; then
    ok "Promoter pushes the branch the vault is actually on ($want_branch)"
  else
    bad "Promoter is set to push '$got_branch' but the vault is on '$want_branch'" \
      "Captured notes will commit locally and never reach GitHub, with no error anywhere." \
      "Set GIT_BRANCH to '$want_branch' in $PLIST, then: launchctl unload \"$PLIST\" && launchctl load -w \"$PLIST\""
  fi
fi

STATE="$HERMES_HOME/promote-state.json"
if [[ -f "$STATE" ]]; then
  st="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("status","?"))' "$STATE" 2>/dev/null || echo '?')"
  case "$st" in
    ok)       ok "Last promoter run reported: ok" ;;
    conflict) bad "Promoter hit a sync conflict" "Nothing is lost — someone needs to merge the vault repo by hand." ;;
    fatal)    bad "Promoter is failing outright" "Run it manually to see why:  \"$PROMOTE\"" ;;
    *)        soft "Promoter status is '$st'" "Run it manually:  \"$PROMOTE\"" ;;
  esac
else
  soft "Promoter has never run" "Run it once now to prove it works:  \"$PROMOTE\""
fi

for s in vault-capture session-log; do
  [[ -f "$HERMES_HOME/skills/note-taking/$s/SKILL.md" ]] \
    && ok "Skill installed: $s" \
    || bad "Skill missing: $s" "" "mkdir -p \"$HERMES_HOME/skills/note-taking/$s\" && cp \"$KIT/${s}-SKILL.md\" \"$HERMES_HOME/skills/note-taking/$s/SKILL.md\""
done

if [[ "$MODE" == "native" && -f "$HERMES_HOME/skills/note-taking/vault-capture/SKILL.md" ]]; then
  # The kit's template is written for Docker's /vault and /opt/data/inbox. On a
  # native install neither path exists, so an unmodified copy tells the agent
  # to read and write locations that are not there — it may still work if the
  # model reasons past its own instructions, but that is not something to rely
  # on. Flag it explicitly rather than let it pass silently.
  bad_paths="$(grep -cE '(^|[^/])(/vault|/opt/data)(/|$| )' "$HERMES_HOME/skills/note-taking/vault-capture/SKILL.md" 2>/dev/null | tr -d ' ')"
  if [[ "${bad_paths:-0}" -gt 0 ]]; then
    bad "vault-capture skill still points at Docker paths (/vault, /opt/data) on a native install" "Neither path exists on this machine. Rewrite it to \$HOME/Memory/<vault> and \$HERMES_HOME/inbox, or the agent is following instructions that point nowhere."
  else
    ok "vault-capture skill uses real (non-Docker) paths"
  fi
fi

# ── The vault itself ─────────────────────────────────────────────────────────
section "The vault"

if [[ -z "$VAULT_SRC" || ! -d "$VAULT_SRC" ]]; then
  nope "Vault checks (no readable vault path)"
else
  buckets="$(find "$VAULT_SRC/wiki/topics" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  [[ "${buckets:-0}" -gt 0 ]] \
    && ok "$buckets bucket(s) under wiki/topics" \
    || bad "No buckets in wiki/topics" "Every note the agent writes will be rejected. Runbook step 3."

  if git -C "$VAULT_SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "Vault is a git repo"
    if remote="$(git -C "$VAULT_SRC" remote get-url origin 2>/dev/null)"; then
      ok "Vault has a remote  (${remote##*/})"
      git -C "$VAULT_SRC" fetch origin -q 2>/dev/null
      ahead="$(git -C "$VAULT_SRC" rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')"
      case "$ahead" in
        0) ok "Vault is fully pushed" ;;
        '?') soft "Can't compare with the remote" "No upstream set, or the network is down." ;;
        *) soft "$ahead commit(s) not pushed" "Their only backup is behind. git -C \"$VAULT_SRC\" push" ;;
      esac
    else
      bad "Vault has no git remote" "A disk failure loses everything. Create a PRIVATE repo and add it as origin."
    fi
  else
    bad "Vault is not a git repo" "No undo and no backup. Runbook step 3."
  fi
fi

# ── Who they are ─────────────────────────────────────────────────────────────
section "Identity"

SOUL="$HERMES_HOME/SOUL.md"
if [[ ! -f "$SOUL" ]]; then
  bad "No SOUL.md" "This is the product, not the plumbing — without it they have a chatbot with their name on it. Runbook step 7."
else
  ok "SOUL.md exists"
  # Template placeholders are either ALL-CAPS tokens (<NAME>) or prose in angle
  # brackets (<city, and their timezone>). Matching a bare '<' also flags inline
  # code paths like `/go/<slug>` and `topics/<bucket>/_manual.md`, which are
  # legitimate and appear in every finished SOUL.md — so require caps or a space.
  PH_RE='<[A-Z][A-Z_]*>|<[^>]* [^>]*>'
  ph="$(grep -cE "$PH_RE" "$SOUL" 2>/dev/null | tr -d ' ')"
  [[ "${ph:-0}" -eq 0 ]] \
    && ok "No <placeholders> left in SOUL.md" \
    || bad "$ph line(s) in SOUL.md still contain <placeholders>" "The agent reasons from these as though they were true. grep -nE '$PH_RE' \"$SOUL\""
  grep -q '<!--' "$SOUL" 2>/dev/null && soft "SOUL.md still has HTML comments" "They cost tokens on every single message. Strip them."
  asks="$(grep -c '⟨ASK⟩' "$SOUL" 2>/dev/null | tr -d ' ')"
  [[ "${asks:-0}" -gt 0 ]] && nope "$asks known blank(s) marked ⟨ASK⟩ — intentional, not a problem"
fi

# ── Channels ─────────────────────────────────────────────────────────────────
section "Channels"

GWLOG="$HERMES_HOME/logs/gateway.log"
if grep -q '\[Telegram\] Connected' "$GWLOG" 2>/dev/null; then
  # Only LIFECYCLE lines say anything about health — the log is mostly routine
  # traffic ("Sending response…"), and the newest of those is not a verdict.
  # Same filter the telegram-kick watchdog uses.
  last_tg="$(grep -E '\[Telegram\] (Connected to Telegram|Connecting to Telegram \(attempt|polling restarted after conflict|Telegram polling conflict)' "$GWLOG" 2>/dev/null | tail -1)"
  case "$last_tg" in
    *"Connected to Telegram"*|*"polling restarted"*) ok "Telegram is connected" ;;
    *conflict*) bad "Telegram is stuck in a polling conflict" "Two pollers on one bot token. Check for a second gateway; see 06-troubleshooting.md." ;;
    *Connecting*) soft "Telegram's last lifecycle line is a connect attempt" "It may still be retrying. tail -5 \"$GWLOG\"" ;;
    *) soft "Telegram connected earlier; can't confirm current state" "tail -5 \"$GWLOG\"" ;;
  esac
elif [[ -f "$GWLOG" ]]; then
  bad "Telegram has never connected" "Check the token and allowed-user ID in .env, then: $RESTART_HINT"
else
  soft "No gateway log yet at $GWLOG" "Normal on a gateway that has only just started."
fi

wa="$(dex hermes config get platforms.whatsapp.enabled | tr -d '\r\n')"
if [[ "$wa" == "true" ]]; then
  wa_health="$(dex curl -s --max-time 4 http://127.0.0.1:3000/health 2>/dev/null || true)"
  if grep -q '"status":"connected"' <<<"$wa_health"; then
    ok "WhatsApp bridge is connected"
  else
    bad "WhatsApp is enabled but its bridge is not connected" "Pair: $HCMD_IT whatsapp"
  fi
  [[ -f "$HERMES_HOME/whatsapp/session/creds.json" || -f "$HERMES_HOME/platforms/whatsapp/session/creds.json" ]] \
    && ok "WhatsApp pairing is stored" \
    || bad "No WhatsApp creds.json — never paired" "$HCMD_IT whatsapp"
else
  nope "WhatsApp not enabled (fine if they only wanted Telegram)"
fi

# One gateway, and only one. In docker mode a host-level gateway is always a
# STRAY — the real one lives inside the container's own PID namespace and a
# host pgrep can never see it, so any match here means someone also started a
# native one by hand and it's now fighting the container for the same bot
# token. In native mode the process we already found in the Environment
# section above IS the one true gateway, so the question flips: we want
# exactly one match, not zero.
#
# Not a bare `pgrep -f 'hermes_cli.main gateway'`: the native launchd job
# wraps the real gateway in `hermes_cli.stderr_timestamp -- ... hermes_cli.main
# gateway run`, and that wrapper's OWN command line contains the pattern as an
# argument — so a single running gateway shows up as two pgrep matches (the
# wrapper and its child), reporting a false "competing gateway". Exclude the
# wrapper explicitly.
proc_list="$(ps -axo command= 2>/dev/null || true)"
gw_count="$(printf '%s\n' "$proc_list" | awk '/hermes_cli\.main gateway/ && !/stderr_timestamp/' | grep -c . || echo 0)"
if [[ "$MODE" == "docker" ]]; then
  if [[ "${gw_count:-0}" -gt 0 ]]; then
    bad "A second gateway is running on the host, competing with the container" "They share ~/.hermes and the same Telegram token, so both fail. macOS: launchctl unload -w ~/Library/LaunchAgents/ai.hermes.gateway.plist"
  else
    ok "Exactly one gateway (the container) — nothing competing on the host"
  fi
else
  case "${gw_count:-0}" in
    0) bad "No native gateway process found" "Expected exactly one for a native install. See the Environment section above." ;;
    1) ok "Exactly one native gateway process running" ;;
    *) bad "$gw_count gateway processes running — competing for the same Telegram token" "Only one should run. Check 'launchctl list | grep hermes' and any 'hermes gateway run' left in a terminal by hand." ;;
  esac
fi

# ── Apply the safe repairs (--fix only) ──────────────────────────────────────
if (( FIX )) && [[ -n "$FIXES" ]]; then
  section "Applying safe repairs"
  applied=0; failed=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    desc="${line%%|||*}"; cmd="${line#*|||}"
    if eval "$cmd" >/dev/null 2>&1; then
      printf '  %sFIXED%s %s\n' "$G" "$Z" "$desc"; applied=$((applied+1))
    else
      printf '  %sCOULD NOT FIX%s %s\n' "$R" "$Z" "$desc"
      printf '        %s↳ tried: %s%s\n' "$D" "$cmd" "$Z"; failed=$((failed+1))
    fi
  done <<< "$FIXES"

  printf '\n  %d repaired, %d could not be\n' "$applied" "$failed"
  if (( applied )); then
    printf '  %sConfig changes need a restart to take effect:%s %s\n' "$D" "$Z" "$RESTART_HINT"
    printf '  %sThen re-run without --fix to confirm what is left.%s\n' "$D" "$Z"
  fi
elif (( FIX )); then
  section "Applying safe repairs"
  printf '  Nothing to repair automatically.\n'
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
printf '\n%s────────────────────────────────────────────────%s\n' "$D" "$Z"
printf '%s%d passed%s · %s%d failed%s · %s%d warnings%s · %d skipped\n' \
  "$G" "$pass" "$Z" "$R" "$fail" "$Z" "$Y" "$warn" "$Z" "$skip"

if [[ "$fail" -gt 0 ]]; then
  printf '\n%sNot ready to hand over.%s Fix these:\n%s' "$R" "$Z" "$FAILED_LINES"
  exit 1
fi

printf '\n%sInstall looks complete.%s ' "$G" "$Z"
[[ "$warn" -gt 0 ]] && printf 'Review the %d warning(s) above, then run the smoke test in runbook step 10.\n' "$warn" \
                    || printf 'Run the smoke test in runbook step 10 to prove it end to end.\n'
exit 0
