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

## Log

| Date | What |
|---|---|
| 2026-08-13 | Install started: Homebrew + Docker in, OpenRouter key + Telegram bot token configured, allowed users = Oz + Mazíx, container pulling. |
| 2026-08-28 | **Gate 08 (promoter) had never been done — memory pipeline was dead since day one.** No `com.hermeskit.vault-promote.plist` existed, no cron job ran it either; vault sat at its single day-1 skeleton commit while 11 real captured notes (incl. IRS-tax and health entries from 2026-08-20) piled up unpromoted in the inbox. Fixed: pulled the kit's 2026-08-24 SIGPIPE fix into `~/.hermes/promote.sh`, installed + loaded the launchd job (`~/Library/LaunchAgents/com.hermeskit.vault-promote.plist`, `<USER>`/`<NAME>`=mazix, `<BRANCH>`=main), ran it — all 11 notes promoted, 0 rejected, committed `7cd8eee`, confirmed pushed (`git ls-remote origin main` matches local HEAD). `promote-state.json` now says `"status": "ok"`. Job runs every 15 min going forward. Also fixed `~/.hermes/skills/note-taking/vault-capture/SKILL.md` — it was the literal Docker-template copy, telling the agent to read/write `/vault` and `/opt/data/inbox` which don't exist on this native install; rewritten to the real paths. Notes had still been landing correctly beforehand, meaning the agent was silently overriding its own skill instructions — fragile, now fixed at the source. |
| 2026-08-28 | **Made `install-verify.sh` work against a native install** (it was Docker-only end to end — would have failed at the first check on this machine) and ran it for real: found and fixed the `session-log` skill was never installed (same Docker-path bug as `vault-capture`, now installed with real paths), and a bug in my own first draft of the new native-mode check (a launchd wrapper process's command line false-positived as "two competing gateways" — fixed by excluding the wrapper). **Also closed the real architecture gap the script surfaces on every native install:** without Docker's `:ro` mount, nothing at the OS level stops Hermes from writing the vault directly — only the skill's own discipline does. `promote.sh` now chmods the vault tree to read-only for everyone except during its own brief run (`.git` stays writable so manual `git log`/`status`/`pull` still work). Proven end to end: direct write to a vault file got `permission denied`, a real capture cycle through the locked state still promoted and pushed cleanly. Not proof against an agent that deliberately chmods before writing — nothing running as the same OS user can be — but it turns an accidental direct write into a loud failure instead of a silent, unreviewed one. `install-verify.sh` now reports this as PASS ("a real barrier, not just a skill convention") instead of WARN. Scheduled gate 09's watchdog too (`hermes cron create "0 13 * * *" --script vault-health.sh --no-agent --deliver telegram`, job `b702df93402d`) — adapted it the same way, since it also defaulted to Docker-only paths; forced one run through the real cron path to confirm it executes cleanly. Result: **33 passed, 0 failed, 1 informational warning** (the honest "native has no kernel enforcement" note, which is now true rather than aspirational). All three template fixes (`install-verify.sh`, `promote.sh`, `vault-health.sh`) are in the shared kit, not just this machine. |
