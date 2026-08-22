# 07 · Operator Notes

*The fleet view. Who has what, what you're on the hook for, and what to check.*

---

## The fleet

Keep this table current. Details go in `people/<name>.md`; this is the glance.

| | Oz | Mazíx | Diane | Doug |
|---|---|---|---|---|
| **Status** | live | — | — | — |
| **Platform** | macOS | | | |
| **Vault** | `~/OzLuv` | `~/Memory/mazix-vault` | | |
| **Git remote** | `qrcteam/ozluv-vault` | | *her own account* | |
| **Pinecone** | `ozluv-vault` (Oz acct) | own account | **her account** | own account |
| **Model** | ChatGPT (Oz) | own | **own** | own |
| **Bot** | `@Ozzzhermesbot` | | | |
| **Writer** | Claude Code | Hermes | Hermes | Hermes |

**Oz's vault moved off `~/Desktop` to `~/OzLuv` on 2026-08-12** — out of TCC's way at last. It
still syncs from a Claude Code SessionStart hook rather than the promoter, which is fine while
Claude Code is the writer. If you ever want it on the same footing as everyone else, the
promoter would work against it now that the path is unblocked.

**A move like that breaks every absolute path pointing at the old location, silently.** That
one broke two:

| What | Was | Now |
|---|---|---|
| SessionStart hook in `~/.claude/settings.json` | `$HOME/Desktop/OzLuv/scripts/pinecone-sync` | `$HOME/OzLuv/...` |
| `~/.claude/skills/bin/sync-all.sh` repo list | `$HOME/Desktop/OzLuv` | `$HOME/OzLuv` |

Both fixed 2026-08-12. The hook ended in `|| true`, so it failed without a murmur and the
index would have gone quietly stale — the exact failure mode this kit is built to prevent,
found in the reference install while writing the kit. **After any vault move, grep for the old
path before you close the terminal:**

```bash
grep -rl "OLD/PATH" ~/.claude/settings.json ~/.claude/skills/bin/ ~/Library/LaunchAgents/
docker inspect hermes --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}'
```

---

## Your setup is the odd one out

Worth being explicit, because it's the thing most likely to confuse you at 11pm:

**Yours:** Claude Code writes the vault (`/end`, `/ask`), Hermes only reads. Pinecone syncs
from a Claude Code session hook.

**Theirs:** Hermes writes via the inbox, the promoter files it, launchd runs the sync. No
Claude Code anywhere.

So when you're debugging one of theirs, **don't reach for `/end` or the SessionStart hook** —
neither exists on their machine. The equivalent is `promote.sh` and the launchd job.

---

## Where the boundary sits

### Mazíx and Doug — family
Their stack can live in `qrcteam` where you can clone and fix things. Practical, and neither is
going to object to you being able to read their notes. Say so out loud once anyway, so it's
consent rather than assumption.

### Diane — a paying client
**Everything is hers:** her Pinecone account, her GitHub repo, her ChatGPT subscription, her
machine.

You should be able to walk away and take nothing with you, and she should be able to fire you
and lose nothing. That means:

- You do **not** hold her API keys after install. Walk her through creating them; she types
  them in.
- Her vault repo lives in her GitHub account. Add yourself as a collaborator if she wants
  support; she can remove you in one click.
- Nothing of hers ever goes into a `qrcteam` repo, an index of yours, or your Airtable.

If she asks you to hold a key for support convenience, that's her call — write it in
`people/diane.md` that she asked, and use a key you can identify and she can revoke.

**The test:** if the engagement ended tomorrow, could she keep using this with no involvement
from you? If not, fix it now rather than at the awkward moment.

---

## What you support, and what you don't

Be explicit with all three at handover — the onboarding doc says this too:

**You handle:** the container won't start, notes stop saving, the bot goes quiet, sync breaks,
Hermes ships a new version.

**They handle:** their own subscription and its billing, keeping the machine awake and online,
what they actually put in their vault.

**Nobody handles:** the model saying something wrong. It's an assistant, not an oracle. Set
this expectation on day one and it's fine; leave it and the first hallucination becomes a
support ticket about trust.

---

## Monthly, five minutes each

```bash
NAME=<name>
git -C ~/Memory/$NAME-vault log --oneline --since="1 month ago" | wc -l   # is it growing?
cat ~/.hermes/promote-state.json                                          # healthy?
ls ~/.hermes/inbox/_rejected/*/ 2>/dev/null                               # anything stuck?
git -C ~/Memory/$NAME-vault status -sb                                    # pushed?
```

**The number that matters is the first one.** A vault that isn't growing means they stopped
using it, and no amount of uptime fixes that. A perfectly healthy container nobody texts is a
failed install.

Then ask them: *"what's it got wrong lately?"* Every answer is a line missing from `SOUL.md`.

---

## Costs

| Per person | |
|---|---|
| Hermes, Obsidian, git, Pinecone free tier | $0 |
| Model subscription | ~$20/mo, **theirs** |

You're not carrying anything recurring. Your cost is time: roughly 90 minutes to install, plus
maybe 15 minutes a month per person once it's settled.

**If you ever bill for this** — Diane, or a future client — bill the setup and a small monthly
for the check-in and support. Don't bill for infrastructure you don't own.

---

## Upgrading Hermes

Hermes moves fast. Don't chase releases; upgrade when something you need is in one.

```bash
docker pull nousresearch/hermes-agent:latest
docker stop hermes && docker rm hermes
# re-run the docker run from runbook step 6 — unchanged
docker exec hermes hermes config set database.journal_mode delete
docker exec hermes hermes config set approvals.cron_mode deny
docker restart hermes
docker exec hermes hermes cron list      # ← recreate any that vanished
docker exec hermes hermes status
```

`~/.hermes` and the vault survive. **Always check cron afterwards** — a missing watchdog is
invisible until the day you need it.

**Upgrade yours first.** You are the canary; nobody else should meet a regression before you
have.

---

## Changing the model breaks cron

Not just upgrades — **any** model change, including re-picking the same model in `hermes model`,
which rewrites `model.default` from `provider/model` to `model`. Every cron job that isn't
pinned records the old string and is then **skipped to prevent unintended spend** rather than
run. Nobody is told; the digest simply stops arriving.

```bash
# after ANY model change, on every install:
docker exec hermes cat /opt/data/cron/jobs.json | python3 -c "
import json,sys
for j in json.load(sys.stdin):
    print(('ENABLED ' if j.get('enabled') else 'disabled'), j.get('name'), '| pinned=', j.get('model'))"
docker exec hermes hermes cron edit <job_id> --model <m> --provider <p>
```

**Monitor jobs lie about this.** One that only calls the agent when its watched output changes
shows `ok` forever and fails the first time it has real work. Read `jobs.json`, not the status
column.

---

## Things this kit deliberately doesn't do

So you don't get talked into them:

- **No shared vault between two people.** Even Oz and Mazíx. Two writers, one git index, over a
  bind mount, with no human watching — it will wedge. If they need shared knowledge, put it in
  a third repo both read.
- **No agent write access to the vault.** The `:ro` mount is the design. Everything else assumes it.
- **No one-command installer.** The runbook is written so it *could* become one — but an
  installer you can't read is how the original setup got confusing. If you build one later,
  build it *from* the runbook and keep the runbook as the source of truth.
- **No Claude OS / dashboard integration.** Separate system, separate decision. It reads this
  stack; it isn't part of it.
- **No MCP servers in Hermes.** `pinecone-sync search` works from the read-only mount and adds
  no second key path.

---

## If you hand this to someone else

Everything needed is in this repo except three things that live only in your head:

1. **Which account owns what** — that's the fleet table above. Keep it current.
2. **Why each person's buckets are what they are** — that's `people/<name>.md`.
3. **What each person actually wants out of it** — that's the top of their `SOUL.md`.

Keep those three current and this is transferable. Let them rot and it's tribal knowledge again.
