---
name: claude-delegate
description: "Delegate a task to Claude Code on the host via handoff files."
version: 0.1.0
author: Hermes Kit
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [Delegation, Claude, Handoff, Automation]
---

# Delegate a task to Claude Code

The host machine runs Claude Code with the owner's full skill library (site audits,
mockups, SEO reports, deploys). You can hand it a task through the handoff drop-box
mounted at `/opt/data/handoffs/`.

## When to Use

- The owner asks for something a Claude skill owns: "run a site audit on X",
  "mock up a homepage for Y", "generate the SEO report".
- A task needs host-side tools you don't have (deploys, repos, local scripts).

## How

1. **Write the task file** (terminal tool). Pick a short kebab-case slug:

   ```bash
   cat > /opt/data/handoffs/inbox/audit-joespizza.md <<'EOF'
   Run /audit-site on joespizza.com (Joe's Pizza, Albuquerque).
   Deliverable: the hosted audit page URL + tracked link.
   Requested via Hermes by the owner on Telegram; reply-ready summary please.
   EOF
   ```

   Give full context in the file — Claude starts cold: business name, URL, what
   the deliverable is, any constraints the owner stated.

2. **Tell the owner** you've handed it off and roughly how long it takes
   (audit ≈ 10–20 min; simple questions ≈ 1–2 min). Do NOT block on clarify
   while waiting.

3. **Poll for the result** — it appears at
   `/opt/data/handoffs/outbox/<slug>.result.md`:

   ```bash
   ls /opt/data/handoffs/outbox/ | grep audit-joespizza || echo not-yet
   ```

   Check every minute or two (or when the owner asks "is it done?").
   The file ends with `status: ok` or `status: FAILED`.

4. **Report back**: summarize the result file for the owner, including any
   URLs it contains. If FAILED, say so plainly and offer to retry once.

## Rules

- One task per file. Never write outside `inbox/`; never edit `outbox/` files.
- If no result after 30 min, tell the owner it looks stuck rather than silently waiting.
- Don't delegate what you can do yourself (answering questions, memory, email drafts).

## Vault writes (person notes, wiki edits, memory promotions)

The vault at `/vault` is read-only BY DESIGN — that never changes. When you need
something WRITTEN there (a person note, a wiki page, an update to an existing note),
delegate it exactly like any other task:

```bash
cat > /opt/data/handoffs/inbox/vault-write-person-laurie.md <<'TASK'
Vault write request from Hermes. Create/update wiki/people/laurie.md in Oz's vault
(~/OzLuv) with: [the content, complete and final]. Follow the vault README
conventions, cross-link related notes, commit and push.
TASK
```

Claude Code holds the write key to the vault and applies its conventions
(frontmatter, cross-links, commit format). Result lands in outbox/ as usual.
Never ask for a writable vault mount — the one-way door is the safety model.
