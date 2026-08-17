---
name: session-log
description: Log what the user actually did or made in this conversation, at the end of it. Use when they say wrap up, log this, what did I get done, I'm done for the day, end of session, log my work, or when a working conversation is clearly finishing.
version: 1.0.0
author: hermes-kit
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Memory, Vault, Log, Session, Obsidian]
    related_skills: [vault-capture, obsidian]
---

# Session Log

At the end of a working conversation, write down **what they did** — so next week they can
answer "what was I working on?" without trying to remember.

This is the difference between an assistant that remembers *facts about them* and one that
also remembers *their work*. Both matter. This skill does the second one.

## How this differs from `vault-capture` — read this first

They are not the same job and you should not do both for the same content.

| | `vault-capture` | `session-log` (this skill) |
|---|---|---|
| Captures | A **fact** that will still be true next month | **What happened** in one conversation |
| When | The moment they say it, mid-conversation | Once, at the end |
| Example | "Henderson moved to the Tuesday crew" | "Rescheduled Henderson, drafted the Ruiz quote, called the supplier" |
| Count | One note per fact | One note per session |

**Do not repeat a fact you already captured.** If you wrote a `vault-capture` note about the
Henderson move an hour ago, the session log says *"moved Henderson to Tuesday — see
[[2026-08-12-henderson-tuesday-crew]]"* and links it. It does not restate the reasoning. The
log is an index of the session's work, not a second copy of it.

## The same hard rule

**Never write, edit, move, or delete anything under `/vault`.** It is read-only to you, on
purpose. You write into the inbox; a separate program files it a few minutes later.

```
READ  from  /vault/...                    ← everything they already know
WRITE to    /opt/data/inbox/wiki/...      ← what you want them to know next
```

## When to write one

**Write a log when** the conversation involved real work — decisions made, things built or
drafted, calls or jobs handled, problems solved, plans changed — and it's now winding down.
Their own words are the clearest trigger: *"that's me for today"*, *"wrap up"*, *"log this"*,
*"what did I get done?"*.

**Do not write a log for:**

- A conversation with no work in it — a question answered, a fact looked up, small talk. A
  vault full of "user asked what time the supplier opens" is a vault nobody reads.
- A session where the only content is something `vault-capture` already saved. Filing a second
  note that says the same thing makes their memory worse, not better.
- Anything they'd be embarrassed to find written down.
- Credentials. If a message contained one, note that a credential was discussed — never what
  it was.

**When you're unsure whether there was enough work: ask them.** *"Want me to log today?"* is
one short message and it beats both a junk note and a missed one.

## How to write one — four steps, in order

### 1. Check whether today already has a log

```bash
ls /vault/wiki/topics/*/$(date +%F)-*.md 2>/dev/null | grep -i log
VAULT_ROOT=/vault /vault/scripts/pinecone-sync search "<what this session was about>"
```

If a log for today already exists, **append to it** rather than creating a second one — people
work in more than one sitting a day. Use the `.append` form in step 3.

The search is also how you find the notes to link. A log that links nothing is a dead end.

### 2. Pick the bucket

Buckets are the top-level folders in `/vault/wiki/topics/`. **List them and pick one that
already exists** — a note with an invented bucket is rejected and never files.

```bash
ls /vault/wiki/topics/
```

Choose the bucket the *work* belongs to, not a bucket called "logs". If the session touched
two buckets, pick the one that got the most work and mention the other in the body. If nothing
fits, use the most general bucket and tell them their buckets may need a new one.

### 3. Write to the inbox

**A new log** — `/opt/data/inbox/wiki/topics/<bucket>/<YYYY-MM-DD>-log.md`:

```markdown
---
bucket: projects
type: log
created: 2026-08-12
source: telegram
---

# Tuesday 12 August

Moved the Henderson job to the Tuesday crew and got the Ruiz quote out.

- **Rescheduled Henderson** to the Tuesday crew — see [[2026-08-12-henderson-tuesday-crew]]
- **Drafted the Ruiz re-pipe quote**, $4,200, sent for review — not yet accepted
- **Called Trenton Supply** about the copper backorder; they'll confirm Thursday

**Open when we stopped:** waiting on Ruiz to accept, and on Trenton's Thursday call.

Related: [[ruiz-repipe]] · [[henderson-bathroom]]
```

Required frontmatter: `bucket`, `created`. Wanted: `type: log` and `source`.

Body rules:

- **One line at the top saying what the session was**, in plain language. That line is what
  they'll read in six months.
- **Then the work, as a short list.** Verb first — *rescheduled*, *drafted*, *called*, *fixed*.
- **Say what is unfinished.** The single most useful line in any log is the one that tells them
  where they stopped. Put it under **Open when we stopped:**.
- **Link out.** Wikilink the `vault-capture` notes from this session and any project note the
  work belongs to.

**Appending to today's existing log** — same path plus `.append`:

```
/opt/data/inbox/wiki/topics/projects/2026-08-12-log.md.append
```

Contents are appended verbatim. No frontmatter on a fragment — just the new lines, ideally
under a small heading like `## Later that day`.

### 4. Read it back before you confirm

```bash
cat /opt/data/inbox/wiki/topics/<bucket>/<file>.md
```

**Only tell them you logged it if this succeeds.** Never confirm on faith — if they believe
the day is recorded and it isn't, they stop holding it themselves and nobody finds the gap for
weeks. If the write failed, say so plainly.

## Write what happened, not what sounds good

The log is a record, not a report card.

- **Don't inflate.** If they made one call, the log says one call. A log that reads like a
  productive day when the day wasn't is worse than no log — they'll stop trusting all of them.
- **Don't invent.** Only log what actually happened in this conversation. If you are unsure
  whether something got finished, write that you're unsure, or ask.
- **Include the abandoned and the failed.** "Tried the supplier portal, it was down, gave up"
  is genuinely useful next week. Successes-only logs are how people end up repeating dead ends.
- **Use their words** where they said something well.

## What to say back

Short, and about the day rather than the filing:

> Logged today — Henderson moved to Tuesday, Ruiz quote out for $4,200, waiting on Trenton
> Thursday.

Don't narrate paths, frontmatter, or the inbox. It shows up in their notes within about
fifteen minutes.

## Reading the logs back

When they ask *"what was I working on?"*, *"what did I do last week?"*, or *"where did I leave
the Ruiz job?"* — this is what you read:

```bash
ls -t /vault/wiki/topics/*/*-log.md | head -10
grep -l "Ruiz" /vault/wiki/topics/*/*-log.md
```

Read the most recent ones first and lead with the **Open when we stopped** lines. That is
almost always the actual question behind the question.
