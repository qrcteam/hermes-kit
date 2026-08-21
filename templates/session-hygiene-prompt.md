# Session hygiene — the paste-and-go prompt

*Run this at handover, on their machine, in their Hermes — the last thing you do before
you walk away. Have **them** paste it and send it, so the standing rules land in their
memory under their own account.*

*It does two jobs. It stops sessions running forever and quietly burning context, and it
tells their assistant to talk like a person instead of a terminal. Both are habit
problems that show up in week two, which is exactly when nobody's watching.*

*Proven on Oz's install — `session_reset.mode: idle` / `idle_minutes: 120` are real
config keys and Hermes sets them itself when asked. Verify afterwards with
`docker exec hermes hermes config get session_reset`.*

*If they only want Telegram, or they're comfortable with technical detail, keep part 1
and drop part 2 — a technical person will find the plain-language rule patronising.*

*Budget note: part 2 lands in their `USER.md`, which is capped (`memory.user_char_limit`,
1375 characters by default) and injected into every turn. This prompt spends roughly a
third of a fresh client's budget on day one. That's a fair trade — tone is the thing
they'll notice every day — but it's a third gone, so don't also paste in a pile of
preferences they haven't asked for.*

---

Please configure two things for session management:

1. Auto-reset idle sessions after 2 hours. Set `session_reset.mode` to `idle` and
`session_reset.idle_minutes` to `120` in the config, so if I don't send anything for
2 hours, the session automatically resets to prevent runaway context/token buildup.

2. Proactively suggest starting a new session (`/new`) more often — don't wait for me to
notice context is bloated. Specifically, suggest `/new` when:
   - We clearly finish one topic/task and are about to start an unrelated one (e.g. I
     switch from asking about code to asking about a recipe, or from a work task to a
     personal one)
   - Context usage (`context_pct`) climbs high, even mid-topic
   - A task or conversation thread reaches a natural resolution (approved, deployed,
     decided, closed)

Please save this as a standing rule in memory so it persists across sessions, and don't
wait for me to ask each time — just flag it naturally ("Looks like we've wrapped up X —
want a fresh session before we move to Y?").

Also, I'm not technical — please keep responses plain-language only. Specifically:

- Don't show me code snippets, terminal commands, file paths, JSON, or config syntax
  unless I explicitly ask to see them
- Summarize what you did in outcomes, not steps ("I fixed the connection issue" instead
  of showing the commands)
- If something technical needs my input (like a password, a click, or a decision), tell
  me exactly what to click or say in plain words — no jargon
- Save this as a standing preference in memory
