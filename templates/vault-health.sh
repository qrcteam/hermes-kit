#!/usr/bin/env bash
# vault-health.sh — the "is the memory actually working?" watchdog.
#
# Scheduled as a --no-agent cron job, run by `hermes cron` wherever the
# gateway itself lives — INSIDE the Hermes container on a Docker install,
# directly on the host on a native one:
#   hermes cron create "0 13 * * *" --name vault-health \
#     --script vault-health.sh --no-agent --deliver telegram
#
# Two facts make this work, both verified against a running install:
#   · --no-agent script jobs bypass `approvals.cron_mode: deny`, because they
#     short-circuit before the agent loop is imported. So this runs unattended
#     even though scheduled agent *actions* are forbidden.
#   · Empty stdout = silent run. Anything printed gets delivered to Telegram.
#
# So: PRINT NOTHING WHEN EVERYTHING IS FINE. The person only hears from this
# when something needs them. A watchdog that chirps daily gets muted, and a
# muted watchdog is worse than none — which is the exact failure this guards
# against: memory quietly not being saved while everyone assumes it is.
#
# `hermes cron create --script` has no way to hand a script per-job
# environment variables, so the paths below can't just default to whichever
# install shape wrote this comment — they have to detect it at run time.
# /.dockerenv only exists inside an actual container; its absence means this
# process is running natively on the host, where /opt/data and /vault don't
# exist at all. On native, the most trustworthy vault path is whatever the
# last real promoter run recorded in STATE_FILE — same idea install-verify.sh
# uses — because that's a fact, not a guess.

set -uo pipefail

if [[ -f /.dockerenv ]]; then
  STATE_FILE="${PROMOTE_STATE:-/opt/data/promote-state.json}"
  INBOX="${INBOX:-/opt/data/inbox}"
  VAULT="${VAULT:-/vault}"
else
  STATE_FILE="${PROMOTE_STATE:-$HOME/.hermes/promote-state.json}"
  INBOX="${INBOX:-$HOME/.hermes/inbox}"
  if [[ -z "${VAULT:-}" && -f "$STATE_FILE" ]]; then
    VAULT="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("vault",""))
except Exception: pass' "$STATE_FILE" 2>/dev/null)"
  fi
  VAULT="${VAULT:-$HOME/Memory/vault}"
fi
STALE_HOURS="${STALE_HOURS:-2}"

alerts=""
add() { alerts="${alerts}• $1"$'\n'; }

# ── 1. is the promoter still running? ────────────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
  add "The promoter has never run. Nothing you've told me is being saved to your notes. (No $STATE_FILE)"
else
  age_hours="$(python3 - "$STATE_FILE" <<'PY' 2>/dev/null || echo 999
import json, sys, datetime
try:
    d = json.load(open(sys.argv[1]))
    t = datetime.datetime.strptime(d["last_run"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
    print(int((datetime.datetime.now(datetime.timezone.utc) - t).total_seconds() // 3600))
except Exception:
    print(999)
PY
)"
  if [[ "$age_hours" -gt "$STALE_HOURS" ]]; then
    add "Your notes haven't been saved in ${age_hours} hours. Anything you've told me since then is waiting, not lost — but it needs a look."
  fi

  status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status","?"))' "$STATE_FILE" 2>/dev/null || echo "?")"
  case "$status" in
    conflict) add "Your notes hit a sync conflict. Nothing is lost, but someone needs to merge it." ;;
    fatal)    add "The note-saving job is failing outright and needs attention." ;;
  esac
fi

# ── 2. anything quarantined? ─────────────────────────────────────────────────
if [[ -d "$INBOX/_rejected" ]]; then
  n="$(find "$INBOX/_rejected" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$n" -gt 0 ]] && add "$n note(s) couldn't be filed and are sitting in the rejected folder."
fi

# ── 3. is the vault actually there? ──────────────────────────────────────────
[[ -d "$VAULT/wiki" ]] || add "I can't see your notes folder at $VAULT. Recall will be wrong until that's fixed."

# ── 4. speak only if there's something to say ────────────────────────────────
if [[ -n "$alerts" ]]; then
  printf 'Heads up — your memory system needs attention:\n\n%s\n' "$alerts"
fi
exit 0
