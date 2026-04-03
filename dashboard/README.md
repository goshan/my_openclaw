# Dashboard Server Setup

This directory contains everything needed to run the visualization server — a separate VPS that downloads SQLite databases from Google Drive and serves them through Metabase.

## How It Works

```
3:00 AM  check_card_emails (OpenClaw, main server)
           → expense data written to expense.db
4:00 AM  drive_sync_dbs (cron, main server)
           → expense.db + mails_monitor.db uploaded to Google Drive
5:00 AM  db_pull (cron, this server)
           → databases downloaded to $HOME/data/
           → Metabase reads updated files on next hourly sync
```

## Files

| File | Description |
|------|-------------|
| `db_pull` | Downloads DB files from a Google Drive folder to a local directory |
| `docker-compose.yml` | Runs Metabase, mounting `$HOME/data/` as the DB source |

---

## Setup

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh

systemctl start docker
systemctl enable docker

# (Optional) Allow your user to run docker without 'sudo'
sudo usermod -aG docker $USER
newgrp docker
```

Vefify:

```bash
docker -v
```

### 2. Install gog

```bash
# Download binary (replace amd64 with arm64 if needed)
curl -L https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_amd64.tar.gz -o gogcli.tar.gz
tar -xzf gogcli.tar.gz
mv gog /usr/local/bin/gog
chmod +x /usr/local/bin/gog
```

### 3. Authenticate gog

The dashboard server has no browser, so use the manual flow:

```bash
# Store your OAuth credentials (downloaded from Google Cloud Console)
gog auth credentials ~/client_secret_....json

# Add your account using the manual flow
gog auth add you@gmail.com --services user --manual
```

The CLI prints an auth URL. Open it in a local browser, approve access, then copy the full redirect URL from the browser address bar and paste it back into the terminal.

You may be prompted for a keyring passphrase:
```
Enter passphrase to unlock "/root/.config/gogcli/keyring":
```
Note this password — you will need it as `GOG_KEYRING_PASSWORD`.

Verify authentication:
```bash
export GOG_ACCOUNT=you@gmail.com
gog gmail labels list
```

### 4. Clone the repo

```bash
git clone <repo-url> <my_openclaw_path>
cd <my_openclaw_path>
```

### 5. Configure environment

```bash
cp env.example env
```

Edit `env` and set at minimum:

| Variable | Value |
|----------|-------|
| `MY_OPENCLAW_ROOT` | Absolute path to this repo |
| `GOG_ACCOUNT` | Your Google account email |
| `GOG_KEYRING_PASSWORD` | Keyring passphrase from step 3 |
| `GOG_DRIVE_FOLDER_ID` | Google Drive folder ID shared with the main server |

`OPENCLAW_ROOT` and `SLACK_WEBHOOK_URL` are not needed on this server.

### 6. Do an initial pull

```bash
source <my_openclaw_path>/env
mkdir -p $HOME/data
<my_openclaw_path>/dashboard/db_pull
```

### 7. Set up the cron job

Create `log` folder

```bash
mkdir -p "$HOME/log
```

```bash
crontab -e
```

Add the following line (runs at 5:00 AM, 1 hour after the main server uploads):

```
0 5 * * * /bin/bash -c 'source <my_openclaw_path>/env && db_pull' >> $HOME/log/db_pull.log 2>&1
```

Adjust the path to `my_openclaw` to match your `MY_OPENCLAW_ROOT`, also adjust the path to correct log path.

### 8. Start Metabase

```bash
cd <my_openclaw_path>/dashboard
docker compose up -d
```

Metabase will be available at `http://<server-ip>:3000`. Complete the initial setup wizard, then:

1. Go to **Settings → Admin → Databases → Add database**
2. Choose **SQLite**
3. Set file path to `/db-data/expense.db`, name it `Expenses`

Metabase re-syncs hourly — new data from the nightly pull is automatically picked up.

this docker will be auto-restarted when system or docker server restarted, so if you want to stop

```bash
docker compose stop
```

---

## Updating

When new databases are added, `drive_sync` on the main server will automatically upload, and `db_pull` downloads all files in the folder, so no script changes are needed.

To update Metabase to a new version:

```bash
cd <my_openclaw_path>/dashboard
docker compose stop
docker compose pull
docker compose up -d
```
