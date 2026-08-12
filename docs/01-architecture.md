# 01 · Architecture

*The mechanics. Read this when something breaks, or when you want to change something and need
to know what it'll take down with it.*

---

## The reference design, for one person

```
┌─ their phone ──────────────────────────────────────────────────────┐
│  Telegram → their own bot (@<name>hermesbot)                       │
└───────────────────────────────┬────────────────────────────────────┘
                                │
┌─ their machine ───────────────┼────────────────────────────────────┐
│                               ▼                                    │
│   ┌── Docker container "hermes" ──────────────────────────────┐    │
│   │  Hermes Agent v0.20.x                                     │    │
│   │                                                           │    │
│   │  /opt/data   ◀── ~/.hermes            (READ-WRITE)        │    │
│   │    ├─ SOUL.md          who this person is                 │    │
│   │    ├─ memories/USER.md short profile it maintains itself  │    │
│   │    ├─ .env             secrets, mode 600                  │    │
│   │    ├─ config.yaml                                         │    │
│   │    ├─ inbox/           ◀── the ONLY place it can write    │    │
│   │    ├─ scripts/         --no-agent cron scripts live here  │    │
│   │    └─ secrets/         pinecone.key, mode 600             │    │
│   │                                                           │    │
│   │  /vault      ◀── ~/Memory/<name>-vault  (READ-ONLY :ro)   │    │
│   └───────────────────────────────────────────────────────────┘    │
│                               │                                    │
│                    inbox/ has files                                │
│                               ▼                                    │
│   ┌── promote.sh (launchd / Task Scheduler, every 15 min) ────┐    │
│   │  1. validate frontmatter    → bad ones to inbox/_rejected │    │
│   │  2. file into the vault     → create or append, never rm  │    │
│   │  3. git add + commit                                      │    │
│   │  4. git pull --rebase       → conflict? escape to branch  │    │
│   │  5. git push                                              │    │
│   │  6. pinecone-sync           → update the semantic index   │    │
│   │  7. write promote-state.json (the heartbeat)              │    │
│   └───────────────────────────────────────────────────────────┘    │
│                               │                                    │
│                               ▼                                    │
│              ~/Memory/<name>-vault   ◀── Obsidian opens this        │
│                       └─ .git ──────────▶ private remote           │
└────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    Pinecone index "<name>-vault"
                     (their own account, their own key)
```

---

## The trust boundary

Everything above the promoter is **untrusted**. Everything at or below it is **trusted**.

Hermes is a language model wired to tools. It can be talked into things. A message it reads —
a forwarded email, a web page, a note someone else wrote — can contain instructions. That's not
a Hermes flaw, it's true of every agent.

So the design assumes the agent will eventually try to do something wrong, and makes the
damaging version impossible rather than forbidden:

| Threat | Containment |
|---|---|
| Agent deletes or rewrites the vault | Vault mounted `:ro`. Enforced by the kernel, not by a prompt |
| Agent writes garbage into memory | Promoter validates frontmatter; failures quarantine to `_rejected/` |
| Agent overwrites a good note with a bad one | Promoter has two verbs: **create** and **append**. Collisions become `-2` |
| Agent leaks secrets | Secrets live in `/opt/data`, which the agent *can* read — so `.env` holds only what it needs, mode 600, and nothing is shared across people |
| Agent escapes the container | Never mount `docker.sock`. Never mount `~/.claude`, `~/.ssh`, or any repo |
| Prompt injection via vault content | Vault is read-only, so the worst case is a bad answer, not a bad write |

**The `:ro` flag is the single most important character in this whole kit.** If you change one
thing, don't change that.

---

## Data flow: a thought becomes a memory

Walk the whole path once, because every failure is somewhere on it.

**1. Capture.** They text: *"remember I switched Henderson to the Tuesday crew"*.

**2. The agent decides it's durable.** The `vault-capture` skill tells it what qualifies — a
fact that will still be true next month. Not "what's the weather".

**3. It searches first.** Before writing, it runs `pinecone-sync search "henderson crew"` so
the new note can link to what already exists. This is why memory compounds instead of
fragmenting into 400 orphans.

**4. It writes to the inbox** — mirroring the vault's own tree, so filing is a move, not a
decision:

```
/opt/data/inbox/wiki/topics/projects/2026-08-12-henderson-tuesday-crew.md
```

**5. It reads the file back** before confirming in Telegram. If the write failed, the person is
told. This is the guard against the worst failure mode — a cheerful *"got it, saved!"* over
nothing.

**6. The promoter runs** within 15 minutes: validate → file → commit → pull → push → index.

**7. Recall.** Next time they ask about Henderson, Hermes finds it two ways — by reading
`/vault` directly, and by semantic search through Pinecone.

---

## Why the promoter is a dumb script

It contains no AI. It's bash. It does the same thing every time.

That's the point. The intelligent part of the system proposes; the predictable part disposes.
When something goes wrong you can read 60 lines of bash and know exactly what happened, rather
than asking a model why it did something.

It's also the only component that needs to be trusted with credentials that can *change* things
— the git push token and the Pinecone write key. Keeping those out of the agent's environment
is worth the extra moving part.

---

## Scheduling: who runs what, when

| Job | Where | Cadence | Purpose |
|---|---|---|---|
| `promote.sh` | Host (launchd / Task Scheduler) | Every 15 min | The whole write path |
| `vault-health.sh` | Hermes cron, `--no-agent` | Daily | Shouts only if something's stale or rejected |
| Daily digest | Hermes cron, normal agent job | Daily, their morning | The briefing |
| Telegram kick | Host launchd (macOS) | Every 5 min | Works around an upstream cold-start wedge |

**Two scheduling facts worth knowing**, both verified against the running container rather than
assumed:

1. **`--no-agent` cron scripts bypass `approvals.cron_mode: deny`.** Script jobs short-circuit
   before the agent loop is even imported. So a health watchdog can run unattended even though
   the config forbids scheduled agent actions. That's the right combination: scheduled *checks*
   are safe, scheduled *actions* need a human.
2. **Empty stdout means a silent run; a non-zero exit delivers an alert.** So the watchdog is
   written to print nothing when everything is fine. You only hear from it when you need to.

---

## Why the vault can't live in `~/Desktop`, `~/Documents`, or `~/Downloads`

macOS TCC (the privacy system) blocks background jobs from those three folders. A launchd agent
touching them fails with `Operation not permitted` — **and fails silently**, because nobody is
watching a log file that only exists when something goes wrong.

This already happened here: 15 out of 15 scheduled sync runs failed for a fortnight before
anyone noticed. The index was quietly stale the whole time.

`~/Memory/<name>-vault` is not TCC-gated. Use it. Nothing else.

---

## Multi-tenancy: what changes per person

The kit ships one design; four things vary:

| Variable | Example | Set in |
|---|---|---|
| `VAULT_ROOT` | `~/Memory/mazix-vault` | promoter env + `docker run -v` |
| `PINECONE_INDEX` | `mazix-vault` | promoter env |
| `PINECONE_STATE` | `~/.hermes/pinecone-state.json` | promoter env |
| `PINECONE_KEY_FILE` | `~/.hermes/secrets/pinecone.key` | promoter env |

The state file deliberately lives in `~/.hermes`, **not** in the vault. Two reasons: the vault
is read-only from inside the container, so a state file there couldn't be written; and it means
the host writes it and the container can read it, which is exactly the sharing pattern needed
for `pinecone-sync search` to work from inside.

Everything else — the scripts, the skill, the config — is byte-identical across installs.

---

## Isolation between people

Nothing is shared. Not the index, not the repo, not the key, not the bot, not the model account.

**Pinecone namespaces are not a security boundary.** They're a partitioning convenience inside
one index, and one leaked key exposes every namespace in it. A `--full` re-sync pointed at the
wrong `VAULT_ROOT` would cross-contaminate people's memories. Separate accounts, separate
indexes, separate blast radius.

This matters most for Diane. She's a paying client; her business memory should be on her
account, under her key, in her repo. If the engagement ends she keeps everything and you revoke
nothing, because you never held it.

---

## What happens when things fail

| Failure | Behaviour | Who notices |
|---|---|---|
| Container stops | No replies at all | Immediately obvious to the person |
| Promoter stops | Captures pile up in `inbox/`, nothing lost | Health watchdog, next day |
| Pinecone key invalid | Notes still land in the vault; recall degrades to literal search | Health watchdog |
| Git remote unreachable | Commits accumulate locally; push retries next run | Health watchdog after 24h |
| Merge conflict | Work is pushed to a `hermes-conflict/…` branch, local stays usable, Telegram message sent | Immediately |
| Bad frontmatter | Note goes to `inbox/_rejected/`, nothing else is affected | Health watchdog |
| Disk full | Promoter exits non-zero → Telegram alert | Immediately |

**Nothing on this list loses a captured thought.** Files leave the inbox only after
`git commit` returns 0. Total failure of git *and* Pinecone still leaves every note sitting on
disk in the writable mount, waiting.

---

## The failure mode that actually matters

It isn't a crash. A crash announces itself.

It's **silent memory loss** — Hermes replying *"got it, saved"* while nothing lands, for six
weeks, until someone asks a question it should be able to answer and can't. By then the
thoughts are gone and there's no log of what was missed.

Three defences, in order of who catches it first:

1. **The receipt.** The agent reads the file back off disk before confirming.
2. **The heartbeat.** Every promoter run writes `promote-state.json`. The watchdog shouts if
   it's more than two hours stale, if anything sits in `_rejected/`, or if a conflict branch
   exists.
3. **Nothing is deleted before it's durable.** Promoted files move to `inbox/_promoted/<date>/`
   only after a successful commit.

---

## Deliberately rejected

Worth recording so these don't get relitigated:

- **Mounting the vault read-write.** The only protection that survives a bad prompt is one the
  kernel enforces. It also puts two operating systems on one `.git/index` across a virtualised
  filesystem — the same family of problem as the SQLite WAL corruption we already hit.
- **Running pinecone-sync from Hermes cron.** Technically possible — python3 is in the
  container and `--no-agent` sidesteps the approvals block — but it can't write the state file
  into a read-only mount and can't do the git half. You'd need the host promoter anyway, and
  then you'd have two schedulers for one job.
- **A human review queue before promotion.** Nobody will ever work it. An unreviewed queue is
  worse than no queue, because it looks like a safety net. Append-only plus git history gives
  retroactive review at zero cost to the user.
- **A shared index with per-person namespaces.** One key, one blast radius, and a client-trust
  boundary in the wrong place.
- **A Pinecone MCP server inside Hermes.** Second key path, second config surface.
  `pinecone-sync search` already works from the read-only mount.

---

**Next:** [`02-runbook-mac.md`](02-runbook-mac.md) to build one.
