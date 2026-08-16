# 06 · Troubleshooting

*Organised by symptom, because that's what you have when you open this.*

Every trap in here has already been paid for once. The point of writing them down is that
nobody pays twice.

---

## First: the 30-second triage

```bash
docker ps | grep hermes                    # is it running at all?
docker exec hermes hermes status           # gateway, model, platforms
cat ~/.hermes/promote-state.json           # is memory actually being saved?
tail -20 ~/Library/Logs/vault-promote.log  # what did the promoter last do?
docker logs --tail 40 hermes               # what did the agent last complain about?
```

Those five lines identify most problems. `promote-state.json` is the one people forget, and
it's the one that catches silent failure.

---

## "The bot doesn't reply"

**Start here:** is the container running?

```bash
docker ps -a | grep hermes
```

**Not listed** → never created. Back to runbook step 6.
**Listed as `Exited`** → `docker logs --tail 50 hermes` will say why. Usually a malformed
`.env` or a bad mount path.

**Running but silent** — work down this list:

| Check | Command | Fix |
|---|---|---|
| Telegram configured? | `docker exec hermes hermes status` | Token missing/wrong in `.env` |
| Is their user ID allowed? | `grep ALLOWED ~/.hermes/.env` | Must be the **numeric** ID from @userinfobot, not their @handle |
| Model logged in? | `docker exec hermes hermes status` | `docker exec -it hermes hermes model` |
| Machine asleep? | — | System Settings → never sleep. The commonest cause by far |

### The Telegram cold-start wedge (macOS)

**Symptom:** worked yesterday, dead this morning, container looks perfectly healthy.

An upstream bug: the Telegram adapter can hang forever on cold start, retrying without ever
connecting. Look for a stuck retry counter:

```bash
grep -i "attempt.*8" ~/.hermes/logs/gateway.log | tail -5
```

Immediate fix:
```bash
docker restart hermes
```

Permanent fix — the kick watchdog, which detects the wedge and forces it loose:
```bash
cp ~/.hermes/host/hermes-telegram-kick.sh ~/.hermes/host/   # if not already there
launchctl load ~/Library/LaunchAgents/com.hermes.telegram-kick.plist
launchctl list | grep telegram-kick
```

Windows doesn't need this — it's macOS-specific.

### Two gateways fighting over one bot token

**Symptom:** `Conflict: terminated by other getUpdates request; make sure that only one bot
instance is running`, on repeat, for days. The kick watchdog fires every 5 minutes and never
wins, because this isn't the cold-start wedge — there really are two pollers.

Cause: a **native** Hermes gateway running on the host alongside the container. Both read the
same `~/.hermes` (it's bind-mounted), so they share the config, the state DB, the WhatsApp
session and the *same Telegram token* — and Telegram allows exactly one poller per bot.

```bash
ps aux | grep "[h]ermes_cli.main gateway"     # want: nothing
launchctl list | grep -i hermes.gateway        # macOS: want: nothing
```

Fix — the container is the install this kit builds; the host one is the interloper:

```bash
launchctl unload -w ~/Library/LaunchAgents/ai.hermes.gateway.plist
docker restart hermes
```

Telegram can take a minute to release the old long-poll. Watch for the recovery line:

```bash
grep "\[Telegram\] Connected" ~/.hermes/logs/gateway.log | tail -1
```

> Two gateways writing one SQLite state dir is also a plausible route to
> *"database disk image is malformed"* — see that section below if you've been running
> this way for a while.

---

## "WhatsApp doesn't reply"

Telegram working and WhatsApp silent is almost always one of two things, in this order.

**1. It isn't switched on — even though `.env` says it is.**

This is the one that eats an afternoon. `WHATSAPP_ENABLED=true` in `.env` is *not* what
starts the platform. Hermes only starts platforms listed under `platforms:` in
`config.yaml`. Miss it and everything looks right — the bridge pairs, the phone shows a
linked device, `.env` is correct — and no message is ever collected.

```bash
docker exec hermes hermes config get platforms.whatsapp.enabled   # want: true
docker logs hermes 2>&1 | grep -ci whatsapp                       # 0 = never started
```

Fix — add the block from `templates/config.yaml.template`, then `docker restart hermes`.

**2. The bridge is running in the wrong place.**

The adapter talks to its bridge on `http://127.0.0.1:<bridge_port>`, and that host is
hardcoded — only the port is configurable. So the bridge must live *inside the container*.
A bridge started on the host is unreachable, and you cannot work around it by pointing
Hermes at `host.docker.internal`: the bridge rejects any request whose Host header isn't
loopback.

```bash
# want: connected, from INSIDE the container
docker exec hermes curl -s http://127.0.0.1:3000/health
# want: nothing — a host bridge will fight the container one over the same session
ps aux | grep "[b]ridge.js"
```

Fix — kill any host bridge, then re-pair inside the container:

```bash
docker exec -it hermes hermes whatsapp
```

**Still silent after both?**

| Check | Command | Fix |
|---|---|---|
| Number allowed? | `grep WHATSAPP_ALLOWED ~/.hermes/.env` | Country code, digits only, no `+` — `15551234567` |
| Bridge paired? | `ls ~/.hermes/whatsapp/session/creds.json` | Missing → re-run `hermes whatsapp` |
| Session broken? | `docker logs hermes \| grep -i whatsapp \| tail` | Phone reset or WhatsApp unlinked it → re-pair |

WhatsApp periodically changes its Web protocol, which breaks third-party bridges until Hermes
ships an updated one. If it dies right after a WhatsApp update and nothing above applies,
update Hermes and re-pair.

---

## "It says it saved something but it's not there"

**This is the failure that matters most.** Work it in order.

**1. Is the note in the inbox?**
```bash
find ~/.hermes/inbox -name '*.md' -not -path '*_promoted*' -not -path '*_rejected*'
```
Empty → the agent never wrote it. Check the capture skill is installed:
```bash
ls ~/.hermes/skills/note-taking/vault-capture/SKILL.md
```
Missing → runbook step 5. Present but ignored → `docker restart hermes`, then check `SOUL.md`
actually tells it to use the vault (ground rule 2 in the template).

**2. Was it rejected?**
```bash
cat ~/.hermes/inbox/_rejected/*/REASONS.txt
```
This tells you exactly why in plain words. Almost always `unknown bucket` — the agent invented
a folder that doesn't exist. Either add the bucket or sharpen the bucket list in `SOUL.md`.

**3. Is the promoter running?**
```bash
cat ~/.hermes/promote-state.json     # how old is last_run?
launchctl list | grep vault-promote  # macOS
```
Stale → run it by hand with the env block from runbook step 8 and read the output.

**4. On Windows: the two-`.hermes` trap.**
The container writes to `C:\Users\<USER>\.hermes\inbox`; the promoter may be reading WSL's
`~/.hermes/inbox`. Both exist, neither errors, nothing is ever saved. Prove they're the same
directory:
```bash
docker exec hermes touch /opt/data/inbox/PROOF
ls /mnt/c/Users/<USER>/.hermes/inbox/PROOF && echo "SAME — good"
docker exec hermes rm /opt/data/inbox/PROOF
```

---

## "Nothing has synced in weeks and nobody noticed"

The one that already cost a fortnight here.

**Cause: the vault is under `~/Desktop`, `~/Documents` or `~/Downloads`.** macOS TCC blocks
launchd from all three. It fails with `Operation not permitted` — **silently**, into a log
nobody reads.

```bash
grep -i "not permitted" ~/Library/Logs/vault-promote.log
```

**Fix — move the vault. Git history comes with it:**

```bash
mv ~/Desktop/OldVault ~/Memory/<NAME>-vault
# update the container mount
docker stop hermes && docker rm hermes
# re-run the docker run from runbook step 6 with the new path
# update the plist
sed -i '' 's|Desktop/OldVault|Memory/<NAME>-vault|g' \
  ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist
launchctl unload ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist
launchctl load  ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist
```

There is no way to grant a launchd agent access to those folders reliably. Don't try. Move it.

**Windows equivalent:** the vault is inside OneDrive. Symptom is `note-DESKTOP-ABC123.md`
conflict copies. Same fix — move to `C:\Users\<USER>\Memory\`.

### …or the vault moved and something still points at the old path

Moving a vault is the right fix for the problem above, and it creates this one. Every absolute
path referencing the old location breaks — and the ones ending in `|| true` break *silently*.

**This has happened here.** The reference install's vault moved from `~/Desktop/OzLuv` to
`~/OzLuv`; the Pinecone sync hook kept pointing at the old path, swallowed its own error, and
the index would have gone stale indefinitely.

**After any move, sweep for the old path before you close the terminal:**

```bash
OLD=~/Desktop/OldVault
grep -rl "${OLD#$HOME/}" ~/.claude/settings.json ~/.claude/skills/bin/ \
                         ~/Library/LaunchAgents/ ~/.hermes/ 2>/dev/null
docker inspect hermes --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}'
```

Then confirm the sync actually runs, rather than assuming:

```bash
/usr/bin/python3 ~/<NEW>/scripts/pinecone-sync    # should print a file/record count
```

---

## "database disk image is malformed"

**Cause:** `journal_mode` isn't `delete`. SQLite's write-ahead log corrupts across Docker bind
mounts — virtiofs on macOS, 9p on Windows. This is not a preference and not a maybe.

```bash
docker exec hermes hermes config get database.journal_mode   # must be: delete
docker exec hermes hermes config set database.journal_mode delete
docker restart hermes
```

If it's already corrupt, the session database has to go. **The vault is untouched** — that's
the point of keeping memory in markdown rather than in the agent's database:

```bash
docker stop hermes
mv ~/.hermes/state.db ~/.hermes/state.db.corrupt-$(date +%F)
docker start hermes
```

They lose conversational history, not memory.

---

## "It gives generic answers / doesn't seem to know them"

Not a bug. A thin `SOUL.md`.

```bash
wc -l ~/.hermes/SOUL.md      # under ~60 lines is thin
grep -c '<' ~/.hermes/SOUL.md # leftover <placeholders>?
```

**Leftover placeholders are worse than blanks** — the agent reasons from them as if true.

Test with something only a well-briefed assistant could answer: *"should I call Scott today or
tomorrow?"* A generic answer means go back to [`04-soul-interview.md`](04-soul-interview.md),
specifically the Rhythm and Hard-nos sections.

Also confirm it can actually read the vault:
```bash
docker exec hermes ls /vault/wiki/topics
```
Empty or missing → the mount is wrong. Check the `-v` path in the `docker run`.

---

## "Search finds nothing" / recall is bad

**Is anything indexed?**
```bash
python3 -c "import json;d=json.load(open('$HOME/.hermes/pinecone-state.json'));print(len([k for k in d if not k.startswith('_')]),'files indexed')"
```

**Test it directly:**
```bash
VAULT_ROOT=~/Memory/<NAME>-vault PINECONE_INDEX=<NAME>-vault \
PINECONE_STATE=~/.hermes/pinecone-state.json \
PINECONE_KEY_FILE=~/.hermes/secrets/pinecone.key \
~/Memory/<NAME>-vault/scripts/pinecone-sync search "something you know is in there"
```

| Error | Fix |
|---|---|
| `No PINECONE_API_KEY` | Key file missing or empty — runbook step 4 |
| `401` | Wrong key, or key from the wrong Pinecone account |
| `404` | Index name doesn't match `PINECONE_INDEX` |
| Runs, finds nothing | Never synced. Run without `search` to do a full sync |

**Important:** Pinecone being broken degrades recall to literal keyword search. It does **not**
lose notes. Fix it calmly — nothing is at risk.

---

## "There's a conflict branch"

The promoter hit a git conflict, parked the work safely, and told them. Nothing is lost — this
is the escape hatch working as designed.

```bash
cd ~/Memory/<NAME>-vault
git branch -a | grep hermes-conflict
git log --oneline main..hermes-conflict/<branch>   # what's on it
git merge hermes-conflict/<branch>                 # usually clean
git push origin main
git branch -d hermes-conflict/<branch>
git push origin --delete hermes-conflict/<branch>
```

Nearly always caused by someone editing the vault through the GitHub web UI. Ask them not to.

---

## "Model errors" / "provider exhausted"

```bash
docker exec hermes hermes status    # look at the provider line
```

- **`exhausted` / 401** → subscription lapsed or OAuth expired.
  `docker exec -it hermes hermes model` and log in again.
- **HTTP 400 on a model slug** → that model isn't available on their plan. **Don't chase it.**
  Several plausible-looking slugs (`gpt-5.x-codex` variants) return 400 for everyone on a
  consumer subscription. Pick one that works and move on; hours have been lost to this.

```bash
docker exec hermes hermes model    # lists what their credential can actually reach
```

### "not a valid model ID" right after adding an OpenRouter key

Happened live 2026-08-13, on the reference install. With `model.provider: auto`, adding
`OPENROUTER_API_KEY` to `.env` can flip provider resolution: the **main** model suddenly
routes to OpenRouter carrying its ChatGPT-backend model ID, OpenRouter answers
`400 — openai-codex/… is not a valid model ID`, and 400s don't retry — the bot just says
the provider failed. The bot goes from working to mute *because a key was added*.

The rule: **whenever you add a second provider key, pin the primary and declare the
fallback explicitly** — never leave `auto` to guess with two credentials in reach:

```bash
docker exec hermes hermes config set model.provider openai-codex
docker exec hermes hermes config set fallback_providers \
  '[{"provider":"openrouter","model":"anthropic/claude-sonnet-4.5"}]'
docker restart hermes
docker exec hermes hermes -z "Reply with exactly: PROVIDER-OK"   # proof, not vibes
```

Now the primary is theirs-and-explicit, and OpenRouter is what it was meant to be: the
understudy that steps in on rate-limits, overloads, and outages.

---

## Rebuilding from scratch

Safe, because the memory isn't in the container:

```bash
docker stop hermes && docker rm hermes
docker pull nousresearch/hermes-agent:latest
# re-run the docker run from runbook step 6
docker exec hermes hermes config set database.journal_mode delete
docker exec hermes hermes config set approvals.cron_mode deny
docker restart hermes
docker exec hermes hermes cron list    # ← cron jobs may need recreating
```

`~/.hermes` and the vault both survive. **Check the cron jobs afterwards** — that's the one
thing people forget, and a missing watchdog is invisible until you need it.

---

## Things that look broken and aren't

| Looks wrong | Actually |
|---|---|
| Watchdog never says anything | Correct. It's silent when healthy — that's the design |
| `promote.sh` logs nothing most runs | Correct. It only logs when it does something |
| Notes take up to 15 min to appear | Correct. That's the promoter interval |
| `hermes mcp list` says none configured | Correct. This kit doesn't use MCP servers |
| A `[[link]]` is greyed out in Obsidian | Correct. Links to unwritten notes are deliberate |
| `_promoted/` filling with copies | Correct. Safety copies, auto-deleted after 7 days |

---

## Never do these

- **Never mount `/var/run/docker.sock`** into the container. It hands the agent control of the
  whole machine.
- **Never mount `~/.claude`, `~/.ssh`, or a code repo.** The vault and `~/.hermes`, nothing else.
- **Never remove `:ro` from the vault mount.** It's the only protection that survives a bad
  prompt, and it's enforced by the kernel rather than by asking nicely.
- **Never share one bot, index, or vault between two people.**
- **Never delete from the vault to "clean up".** Move it, or mark it `superseded-by:`.
- **Never edit the vault through the GitHub web UI.** That's what causes conflict branches.
