# <NAME>'s vault

This folder is your memory. Your assistant reads it to know things, and writes to it
when you tell it something worth keeping.

**It's just markdown files.** Open them in Obsidian, or any text editor, or read them
on GitHub. Nothing here is locked in a format you can't get out of. If every AI tool
you use disappeared tomorrow, this folder would still be a perfectly good notebook.

---

## What's in here

```
wiki/
  topics/<bucket>/     one folder per area of your life
    _manual.md         the overview for that area — read this first
    <note>.md          one fact per note
  people/              someone you deal with, and what matters about them
  reference/           things you look up rather than decide
raw/
  sessions/            dated logs of longer conversations
scripts/
  pinecone-sync        keeps the search index current (don't edit)
```

## How notes are written

**Filename:** `2026-08-12-what-it-is.md` — the date, then a short description in
lowercase with dashes.

**Top of the file** (this bit is for the computer):

```yaml
---
bucket: projects        # which folder it lives in
type: decision          # decision · note · reference · preference · gotcha · project
created: 2026-08-12
source: telegram
---
```

**The body:** the fact first, in one line. Then *why*, if there's a why. Then links
to related notes in `[[double brackets]]`.

```markdown
# Moved Henderson to the Tuesday crew

Switched the Henderson job to the Tuesday crew starting this week.

**Why:** Thursday's tied up on the Ruiz re-pipe until the end of the month.

Related: [[henderson-bathroom]] · [[ruiz-repipe]]
```

**One fact per note.** Three things you learned means three notes. It feels wasteful
and it isn't — it's what makes them findable later.

**Links to notes that don't exist yet are fine.** They mark something worth writing
down eventually. Obsidian shows them greyed out.

## When two notes disagree

The newer one wins. If you notice an old note that's no longer true, either fix it or
add `superseded-by: [[the-new-note]]` to its frontmatter. Don't leave two live answers
to the same question — that's how a memory becomes useless.

## Can I just edit these myself?

Yes. Please do. Fix anything wrong, delete anything you don't want remembered, write
notes by hand if you feel like it. Your assistant will pick up the changes.

The only thing to avoid is renaming the `wiki/topics/<bucket>` folders, because the
assistant files new notes into them by name. Ask before you rename one.

## Where it goes

Every change is committed to git and pushed to a private repository, automatically,
within about fifteen minutes. That's your backup and your undo button. Nothing is ever
deleted by the assistant — it can only create new notes and add to existing ones.
