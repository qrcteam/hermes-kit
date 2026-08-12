#!/bin/bash
# claude-bridge.sh — Hermes → Claude Code delegation bridge (host side).
#
# Hermes (in its container) writes a task file to  ~/.hermes/handoffs/inbox/<slug>.md
# (container path /opt/data/handoffs/inbox/). This script — fired by launchd on
# inbox changes, plus a periodic backstop — claims each task, runs Claude Code
# headless on it, and writes the result to  ~/.hermes/handoffs/outbox/<slug>.result.md
# where Hermes polls for it.
#
# Lifecycle:   inbox/ → processing/ → outbox/ (+ original to archive/ or failed/)
# Claim is an atomic mv, so a slow run and a fresh launchd fire can't double-run a task.
#
# Install: copy to ~/.hermes/claude-bridge.sh, chmod +x, load the matching
# com.hermeskit.claude-bridge.plist LaunchAgent.
#
# SECURITY NOTE: tasks run with --dangerously-skip-permissions so audits/deploys
# don't stall on prompts. Only Hermes (the owner's own agent) writes to inbox/;
# do not point anything untrusted at that directory.

set -u

HANDOFFS="${HANDOFFS:-$HOME/.hermes/handoffs}"
CLAUDE_BIN="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
LOG="$HOME/Library/Logs/claude-bridge.log"
LOCKDIR="$HANDOFFS/.bridge.lock"

INBOX="$HANDOFFS/inbox"; PROCESSING="$HANDOFFS/processing"
OUTBOX="$HANDOFFS/outbox"; ARCHIVE="$HANDOFFS/archive"; FAILED="$HANDOFFS/failed"
mkdir -p "$INBOX" "$PROCESSING" "$OUTBOX" "$ARCHIVE" "$FAILED"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$LOG"; }

# One runner at a time. mkdir is atomic; a stale lock (>2h) is reaped.
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  if [ -n "$(find "$LOCKDIR" -maxdepth 0 -mmin +120 2>/dev/null)" ]; then
    log "reaping stale lock"; rmdir "$LOCKDIR" 2>/dev/null || exit 0
    mkdir "$LOCKDIR" 2>/dev/null || exit 0
  else
    exit 0   # another runner is active; it will drain the inbox
  fi
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

# Recover tasks orphaned in processing/ by a crash or reboot (older than 2h).
find "$PROCESSING" -type f -mmin +120 -exec mv {} "$INBOX/" \; 2>/dev/null

while :; do
  task="$(ls -1 "$INBOX" 2>/dev/null | head -1)"
  [ -z "$task" ] && break
  case "$task" in *.md|*.txt) ;; *) mv "$INBOX/$task" "$FAILED/"; log "skip non-task file: $task"; continue;; esac

  mv "$INBOX/$task" "$PROCESSING/$task" 2>/dev/null || continue   # atomic claim
  slug="${task%.*}"
  result="$OUTBOX/$slug.result.md"
  log "start: $task"

  {
    echo "# Result: $slug"
    echo "_started: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
    echo
  } > "$result.tmp"

  if (cd "$HOME" && "$CLAUDE_BIN" -p --output-format text --dangerously-skip-permissions \
        < "$PROCESSING/$task" >> "$result.tmp" 2>> "$LOG"); then
    echo >> "$result.tmp"
    echo "_finished: $(date -u +%Y-%m-%dT%H:%M:%SZ) · status: ok_" >> "$result.tmp"
    mv "$result.tmp" "$result"
    mv "$PROCESSING/$task" "$ARCHIVE/$task"
    log "done: $task"
  else
    rc=$?
    echo >> "$result.tmp"
    echo "_finished: $(date -u +%Y-%m-%dT%H:%M:%SZ) · status: FAILED (exit $rc) — see claude-bridge.log_" >> "$result.tmp"
    mv "$result.tmp" "$result"
    mv "$PROCESSING/$task" "$FAILED/$task"
    log "FAILED (exit $rc): $task"
  fi
done
