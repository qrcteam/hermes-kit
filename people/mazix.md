# Mazíx Mahalel

**Status:** INSTALLING — started 2026-08-13, memory pipeline verified end-to-end 2026-08-28
(gates 00–09 pass on a native-mode `install-verify.sh`; 10 smoke test and 11 handover not done)
**Platform:** macOS (confirmed — Homebrew install) · **Installed:** in progress 2026-08-13

> No secrets in this file. Names of things, not values.

## The one job

> *<Fill in from the SOUL interview. Working assumption: catch ideas before they evaporate,
> and hold the creative thread across days.>*

Life and business partner; the QRC / OzMazix side. IG **@mazix.mahalel** — her voice, not Oz's,
and the agent must never conflate the two.

## Paths

| | |
|---|---|
| Vault | `~/Memory/mazix-vault` |
| Git remote | `qrcteam/mazix-vault` (private) |
| Pinecone index | `mazix-vault` — **her own account** |
| Bot | `@<tbd>` |
| Model | **her own** subscription |
| Digest | see below — probably not a daily |

## Buckets — proposed, confirm with her

`creative` · `qrc-brand` · `health` · `home` · `personal`

**Why these:** her work isn't project-shaped the way Doug's is, so a `projects` bucket would
sit empty while everything piled into one place. Split by *area of life* instead of by
deliverable.

## Notes for this install

- **She's the first real run.** Follow [`02-runbook-mac.md`](../docs/02-runbook-mac.md)
  verbatim, no improvising. Every place you reach for knowledge that isn't on the page is a gap
  to fix in the doc before Doug.
- **Lean hard on capture, light on digest.** For a creative person a daily status report is
  noise. Consider the variant in
  [`05-make-it-useful.md`](../docs/05-make-it-useful.md) that surfaces one idea she captured
  and never came back to, and asks her a question about it. Or skip the digest for the first
  fortnight and see if she misses it.
- **Voice notes will be most of the input.** Confirm STT is on and test one on day one.
- **The `personal` bucket should welcome the poetic and philosophical** — that register is real
  work on this side of the house, not noise to be tidied away.

## Boundary

Family, shared life. Repo can live in `qrcteam` where Oz can support it. **Say out loud that he
can read it** — consent, not assumption.

Pinecone on her own account regardless. It costs nothing and it's the right default.

## Deviations from the runbook

- **Runs native, not Docker.** Gateway is a launchd job (`ai.hermes.gateway`) running
  `hermes_cli.main gateway run` directly against a venv at `~/.hermes/hermes-agent/venv`, not
  a container. There is no `/vault` or `/opt/data` mount — real paths are `~/Memory/mazix-vault`
  and `~/.hermes/inbox`. `install-verify.sh` is Docker-only (`docker exec`, `docker inspect`)
  and will not run cleanly against this install as-is; verified everything by hand instead
  (2026-08-28).
- **A second, separate memory system exists outside the kit: `~/Memory/mazix-memory`** (moved
  2026-08-28 from `~/Documents/mazix-memory`). Her `SOUL.md` routes real day-to-day work — Main
  Room, Ravenous Room, Agenda, Care Rhythm, the "Moon Power 🌝" reset ritual — through this
  Obsidian vault directly, with Hermes given explicit read/write trust over it (no inbox, no
  promoter, no validation — by design, since it holds living documents that get edited in
  place, e.g. "strike a completed agenda item," not append-only facts). **This is not a
  duplicate of `~/Memory/mazix-vault` and should not be merged into it** — the vault pipeline's
  create-or-append-only design cannot represent an in-place edit at all. Origin: she (or a
  session working with her) built this on 2026-08-27 after discovering "the configured Vault
  path was invalid" — which was this exact install's real bug, the promoter having never been
  scheduled (see the 2026-08-28 entry below). Now git-backed the same way: private repo
  `qrcteam/mazix-memory`, `~/.hermes/scripts/memory-sync.sh` auto-commits and pushes every
  15 min via `com.mazix.memory-sync.plist` (not a kit template — bespoke to this person's
  setup). "The Ravenous Book" subfolder was already its own separate repo
  (`qrcteam/the-ravenous-book`) before any of this and stayed that way, `.gitignore`d out of
  the parent repo to avoid nesting.

## Log

| Date | What |
|---|---|
| 2026-08-13 | Install started: Homebrew + Docker in, OpenRouter key + Telegram bot token configured, allowed users = Oz + Mazíx, container pulling. |
| 2026-08-28 | **Gate 08 (promoter) had never been done — memory pipeline was dead since day one.** No `com.hermeskit.vault-promote.plist` existed, no cron job ran it either; vault sat at its single day-1 skeleton commit while 11 real captured notes (incl. IRS-tax and health entries from 2026-08-20) piled up unpromoted in the inbox. Fixed: pulled the kit's 2026-08-24 SIGPIPE fix into `~/.hermes/promote.sh`, installed + loaded the launchd job (`~/Library/LaunchAgents/com.hermeskit.vault-promote.plist`, `<USER>`/`<NAME>`=mazix, `<BRANCH>`=main), ran it — all 11 notes promoted, 0 rejected, committed `7cd8eee`, confirmed pushed (`git ls-remote origin main` matches local HEAD). `promote-state.json` now says `"status": "ok"`. Job runs every 15 min going forward. Also fixed `~/.hermes/skills/note-taking/vault-capture/SKILL.md` — it was the literal Docker-template copy, telling the agent to read/write `/vault` and `/opt/data/inbox` which don't exist on this native install; rewritten to the real paths. Notes had still been landing correctly beforehand, meaning the agent was silently overriding its own skill instructions — fragile, now fixed at the source. |
| 2026-08-28 | **Made `install-verify.sh` work against a native install** (it was Docker-only end to end — would have failed at the first check on this machine) and ran it for real: found and fixed the `session-log` skill was never installed (same Docker-path bug as `vault-capture`, now installed with real paths), and a bug in my own first draft of the new native-mode check (a launchd wrapper process's command line false-positived as "two competing gateways" — fixed by excluding the wrapper). **Also closed the real architecture gap the script surfaces on every native install:** without Docker's `:ro` mount, nothing at the OS level stops Hermes from writing the vault directly — only the skill's own discipline does. `promote.sh` now chmods the vault tree to read-only for everyone except during its own brief run (`.git` stays writable so manual `git log`/`status`/`pull` still work). Proven end to end: direct write to a vault file got `permission denied`, a real capture cycle through the locked state still promoted and pushed cleanly. Not proof against an agent that deliberately chmods before writing — nothing running as the same OS user can be — but it turns an accidental direct write into a loud failure instead of a silent, unreviewed one. `install-verify.sh` now reports this as PASS ("a real barrier, not just a skill convention") instead of WARN. Scheduled gate 09's watchdog too (`hermes cron create "0 13 * * *" --script vault-health.sh --no-agent --deliver telegram`, job `b702df93402d`) — adapted it the same way, since it also defaulted to Docker-only paths; forced one run through the real cron path to confirm it executes cleanly. Result: **33 passed, 0 failed, 1 informational warning** (the honest "native has no kernel enforcement" note, which is now true rather than aspirational). All three template fixes (`install-verify.sh`, `promote.sh`, `vault-health.sh`) are in the shared kit, not just this machine. |
| 2026-08-28 | **Discovered and fixed a second, undocumented memory system.** Her `SOUL.md` routes real day-to-day work (Room files, Agenda, Care Rhythm) through `~/Documents/mazix-memory` — a hand-built Obsidian system, separate from the kit's vault, that she built 2026-08-27 after hitting the exact promoter bug fixed above (her own record: "the configured Vault path was invalid"). It had no git repo at all — no backup, no undo — and sat under `~/Documents`, the folder macOS silently blocks background jobs from reading. Set up a private repo (`qrcteam/mazix-memory`) and a 15-min auto-commit job; the first attempt confirmed the TCC block live (`getcwd: Operation not permitted` from launchd, same script worked fine against `~/Memory`). Moved the folder to `~/Memory/mazix-memory` (git history intact), updated the three places that had the old path baked in — `SOUL.md`'s Room-file paths, Obsidian's own vault registry (`~/Library/Application Support/obsidian/obsidian.json`), and the sync job itself — and left a dated note in her own `Sync-and-Sweep.md` explaining the fix rather than silently editing her record. Proven end to end: real edit → auto-committed → pushed → confirmed on GitHub. Published an artifact for her, "How Hermes Remembers," covering both systems in plain language: <https://claude.ai/code/artifact/9786996e-01a2-4d63-ae18-f40817cd92ab>. |
| 2026-08-28 | **Pruned `MEMORY.md`/`USER.md`, both over their configured caps at the time** (2221/2200, 1405/1375 — already silently evicting). Root cause wasn't too many facts, it was the same facts stored 2-3x across global memory AND the Room files that already get read fresh every time: SOUL.md's own Rooms/Titles sections restated twice in MEMORY.md, "add it to the Book" defined identically in three places, a Ravenous P/C/Y label duplicated into USER.md as "P/T/L" (a drift that consolidating removes as a whole class of bug, not just this one instance). Moved genuinely room-specific facts INTO the relevant Room file first (Ravenous Room gained the cold-test workflow, nomadic-kitchen-tools rule, Yum-lock rule, content-only-pulls rule; Main Room gained new Agenda and Travel sections) so nothing was lost, then cut the duplicates from global memory. Result: MEMORY.md 2221→790 (36% of cap), USER.md 1405→332 (24% of cap) — real headroom, not just under the wire. Backups at `~/.hermes/memories/*.bak-20260829T032037Z`. **Also closed the gap that let this happen unnoticed:** `vault-health.sh` (the daily watchdog) now checks both files against their configured caps and warns at 90%, before something is actually evicted — verified with a synthetic over-cap file, and confirmed silent on the real (now-healthy) install. Shipped to the shared kit, not just this install. |
