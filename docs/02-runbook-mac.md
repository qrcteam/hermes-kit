# 02 · Runbook — macOS

*One person, one machine, start to finish. Roughly 90 minutes, of which about 45 is the
[SOUL interview](04-soul-interview.md) and most of the rest is waiting for Docker.*

Windows? → [`03-runbook-windows.md`](03-runbook-windows.md).

---

## Before install day

Sort these out in advance. Discovering them mid-install is what turns 90 minutes into a
Saturday.

- [ ] **Their machine stays on and awake.** Hermes has to be running to receive a text.
      System Settings → Lock Screen → *Turn display off* is fine; **sleep is not**. Check
      Energy settings on a laptop.
- [ ] **A model subscription in their name** — ChatGPT Plus ($20) is the smoothest path.
      They'll log in themselves during step 6. You cannot use yours.
- [ ] **A GitHub account** (theirs or yours — decide now, see
      [`07-operator-notes.md`](07-operator-notes.md)).
- [ ] **A Pinecone account** — free tier, theirs.
- [ ] **Their four buckets, decided.** In their words. See doc 00, "Decide before you start".
- [ ] **45 minutes of their time** for the interview. Book it.

Throughout, replace `<NAME>` with a lowercase first name (`mazix`, `doug`, `diane`) and
`<USER>` with their macOS short username (`whoami`).

---

## 1 · Install the software

```bash
# Docker Desktop — the engine Hermes runs in
brew install --cask docker

# Obsidian — the window onto their memory
brew install --cask obsidian
```

**Open Docker Desktop once** and let it finish starting. It must be running for everything
below.

```bash
docker --version && docker ps
```
> **You should see** a version number and an empty container table. If `docker ps` errors,
> Docker Desktop isn't up yet.

---

## 2 · Make their Telegram bot

On their phone, in Telegram:

1. Message **@BotFather** → `/newbot`
2. Name it something they'll recognise — *"Doug's Assistant"*
3. Username must end in `bot` — `dougs_memory_bot`
4. **Copy the token.** Looks like `8123456789:AAF...`. Treat it like a password.
5. Message **@userinfobot** → it replies with their numeric user ID. Copy that too.

> **You should have** two strings: a bot token and a numeric user ID.

That user ID is the only thing standing between a stranger and their memory. Get it right.

---

## 3 · Build the vault

**Not `~/Desktop`. Not `~/Documents`. Not `~/Downloads`.** macOS blocks background jobs from
all three and does it silently. `~/Memory` is not blocked.

```bash
export NAME=<NAME>
export VAULT=~/Memory/$NAME-vault
mkdir -p "$VAULT"

# Copy the skeleton out of this kit
cp -R ~/Documents/Projects/hermes/templates/vault-skeleton/. "$VAULT"/
mv "$VAULT/gitignore.template" "$VAULT/.gitignore"
chmod +x "$VAULT/scripts/pinecone-sync"

# Their buckets — edit this line, four or five, their words not yours
for b in projects clients learning personal; do
  mkdir -p "$VAULT/wiki/topics/$b"
  sed "s/<bucket-name>/$b/g; s/<Bucket Name>/${b}/g; s/<YYYY-MM-DD>/$(date +%F)/" \
    "$VAULT/wiki/topics/_MANUAL-TEMPLATE.md" > "$VAULT/wiki/topics/$b/_manual.md"
done
rm "$VAULT/wiki/topics/_MANUAL-TEMPLATE.md"
mkdir -p "$VAULT/wiki/people" "$VAULT/wiki/reference" "$VAULT/raw/sessions"

cd "$VAULT" && git init -q -b main && git add -A \
  && git commit -qm "vault: initial skeleton for $NAME"
```

Now create an **empty private repo** on GitHub called `<NAME>-vault` — no README, no
`.gitignore` — and connect it:

```bash
cd "$VAULT"
git remote add origin git@github.com:<OWNER>/<NAME>-vault.git
git push -u origin main
```

> **You should see** the skeleton on GitHub, and the repo marked **Private**. If it says
> Public, stop and fix that now.

```bash
ls "$VAULT/wiki/topics"
```
> **You should see** their four bucket folders, each containing `_manual.md`.

---

## 4 · Create their Pinecone index

Sign in at [app.pinecone.io](https://app.pinecone.io) with **their** account, make an API key,
then:

```bash
export PC_KEY=<paste their pinecone key>

curl -s "https://api.pinecone.io/indexes/create-for-model" \
  -H "Api-Key: $PC_KEY" -H "Content-Type: application/json" \
  -H "X-Pinecone-API-Version: 2025-04" \
  -d '{
    "name": "'"$NAME"'-vault",
    "cloud": "aws",
    "region": "us-east-1",
    "embed": { "model": "llama-text-embed-v2", "field_map": { "text": "text" } }
  }' | python3 -m json.tool
```

> **You should see** JSON with `"name": "<NAME>-vault"` and a `host`. If it says the index
> already exists, that's fine — carry on.

Store the key **in a file, not in the environment**:

```bash
mkdir -p ~/.hermes/secrets
printf '%s' "$PC_KEY" > ~/.hermes/secrets/pinecone.key
chmod 600 ~/.hermes/secrets/pinecone.key
unset PC_KEY
```

Why a file: the promoter needs a key that can *write* to the index; the agent only ever needs
to *search*. Keeping it out of the agent's environment means a prompt injection can't
exfiltrate a credential that could wipe the index.

---

## 5 · Configure Hermes

```bash
mkdir -p ~/.hermes/{inbox,scripts,secrets}
cp ~/Documents/Projects/hermes/templates/env.template ~/.hermes/.env
chmod 600 ~/.hermes/.env
open -e ~/.hermes/.env    # paste the bot token and their numeric user ID
```

Install the two scripts and the capture skill:

```bash
K=~/Documents/Projects/hermes/templates

cp "$K/promote.sh"        ~/.hermes/promote.sh
cp "$K/vault-health.sh"   ~/.hermes/scripts/vault-health.sh
chmod +x ~/.hermes/promote.sh ~/.hermes/scripts/vault-health.sh

mkdir -p ~/.hermes/skills/note-taking/vault-capture
cp "$K/vault-capture-SKILL.md" ~/.hermes/skills/note-taking/vault-capture/SKILL.md
```

---

## 6 · Start Hermes

```bash
docker run -d --name hermes --restart unless-stopped \
  -p 127.0.0.1:8642:8642 \
  --env-file ~/.hermes/.env \
  -v "$HOME/.hermes:/opt/data" \
  -v "$HOME/Memory/$NAME-vault:/vault:ro" \
  nousresearch/hermes-agent:latest
```

**The `:ro` on the vault mount is the single most important character in this kit.** It is
what makes it impossible — not merely forbidden — for the agent to damage their memory.

Pin the two settings that must not drift:

```bash
docker exec hermes hermes config set database.journal_mode delete
docker exec hermes hermes config set approvals.mode smart
docker exec hermes hermes config set approvals.cron_mode deny
docker restart hermes
```

`journal_mode: delete` is not a preference. SQLite's write-ahead log **corrupts** across a
macOS Docker bind mount. Get it wrong and you'll see `database disk image is malformed` in a
week.

Now log in to their model — **they should type this part**, it's their account:

```bash
docker exec -it hermes hermes model
```

Pick their provider and follow the device-flow link. Credentials land in `~/.hermes/auth.json`.

```bash
docker exec hermes hermes status
```
> **You should see** Gateway running, Telegram ✓ configured, and a model with a logged-in
> provider.

**Test it now, before going further.** Have them text their bot "hello".
> **They should get a reply.** If nothing comes back, go to
> [`06-troubleshooting.md`](06-troubleshooting.md) → *The bot is silent* before continuing.

---

## 7 · Write their SOUL.md

**This is the step that matters.** Everything before it is plumbing; this is the product.

Run the interview in [`04-soul-interview.md`](04-soul-interview.md) — about 45 minutes — then:

```bash
cp ~/Documents/Projects/hermes/templates/SOUL.md.template ~/.hermes/SOUL.md
open -e ~/.hermes/SOUL.md
```

Write it in your own prose. Strip every HTML comment and every `<angle bracket>` before
saving. Then:

```bash
docker restart hermes
grep -c '<' ~/.hermes/SOUL.md
```
> **You should see** a low number — ideally `0`. Any `<placeholder>` left in the file is
> something the agent will confidently reason from as if it were true.

---

## 8 · Turn on the promoter

This is the piece that actually writes their memory.

```bash
sed -e "s|<USER>|$(whoami)|g" -e "s|<NAME>|$NAME|g" \
  ~/Documents/Projects/hermes/templates/com.hermeskit.vault-promote.plist \
  > ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist

plutil -lint ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist
launchctl unload ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist 2>/dev/null
launchctl load  ~/Library/LaunchAgents/com.hermeskit.vault-promote.plist
launchctl list | grep vault-promote
```
> **You should see** a line with exit status `0`. A `78` means the plist is malformed; a
> `1` usually means a path in it is wrong.

Prove it runs before trusting the schedule:

```bash
VAULT_ROOT=~/Memory/$NAME-vault \
PINECONE_INDEX=$NAME-vault \
PINECONE_STATE=~/.hermes/pinecone-state.json \
PINECONE_KEY_FILE=~/.hermes/secrets/pinecone.key \
PINECONE_SYNC=~/Memory/$NAME-vault/scripts/pinecone-sync \
bash ~/.hermes/promote.sh

cat ~/.hermes/promote-state.json
```
> **You should see** `"status": "ok"`. Anything else, read the message — it says what's wrong.

---

## 9 · Turn on the watchdog and the digest

```bash
# Shouts only when something is wrong. Silent otherwise, on purpose.
docker exec hermes hermes cron create "0 14 * * *" \
  --name vault-health --script vault-health.sh --no-agent --deliver telegram

# Their morning briefing. Adjust the hour — this is UTC.
docker exec hermes hermes cron create "0 13 * * *" \
  --name daily-digest --deliver telegram \
  "Good morning. Read /vault/wiki/topics/*/_manual.md and any notes from the last 3 days.
   Give a short briefing: what's open, what's owed, what they said they'd do. Two or three
   things, in plain sentences, not a table. If nothing needs attention, say so in one line."

docker exec hermes hermes cron list
```
> **You should see** both jobs listed. The digest hour is UTC — Mountain Time is UTC−6 in
> summer, so `13` = 7am. Check their actual timezone.

---

## 10 · Smoke test — the one that proves it all works

Have them text their bot:

> *remember I switched the Henderson job to the Tuesday crew because Thursday's tied up on Ruiz*

The agent should reply confirming it, in plain language.

**Then wait 15 minutes** (or run `bash ~/.hermes/promote.sh` with the env from step 8) and:

```bash
# 1. Did the note land in the vault?
ls -la ~/Memory/$NAME-vault/wiki/topics/*/ | grep -i henderson

# 2. Is it committed and pushed?
git -C ~/Memory/$NAME-vault log --oneline -3
git -C ~/Memory/$NAME-vault status -sb

# 3. Is it findable by meaning, not just keyword?
VAULT_ROOT=~/Memory/$NAME-vault PINECONE_INDEX=$NAME-vault \
PINECONE_STATE=~/.hermes/pinecone-state.json \
PINECONE_KEY_FILE=~/.hermes/secrets/pinecone.key \
~/Memory/$NAME-vault/scripts/pinecone-sync search "who is doing the Henderson work"
```

> **All three must pass.** A note on disk, a clean push, and a semantic search that finds it
> without sharing a keyword. If the third fails but the first two pass, their memory is safe —
> recall is just degraded to literal search. Fix it, but don't panic.

Finally, ask them to text: *"who's on Henderson?"* — the answer should come back right.

---

## 11 · Hand it over

```bash
# Open the vault in Obsidian so they can see their own memory
open -a Obsidian ~/Memory/$NAME-vault
```

Give them [`onboarding/<NAME>.md`](../onboarding/) and **nothing else**. Then walk away —
if they have to ask you something the doc should have answered, that's an edit to make.

Fill in `people/<NAME>.md` while it's fresh: paths, bot handle, index name, git remote, whose
model account. **No secrets in that file.**

---

## Checklist

- [ ] Docker Desktop installed and running; machine set to never sleep
- [ ] Bot created, token and numeric user ID in `~/.hermes/.env` (mode 600)
- [ ] Vault at `~/Memory/<NAME>-vault` — **not** Desktop/Documents/Downloads
- [ ] Private GitHub repo, pushed, confirmed private
- [ ] Pinecone index created; key in `~/.hermes/secrets/pinecone.key` (mode 600)
- [ ] Container running with **`:ro`** on the vault mount
- [ ] `journal_mode: delete` set
- [ ] Model logged in **on their own account**
- [ ] `SOUL.md` written, no `<placeholders>` left
- [ ] launchd job loaded, manual run returns `"status": "ok"`
- [ ] Watchdog + digest cron jobs created
- [ ] All three smoke tests pass
- [ ] `people/<NAME>.md` filled in
- [ ] Onboarding doc handed over

---

**Next:** [`05-make-it-useful.md`](05-make-it-useful.md) — the first week is where these
either stick or get abandoned.
