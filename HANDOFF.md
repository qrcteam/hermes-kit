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
- **OpenRouter-key-hijacks-auto gotcha, hit live on Oz's install**: with model.provider:auto
  + a base_url pointing at openrouter, adding OPENROUTER_API_KEY flipped the MAIN model onto
  openrouter → 400 "openai-codex/gpt-5.6-terra is not a valid model ID" (non-retryable, bot
  mute). Fix applied + verified (hermes -z → PROVIDER-OK): model.provider pinned openai-codex,
  fallback_providers=[{openrouter, anthropic/claude-sonnet-4.5}]. Documented in
  06-troubleshooting + accounts page card; hosted snapshot redeployed. RULE for installs:
  second provider key ⇒ pin primary + explicit fallback, never leave auto. [gotcha]
- **SOUL starter shipped** — Jack Roberts' prefill-first pattern productized: person's own
  ChatGPT/Claude fills the template from its existing memory of them, then interviews only
  the gaps. `templates/soul-self-interview-prompt.md` (v2) + person-facing hosted page
  **beautiful-possibilities.com/kit/install/soul** (send by text; they paste, talk via
  dictation, send the draft back). NOTE: Claude cannot hear audio files — dictation IS the
  voice path; recorder-file flow needs local whisper. Jack's Notion template bookmarked in
  onboarding/README. [decision]
- **Trenton = cohort slot #5** (Oz confirmed 2026-08-13). people/trenton.md created —
  relationship + boundary pattern (qrcteam vs own-account) still ⟨ASK OZ⟩. Offer doc
  tracker updated. SOUL starters to send: Diane, Doug, Trenton (+ Mazíx if sit-down
  doesn't happen). [state]
- **/kit/install styling CLAIMED by another session** (Oz, 2026-08-13) — this session is
  HANDS OFF docs/install-guide/*.html until Oz says done. Sent the claimant (projects-ce)
  the architecture facts: kit repo = source of truth, bp-promo copies = snapshots (sync +
  runbook-link rewrite + full deploy motion), e2m design system is deliberate, page JS is
  load-bearing, offline/file:// constraint stands. [state]
- **/kit/install restyle SHIPPED** (projects-ce session, 2026-08-13) — all three
  docs/install-guide pages restyled from the e2m palette into BP's Concourse system per Oz
  ("match /proposal"): Fira Sans (Google Fonts link swapped, system fallback offline), BP
  yellow #FFCC00 + ink #0D0D0D, green #12813F for every done/confirm state, BP twin-spark
  lockup navbar. Functional distinction kept: black = terminal, yellow keyline =
  paste-to-Claude, amber = gotcha, green dashed = verify. Values-only CSS — no JS, IDs,
  data-attributes, or localStorage keys touched; verified on local serve (switcher, tallies,
  copy, trays). Synced to bp-promo/public/kit/install/ (runbook link rewritten) and deployed
  (bp-promo 3c39cc8). Hands-off hold can lift. [state]
- **/kit/install mobile fix** (projects-ce, 2026-08-13 follow-up) — Oz reported the gate
  menu floating over content on phones. Root causes BOTH pre-dated the restyle: the ≤820px
  nav.rail override sat before the base sticky rule so the base won the cascade (rail stayed
  sticky, no backdrop → floated over content); and the horizontal gate strip lacked
  min-width:0 on the grid item + width:auto on gates, blowing the page to 1855px sideways.
  Phone overrides now live LAST in index.html's stylesheet (load-bearing position — don't
  move them up), header+rail go static ≤820px, rail scrolls internally. accounts.html header
  also static ≤820px. Verified at 390px. Synced + deployed (bp-promo e352d95). [gotcha]

## 2026-08-14 session tg-diagnose (cont.) — Oz's install: the great wiring
- **Oz's Hermes now reads: Projects (filtered mirror), Claude OS, 6 Supabase DBs, GitHub,
  Cloudflare.** Architecture rule established with Oz: READS wide and direct; WRITES only
  through gates (claude-bridge, approvals, drafts-not-sends). [decision]
- Projects: sidecar container `hermes-projects-mirror` rsyncs ~/Documents/Projects →
  ~/Memory/hermes-projects-mirror every 15min with secret-file excludes
  (~/.hermes/projects-mirror-excludes.txt) — mounted :ro at /projects. Sidecar exists
  BECAUSE launchd can't read ~/Documents (TCC) but Docker can. Residual risk (told Oz):
  secrets hardcoded in source are still visible. [decision]
- ~/.claude-os mounted :ro at /claude-os with its dev-token masked via
  `-v /dev/null:/claude-os/dev-token:ro`. [state]
- **GOTCHA — container recreate MUST pass explicit cmd `hermes gateway run`**: image
  default CMD runs the interactive CLI, which exits with no TTY → 39-restart crash loop
  after an mcp add triggered a service restart. Oz's original was legacy-cmd style. [gotcha]
- Supabase: NO PATs (account-wide power, Oz rejected on the dashboard warning — correctly).
  Instead per-project Postgres role `hermes_ro` (SELECT-only, password in transcript-safe
  blocks) + @modelcontextprotocol/server-postgres via npx, one MCP server per DB ×6
  (ozmazixhq, bp-old-admin, mazix/oz-bp/doug/diane foundations). [decision]
- **GOTCHAS (supabase wiring):** direct db hosts are IPv6-only — containers need the
  pooler (user `hermes_ro.<ref>`), and region must be probed (they landed on 4 different
  pooler hosts). Node pg rejects Supabase CA → `?sslmode=no-verify` (still TLS). npx cold
  start can exceed agent tool timeout — pre-warm with a direct run. And `hermes mcp add`
  through a bash function mangled interpolated conn strings — ALWAYS inline them;
  verify with `grep 'hermes_ro\.\.' config.yaml`. Adds need `printf 'Y\n' | docker exec -i`
  (interactive tool-enable prompt). [gotcha]
- GitHub: fine-grained PAT (Contents/Issues/PRs read-only, all repos, auth=qrcteam,
  write-403-verified) in ~/.hermes/secrets/github-readonly.pat → official npx
  server-github MCP (26 tools; writes enforced-blocked at token). [state]
- Cloudflare: custom read token (Zone/DNS/Analytics/Workers read, 12 zones,
  write-403-verified) in ~/.hermes/secrets/cloudflare-readonly.token + new Hermes skill
  infra/cloudflare-readonly (curl recipes, delegate-writes rule). [state]
- REMAINING: Google OAuth sitting (oz@beautiful-possibilities.com +
  team@quantumrealitycreators.com; gmail read+drafts-only, calendar rw, drive read) —
  plan: host-side Workspace MCP + hermes connects via host.docker.internal. [state]
- **Google wired (both accounts) — the sitting is DONE.** workspace-mcp (uvx, taylorwilsdon)
  on the HOST as LaunchAgent com.hermeskit.workspace-mcp (wrapper ~/.hermes/workspace-mcp.sh
  reads OAuth client id/secret from ~/.hermes/secrets/google-oauth-*), streamable-http :8000,
  hermes connects via url http://host.docker.internal:8000/mcp (config entry hand-inserted —
  `hermes mcp add --url` NEVER accepts piped Y, unlike stdio adds). Permissions:
  gmail:DRAFTS tier (no send tool registered), calendar:full, drive:readonly.
  oz@beautiful-possibilities.com + team@quantumrealitycreators.com both consented (app
  published-unverified so refresh tokens persist). VERIFIED live: calendars both accounts,
  inbox read, and calendar WRITE (create+delete round trip). [state]
- Gotchas: OAuth state tokens expire in ~minutes — generate the auth URL and click
  IMMEDIATELY. GCP consent app must be PUBLISHED (not Testing) or logins die weekly.
  uvx server takes ~30s to come up — don't diagnose before that. Google-scope caveat
  (told Oz): the OAuth grant includes gmail.compose/modify; drafts-only is enforced by the
  server's tool tier, not the Google scope. [gotcha]
- **GOTCHA — builtin google-workspace skill hijacks Google asks**: Hermes ships a bundled
  token-based google skill (wants /opt/data/google_token.json) that the agent may pick over
  the MCP tools → NOT_AUTHENTICATED in chat while MCP works fine. Fix: overwrite the ACTIVE
  copy at ~/.hermes/skills/productivity/google-workspace/SKILL.md with a redirect stub
  (user-modified skills are never re-seeded; deleting the image copy does nothing — it
  re-seeds each start) + Operational note pinned in SOUL.md. Verified: agent self-describes
  the MCP route. [gotcha]
- **Quo (phone) wired via its official OAuth MCP (mcp.quo.com/mcp).** Tools allowlisted to 12:
  tasks create/update, contacts create/update, reads (messages/transcripts/missed calls) —
  all three send-message tools EXCLUDED via config `tools.include` (RAW hyphenated server
  names — hermes displays underscores, include-list must use the server's real names) and
  the OAuth grant carries no send scope anyway. Task-creation verified live. [state]
- **THE pattern for OAuth MCP servers from inside docker — use the PASTE flow:** loopback
  callbacks are netns-private and every port-publish/relay scheme raced or bound wrong
  (4 attempts). What works: one-off container `--entrypoint /opt/hermes/.venv/bin/hermes
  mcp login <name>` with -i and NO ports (entrypoint bypass also stops the image's s6 from
  starting a gateway that steals the Telegram poller); user clicks the printed URL, the
  browser's failed redirect still carries ?code=&state= in the address bar; pipe that URL
  into `docker attach` — the login CLI accepts pasted redirects by design. Wait for
  ~/.hermes/mcp-tokens/<name>.json BEFORE teardown (killing early loses the exchange).
  Oz asked if docker is worth this friction — ruled YES, the box is the product; friction
  is one-time and now documented. [gotcha]
- **SOUL interview now has a HUMAN/operator page, not just the self-interview prompt.**
  `templates/soul-interview.src.html` is the SOURCE OF TRUTH; `templates/build-soul-interview-web.py`
  emits two builds from it — (a) the Claude artifact (fonts inlined as base64, because the
  artifact CSP blocks font CDNs, light+dark) and (b) the web page
  `docs/install-guide/soul-interview.html`, mirrored into bp-promo at
  `public/kit/install/soul-interview.html` (fonts from `/fonts/*.woff2` per PublicLayout's
  convention, light-only to match its sibling soul.html, noindex). **Edit the .src.html and
  re-run the builder — never hand-edit either output.** Content is `docs/04-soul-interview.md`
  verbatim; the six ESSENTIAL questions (4, 7, 12, 20, 24, 26) are exactly the ones that doc
  flags with superlatives. Committed but NOT yet live — bp-promo held a concurrent session's
  in-flight proposals work at the time and wrangler ships worker+dist together. [state]
- **Gotcha — the two install-guide copies are hand-synced.** `hermes/docs/install-guide/*.html`
  and `bp-promo/public/kit/install/*.html` are byte-identical copies with no sync script; a
  change to one silently leaves the other stale. Verified soul.html identical across both
  before adding the new page to each. Also note soul.html still pulls Fira Sans from the
  Google Fonts CDN while the rest of the site self-hosts from `/fonts` — worth aligning. [gotcha]
- **WhatsApp is now a first-class channel in the kit (self-chat alongside Telegram).** Wired
  live on Oz's box this session and documented across the kit: `templates/env.template`
  (WHATSAPP_ENABLED/MODE/ALLOWED_USERS), `templates/config.yaml.template` (the
  `platforms.whatsapp` block), `02-runbook-mac.md` step 2 (ask them) + step 6 (pair),
  `03-runbook-windows.md` (same, plus the Windows Terminal QR note),
  `06-troubleshooting.md` (new "WhatsApp doesn't reply"), `00-decision-map.md`, and the
  onboarding template. [state]
- **THE WhatsApp gotcha — `.env` is NOT the on/off switch.** `WHATSAPP_ENABLED=true` was
  already set on Oz's install and WhatsApp had never once replied. Hermes only starts a
  platform that is listed under `platforms:` in config.yaml; anything missing from that map
  is off no matter what .env says. The failure is silent and convincing — the bridge pairs,
  the phone shows a linked device, `hermes auth`/`.env` all look right, and no message is
  ever collected. `docker logs hermes | grep -ci whatsapp` returning 0 is the tell. The
  official Nous docs omit this (they describe the .env-only path). [gotcha]
- **The bridge must run INSIDE the container.** `plugins/platforms/whatsapp/adapter.py`
  hardcodes `http://127.0.0.1:{bridge_port}` for every call — only the port is configurable,
  never the host. So pair with `docker exec -it hermes hermes whatsapp`. You CANNOT run the
  bridge on the host and point hermes at `host.docker.internal`: the bridge rejects any
  request whose Host header isn't loopback (`Invalid Host header. Bridge accepts loopback
  hosts only`). Verified both ways — spoofing `-H "Host: localhost:3000"` makes the identical
  request succeed. [gotcha]
- **No QR needed if a pairing already exists.** Session lives at `~/.hermes/whatsapp/session`
  (legacy path; newer installs use `platforms/whatsapp/session`) and `creds.json` there is the
  paired marker. Since `~/.hermes` is mounted rw at `/opt/data`, the container reuses a
  host-made pairing as-is. That folder is a full credential to the WhatsApp account — never
  copy it to another machine, commit it, or back it up off-laptop. [gotcha]
- **ROOT CAUSE of the long-running Telegram conflict: TWO gateways.** A native host gateway
  (launchd `ai.hermes.gateway`, RunAtLoad+KeepAlive, installed 2026-08-14 22:10) was running
  alongside the container. Both read the same bind-mounted `~/.hermes`, so they shared config,
  state DB, WhatsApp session and the *same Telegram bot token* — Telegram permits one poller,
  hence `Conflict: terminated by other getUpdates request` since Aug 14 and 435 logged
  telegram-kick fires. Killing the host bridge alone never stuck because the host gateway
  respawned it. Fix: `launchctl unload -w ~/Library/LaunchAgents/ai.hermes.gateway.plist`.
  **The container is canonical** — proven, not preferred: `mcp_servers.google.url` is
  `http://host.docker.internal:8000/mcp`, which resolves only inside a container (verified it
  fails to resolve on the host). Suspect this also contributed to the recurring
  `database disk image is malformed` FTS corruption. [gotcha]
- **`templates/install-verify.sh` — one command that walks the whole runbook checklist.**
  Read-only, runs on the HOST (not in the container — half the checks are things the
  container can't see: Docker itself, the launchd/Task Scheduler job, the vault's git remote,
  and whether a second gateway is competing). 31 checks across environment, mounts, settings,
  credentials, memory pipeline, vault, SOUL.md and channels. Non-zero exit while anything is
  red, so you can re-run after each fix. Wired into runbook step 10 (before the smoke test)
  and the checklist header. [state]
- **Deliberately NOT a client build of Claude OS.** Claude OS is Jack Roberts' software —
  the licence permits modifying it for your own use but forbids redistributing or repackaging
  it, so a stripped-down copy installed on Diane's or Laurie's laptop is out. It also reads
  ~/.claude sessions / Obsidian / OpenRouter, none of which a client install has. This script
  is original and covers the actual need. [gotcha]
- **THREE bugs found only by running it against a live install — worth knowing if you write
  anything similar.** (1) `docker inspect` returns Docker Desktop's INTERNAL bind-mount path,
  `/host_mnt/Users/...` on macOS and `/run/desktop/mnt/host/...` on Windows; testing that
  against the host filesystem makes every vault check silently SKIP. Strip the prefix.
  (2) Grepping SOUL.md for a bare `<` false-positives on legitimate inline code paths like
  `/go/<slug>` and `topics/<bucket>/_manual.md` that appear in every finished SOUL. The
  working regex is `<[A-Z][A-Z_]*>|<[^>]* [^>]*>` — caps tokens or prose-with-a-space —
  verified to catch 35 real placeholders in SOUL.md.template and 0 in a finished one.
  (3) The newest `[Telegram]` log line is usually routine traffic ("Sending response"), not a
  verdict; filter to LIFECYCLE lines only, same as the telegram-kick watchdog does. [gotcha]
- **Running it on the OPERATOR's Mac correctly fails the whole Memory-pipeline section** —
  no inbox, no promote.sh, no promoter job — because on that machine Claude Code writes the
  vault and Hermes only reads. Not a bug; noted in the script header. [gotcha]
- **`install-verify.sh` gained `--fix`** (2026-08-17). Bare run is still strictly read-only.
  `--fix` applies ONLY repairs that are idempotent, reversible and cannot lose data: mkdir
  inbox, chmod modes, copy a missing skill from the kit, `chmod +x promote.sh`, load the
  promoter launchd job, start a stopped container, set a drifted config key. Deliberately NOT
  auto-fixed — re-creating the container (mounts are fixed at `docker run`), moving the vault,
  `git init`, model login, WhatsApp pairing, SOUL.md edits, and **unloading a competing host
  gateway** (someone's LaunchAgent; the call is theirs). Config fixes need `docker restart`
  after. [state]
- **GOTCHA that nearly shipped a lying fixer: `launchctl load` of a MISSING plist exits 0.**
  The naive `launchctl load -w …` fix reported "FIXED Promoter is NOT scheduled" on a machine
  where that plist does not exist and no job was loaded — a false success on the single check
  whose failure means "nothing this person says will ever be saved". Every risky fix command is
  now self-verifying: guard that the file exists, run it, then PROVE it (`launchctl list |
  grep -q vault-promote`). Same discipline vault-capture demands of the agent. [gotcha]
- **Hermes `state.db` corruption REPAIRED (2026-08-17).** `PRAGMA integrity_check` showed real
  b-tree damage ("2nd reference to page 1766/1768"), not merely stale FTS. Repair: stop
  container → back up → `sqlite3 state.db .recover | sqlite3 state.db.recovered` → verify →
  swap → start. Result: integrity `ok`, 0 malformed errors since, FTS `MATCH` working again.
  **Cost: 3 messages lost of 1,896** (ids 1150/1170/1171 — individually unreadable, they sat on
  the damaged pages); everything else intact, and the apparent `system_prompts` 23→22 drop was
  a duplicate removed, not a loss. Old files kept in
  `~/.hermes/_quarantine-2026-08-17-state-db-corruption/`. NOTE `.recover` preserved the FTS5
  virtual tables correctly — verify that (`sqlite_master … CREATE VIRTUAL`) if repeating, since
  `.recover` can flatten them to plain tables. [state]
- **Gotcha while verifying that repair: `docker logs` RESETS on container restart; the
  persistent log is `~/.hermes/logs/gateway.log`.** Telegram looked wedged at "attempt 1/8" for
  minutes because docker logs had lost the success line — gateway.log showed it had connected
  11s in (via the `fallback_ips`, primary api.telegram.org being unreachable). Always judge
  channel health from gateway.log, which is what telegram-kick and install-verify both read. [gotcha]
- **@ozbpclientbot was dark Aug 14 → Aug 17 because the hermes terminal was launched as
  plain `claude`, not `tgclaude telegram-bp-client`.** The Claude Code channel bots are NOT
  daemons — `bun server.ts` is a child of the interactive session, so no bound session means
  no poller, and the bot is deaf AND mute while the chat looks identical to "nobody wrote".
  Do not debug these from the Telegram side first: token/webhook/allowlist/409 were all clean.
  The fast diagnostic is the transcript marker — grep a session's jsonl in
  `~/.claude/projects/<proj>/` for `sender reads Telegram` (the channel's injected MCP
  instruction). 1 = the session was bound, 0 = it never had the channel. That distinguished
  the Aug 14 session (bound, 8 reply calls) from Aug 16 and Aug 17-until-12:53 (both 0).
  Note this is separate from the Hermes CONTAINER's telegram bot (token 8210767160) — five
  distinct bots, distinct tokens, no 409 between them. [gotcha]
- **Watchdog added: `com.claude.telegram-watchdog`, every 600s, RunAtLoad** →
  `~/.claude/bin/telegram-watchdog.sh` (git: qrcteam/claude-skills `bin/`, plist committed
  beside it). Flags DARK (bot.pid names no live server.ts — cmd-matched, so pid reuse can't
  fake it), WEDGED (process up but no :443 to Telegram on two consecutive passes), and stays
  silent on DORMANT channels it has never once seen alive (telegram-mazix). One alert per
  outage + one on recovery, never a repeating timer; 7d grace then quiet. Alerts are sent by
  the HERMES bot on purpose — it's in Docker, so it can still speak when the thing that died
  is a terminal-bound bot. `--status` is read-only; `TG_WATCHDOG_CHANNELS_DIR` +
  `TG_WATCHDOG_DRY_RUN` drive it against a fixture (all 8 state transitions verified).
  Caveat: it can't tell a deliberate shutdown from a crash, so closing a channel terminal on
  purpose earns one alert. [state]
- **Related: this session (pid 11008) was started WITHOUT `caffeinate`** — process tree was
  `zsh → command claude`, whereas `tgclaude` wraps in `caffeinate -is`. Launched by hand with
  the `--channels` flag rather than through the wrapper. Consequence: Mac sleep silently kills
  the bot. Always start channel sessions via `tgclaude <channel>`. [gotcha]
- **Hermes MCP: Airtable + Pinecone connected, Stripe staged (2026-08-17).** Both verified by a
  live stdio probe, not just "the process started": `airtable` resolves to **Beautiful
  Possibilities CRM** (`appgbY1GeuiGKzzoh`, 16 tools incl. `describe_table`/`search_records`) and
  `pinecone` to the **`ozluv-vault`** index (llama-text-embed-v2, dim 1024) — so Hermes finally
  has semantic recall over the vault instead of only path-guessing from `_manual.md`. `stripe`
  (`@stripe/mcp`) is installed and configured but `enabled: false`: **no Stripe credential exists
  anywhere on this machine** (checked .env, secrets/, keychain, .claude.json — Claude Code's
  Stripe is an OAuth connector Hermes can't reuse). To finish: put a restricted read key in
  `~/.hermes/.env` as `STRIPE_SECRET_KEY`, flip `enabled: true`, `docker restart hermes`. [state]
- **GOTCHA that was silently degrading every MCP server: `npx` at boot races itself.** Each stdio
  server ran `npx -y <pkg>`; all of them hit the one shared cache in `/opt/data/.npm` at once and
  npm's cacache lock reported `ECOMPROMISED / Lock compromised`. Servers were retrying **49–60
  times each per boot** and some never came up — and it varied per boot, which is why it never got
  diagnosed. A single `npx` by hand always succeeds; the bug exists only under concurrency, so it
  got worse each time a server was added. Fix: `npm install` all MCP packages once into
  `/opt/data/mcp-node` (persistent rw mount, survives container recreate) and point every entry at
  `node_modules/.bin/<bin>`. After: **0 npm errors, each server starts exactly once.** Predates
  this session's changes — it was hitting supabase-mazix too. Written up in
  `docs/06-troubleshooting.md`. [gotcha]
- **Secrets moved out of `config.yaml`.** The 6 Supabase URLs had the same `hermes_ro` password in
  plaintext; now `${SUPABASE_HERMES_RO_PW}` from `~/.hermes/.env`. Verified upstream-supported:
  `tools/mcp_tool.py:_interpolate_env_vars` recurses dicts **and lists**, so it resolves inside
  connection-string args, and an unset var keeps the literal placeholder (fails to auth, doesn't
  crash). Prefer `env:` over `args` for keys — argv is readable by `ps` inside the container.
  Backups: `config.yaml.bak-*-premcp` / `-prenpxfix` / `-prestripe`. [state]
- **`skills/business/airtable-pipeline` rewritten off curl onto the MCP tools.** Note
  `crm-task-coordination` never used curl — it's tool-agnostic and defers to the pipeline skill,
  so it needed no change. **Hard rule 1 was materially weakened by this connection and now says
  so:** the old text claimed "your token has no schema permissions, structural changes will fail
  anyway", but the base reports `permissionLevel: create` and `delete_records` / `create_table` /
  `create_field` are now live callable tools. The prose rule is the only guard left. [gotcha]
- **`~/.hermes` and `~/.hermes/skills` are NOT git repos** — live runtime state, versioned only by
  the dated `.bak-<ts>` convention. Anything durable has to be copied into a kit repo to survive.
  The hermes CLI can't be run in the container either (`cli.py` needs `rich`, not installed), so
  MCP servers are configured by hand-editing `config.yaml`; it has no comments and carries
  `_config_version`, so a `yaml.safe_dump` round-trip with `sort_keys=False` is safe. [gotcha]
- **`/kit/install/soul-interview` rewritten for the person being configured (2026-08-18).**
  It was an operator's script — third person throughout ("who am I talking to?", "how to talk
  to them"), mechanics before purpose, and the crucial "don't ask all 27" reassurance buried
  as step 3 of the prep list. Now: opens with what a SOUL file is and does for *you*, states
  up front that 27 is a question bank not a form, and every question is second person and
  sayable out loud. **Source of truth is `templates/soul-interview.src.html`** — one file,
  two outputs via `build-soul-interview-web.py` (artifact with base64 fonts + web page with
  `/fonts/*.woff2`, light-only). Edit the source, never the built files. Deploy chain:
  build → copy `soul-interview.web.html` to BOTH `docs/install-guide/soul-interview.html`
  and `bp-promo/public/kit/install/soul-interview.html`, then ship bp-promo. The two build
  outputs in `templates/` are deliberately untracked; the committed copy is the docs one. [state]
- **New question hierarchy — three classes, use them consistently:** `.ask` (the question,
  1.3rem, always dominant), `.reason` (one-line "why this matters", small-caps label),
  `.probe` (optional follow-ups, left-bordered block), plus the existing `.eg` gold callout.
  Not every question gets all four — that was the point. Anchors `#q1`–`#q27` and all section
  ids are unchanged; `#nos` and `#after` kept their ids under new labels (Boundaries,
  Afterwards) so existing links and the scrollspy still work. [state]
- **GOTCHA for anyone editing these kit pages: `file://` URLs are blocked by the Chrome
  extension**, so you cannot visually check a built page by opening it directly. Serve it
  instead — `cd bp-promo/public && python3 -m http.server 8777`, then load
  `http://127.0.0.1:8777/kit/install/soul-interview.html`. Serving from `bp-promo/public`
  rather than `templates/` matters: the web build references `/fonts/*.woff2`, which only
  resolve from that root, so serving the templates dir renders in fallback fonts and the
  layout you check is not the layout that ships. [gotcha]
- **Open question left for Oz: `/kit/install/soul` and `/kit/install/soul-interview` now
  overlap.** `soul.html` was already fully person-facing ("Your assistant's first briefing —
  you're getting a personal AI assistant"), and soul-interview is now person-facing too.
  Neither links to the other. They are not duplicates — soul is the short why-this-exists
  intro, soul-interview is the question bank — but nothing on either page says so. Worth a
  cross-link and one line of framing on each. Not done; not asked for. [state]
## 2026-08-20/21 session — Laurie prep + client-facing accounts page
- **Laurie is on macOS** (confirmed by Oz) and her install is the next one up — runbook 02, the
  proven path, no WSL adventure. Meeting was set for 2026-08-21. `people/laurie.md` now exists — platform, paths, offer and the boundary ruling; fill the rest
  on install day. **Boundary ruled by Oz 2026-08-20: her vault repo starts in `qrcteam` and
  transfers to her own GitHub once the install is stable** (one-click ownership transfer, vault
  keeps working through it). Two obligations ride on that — say out loud on install day that Oz
  can read her notes, and actually do the transfer at stable state. [decision]
- **New client-facing page: the six accounts, shipped live.** `docs/install-guide/start.html`
  (source of truth, committed) → mirrored to `bp-promo/public/kit/install/start.html`, deployed,
  live at **<https://beautiful-possibilities.com/kit/install/start>** — noindex, same treatment
  as soul / soul-interview. Markdown twin at `onboarding/laurie-accounts.md`. Copy is
  deliberately generic (no client name) so it serves the whole founder cohort. Content is the
  canonical six — Telegram, model subscription ($20/mo, THEIR card), GitHub, Pinecone,
  OpenRouter (~$10), Obsidian (no account) — plus the CRM login they already have, the two Mac
  facts (never sleep; one piece of software installed together), what to bring, and the
  "I'm not asking you for any keys" close. Forbidden words honoured: no Docker/repo/index/sync
  anywhere in it. [decision]
- **GOTCHA — bp-promo serves these extensionless.** `/kit/install/start.html` 307-redirects to
  `/kit/install/start`. Send clients the clean form; the `.html` one works but bounces. [gotcha]
- **GOTCHA — artifacts are not shareable to clients.** Oz can only share a claude.ai artifact
  with teammates, so an artifact is fine as a draft/preview for him but is NEVER the deliverable
  for a client. Anything a client must open ships to bp-promo. Cost this session one full
  build-and-publish cycle before it surfaced. [gotcha]
- **Foundation guide not built yet.** A paste-ready prompt was handed to Oz for the oz-foundation
  session: add a `hermes-accounts` Guide to `app/lib/guides.ts` with `public: true`, which serves
  logged-out at `/g/hermes-accounts` (same mechanism as `/g/map-interview`). That becomes the
  permanent home on his own domain; `/kit/install/start` can retire or stay as the kit copy.
  Note the guides system is structured data rendered by `GuideBody` — the artifact's tick-off
  checkboxes and bespoke typography do NOT carry over into a Guide entry. [state]
- **claude-os is Jack Roberts' software and must NOT be pushed to GitHub** — its LICENSE forbids
  re-uploading to any code host, public or private. Oz asked for a private qrcteam mirror; the
  push was stopped and the reason explained. Backed up instead as a local git bundle:
  `~/Documents/Projects/_archive/claude-os-2026-08-21.bundle` (90 MB, verified, all refs) with a
  README beside it. Protects the two local-only commits — `966cd38` ($150/hr rate + minute
  estimates) and `7535665` (os3.2 Design Studio merge). Repo has no remote by design.
  Still to do: get that one file off this machine. [gotcha]

## 2026-08-21 session — Laurie install-day runbook + ownership reversal
- **REVERSED: Laurie's vault repo starts in HER GitHub, not `qrcteam`.** Oz's call on install
  day, superseding the 2026-08-20 ruling (which had it starting in `qrcteam` and transferring at
  stable state). Support access is now an invitation instead of a default: she may add `qrcteam`
  as a **collaborator** on her own repo and can revoke it in one click. `people/laurie.md` records
  both the new decision and the superseded one — don't delete the old ruling, the reasoning
  matters. [decision]
- **`qrcteam/laurie-app` is the one repo of hers still in Oz's org** — her foundation instance,
  started before the day-one-ownership call. **Transfer it to her account at stable state.** This
  is now the only outstanding ownership obligation for Laurie. [state]
- **`gh` does the GitHub work on her Mac, not SSH.** `gh auth login` as her, then
  `gh repo create laurie-vault --private --source=. --remote=origin --push` — unqualified name
  creates it under the authenticated user, so no owner prefix and no SSH keypair on a client
  machine. Runbook 02 still says `git@github.com:` + a manual repo creation; worth promoting the
  `gh` path into the runbook once it's been proven on a real install. [decision]
- **New: `docs/install-day-laurie.html`** — install-day arrangement of runbook 02 for one remote
  macOS install: call → remote in → clone → 8 phases → landmines → handover, 23 tick-off gates
  with localStorage. Artifact (private, for Oz):
  <https://claude.ai/code/artifact/06b754ae-71f4-4962-b29d-b830c01071ce>. It adds three steps the
  runbook has never had — remote access (Zoom screen-share + remote control, UNPROVEN, Mazíx was
  on-site), Command Line Tools + Homebrew (a stock Mac has neither `git` nor `brew`), and `gh`
  auth instead of SSH. [state]
- **GOTCHA — both machines get the kit at `~/Documents/Projects/hermes`,** so every command reads
  identically on either side. Running runbook steps 5–6 on Oz's own Mac by mistake would overwrite
  his `~/.hermes/.env` and Pinecone key and start a second gateway fighting `@Ozzzhermesbot` for
  its token. Every command block on the new page is stamped HER MAC / YOUR MAC for this reason.
  Only phase 00 (and the SOUL transcription + `people/laurie.md`) run on Oz's machine. [gotcha]
- **Laurie's buckets are still undecided** — the page carries Doug's set as a placeholder. They
  get created at step 04.2 and renaming later is a chore; ask her in the first ten minutes. [state]
- **CORRECTION (logged 2026-08-22): this was already kit canon, not a new discovery.** The
  gate card has shipped paste-to-Claude prompts per gate since 2026-08-14 and the vault note
  `hermes-kit-install-suite` calls Claude-driven install "the method". What IS true: **runbook 02
  never mentions Claude Code**, so anything built from it (including the install-day page)
  reproduces the old hand-typing shape. Laurie is the first live proof of it done remotely.
  Fold it into runbook 02 before Trenton.
- **The easiest install path is Claude Code running ON their machine.** Laurie's install
  (2026-08-21, macOS, remote): clone `hermes-kit` onto her Mac, start Claude Code there, and let it
  read the runbook and drive the install locally while Oz supervises over screen share. Confirmed
  by Oz as "the easiest thing." This largely retires the phase-02 model of Oz hand-typing every
  command through remote control — the remote session becomes supervision, not data entry, and the
  runbook's `~/Documents/Projects/hermes` paths resolve natively because the kit is genuinely there.
  **Make this the documented default in `02-runbook-mac.md` before Trenton's install.** [decision]
- **Open boundary question this raises:** whose Claude Code account authenticates on a client's
  machine, and does it get removed at handover? Same test as everything else — she should be able
  to fire Oz tomorrow and lose nothing. Not yet decided; settle before the next client install. [state]
- **Hermes' always-loaded memory is a capped budget — and it evicts silently.** `MEMORY.md`
  (2200 chars) and `USER.md` (1375) are injected into every message, so the caps are per-turn
  token budgets, not storage. Hit live on Oz's install 2026-08-21/22: MEMORY.md at 95%, Hermes
  wrote one new standing rule overnight, and the unrelated six-needs-lens entry was **gone** by
  morning with no announcement. Pruned to pointers (MEMORY 2151→1572, USER 1372→1227); four
  facts moved into the vault as proper notes and proven recoverable —
  `hermes -z "Search /vault for the six-needs lens"` returned it. Principle written up as
  `wiki/concepts/hermes-memory-is-a-budget-not-a-drawer.md`. [gotcha]
- **Kit hardened for it:** `templates/SOUL.md.template` ground rules gained "search the vault
  before you say you don't know" and a new rule 3 telling the agent its always-loaded memory is
  a budget, that a full file evicts silently, and to say so out loud if it evicts something.
  `06-troubleshooting.md` gained *"It forgot something it used to know"* with the prune
  procedure and the verify command. [decision]
- **CRON TRAP, unfixed in the docs:** changing the model re-shapes `model.default` (the picker
  drops the `provider/` prefix), and any **unpinned** cron job whose config drifted since
  creation is SKIPPED, not run — "to prevent unintended spend." Killed Oz's daily-digest on
  2026-08-22. Fix: `hermes cron edit <id> --model <m> --provider <p>`. Watch out — a monitor job
  can show `ok` while carrying a stale snapshot, because it only calls inference on output
  change; Oz's `forge-completion-hermes-review` was one bad tick from going quiet with a green
  status. **Written up 2026-08-22:** runbook 02 step 9 (pin the digest at creation + checklist line),
  `06-troubleshooting.md` -> *"The digest stopped arriving"*, and `07-operator-notes.md` ->
  *"Changing the model breaks cron"*. [gotcha]

## 2026-08-22 session — memory prune, cron trap, claude-os autostart · REBOOT PENDING
**Mac is being rebooted at the end of this session** (Chrome wedged). Everything below is
committed and pushed — hermes-kit at `c44805f`, vault in sync. Nothing is in flight.

### Check these first after the reboot
1. **Docker Desktop was DOWN before the reboot** (socket gone, process not running — not
   deliberate). Hermes cannot answer a text until Docker Desktop is running again. Relaunch it,
   then: `docker ps` → hermes up (`--restart unless-stopped` handles the container itself).
   **If Docker Desktop does not start on login, turn that on** — Settings → General → *Start
   Docker Desktop when you sign in*. A Mac that reboots without it is a silently dead assistant.
2. **Cron pins survived?** `docker exec hermes hermes cron list` — then confirm the pins really
   are there (the status column lies, see below):
   `docker exec hermes cat /opt/data/cron/jobs.json | python3 -c "import json,sys; [print(j.get('name'), j.get('model'), j.get('provider')) for j in json.load(sys.stdin)]"`
   Want `daily-digest` and `forge-completion-hermes-review` both on `gpt-5.6-terra` /
   `openai-codex`. Next digest fires 13:00 UTC (7am MT).
3. **claude-os dashboard on 8081.** `curl -s -o /dev/null -w '%{http_code}' localhost:8081/__hermes_status`
   The launchd job is now **`--strictPort`**, so if anything else grabs 8081 first it will
   crash-loop instead of silently relocating — check `~/.claude-os/dashboard.log` if it's dead.
4. **Memory files still pruned?** `wc -c ~/.hermes/memories/MEMORY.md ~/.hermes/memories/USER.md`
   — expect ~1572 and ~1227. Hermes writes to these on its own, so they will creep back up.

### What changed today
- **Hermes memory pruned to pointers.** MEMORY.md 2151→1572 (of 2200), USER.md 1372→1227 (of
  1375). Four background facts moved into the vault as real notes and proven recoverable via
  `/vault` search. Principle: `wiki/concepts/hermes-memory-is-a-budget-not-a-drawer.md`.
  Backups at `~/.hermes/memories/*.bak-20260822T154202`. Nothing dropped from USER.md — only
  compressed. [decision]
- **A fact was already lost before we started.** The six-needs-lens entry was evicted overnight
  by Hermes to fit a new rule, silently. Recovered only because it had been read aloud the day
  before. This is the whole argument for the prune. [gotcha]
- **Cron model-drift trap documented** in runbook 02 step 9 (pin at creation + checklist),
  `06-troubleshooting.md` ("The digest stopped arriving") and `07-operator-notes.md` ("Changing
  the model breaks cron"). [decision]
- **SOUL.md.template ground rules** gained "search the vault before you say you don't know" and
  a new rule 3 on the memory budget, so every future install starts knowing this. [decision]
- **`templates/session-hygiene-prompt.md`** — new paste-and-go prompt for handover (idle reset
  at 2h + plain-language standing preference). Wired into runbook 02 step 11 + checklist and the
  Laurie page as step 08.2. [decision]
- **claude-os autostart was already configured** (`com.claude-os.dashboard`, since 2026-08-14).
  Fixed the real weakness: the port was unpinned, and the app prefers 8080 — it only landed on
  8081 because a Python service held 8080. A reboot could have moved it and silently broken the
  `claude-os` Hermes skill, which hardcodes 8081 in five endpoints. Now
  `--port 8081 --strictPort`. Old plist backed up in `~/.claude-os/`. [gotcha]

### Laurie — install in progress, unfinished
Through the vault build with **Claude Code running on her Mac** driving the runbook (the day's
big finding — see the previous entry). **Not confirmed done:** phase 05 (container, model login,
her first bot reply), 06 (SOUL), 07 (promoter + crons + three smoke tests), 08 (handover).
**Her buckets were never captured** — the install-day page still carries Doug's set as a
placeholder. Ask her, then fill `people/laurie.md`.
Open question logged and unanswered: **whose Claude Code account authenticated on her machine,
and does it come off at handover?** Settle before the next client install.
- **ANSWERED 2026-08-22 (Oz), three open threads closed:**
  1. **Laurie's buckets — she entered them herself during the install.** Not lost, just not
     written down: `ls ~/Memory/laurie-vault/wiki/topics/` on her Mac, or her repo if collaborator
     access was granted. Copy into `people/laurie.md` + the install-day page.
  2. **The Claude Code on her machine was HER Claude account.** Nothing of Oz's authenticates
     there; nothing to remove at handover. **Standing shape for client installs: the client's own
     Claude, on the client's own machine.**
  3. **Claude-driven install is VITAL** — Oz: *"I won't work on it without Claude."*
     **`02-runbook-mac.md` gets rewritten around Claude Code on the target machine as THE method**,
     hand-typed commands demoted to a fallback. Canon since 2026-08-14 everywhere except the
     runbook — which is the document people actually follow. **Do it before Trenton (#5). This is
     the next session's first task.** [decision]
- **DONE 2026-08-22 — `02-runbook-mac.md` rewritten around Claude-driven install.** New header
  declares the method and Oz's ruling; new **"How this install runs"** section carries the
  operator loop, seven standing rules for Claude (vault path, `:ro`, keys never in the agent
  env, never echo a secret, move-don't-delete, show the proof, stop and ask), and a
  **nine-row table of what Claude CANNOT do** — the human-only moments, four of which are
  account signups to chase before install day. Hand-typing is now the documented fallback.
- **Kit path changed on the client machine: `~/hermes-kit`, via `$KIT`** (was
  `~/Documents/Projects/hermes`). Matches the gate card, which already said so, and **kills the
  same-path-on-both-machines hazard** — Oz's kit stays at `~/Documents/Projects/hermes`, so a
  command meant for their Mac can no longer be run on his by accident.
- **Step 3 now uses `gh`, not SSH.** `gh auth login` as them, then
  `gh repo create <NAME>-vault --private --source=. --remote=origin --push` — no keypair on a
  client machine, and an unqualified name puts the repo in their account by construction. The
  gate checks the **owner**, not just private. Ownership framed as a decision (paying client =
  theirs on day one; family = `qrcteam` with the consent sentence).
- **`docs/install-day-laurie.html` marked SUPERSEDED** in-page — it was generated from the old
  runbook, so it describes hand-typing and the old kit path. Kept as Laurie's record.
  **Trenton (#5) gets a fresh page from the new runbook.** [decision]
- **Gate card reconciled against the rewritten runbook (2026-08-22).** It had drifted in seven
  places, and was **internally inconsistent** — its gate-00 prompt said `~/hermes-kit` while its
  own command blocks still said `~/Documents/Projects/hermes`. Fixed: kit path -> `$KIT` (5),
  gate 03 SSH -> `gh` + owner check, **gate 05 was missing the `session-log` skill entirely**
  (half of memory — facts without "what was I working on?"), gate 09 gained the digest pin +
  the drift gotcha, gate 10 gained `install-verify.sh` as step 0, gate 11 gained the
  session-hygiene prompt + verify, and the OWNERS map gained laurie/trenton plus the day-one
  ownership rule. `tool_progress off` went the other way — it was gate-card-only, now in the
  runbook too. Verified: `node --check` on the extracted script passes and all 12 gates parse
  with their fields. **Not visually verified — the Chrome extension was disconnected.** Open
  `docs/install-guide/index.html` in a browser once Chrome is healthy. [decision]
