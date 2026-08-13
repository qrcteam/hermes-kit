# HANDOFF — hermes-kit

Append-only decision log. Read the tail before starting work; append the moment a decision
crystallizes. Tags: `[decision]` `[gotcha]` `[state]`.

---

## 2026-08-12 session kit-build

**What this repo is:** a guide + templates for giving ONE non-technical person a Hermes agent
that remembers them (Hermes in Docker + markdown vault + git + Pinecone). For Mazíx, Diane
(paying client) and Doug. Not a product, not an installer — a runbook Oz follows four times.

### Decisions

- **Capture-in / promote-out is the whole architecture.** In Oz's own setup Claude Code writes
  the vault and Hermes only reads. Mazíx/Diane/Doug won't run Claude Code, so Hermes must write
  — but an agent with write access to someone's entire memory is the thing to avoid. So: agent
  stages notes in `/opt/data/inbox`, a host-side bash promoter is the ONLY privileged writer,
  vault stays mounted `:ro`. Kernel-enforced, not prompt-enforced. [decision]
- **The `:ro` on the vault mount is load-bearing.** Everything else in the design assumes it.
  Do not remove it to "make capture simpler" — that request will come up. [decision]
- **Promoter has two verbs only: create and append.** No delete, no overwrite; collision →
  `-2`. Validation lives in bash, not in the model. [decision]
- **No human review queue before promotion.** None of the three will ever work one, and an
  unreviewed queue is worse than none because it looks like a safety net. Append-only + git
  history gives retroactive review at zero user cost. [decision]
- **Per-person isolation is total** — own Pinecone ACCOUNT (not namespace), own git repo, own
  model subscription, own bot. Namespaces are a partitioning convenience, not a security
  boundary; one leaked key exposes every namespace in the index. Oz confirmed each person gets
  their own Pinecone account. [decision]
- **Diane's stack is entirely hers** — her account, her repo, her key, her sub. Test: could she
  keep using this with zero involvement from Oz if the engagement ended? [decision]
- **No one-command installer**, deliberately. Oz explicitly did not ask for one, and an
  installer you can't read is how the original setup got confusing. Runbook is written so it
  *could* become one later; if you build it, build it FROM the runbook and keep the runbook as
  source of truth. [decision]
- **Vaults live at `~/Memory/<name>-vault`.** Never Desktop/Documents/Downloads (macOS TCC),
  never inside OneDrive (Windows). [decision]
- **Install order: Mazíx → Doug → Diane.** Paying client gets the twice-debugged version.
  Doug's run proves the Windows runbook if he's on Windows. [decision]
- **Decision map published as an artifact** (private) — Oz wanted a shareable visual he can
  discuss, same motivation as the earlier `ai-stack.html`.
  URL `https://claude.ai/code/artifact/b976f9cf-f82c-41df-85b2-c588e363e464`.
  **Republish from the same file path to keep that URL**; source of truth is
  `docs/assets/decision-map.html`. [state]

### Verified against the running container — don't re-derive

- `docker exec hermes which python3 git` → python3 **3.13.5**, git **2.47.3**, runs as uid 0.
- Container sets **`HERMES_WRITE_SAFE_ROOT=/opt/data`** — Hermes already enforces the same
  boundary the design relies on. Nice confirmation, not a substitute for `:ro`.
- **`hermes cron create --script X --no-agent` BYPASSES `approvals.cron_mode: deny`** — script
  jobs short-circuit before the agent loop is imported (`cron/scheduler.py:3213`). This is what
  makes an unattended health watchdog possible while scheduled *actions* stay forbidden. [gotcha]
- **Empty stdout on a `--no-agent` cron script = silent run**; non-zero exit delivers an alert.
  `vault-health.sh` is written to print nothing when green. Do not "improve" it by adding a
  daily all-clear — a chirping watchdog gets muted, and a muted watchdog is the failure. [gotcha]
- `--script` paths must live under `~/.hermes/scripts/` (path-traversal guarded).

### Gotchas paid for in this session

- **macOS ships bash 3.2 — `mapfile` does not exist.** `promote.sh` populates arrays with a
  `while read` loop instead. Any new bash in this kit must be 3.2-safe; check with
  `/bin/bash -n`. [gotcha]
- **CRLF breaks naive frontmatter checks.** On Windows the vault sits on the Windows filesystem
  and a note hand-edited there comes back CRLF; `^---$` would silently reject every one.
  All patterns are `^---[[:space:]]*$`. Tested. [gotcha]
- **Windows two-`.hermes` trap** — the container mounts `C:\Users\<u>\.hermes` but the promoter
  in WSL defaults to WSL's own `~/.hermes`. Both exist, neither errors, nothing is ever saved.
  Runbook 03 has a `PROOF` check; make sure it stays there. [gotcha]
- **`~/OzLuv` move broke two absolute paths, silently** — the vault moved off `~/Desktop`
  mid-session (by Oz/another session) and left `$HOME/Desktop/OzLuv/scripts/pinecone-sync`
  behind in the `~/.claude/settings.json` SessionStart hook (ended in `|| true`, so it failed
  without a word) and in `~/.claude/skills/bin/sync-all.sh`. **Both fixed and verified**
  (sync runs, 251 files tracked). After any vault move, grep for the old path across
  `settings.json`, `skills/bin/`, `LaunchAgents/`, and `docker inspect hermes`. [gotcha]

### Changes made OUTSIDE this repo

- `~/OzLuv/scripts/pinecone-sync` — **multi-tenant patch**: `VAULT_ROOT`, `PINECONE_INDEX`,
  `PINECONE_STATE`, `PINECONE_KEY_FILE` all read from env with Oz's current values as defaults,
  plus an `_index` guard so a reused state file can't write into the wrong person's vectors.
  Backward-compatible; Oz's live search verified working after. Already committed to the vault
  by another session's `/end`. Copy also ships at
  `templates/vault-skeleton/scripts/pinecone-sync` — **keep the two in step**. [state]
- `~/.claude/settings.json` + `~/.claude/skills/bin/sync-all.sh` — stale Desktop paths fixed
  (see gotcha above). [state]

### Where it stopped

- **Repo is committed locally, has NO git remote.** Oz was asked; creating `qrcteam/hermes-kit`
  and pushing is still pending his word. That's the next action. [state]
- **Nothing has been installed for anyone yet.** `people/{mazix,doug,diane}.md` hold proposed
  buckets and working assumptions only — the "one job" line in each must be replaced with the
  person's real answer after the SOUL interview. [state]
- **Unconfirmed:** which of the three are on Windows. Oz said "mixed — at least one". Runbook 03
  exists but has NOT been exercised against a real Windows machine. [state]
- `promote.sh` and `vault-health.sh` are tested against a throwaway vault (create, append,
  collision, three reject paths, CRLF, silent-when-green, loud-when-red) but **have never run
  against a real Hermes install**. First real exercise is Mazíx. [state]

## 2026-08-12 session kit-build (addendum)
- Pushed to **`qrcteam/hermes-kit`**, private, default branch `master`. Supersedes the
  "no git remote" stop-point above — that thread is closed. [state]
- **`qrcteam` is a GitHub USER account, not an org** — `gh api orgs/qrcteam` 404s and the
  current `gh` token has no `admin:org` scope. It's also the account `gh` is authenticated as,
  so `gh repo create qrcteam/<name>` just works. Don't go hunting for org permissions. [gotcha]

## 2026-08-12 session tg-diagnose
- Oz reported "no telegrams back" from his own Hermes install (via Claude Telegram). NOT a crash:
  the agent's `clarify` tool asked a question at 15:15 UTC and blocked the session for its full
  3600s timeout. Oz's replies during the wait — voice notes AND short texts — never unblocked it;
  they were cached/batched but not matched to the pending clarify. It woke at 16:15 and resumed
  normally. Kit installs will hit this: users answer clarify questions by voice. [gotcha]
- Second weakness on Oz's install: primary provider (openai-codex via chatgpt.com) throws
  intermittent APIConnectionError (retries succeed at attempt 2), and BOTH fallbacks are dead —
  OpenRouter = payment/credit error, Nous = never authenticated (`hermes auth` never run).
  One bad codex day = mute agent. Check fallback health in vault-health / runbooks. [gotcha]
- Offered Oz: drop clarify timeout (60min → ~2min) + fix a fallback provider. Awaiting his word. [state]
- Set `agent.clarify_timeout: 120` in Oz's `~/.hermes/config.yaml` (was default 3600). Verified
  live in-container — clarify reads config per call, no gateway restart. Backup at
  config.yaml.bak-<utc>. Caveat from upstream docstring (#32762): very short timeouts can evict
  a clarify entry mid-think so a late button-tap lands on a dead entry — watch for it. [decision]
- Proposed Hermes→Claude delegation bridge: drop-box at ~/.hermes/handoffs/{inbox,outbox} +
  host-side watcher running `claude -p` (skills like /audit-site). Awaiting Oz's go. [state]
- **HCD PDF-refresh assignment (via Monday/ChatGPT → Oz's Telegram): already done by the
  bp-promo-1e session at 10:56 local** — coordinated via SendMessage, stood down. Live hosted
  PDF deliberately still the old priced 5-pager until Oz says swap. That session is iterating
  a new packet page 3; leave HCD's packet to it. [state]
- **`claude -p` HANGS under launchd** (LaunchAgent, launchctl submit — all forms). Parked in
  kevent with ESTABLISHED api.anthropic.com conns, ~0.5s CPU, no output even with --debug.
  NOT env (minimal-env repro works in shell), NOT keychain (security read OK under launchd),
  NOT MCP (--strict-mcp-config still hangs). Unsolved; bridge LaunchAgent UNLOADED for now.
  Bridge itself verified end-to-end when run from a user shell (8s round-trip). [gotcha]
- **Headless `claude -p` spawns the user's full MCP set, including the Telegram plugin —
  which steals the bot's single getUpdates slot and kills the interactive session's Telegram
  channel** (hit live mid-debug; plugin server.ts exits when another poller holds the token).
  Fix shipped: bridge runs claude with `--strict-mcp-config`. If Telegram goes quiet, check
  for stray headless claudes first. Interim delegation: this session watches handoffs/inbox
  with a persistent Monitor and executes tasks itself; replies to Oz sent via Bot API curl
  (token in ~/.claude/channels/<chan>/.env) while the MCP channel is down. [gotcha]
- Built `docs/install-guide/index.html` — interactive "gate card" companion to runbook 02:
  12 stamped gates w/ timestamps, per-person command substitution (mazix/doug/diane/custom),
  screenshot slots by convention (`docs/install-guide/shots/<person>/step-NN-k.png`, paste →
  correctly-named download), deviation notes, markdown log export for `people/<name>.md`.
  State is localStorage per person; page is offline/file:// safe, zero deps. Tested via
  playwright (render + stamp flow). Mirrors the Mac runbook only — Windows installs still
  go through 03 raw. [decision]
- **The offer now has a working document: `docs/08-the-offer.md`.** Journey = 6 months in
  3 phases (Initiate ~6wk install/connect · Investigate ~6wk map/learn · Innovate ~3mo
  zone-of-genius automation) + phase-4 "-ate" ongoing tier riffed at $500/mo cap 25 (name
  candidates: Elevate/Cultivate/Iterate/Accelerate — undecided). Reference copy of the offer
  = the Laurie email "Here it is in writing", SENT 2026-08-12 16:23Z, Gmail 19ff6c9a67b62e72,
  $1,500 founder price, decision due Mon 08-17. Founder cohort = 5 installs (Mazíx, Diane,
  Doug presumed, Laurie offered, 1 open). Question-stack lives in that doc — every prospect
  question the kit can't answer gets a dated row. Pricing there is DRAFT; canon moves to
  bp-promo offers.json when live. Vault notes: bp-business/ai-os-six-month-journey +
  laurie-ai-os-founding-offer (updated to SENT). [decision]
- **Retainer ruling (Oz, same day):** $2,500/mo = full-build "rock and roll" retainer
  (scheduled calls, monthly objectives); drops to $500/mo access & support (working hours,
  NO 1:1 calls, cap 25) once a STABLE STATE is reached — trigger is state, not calendar.
  Doc 08 updated; "stable place" still needs a checklist definition. [decision]
- WhatsApp channel attempted on Oz's install (`docker exec -it hermes hermes whatsapp`,
  Baileys bridge + QR wizard) — **failed, error not captured**, Oz parked it and stays on
  Telegram. Worth a real debug pass before offering WhatsApp to cohort installs (Diane/
  Laurie likely prefer it). Wizard is safely resumable; check bridge npm install + creds.json
  path in ~/.hermes when picking this back up. [state]
## 2026-08-13 session tg-diagnose (cont.)
- **OpenRouter wired into Oz's install.** Key found in all-in-one-business-app/.env (valid,
  paid tier, $20 credits / ~$15.8 remaining), added to ~/.hermes/.env, gateway restarted.
  Hermes's env reader resolves it; zero auxiliary payment/credit warnings post-restart
  (this morning's spam was pre-restart noise — docker logs spans the day, use --since).
  Auxiliary lane (smart approvals, curation) + fallback provider now live. Nous still
  unauthenticated — fine, OpenRouter covers the fallback role. [state]
- **Gate card is now the full operator guide**: per-gate "paste to Claude" prompt blocks
  (Claude-driven install is the real method — runbook 02 stays canon for the commands),
  kit-clone preflight, per-person repo OWNER (mazix/doug→qrcteam, diane→HER OWN GitHub per
  people/diane.md boundary). Hosted noindexed at beautiful-possibilities.com/kit/install/
  (snapshot in bp-promo/public/kit/install/ — re-copy on changes). Flagged to Oz: his own
  ruling says Diane installs LAST/debugged-twice; he's planning her tomorrow — his call. [decision]
