---
name: vault-capture
description: Save something the user wants remembered. Use whenever they say remember this, save this, note this, don't let me forget, or tell you a durable fact about their work or life.
version: 1.0.0
author: hermes-kit
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Memory, Vault, Capture, Obsidian]
    related_skills: [obsidian]
---

# Vault Capture

This is how you remember things. The user's long-term memory is a folder of markdown notes
mounted at `/vault`. **You cannot write there — it is read-only, on purpose.** You write
proposals into an inbox, and a separate program files them a few minutes later.

## The one hard rule

**Never attempt to write, edit, move, or delete anything under `/vault`.** It will fail. If you
find yourself trying, you have misunderstood this skill — write to the inbox instead.

```
READ  from  /vault/...                    ← everything the user already knows
WRITE to    /opt/data/inbox/wiki/topics/... ← what you want them to know next
```

## When to capture

Capture a fact if it will still be true next month.

**Capture:** decisions and why they were made · people and what matters about them · project
state and what's next · preferences, especially corrections to how you behave · commitments and
deadlines · anything they explicitly ask you to remember.

**Don't capture:** the weather · one-off calculations · what you just said to each other ·
anything they'd be embarrassed to find written down · passwords, card numbers, or anything that
looks like a secret. If a message contains a credential, say so and don't write it anywhere.

When in doubt, capture. A slightly noisy memory beats a forgotten decision. Notes are
append-only and reversible; a lost thought is not.

## How to capture — four steps, in order

### 1. Search first. Always.

```bash
VAULT_ROOT=/vault /vault/scripts/pinecone-sync search "<the gist, in plain words>"
```

This is not optional and it is not for your benefit — it is what stops the memory becoming four
hundred disconnected orphans. You are looking for two things:

- **Does a note about this already exist?** If yes, append to it rather than making a second one.
- **What should this link to?** Every new note should wikilink at least one existing note.

If the search command isn't available, fall back to reading `/vault/wiki/topics/<bucket>/_manual.md`
and grepping the bucket folder.

### 2. Pick the bucket

Buckets are the top-level folders in `/vault/wiki/topics/`. **List them and choose one that
exists** — do not invent one. A note with an unknown bucket gets rejected and the user is told
their note couldn't be filed, which is a bad experience you can trivially avoid by looking.

If nothing fits, use the most general bucket rather than inventing. Then mention to the user
that their buckets might need a new one.

### 3. Write to the inbox

Mirror the vault's own tree, so filing is a move rather than a decision.

**A new note** — `/opt/data/inbox/wiki/topics/<bucket>/<YYYY-MM-DD>-<kebab-case-slug>.md`:

```markdown
---
bucket: projects
type: decision
created: 2026-08-12
source: telegram
---

# Henderson moved to the Tuesday crew

Switched the Henderson job to the Tuesday crew starting this week.

**Why:** the Thursday crew is tied up on the Ruiz re-pipe through the end of the month.

Related: [[henderson-bathroom]] · [[ruiz-repipe]]
```

Required frontmatter: `bucket`, `created`. Strongly wanted: `type`
(`decision` · `note` · `reference` · `preference` · `gotcha` · `project`) and `source`.

Body rules: **the fact first, in one line.** Then *why*, if there is a why. Then wikilinks. One
fact per note — if they told you three things, write three notes.

**Adding to an existing note** — same path plus `.append`:

```
/opt/data/inbox/wiki/topics/projects/henderson-bathroom.md.append
```

The contents are appended verbatim to the end of the existing note. No frontmatter needed on a
fragment — just the new lines. The target must already exist in the vault or it will be rejected.

### 4. Read it back before you confirm

```bash
cat /opt/data/inbox/wiki/topics/<bucket>/<file>.md
```

**Only tell the user you saved it if this succeeds.** Never say "got it, saved!" on faith.

A cheerful confirmation over a write that silently failed is the single worst thing this system
can do — the user stops holding the thought themselves because they believe you have it, and
nobody discovers the gap for weeks. If the write failed, say so plainly and tell them the fact
is not saved.

## What to say back

Short. Confirm what you understood, not the mechanics:

> Got it — Henderson's on the Tuesday crew now, because Thursday's stuck on Ruiz until month
> end. Saved under projects.

Don't narrate file paths, frontmatter, or the inbox. They don't care and shouldn't have to.
It appears in their notes within about fifteen minutes.

## Naming

`YYYY-MM-DD-what-it-is.md` — kebab-case, descriptive, no spaces.

Good: `2026-08-12-henderson-tuesday-crew.md` · `2026-08-12-prefers-morning-calls.md`
Bad: `note1.md` · `Henderson Update.md` · `important.md`

If a name is already taken the filer appends `-2` rather than overwriting. Nothing you write can
destroy an existing note — but a better name still saves someone confusion later.

## Recall

To answer a question from memory, use both:

```bash
VAULT_ROOT=/vault /vault/scripts/pinecone-sync search "how did we handle the deposit?"   # by meaning
grep -ril "deposit" /vault/wiki                                                          # by keyword
```

Start at `/vault/wiki/topics/<bucket>/_manual.md` for a bucket overview, then follow the
`[[wikilinks]]`. **A note dated later than the manual is the more current answer.** If two notes
contradict each other, say so and give the newer one — don't quietly pick.
