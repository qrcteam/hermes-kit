# 05 · Making It Useful

*The install works. Now stop it from being abandoned in three weeks.*

Most personal-AI setups die the same way: nothing is wrong with them, the person just stops
texting it. This document is about the first month, which is when that gets decided.

---

## The first week is a habit problem, not a tech problem

Nobody adopts a memory system by being told it exists. They adopt it the first time it
remembers something they'd forgotten.

**Engineer that moment in the first three days.**

### Day 1 — seed it with things they already know

Sit with them for fifteen minutes and have them tell it eight or ten things they'd want back
later. Not made-up test data — real facts.

> *"remember the Henderson deposit is due the 20th"*
> *"remember Sarah at Wexford prefers email, never call her"*
> *"remember I decided against the Squarespace migration because of the booking plugin"*

Now the vault isn't empty, and their first real question has something to hit.

### Day 2 — make it answer one

Have them ask something from yesterday's batch:

> *"when's the Henderson deposit due?"*
> *"how should I contact Sarah?"*

That's the moment. It's small, and it's the whole product.

### Day 3 — show them the notes

Open Obsidian. Show them the actual markdown files. *"This is what it knows. It's just text.
You can edit any of it, and if you ever stop using this, the folder still works."*

This matters more than it sounds. People trust a system whose insides they've seen. It also
converts the vague worry — *"where is this stuff going?"* — into a folder they can point at.

### Week 1 — one nudge

Around day five: *"has it remembered anything useful yet?"* If no, ask what they asked and what
came back. The answer is almost always a thin `SOUL.md` or a bucket that doesn't fit how they
think. Both are ten-minute fixes if you catch them in week one, and permanent if you don't.

---

## Buckets: get these right or nothing files properly

Buckets are the top-level folders in `wiki/topics/`. They're the one structural decision that's
annoying to change later, because notes are already filed into them.

**Four or five. In their words.** Not yours, not a productivity system's.

| Person | Buckets that fit |
|---|---|
| Doug (web projects) | `projects` · `clients` · `learning` · `personal` |
| Mazíx (creative) | `creative` · `qrc-brand` · `health` · `home` · `personal` |
| Diane (consulting) | `clients` · `offers` · `marketing` · `ops` · `personal` |

**Signs you got it wrong**, watch for these in week two:

- Everything lands in one bucket → too granular elsewhere, or one bucket is really their whole life
- A bucket is empty after a month → it wasn't a real area, fold it in
- They can't guess which bucket something is in → the names are yours, not theirs

**Always include `personal`.** Even for a work-focused agent. It catches everything that doesn't
fit, and the alternative is the agent inventing a bucket and getting the note rejected.

---

## The daily digest

The highest-value recurring thing, and the easiest to get wrong. A digest people ignore is
worse than none — it trains them to ignore the channel the watchdog also uses.

**Rules:**

- **Two or three things, never ten.** A wall gets scrolled past.
- **Plain sentences, not a table.** *"Henderson deposit is due Thursday and you haven't
  invoiced it"* beats a three-column status grid.
- **Say when there's nothing.** One line. *"Nothing needs you today."* Silence reads as broken;
  a wall reads as noise.
- **Their morning, not yours.** Cron is UTC. Mountain Time is UTC−6 in summer, −7 in winter —
  so a 7am digest is `0 13 * * *` in summer and drifts by an hour in November. Check it twice a
  year or accept the drift.

Tune the prompt per person:

```bash
# Doug — "what was I working on?"
docker exec hermes hermes cron create "0 14 * * *" --name daily-digest --deliver telegram \
  "Read /vault/wiki/topics/projects/ and any notes from the last 7 days. Remind me what I was
   working on and where I left off. Lead with anything I said I'd do and haven't. Two or three
   things, plain sentences. Nothing outstanding? Say so in one line."
```

```bash
# Mazíx — creative thread, not a task list
docker exec hermes hermes cron create "0 15 * * *" --name daily-digest --deliver telegram \
  "Read the last week of notes in /vault. Surface one idea I captured and haven't come back to.
   Ask me one question about it. Keep it to three sentences. Don't give me a to-do list."
```

Note the second one **asks a question**. For a creative person a digest that prompts thinking
beats a digest that reports status.

---

## What to add after it's stuck (not before)

Resist adding anything in week one. A person still learning to text their assistant does not
need more surface area.

**Once the habit holds:**

- **A weekly review** — Sunday evening, "what happened this week, what's open".
  Higher value than the daily for anyone whose work moves slowly.
- **Skills they'd actually use.** Hermes ships a large library — `hermes skills list`. Most
  people need none. Look at what they *already* do manually before installing anything.
- **Their calendar or email**, if it earns its keep. Each integration is another key, another
  failure mode, and another thing to explain. Add one at a time, a fortnight apart.

**What not to add:** a second bot, a dashboard, a shared vault between two people. Every one of
these has been tried and each adds confusion faster than capability.

---

## Teaching them to talk to it

Three habits worth stating explicitly. Put them in the onboarding doc:

**1. Say "remember" when you mean it.**
It captures on its own judgment, but the word is a reliable trigger.

**2. Ask it things.** People forget this half exists. *"What did I say about the Henderson
deposit?"* *"When did I last talk to Sarah?"*

**3. Correct it out loud.** *"No, the deposit's the 20th not the 12th."* The correction gets
saved. Most people silently sigh and move on, and the wrong fact stays wrong forever.

---

## Monthly, for you

Five minutes per person:

```bash
# Is the memory actually growing?
git -C ~/Memory/<NAME>-vault log --oneline --since="1 month ago" | wc -l

# Anything failing to file?
ls ~/.hermes/inbox/_rejected/*/ 2>/dev/null

# Is the promoter healthy?
cat ~/.hermes/promote-state.json
```

**A vault that isn't growing means they've stopped using it.** That's the number to watch — not
uptime. A perfectly healthy container nobody texts is a failed install.

Ask them the same question each time: *"what has it got wrong lately?"* Every answer is a line
missing from `SOUL.md`.

---

**Next:** [`06-troubleshooting.md`](06-troubleshooting.md) when something breaks ·
[`07-operator-notes.md`](07-operator-notes.md) for the fleet view.
