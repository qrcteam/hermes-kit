# Mazíx Mahalel

**Status:** INSTALLING — started 2026-08-13 (Oz on-site, Claude driving on her machine)
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
