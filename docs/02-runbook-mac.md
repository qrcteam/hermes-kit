# 02 · Runbook — macOS

*One person, one machine, start to finish. Roughly 90 minutes, of which about 45 is the
[SOUL interview](04-soul-interview.md) and most of the rest is waiting for Docker.*

> ## This install is Claude-driven
>
> **Claude Code runs on *their* machine, reads this runbook, and executes it gate by gate
> while you supervise.** You are not typing these commands. You paste a gate prompt, read
> what comes back, and answer the questions Claude stops to ask.
>
> Ruled by Oz 2026-08-22: *"Claude-driven install is vital — I won't work on it without
> Claude."* Proven remotely on install #4 (Laurie, macOS).
>
> **To run it:** open [`install-guide/index.html`](install-guide/index.html) — 12 stamped
> gates, a ready paste-to-Claude prompt per gate, screenshot slots, and a one-click log
> export for `people/<NAME>.md`.
>
> **The commands below are what Claude executes**, and what you fall back to by hand if
> Claude is unavailable. This file is the source of truth for *what* happens; the gate
> prompts are the source of truth for *how it gets driven*. When the two disagree, fix
> both — never let a gate prompt carry a step this file doesn't.

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
- [ ] **Claude Code installed on their machine, signed in to THEIR Claude account.** This is
      how the install is driven. Their account, not yours — nothing of yours should
      authenticate on a client's machine.
- [ ] **A GitHub account, and whose it is decided.** A paying client's vault repo is created in
      **their** account on install day; family can use `qrcteam`. See
      [`07-operator-notes.md`](07-operator-notes.md).
- [ ] **A Pinecone account** — free tier, theirs.
- [ ] **Their four buckets, decided.** In their words. See doc 00, "Decide before you start".
- [ ] **45 minutes of their time** for the interview. Book it.

Throughout, replace `<NAME>` with a lowercase first name (`mazix`, `doug`, `diane`) and
`<USER>` with their macOS short username (`whoami`).

**The kit lives at `~/hermes-kit` on their machine** — every command below uses `$KIT`:

```bash
export KIT=~/hermes-kit
git clone https://github.com/qrcteam/hermes-kit.git "$KIT" 2>/dev/null || git -C "$KIT" pull
```

Not `~/Documents/Projects/hermes` — that is where the kit sits on **your** machine, and having
the same path on both is how a command meant for their Mac gets run on yours. Different paths
make that mistake impossible. (`~/Documents` is fine for the kit itself — the
Desktop/Documents/Downloads ban is about the *vault*, which is read by a background job.)

---

## How this install runs

**The loop, all day:**

1. You paste the gate's prompt into Claude Code on their machine.
2. Claude does the work and shows you the output of the verification command.
3. Claude **stops and asks** whenever the step needs a human — see the list below.
4. You stamp the gate on the card and move on. A red gate is not a gate you pass.

**Whose everything:** their machine, their Claude account, their accounts throughout. Nothing
of yours authenticates on a client's machine, so there is nothing to remove at handover and
they could fire you tomorrow and lose nothing.

### Standing rules for Claude — true for every gate

These are the ones that cost real money or real memory when broken. The gate-00 prompt sets
them; they are repeated here because this is the file Claude actually reads.

- **The vault never goes under `~/Desktop`, `~/Documents` or `~/Downloads`.** macOS blocks
  background jobs from all three, silently. `~/Memory/<NAME>-vault`, always.
- **The vault mount is always `:ro`.** That single character is what makes damaging their
  memory impossible rather than merely forbidden.
- **Keys never enter the agent's environment.** Pinecone's key lives in a file the promoter
  reads. Model credentials come from an OAuth device flow, never a pasted key.
- **Never echo, log or commit a secret.** Show `.env` **key names only**, never values.
- **Move, don't delete.** Nothing is ever `rm -rf`'d on someone else's machine.
- **Stop at every gate and show the verification output.** Don't self-certify and continue —
  a step that reports success without printing its proof has not been done.
- **When a step needs a human, stop and ask.** Never guess a bucket word, never invent an
  account, never fake a scan.

### What Claude cannot do — plan for these nine

Every one of these needs a human's hands or a human's account. They are where the install
stalls if nobody is expecting them, and they are the reason the operator stays on the call.

| # | Gate | Who does it | What it is |
|---|---|---|---|
| 1 | 01 | **They** | Docker Desktop's first launch — admin password and licence prompt |
| 2 | 02 | **They**, on their phone | @BotFather `/newbot`, then @userinfobot for the numeric ID |
| 3 | 03 | **They** | `gh auth login` — the account this names is the account that will own their memory |
| 4 | 03 | **They**, out loud | Their bucket words. Claude must stop and ask; the template's four are not theirs |
| 5 | 04 | **They** | Pinecone signup and creating the API key on their own screen |
| 6 | 06 | **They** | The model login device flow — their subscription, their card |
| 7 | 06 | **They**, on their phone | The WhatsApp QR scan, if they want WhatsApp |
| 8 | 07 | **You** | The SOUL interview. Claude writes it up; it cannot conduct it |
| 9 | 10 | **They** | Texting the bot the smoke-test message, and the recall question after |

Four of those are account signups. Chase them **before install day** — discovering a missing
Pinecone account at minute forty is two people watching an inbox.

### If Claude isn't available

Work the numbered steps below by hand, in order. Everything still works; it is just slower and
every typo is yours. Log it as a deviation in `people/<NAME>.md` so the next install knows the
path was exercised.

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

### Also ask them about WhatsApp

Most people want WhatsApp too, and for a lot of them it's the one they'll actually use —
it's already where they message everyone else, so the agent sits in the same list as their
friends instead of in an app they opened for this. Run **self-chat mode**: they message
*themselves* on their own number and the agent answers in that thread. No second phone
number, nothing new to install.

Nothing to do now — WhatsApp pairing needs the container running, so it happens in step 6.
Just find out now whether they want it, and get their number in the form `15551234567`
(country code, digits only, no `+`).

> **Worth saying out loud to them:** the WhatsApp bridge emulates WhatsApp Web rather than
> using Meta's official Business API. Meta doesn't sanction it. For personal, conversational
> use it's fine, and that's what self-chat is. Don't put a *client's* business number on it
> and don't automate outbound messages from it.

---

## 3 · Build the vault

**Not `~/Desktop`. Not `~/Documents`. Not `~/Downloads`.** macOS blocks background jobs from
all three and does it silently. `~/Memory` is not blocked.

```bash
export NAME=<NAME>
export VAULT=~/Memory/$NAME-vault
mkdir -p "$VAULT"

# Copy the skeleton out of this kit
cp -R $KIT/templates/vault-skeleton/. "$VAULT"/
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

Now the private remote. **Use `gh`, not SSH** — no keypair to generate on someone else's
machine, and an unqualified repo name creates it in the authenticated account by construction,
which is exactly the ownership you want:

```bash
brew install gh          # if not already there
gh auth login            # ← THEY log in, on their own account
```

> **Human, not Claude.** Whatever account `gh auth status` names is the account that will own
> their memory. Read it back to them before continuing.

```bash
cd "$VAULT"
gh repo create <NAME>-vault --private --source=. --remote=origin --push
gh repo view --json owner,visibility
```

> **You should see** `"PRIVATE"` and **their** account as owner. If it says Public, or the
> owner is `qrcteam` when it shouldn't be, stop and fix that now.

**Whose account is a decision, not a default.** A paying client's vault repo is created in
**their** GitHub on install day — see [`07-operator-notes.md`](07-operator-notes.md). If they
want you able to fix things without a screen-share, they add you as a collaborator on their own
repo and can revoke it in one click. For family, `qrcteam` is fine — say the consent sentence
out loud once anyway.

```bash
ls "$VAULT/wiki/topics"
```
> **You should see** their four bucket folders, each containing `_manual.md`.

---

## 4 · Create their Pinecone index

Sign up at [app.pinecone.io/?sessionType=signup](https://app.pinecone.io/?sessionType=signup) with **their** account (free tier), make an API key,
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
cp $KIT/templates/env.template ~/.hermes/.env
chmod 600 ~/.hermes/.env
open -e ~/.hermes/.env    # paste the bot token and their numeric user ID
```

Install the two scripts and the two memory skills:

```bash
K=$KIT/templates

cp "$K/promote.sh"        ~/.hermes/promote.sh
cp "$K/vault-health.sh"   ~/.hermes/scripts/vault-health.sh
chmod +x ~/.hermes/promote.sh ~/.hermes/scripts/vault-health.sh

mkdir -p ~/.hermes/skills/note-taking/vault-capture
cp "$K/vault-capture-SKILL.md" ~/.hermes/skills/note-taking/vault-capture/SKILL.md

mkdir -p ~/.hermes/skills/note-taking/session-log
cp "$K/session-log-SKILL.md"   ~/.hermes/skills/note-taking/session-log/SKILL.md
```

**The two skills do different halves of memory, and they need each other:**

- `vault-capture` saves **facts**, the moment they're said — *"Henderson moved to the Tuesday
  crew."*
- `session-log` saves **what they did**, once, at the end of a working conversation —
  *"rescheduled Henderson, sent the Ruiz quote, waiting on Trenton."*

Facts alone answer "what do I know?" but not "what was I working on?", which is the question
most people actually ask a week later. The log also records **where they stopped**, which is the
line they'll reread most.

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

# quiet bot — no tool chrome in a non-technical person's chat
docker exec hermes hermes config set display.platforms.telegram.tool_progress off

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

### Pair WhatsApp — skip if they only want Telegram

Telegram has to be working before you start this. Two channels failing at once is twice the
diagnosis.

Confirm the `platforms.whatsapp` block from `config.yaml.template` is in their config —
**this is the step everything hinges on.** `WHATSAPP_ENABLED=true` in `.env` is not enough
on its own; Hermes only starts platforms listed under `platforms:`:

```bash
docker exec hermes hermes config get platforms.whatsapp.enabled   # want: true
```

Then pair. **Inside the container** — the bridge only ever listens on the container's own
loopback, so pairing anywhere else produces a bridge Hermes cannot reach:

```bash
docker exec -it hermes hermes whatsapp
```

It installs the bridge dependencies on first run (~30s, looks like a hang — wait), asks for
the mode (**self-chat**), then prints a QR code. On their phone: **WhatsApp → Settings →
Linked Devices → Link a Device**, and point the camera at the terminal.

> Garbled QR? The terminal needs to be at least 60 columns and Unicode-capable.

```bash
docker restart hermes
docker logs hermes 2>&1 | grep -i whatsapp | tail -3
```
> **You should see** `[Whatsapp] Bridge ready (status: connected)`.

**Test it.** Have them message *themselves* on WhatsApp — their own name at the top of the
chat list — and say "hello".
> **They should get a reply in that same thread.** If not:
> [`06-troubleshooting.md`](06-troubleshooting.md) → *WhatsApp doesn't reply*.

The pairing lives in `~/.hermes/whatsapp/session` and survives restarts, so this is a
one-time step. That folder is a full credential to their WhatsApp account — it must never be
copied to another machine, committed, or included in a backup that leaves the laptop.

---

## 7 · Write their SOUL.md

**This is the step that matters.** Everything before it is plumbing; this is the product.

Run the interview in [`04-soul-interview.md`](04-soul-interview.md) — about 45 minutes — then:

```bash
cp $KIT/templates/SOUL.md.template ~/.hermes/SOUL.md
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
  $KIT/templates/com.hermeskit.vault-promote.plist \
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

**Now pin the digest to their model.** An unpinned job is skipped — not run — the moment the
global model config drifts, and it drifts on something as small as re-picking the same model in
`hermes model` (the picker rewrites `openai-codex/gpt-5.6-terra` to `gpt-5.6-terra`, and that
counts). The failure is silent from the person's side: the digest just stops arriving.

```bash
docker exec hermes hermes cron list | grep -A1 daily-digest      # grab the job id
docker exec hermes hermes cron edit <job_id> \
  --model <model from hermes status> --provider <provider from hermes status>
```

The watchdog runs `--no-agent`, so it needs no pin. **Any job that calls the agent does.**
See [`06-troubleshooting.md`](06-troubleshooting.md) → *"The digest stopped arriving"*.

---

## 10 · Smoke test — the one that proves it all works

**First, check the wiring in one command** — it walks every item on the checklist at the
bottom of this doc so you don't have to hold it in your head:

```bash
bash $KIT/templates/install-verify.sh
```

Read-only; it reports and never changes anything. Every `FAIL` prints its own fix underneath,
and the ones it could repair itself say so. Exit code is non-zero while anything is red, so you
can re-run after each fix until it's clean.

To let it repair the mechanical ones — missing inbox, wrong file mode, uncopied skill,
unloaded launchd job, stopped container, drifted config key:

```bash
bash $KIT/templates/install-verify.sh --fix
docker restart hermes    # only if it changed a config key
```

`--fix` touches **only** what is idempotent, reversible and can't lose data. It deliberately
will not re-create the container, move the vault, `git init` anything, log in a model, pair
WhatsApp, edit `SOUL.md`, or unload a competing host gateway — those need a human, an account,
or a decision that isn't a script's to make. Anything it can't repair it says so plainly and
prints the command it tried.

Get it green **before** the live test below — a failing smoke test on top of a half-finished
install tells you nothing about which of the two is broken.

Then have them text their bot:

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

**Set the session rules before you leave.** Have *them* paste
[`templates/session-hygiene-prompt.md`](../templates/session-hygiene-prompt.md) into their
Hermes and send it. It does two jobs: idle sessions reset after two hours instead of running
forever and quietly burning context, and the agent starts talking in plain language instead of
showing them terminal commands. Both are week-two problems, and week two is when nobody's
watching. Then verify Hermes actually wrote the config rather than just agreeing to:

```bash
docker exec hermes hermes config get session_reset
```
> **You should see** `mode: idle` and `idle_minutes: 120`. If it only said it would, say it
> again — a model agreeing is not a config change.

Give them [`onboarding/<NAME>.md`](../onboarding/) and **nothing else**. Then walk away —
if they have to ask you something the doc should have answered, that's an edit to make.

Fill in `people/<NAME>.md` while it's fresh: paths, bot handle, index name, git remote, whose
model account. **No secrets in that file.**

---

## Checklist

**`bash templates/install-verify.sh` checks everything below except the last three by
itself.** Run it first; work this list only for whatever it can't see.

- [ ] Claude Code ran the install on their machine, on **their** Claude account
- [ ] Kit cloned to `~/hermes-kit` on their machine (not your `~/Documents` path)
- [ ] Docker Desktop installed and running; machine set to never sleep
- [ ] Bot created, token and numeric user ID in `~/.hermes/.env` (mode 600)
- [ ] Vault at `~/Memory/<NAME>-vault` — **not** Desktop/Documents/Downloads
- [ ] Private GitHub repo, pushed, confirmed private **and confirmed owned by the right account**
- [ ] Pinecone index created; key in `~/.hermes/secrets/pinecone.key` (mode 600)
- [ ] Container running with **`:ro`** on the vault mount
- [ ] `journal_mode: delete` set
- [ ] Model logged in **on their own account**
- [ ] Both memory skills installed — `vault-capture` **and** `session-log`
- [ ] Session log tested: said "log my work", a `<date>-log.md` reached the vault
- [ ] If they want WhatsApp: `platforms.whatsapp.enabled: true` **in config.yaml**, paired
      from inside the container, and they got a reply in their own self-chat
- [ ] Exactly one gateway running — container only, no native `hermes gateway` on the host
- [ ] `SOUL.md` written, no `<placeholders>` left
- [ ] launchd job loaded, manual run returns `"status": "ok"`
- [ ] Watchdog + digest cron jobs created; **digest pinned** to their model + provider
- [ ] All three smoke tests pass
- [ ] `people/<NAME>.md` filled in
- [ ] Session hygiene prompt pasted by them; `session_reset` verified as `idle` / `120`
- [ ] Onboarding doc handed over

---

**Next:** [`05-make-it-useful.md`](05-make-it-useful.md) — the first week is where these
either stick or get abandoned.
