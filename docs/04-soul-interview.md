# 04 · The SOUL Interview

*45 minutes of questions whose answers become `~/.hermes/SOUL.md`.*

**This is the actual work.** The install is plumbing — an afternoon, mostly waiting for Docker.
This is what separates an assistant that knows someone from a chatbot wearing their name.

Skip it and you'll hand someone a very expensive ChatGPT that doesn't remember them. They'll be
polite about it for two weeks and then stop texting it.

---

## How to run it

**Sit with them.** Phone call is fine, texting is not. You need the tangents — the aside they
add after answering is usually better than the answer.

**Record it** (with permission) or take rough notes. You're not transcribing; you're listening
for the sharp specific line you'll quote later.

**Don't ask all 25.** Ask what fits. A short honest SOUL beats a padded one, and question 4
matters more than questions 12 through 18 combined.

**Write it up in your own prose afterwards.** Not a Q&A dump — briefing notes for a new chief
of staff who starts Monday. Quote them directly where they said it well; their words beat your
summary every time.

### The two rules that make it good

1. **Specific beats complete.** Five sharp facts outperform forty vague ones. *"Mornings are
   calls and admin, afternoons are for making things"* changes behaviour. *"Values work-life
   balance"* does nothing.
2. **True beats flattering.** *"Revenue is $0/mo"* is more useful than *"growing steadily"* —
   the agent calibrates every suggestion off this. If it thinks they're comfortable, it will
   propose expensive things. Write what's true, and date it.

---

## Identity — who am I talking to?

**1. What do you actually do all day?**
Not their title. What the hours go into.

**2. How would you describe your own working style?**
Push for their phrase, not a category.
> *Worked example, real SOUL.md:* "Self-described: messy creative. The systems around him
> exist to organize without adding friction."
> That one line permanently changes how the agent proposes things.

**3. Where are you, and what's your timezone?**
Drives every "today", "tomorrow" and digest hour. Get it exactly right.

**4. If this thing works perfectly, what does it do for you?**
**The most important question in the interview.** One sentence. It goes at the top of the file
and shapes everything else.
> *"I want to know what I was working on."* — Doug
> *"I want ideas caught before they evaporate."* — Mazíx
>
> These lead to very different assistants. Don't accept "help me be organised" — ask what
> being disorganised actually costs them this week.

---

## Mission — what are they pushing at?

**5. What are you trying to make happen in the next few months?**
With a number and a date if there is one.

**6. What's the one thing that, if it slipped, would matter most?**

**7. What have you already decided *not* to do?**
**The most valuable section people skip.** Every "no" here is a suggestion the agent won't
waste their time with, and a debate they won't have to have twice.
> *Real examples:* "No paid ads until 3 case studies exist." · "No new features unless a
> paying client needs them." · "The old 10-clients-in-6-weeks target is dead."

**8. What does everyone keep telling you to do that you're deliberately not doing?**
Same as 7, asked sideways. Often gets a better answer.

---

## Work — the situation, honestly

*Skip this whole block for a personal-only agent.*

**9. What do you sell, and how does money actually work?**
If prices change, ask where the real answer lives. A rule like *"read the file, never quote
from memory"* belongs in the SOUL verbatim.

**10. Where do things actually stand right now — revenue, costs, runway?**
Be blunt with them about why you're asking: an agent that thinks they're flush suggests
expensive things.

**11. Who else is involved?**
"Strictly solo — there is nobody to delegate to" changes every proposal the agent makes.

---

## Voice — how to talk to them

*Get this wrong and they'll stop using it inside a week.*

**12. When an assistant annoys you, what did it just do?**
Best question in this section. Ask it exactly like this.
> *Real answers that became rules:* "Never ask me to confirm an obvious next step." ·
> "One question at a time. Don't stack them." · "Short by default. No bullet walls."

**13. Long or short? Answer first, or reasoning first?**

**14. Do you want to be told when you're wrong?**
Some people genuinely don't. Believe them.

**15. Casual or formal?**
Match their register. If they say "dude" in the interview, write that down.

**16. You're often away from your phone — should it acknowledge a message before it starts?**
Silence reads as broken to most people.

**17. Do you send voice notes? Do you want spoken replies back?**
Most people send voice constantly once they realise they can. Fewer want audio back — ask
separately, don't assume the answer to one is the answer to the other.

**18. Will it ever draft anything you send to someone else?**
If yes: spelling, case, banned punctuation, words they hate.

---

## Rhythm — when to speak, when to shut up

**19. When are you sharpest?**
The block to protect.

**20. What does your day shape look like?**
> *Real example:* "Mornings are calls and admin; afternoons and evenings are creative work."
> The agent then puts phone-and-form tasks in the morning and judgment tasks in the afternoon.
> No other single line does more for a digest.

**21. When should it absolutely not ping you?**
Quiet hours. Non-negotiable, and the fastest way to get an assistant muted forever.

**22. Is there one habit that, if it slips, everything slips?**
If they have one, that's the single nudge worth making. Write it down as such.

**23. What do you do when it's going badly?**
So the agent can say *"go for a walk"* instead of offering another tactic.
> *Real example:* "Recovery is getting out of the house. If he's been at the screen all day
> and things are grinding, that's the suggestion — not another tactic."

---

## Hard nos — the rules with consequences

**24. What must it never, ever do?**
Push for the *consequence*, not just the rule. Rules with evidence attached get followed, and
the agent generalises correctly to cases you didn't list.
> *Real example:* "Never fetch a `/go/` link — every request records a real click and corrupts
> his prospect stats. Four false opens already on record."
> The receipt is what makes it stick.

Always include, regardless of what they say:
- Never paste secrets into chat, never commit personal information
- Never claim a fact they haven't shared — say "I don't know"
- Never guarantee an outcome on their behalf

---

## People and history

**25. Who will you mention that it needs to know instantly?**
Name, relationship, and **the one thing that matters** — not a biography.

**26. What have you learned the hard way?**
Often the best content in the whole file, and it only exists if you ask. Get the cost attached.
> *Real example:* "13 audits, 0 closes on the ownership pitch. Ownership was never why anyone
> said yes."

**27. What decisions are settled that you don't want reopened?**
Date them. Stops the agent relitigating the same question every few weeks.

---

## Writing it up

Fill in [`templates/SOUL.md.template`](../templates/SOUL.md.template). Then:

- [ ] **Every `<placeholder>` and every HTML comment removed.** A placeholder left in is
      something the agent will confidently reason from as though it were true.
      Check: `grep -c '<' ~/.hermes/SOUL.md` should be at or near `0`.
- [ ] **Unknowns marked `⟨ASK⟩`**, not guessed. A blank the agent asks about beats a
      plausible invention.
- [ ] **Volatile facts dated**, so a stale one is visibly stale.
- [ ] **Their words quoted** where they said it well.
- [ ] **Read it aloud.** If a section sounds like a form, rewrite it as a sentence.
- [ ] **Show it to them.** They'll correct one thing you got importantly wrong. They always do.
      This step is worth ten minutes.

Then `docker restart hermes` and test with something only a well-briefed assistant could get
right: *"should I call Scott today or tomorrow?"* A generic answer means the SOUL is thin.

---

## Keeping it alive

`SOUL.md` is not write-once. It's the file that decays fastest, because it holds exactly the
facts that change.

- **After two weeks**, ask what it keeps getting wrong. Every complaint is a missing line.
- **Every few months**, reread it together. Delete what's no longer true — a stale SOUL is
  worse than a short one, because the agent trusts it completely.
- **When something big changes** — a goal met, a client gone, a decision reversed — edit it
  that day. It takes two minutes and it's the difference between an assistant that's current
  and one that's quietly working from last quarter.

The vault grows by itself. **This file only changes if a human changes it.**

---

**Next:** [`05-make-it-useful.md`](05-make-it-useful.md) — the first week.
