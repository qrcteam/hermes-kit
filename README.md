# hermes-kit

**A repeatable way to give one person a personal AI agent that remembers them.**

This is the kit Oz uses to set up Hermes + Obsidian + git + Pinecone for someone who is not a
developer — Mazíx, Diane, Doug — on their own machine, without re-deriving the whole thing
each time.

---

## Start here

**Never set one of these up before, or need to explain it to someone?**
→ [`docs/00-decision-map.md`](docs/00-decision-map.md) — what each piece does, in plain English,
and what you can skip.
→ **Shareable version:** <https://claude.ai/code/artifact/b976f9cf-f82c-41df-85b2-c588e363e464>
(same content as a hosted page, with the architecture diagram — private until you share it.
Source in [`docs/assets/decision-map.html`](docs/assets/decision-map.html).)

**Ready to install one?**
→ [`docs/02-runbook-mac.md`](docs/02-runbook-mac.md) (or
[`03-runbook-windows.md`](docs/03-runbook-windows.md)) — numbered steps, paste-ready commands.

**Install done, now make it actually useful?**
→ [`docs/04-soul-interview.md`](docs/04-soul-interview.md) — **this is the real work.** The
install takes an afternoon. This is what separates a useful agent from a generic chatbot.

**Something's broken?**
→ [`docs/06-troubleshooting.md`](docs/06-troubleshooting.md) — every trap already paid for
once, so nobody pays for it twice.

---

## What this actually builds

One person gets:

| | |
|---|---|
| An agent they text | Hermes Agent in Docker, reachable via their own Telegram bot |
| A memory that persists | A markdown vault they can open in Obsidian and read like a notebook |
| Undo + backup | The vault is a git repo, pushed to a private remote |
| Recall by meaning | Pinecone semantic index, so "what was I doing with the plumber?" works |
| A morning briefing | A daily digest of what matters, delivered to their phone |

They text it. It remembers. They can read everything it remembers in a normal app. Nothing is
locked in a black box.

---

## The one rule that shapes everything

**The agent never has write access to the vault.**

It writes into an inbox. A separate host-side script — the *promoter* — is the only thing that
touches the actual memory. The vault is mounted read-only, kernel-enforced.

This isn't paranoia. It means no prompt injection, no misread instruction, and no bad day can
delete someone's memory. See [`docs/01-architecture.md`](docs/01-architecture.md).

```
Telegram ──▶ Hermes ──▶ inbox ──▶ [promoter] ──▶ vault ──▶ git push
                 ▲                                  │
                 └────── reads (read-only) ─────────┘
```

---

## Repo layout

```
docs/          the guide — read in order, or jump via "Start here" above
templates/     the actual files you copy onto a person's machine
onboarding/    what you hand the human (zero technical content)
people/        one record per install: paths, bot handle, index name. never secrets.
```

---

## Ground rules

- **No secrets in this repo, ever.** `templates/env.template` lists variable *names* only.
  Keys live in `~/.hermes/.env` (mode 600) and `~/.hermes/secrets/` on each person's machine.
- **Each person owns their own stack** — their own Pinecone account, their own git repo, their
  own model subscription, their own bot. Nothing is shared, nothing commingles.
- **Vaults never live under `~/Desktop`, `~/Documents`, or `~/Downloads`.** macOS blocks
  background jobs from those folders. `~/Memory/<name>-vault`. This one has already cost a
  fortnight of silently failed syncs.
- **Move, don't delete.** The promoter has two verbs: create and append. That's deliberate.

---

## Install order

Do them in this sequence, not all at once:

1. **Mazíx** — first real run, expect to fix the runbook as you go
2. **Doug** — proves the second platform and the "what was I working on?" persona
3. **Diane** — last, because a paying client should get the version debugged twice

Record each one in `people/<name>.md` as you go.
