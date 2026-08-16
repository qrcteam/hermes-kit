# 03 · Runbook — Windows

*This is a **delta**, not a second runbook. Work through
[`02-runbook-mac.md`](02-runbook-mac.md) and substitute the steps below where they differ.
Everything not mentioned here is identical.*

The design goal is **one promoter script, two platforms**. `promote.sh` runs unchanged inside
WSL2. Do not write a PowerShell port — you'd then have two things to keep in step, and they
would drift.

---

## The shape of it

```
Windows                          WSL2 (Ubuntu)
─────────────────────────        ─────────────────────────
Docker Desktop ──────────────────► hermes container
Obsidian ──┐                      promote.sh (same file as macOS)
           │                            │
           ▼                            ▼
   C:\Users\<USER>\Memory\<NAME>-vault
        = /mnt/c/Users/<USER>/Memory/<NAME>-vault
```

**The vault lives on the Windows filesystem**, so Obsidian opens it natively and Explorer can
see it. WSL reaches it through `/mnt/c`. That path is slower than native — irrelevant for a few
hundred markdown files, and worth it for a vault the person can actually open.

Don't let anyone talk you into moving the vault inside WSL for speed. Obsidian on Windows
handles `\\wsl$\` paths badly, and a memory they can't open is a memory they won't trust.

---

## Step 1 (replaces) · Install

Install **WSL2** first — Docker Desktop needs it:

```powershell
wsl --install -d Ubuntu
```

Reboot. Set a username and password when Ubuntu first launches.

Then install [Docker Desktop](https://docker.com/products/docker-desktop) and
[Obsidian](https://obsidian.md). In Docker Desktop:

- **Settings → General →** ✅ *Use the WSL 2 based engine*
- **Settings → Resources → WSL Integration →** ✅ enable for **Ubuntu**
- **Settings → General →** ✅ *Start Docker Desktop when you sign in*

Verify from inside WSL — this is where everything will run:

```bash
wsl
docker ps && git --version && python3 --version
```
> **You should see** an empty container table and both version numbers. If `docker` isn't
> found inside WSL, the WSL Integration toggle above isn't on.

---

## Step 3 (replaces) · Build the vault

**Where not to put it.** macOS has TCC; Windows has **OneDrive**. If `Documents` or `Desktop`
is OneDrive-backed — the default on most new machines — OneDrive will fight the promoter over
every file, produce `note-DESKTOP-ABC123.md` conflict copies, and occasionally upload the
`.git` directory into an unusable state.

`C:\Users\<USER>\Memory\` is not synced by default. Use it. **Check** by looking for a green
tick or cloud icon on the folder in Explorer — if you see one, move it.

From inside WSL:

```bash
export NAME=<NAME>
export WUSER=<Windows username>
export VAULT=/mnt/c/Users/$WUSER/Memory/$NAME-vault
mkdir -p "$VAULT"

cp -R /mnt/c/Users/$WUSER/hermes-kit/templates/vault-skeleton/. "$VAULT"/
mv "$VAULT/gitignore.template" "$VAULT/.gitignore"
chmod +x "$VAULT/scripts/pinecone-sync"

for b in projects clients learning personal; do
  mkdir -p "$VAULT/wiki/topics/$b"
  sed "s/<bucket-name>/$b/g; s/<Bucket Name>/${b}/g; s/<YYYY-MM-DD>/$(date +%F)/" \
    "$VAULT/wiki/topics/_MANUAL-TEMPLATE.md" > "$VAULT/wiki/topics/$b/_manual.md"
done
rm "$VAULT/wiki/topics/_MANUAL-TEMPLATE.md"
mkdir -p "$VAULT/wiki/people" "$VAULT/wiki/reference" "$VAULT/raw/sessions"

cd "$VAULT"
git init -q -b main

# Two Windows-specific settings that matter more than they look:
git config core.autocrlf false   # keep LF. Otherwise every file churns on every commit.
git config core.filemode false   # /mnt/c can't represent Unix permissions

git add -A && git commit -qm "vault: initial skeleton for $NAME"
```

`core.autocrlf false` is the important one. Left at Windows' default, git rewrites line endings
on checkout and every single file shows as modified forever, which buries real changes in noise.

*(The promoter tolerates CRLF notes regardless — a note hand-edited in Notepad still files
correctly. This setting is about keeping the git history readable.)*

---

## Step 6 (replaces) · Start Hermes

Run this **from PowerShell**, not WSL — Docker Desktop is a Windows service and wants Windows
paths for bind mounts:

```powershell
docker run -d --name hermes --restart unless-stopped `
  -p 127.0.0.1:8642:8642 `
  --env-file "$env:USERPROFILE\.hermes\.env" `
  -v "$env:USERPROFILE\.hermes:/opt/data" `
  -v "$env:USERPROFILE\Memory\<NAME>-vault:/vault:ro" `
  nousresearch/hermes-agent:latest
```

The `:ro` matters here exactly as much as it does on macOS.

`journal_mode: delete` matters **more** on Windows, not less. WSL2 bind mounts use 9p, which is
even less forgiving of SQLite's write-ahead log than macOS virtiofs:

```powershell
docker exec hermes hermes config set database.journal_mode delete
docker exec hermes hermes config set approvals.mode smart
docker exec hermes hermes config set approvals.cron_mode deny
docker restart hermes
```

### Pairing WhatsApp on Windows

Identical to macOS — the pairing runs inside the container, so the host OS doesn't matter:

```powershell
docker exec -it hermes hermes whatsapp
```

Two Windows-specific notes:

- **Run it from Windows Terminal, not the old `cmd.exe` console.** The QR code is drawn with
  Unicode block characters; the legacy console renders it as garbage and there is nothing to
  scan. Windows Terminal or PowerShell 7 in a window at least 60 columns wide.
- **`.env` is not enough** — same trap as everywhere else. The `platforms.whatsapp` block from
  `templates/config.yaml.template` has to be in their `config.yaml`, and on Windows make sure
  you edited the copy the *container* reads (see the two-directories section immediately
  below — this is exactly the kind of thing that gets edited in the wrong one).

```powershell
docker exec hermes hermes config get platforms.whatsapp.enabled   # want: true
```

The rest — self-chat mode, the allowlist format, the session folder being a credential — is
the same as [`02-runbook-mac.md`](02-runbook-mac.md) step 6.

### Two `~/.hermes` directories — read this twice

This is the single most confusing thing about the Windows install.

| Path | Who uses it |
|---|---|
| `C:\Users\<USER>\.hermes` | **Docker mounts this.** The container's `/opt/data` |
| `\\wsl$\Ubuntu\home\<user>\.hermes` | WSL's own home — **the promoter's default `HERMES_HOME`** |

If you copy `promote.sh` into the WSL one but the container writes its inbox to the Windows
one, the promoter will run every 15 minutes, find nothing, report success, and **not a single
note will ever be saved.** That is exactly the silent-failure mode this whole design exists to
prevent — and on Windows it's the easiest mistake to make.

**Point everything at the Windows directory.** From WSL:

```bash
export WHERMES=/mnt/c/Users/$WUSER/.hermes
mkdir -p "$WHERMES"/{inbox,scripts,secrets}

cp /mnt/c/Users/$WUSER/hermes-kit/templates/promote.sh      "$WHERMES/promote.sh"
cp /mnt/c/Users/$WUSER/hermes-kit/templates/vault-health.sh "$WHERMES/scripts/vault-health.sh"
chmod +x "$WHERMES/promote.sh" "$WHERMES/scripts/vault-health.sh"

mkdir -p "$WHERMES/skills/note-taking/vault-capture"
cp /mnt/c/Users/$WUSER/hermes-kit/templates/vault-capture-SKILL.md \
   "$WHERMES/skills/note-taking/vault-capture/SKILL.md"

printf '%s' '<pinecone key>' > "$WHERMES/secrets/pinecone.key"
chmod 600 "$WHERMES/secrets/pinecone.key"
```

> **Sanity check:** `ls /mnt/c/Users/$WUSER/.hermes/inbox` from WSL and
> `docker exec hermes ls /opt/data/inbox` must show **the same folder**. Prove it:
> ```bash
> docker exec hermes touch /opt/data/inbox/PROOF
> ls /mnt/c/Users/$WUSER/.hermes/inbox/PROOF && echo "SAME DIRECTORY — good"
> docker exec hermes rm /opt/data/inbox/PROOF
> ```
> If that file doesn't appear, stop. Nothing downstream will work.

---

## Step 8 (replaces) · Turn on the promoter

Task Scheduler instead of launchd. Edit
`templates/vault-promote-task.xml`, replacing `<USER>` and `<NAME>`, then from PowerShell:

```powershell
schtasks /Create /TN "HermesVaultPromote" /XML "C:\Users\<USER>\vault-promote-task.xml"
schtasks /Run /TN "HermesVaultPromote"
schtasks /Query /TN "HermesVaultPromote" /V /FO LIST | Select-String "Last Result"
```
> **You should see** `Last Result: 0`.

If it rejects the file with an encoding complaint, re-save as UTF-16:
```powershell
Get-Content vault-promote-task.xml | Set-Content -Encoding Unicode vault-promote-task-16.xml
```

Prove the promoter itself works before trusting the schedule — from WSL:

```bash
VAULT_ROOT=/mnt/c/Users/$WUSER/Memory/$NAME-vault \
HERMES_HOME=/mnt/c/Users/$WUSER/.hermes \
PINECONE_INDEX=$NAME-vault \
PINECONE_STATE=/mnt/c/Users/$WUSER/.hermes/pinecone-state.json \
PINECONE_KEY_FILE=/mnt/c/Users/$WUSER/.hermes/secrets/pinecone.key \
PINECONE_SYNC=/mnt/c/Users/$WUSER/Memory/$NAME-vault/scripts/pinecone-sync \
bash /mnt/c/Users/$WUSER/.hermes/promote.sh

cat /mnt/c/Users/$WUSER/.hermes/promote-state.json
```
> **You should see** `"status": "ok"`.

---

## Not needed on Windows

- **The Telegram kick watchdog.** That works around a macOS-specific cold-start wedge.
- **Anything about TCC.** Windows' equivalent trap is OneDrive — handled in step 3.

---

## Windows-only gotchas

| Symptom | Cause | Fix |
|---|---|---|
| Notes never appear; promoter says "ok" | The two-`.hermes` trap | Run the PROOF check in step 6 |
| Every file shows modified in git, forever | `core.autocrlf` at default | `git config core.autocrlf false`, then re-clone or `git add --renormalize .` |
| `note-DESKTOP-ABC123.md` copies appearing | Vault is inside OneDrive | Move it to `C:\Users\<USER>\Memory\` |
| Bot goes quiet after a reboot | Docker Desktop not set to auto-start | Settings → General → *Start when you sign in* |
| Bot goes quiet at night | Windows fast-startup / sleep | Power plan → sleep = Never, and disable fast startup |
| `database disk image is malformed` | `journal_mode` isn't `delete` | Set it, then `docker restart hermes` |
| Task shows `Last Result: 1` | A path in the XML is wrong | Read `\\wsl$\Ubuntu\home\<user>\vault-promote.log` |

---

**Back to** [`02-runbook-mac.md`](02-runbook-mac.md) for steps 2, 4, 5, 7, 9, 10 and 11 —
they're identical.
