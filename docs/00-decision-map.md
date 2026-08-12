# 00 · The Decision Map

*Read this before you install anything. It's the whole system in plain English.*

> **Shareable version:** <https://claude.ai/code/artifact/b976f9cf-f82c-41df-85b2-c588e363e464>
> — the same content as a hosted page with the architecture diagram drawn out. Private until
> you share it from the page's share menu. Source: [`assets/decision-map.html`](assets/decision-map.html).

---

## The one-sentence version

**You're giving someone a text-message assistant that writes down what it learns into a folder
of notes they own, backs that folder up, and can search it by meaning instead of by keyword.**

Everything below is just which tool does which part of that sentence.

---

## The four pieces

### 1. Hermes — *the agent you text*

An open-source AI agent from Nous Research. It runs continuously on the person's machine inside
Docker and connects to a Telegram bot, so they text it from their phone like a person.

Unlike ChatGPT, it doesn't start every conversation from zero. It reads a file describing who
they are, and it reads their notes.

- **What it costs:** free software. They need a model to run it on — see *Money*, below.
- **Without it:** you have a folder of notes and no one to talk to.
- **Not the same as:** OpenClaw (different product entirely — the course conflates them) or
  Claude OS (Jack's dashboard — a separate thing that *views* this stack, doesn't run it).

### 2. The vault — *the memory itself*

A plain folder of markdown files. Notes organised into a handful of buckets, one fact per note,
cross-linked. This is what Hermes reads to know things, and what it writes to when it learns
something.

The whole point is that it's *plain text in a folder*. If Hermes disappears tomorrow, or you
fall out with Nous Research, or the whole AI industry evaporates — the person still has a
readable notebook. No lock-in, no export step.

- **What it costs:** nothing.
- **Without it:** the agent forgets everything between conversations. This is the piece.
- **Mandatory.** There is no version of this without it.

### 3. Obsidian — *the window onto the memory*

A free app that opens that folder and makes it navigable — backlinks, search, a graph view.

**Obsidian is a viewer, not a writer.** It doesn't do anything to the system. It's how a human
looks at what the agent knows and thinks *"oh, that's not right"* and fixes it. Removing
Obsidian breaks nothing.

- **What it costs:** free.
- **Without it:** the memory still works perfectly. It's just a folder of `.md` files you'd be
  opening in TextEdit instead.
- **Skip it for:** anyone who will genuinely never open it. Install it for anyone who wants to
  see what their agent thinks it knows — most people find this reassuring.

### 4. Pinecone — *recall by meaning*

A hosted vector database. Every note gets converted to a list of numbers representing its
meaning; searching converts the question the same way and finds the closest notes.

The practical difference: keyword search for `"plumber"` only finds notes containing the word
"plumber". Semantic search for *"who did I hire for the bathroom?"* finds the note that says
`"went with Ruiz for the Henderson bathroom re-pipe"` — no shared words at all.

- **What it costs:** free tier is genuinely enough for one person's notes.
- **Without it:** search still works, it's just literal. Fine at 50 notes. Frustrating at 500.
- **Skip it until:** roughly 200 notes. It adds an API key and a sync step; there's no reason
  to carry that on day one. **That said — you asked for the full stack from day one, so the
  runbook installs it. This paragraph is here so you know it's the one piece you could defer if
  an install is going badly.**

---

## How they fit together

```
        the person
             │  texts
             ▼
     ┌───────────────┐
     │    HERMES     │  reads SOUL.md to know who they are
     │  (in Docker)  │  reads the vault to know things
     └───────┬───────┘  writes new facts to → inbox
             │
             ▼
        ┌─────────┐
        │  INBOX  │  a staging folder. the agent can write here.
        └────┬────┘
             │
             ▼  every 15 minutes
     ┌───────────────┐
     │  THE PROMOTER │  the ONLY thing allowed to write the vault
     └───────┬───────┘  checks each note, files it, commits, pushes, re-indexes
             │
        ┌────┴─────┬──────────────┬──────────────┐
        ▼          ▼              ▼              ▼
    ┌───────┐  ┌───────┐    ┌──────────┐   ┌──────────┐
    │ VAULT │  │  GIT  │    │ PINECONE │   │ OBSIDIAN │
    │ notes │  │ undo  │    │  recall  │   │  viewer  │
    └───────┘  └───────┘    └──────────┘   └──────────┘
         ▲
         └──── Hermes reads this back, read-only
```

**Why the promoter exists:** if Hermes could write directly to the vault, then one confused
instruction — or one malicious message, or one bad model day — could rewrite or delete a
person's entire memory. So it can't. It writes proposals into a staging folder; a dumb,
predictable script that contains no AI does the filing. The vault is mounted read-only at the
operating-system level, which means it isn't a rule the agent is asked to follow. It's a rule
it *cannot break*.

---

## What's mandatory, what's optional

| Piece | Verdict | Why |
|---|---|---|
| The vault (a folder of markdown) | **Mandatory** | It *is* the memory |
| `SOUL.md` | **Mandatory** | Without it you have a generic chatbot. See doc 04 |
| Git | **Mandatory** | Undo, and the only backup. A disk dies and the memory is gone otherwise |
| Hermes + Telegram | **Mandatory** | It's the thing they talk to |
| The promoter | **Mandatory** | Nothing gets remembered without it |
| Pinecone | Optional under ~200 notes | Recall by meaning. Nice early, necessary later |
| Obsidian | Optional | Purely a human convenience |
| Daily digest | Optional | Great for Doug, probably noise for Mazíx |

---

## Money, honestly

Per person, per month:

| | Cost | Notes |
|---|---|---|
| Hermes | $0 | Open source, runs on their machine |
| Obsidian | $0 | Free for personal use |
| Git hosting | $0 | Private GitHub repos are free |
| Pinecone | $0 | Free tier covers one person's notes comfortably |
| **Model access** | **~$20/mo** | **The only real cost.** Their own ChatGPT or Claude subscription |
| **Total** | **~$20/mo each** | |

**Each person brings their own model subscription.** Yours can't be shared — the Codex OAuth
credential is tied to your account, and running four people through it will get it rate-limited
or flagged. It also keeps the boundary clean: Diane pays for Diane's agent.

Electricity and a machine that stays awake are the unlisted costs. Hermes has to be running to
receive a text.

---

## The three things the course blurs

Worth being blunt, because this is where the confusion came from:

1. **Hermes Agent ≠ OpenClaw.** Different projects, different people. You're running
   NousResearch's `hermes-agent`. When course material says "OpenClaw", mentally substitute.
2. **Hermes ≠ Claude OS.** Claude OS is Jack's dashboard — a console that *displays* stats from
   Hermes, your vault and Pinecone. It's a viewer. It is not part of this stack and this kit
   doesn't touch it.
3. **Hermes ≠ Claude Code.** Claude Code is the developer tool you build with. Hermes is the
   assistant you text. They both read the vault; only one of them writes code. Mazíx, Diane and
   Doug get Hermes only.

---

## What this is *not* for

Be clear with people about this so expectations don't drift:

- **Not a task manager.** It remembers; it doesn't nag you into doing things. (It can send a
  morning digest, which is not the same thing.)
- **Not a second brain you have to maintain.** If someone has to curate it, they won't. Capture
  is automatic and messy on purpose.
- **Not private from the model provider.** What they text goes to OpenAI or Anthropic like any
  other chat. The *storage* is local and theirs. The *thinking* is not.
- **Not a replacement for their existing tools.** Diane keeps Keap. Doug keeps whatever he
  keeps. This sits alongside.

---

## Decide before you start

Four questions per person. Write the answers into `people/<name>.md` before touching a terminal.

1. **What machine?** Mac → runbook 02. Windows → runbook 03.
2. **What model subscription do they already have?** ChatGPT $20 is the path of least
   resistance. If they have neither, that's a conversation before install day, not during.
3. **What are their buckets?** Four or five life areas, in their words, not yours. Doug's are
   probably `projects / clients / learning / personal`. Mazíx's are not.
4. **What's the one job?** One sentence. *"Doug wants to know what he was working on."*
   *"Mazíx wants ideas caught before they evaporate."* This sentence goes at the top of their
   `SOUL.md` and shapes every other decision.

---

**Next:** [`01-architecture.md`](01-architecture.md) if you want the mechanics ·
[`02-runbook-mac.md`](02-runbook-mac.md) if you're ready to build one.
