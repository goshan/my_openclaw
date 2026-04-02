# Dashboard Server Setup

This directory contains everything needed to run the visualization server — a separate VPS that downloads SQLite databases from Google Drive and serves them through Metabase.

## How It Works

```
3:00 AM  check_card_emails (OpenClaw, main server)
           → expense data written to expense.db
3:30 AM  drive_sync_dbs (cron, main server)
           → expense.db + mails_monitor.db uploaded to Google Drive
4:00 AM  db_pull (cron, this server)
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
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Install gog

```bash
# Download binary (replace amd64 with arm64 if needed)
curl -L https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_amd64.tar.gz -o gogcli.tar.gz
tar -xzf gogcli.tar.gz
sudo mv gog /usr/local/bin/gog
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
git clone <repo-url> ~/openclaw_config
cd ~/openclaw_config
```

### 5. Configure environment

```bash
cp env.example env
```

Edit `env` and set at minimum:

| Variable | Value |
|----------|-------|
| `MY_OPENCLAW_ROOT` | Absolute path to this repo, e.g. `/home/ubuntu/openclaw_config` |
| `GOG_ACCOUNT` | Your Google account email |
| `GOG_KEYRING_PASSWORD` | Keyring passphrase from step 3 |
| `DRIVE_FOLDER_ID` | Google Drive folder ID shared with the main server |

`OPENCLAW_ROOT` and `SLACK_WEBHOOK_URL` are not needed on this server.

### 6. Install db_pull

```bash
sudo cp ~/openclaw_config/dashboard/db_pull /usr/local/bin/db_pull
sudo chmod +x /usr/local/bin/db_pull
```

### 7. Do an initial pull

```bash
source ~/openclaw_config/env
mkdir -p $HOME/data
db_pull $DRIVE_FOLDER_ID $HOME/data/
```

### 8. Start Metabase

```bash
cd ~/openclaw_config/dashboard
docker compose up -d
```

Metabase will be available at `http://<server-ip>:3000`. Complete the initial setup wizard, then:

1. Go to **Settings → Admin → Databases → Add database**
2. Choose **SQLite**
3. Set file path to `/db-data/expense.db`, name it `Expenses`
4. Repeat for `/db-data/mails_monitor.db`, name it `Mail Monitor`

Metabase re-syncs hourly — new data from the nightly pull is automatically picked up.

### 9. Set up the cron job

```bash
crontab -e
```

Add the following line (runs at 4:00 AM, 30 minutes after the main server uploads):

```
0 4 * * * /bin/bash -c 'source /home/ubuntu/openclaw_config/env && db_pull $DRIVE_FOLDER_ID $HOME/data/' >> /var/log/db_pull.log 2>&1
```

Adjust the path to `openclaw_config` to match your `MY_OPENCLAW_ROOT`.

---

## Updating

When new databases are added to `drive_sync` on the main server, update the cron job on this server accordingly — `db_pull` downloads all files in the folder, so no script changes are needed.

To update Metabase to a new version:

```bash
cd ~/openclaw_config/dashboard
docker compose pull
docker compose up -d
```
