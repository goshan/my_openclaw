# Dashboard Server Setup

This directory contains everything needed to run the visualization server — a separate VPS that connect to MySQL remotely, and serves them through Metabase.

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Runs Metabase on port 4000, connecting to local MySQL |

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

Verify:

```bash
docker -v
```

### 2. Install MySQL

```bash
sudo apt update
sudo apt install -y mysql-server mysql-client
sudo systemctl enable mysql
sudo systemctl start mysql
```

Create the databases and user:

Only do this if the Mysql DB is in this server

```bash
sudo mysql
```

```sql
CREATE DATABASE mails_monitor CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE expense CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER '<user>'@'localhost' IDENTIFIED BY '<password>';
GRANT ALL PRIVILEGES ON mails_monitor.* TO 'openclaw'@'localhost';
GRANT ALL PRIVILEGES ON expense.* TO 'openclaw'@'localhost';
FLUSH PRIVILEGES;
```

### 3. Install gog

```bash
# Download binary (replace amd64 with arm64 if needed)
curl -L https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_amd64.tar.gz -o gogcli.tar.gz
tar -xzf gogcli.tar.gz
mv gog /usr/local/bin/gog
chmod +x /usr/local/bin/gog
```

### 4. Authenticate gog

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

### 5. Clone the repo

```bash
git clone <repo-url> <my_openclaw_path>
cd <my_openclaw_path>
```

### 6. Configure environment

```bash
cp env.example env
```

Edit `env` and set at minimum:

| Variable | Value |
|----------|-------|
| `MY_OPENCLAW_ROOT` | Absolute path to this repo |
| `GOG_ACCOUNT` | Your Google account email |
| `GOG_KEYRING_PASSWORD` | Keyring passphrase from step 4 |
| `MYSQL_HOST` | `127.0.0.1` |
| `MYSQL_PORT` | `3306` |
| `MYSQL_USER` | User set in step 2 |
| `MYSQL_PASSWORD` | Password set in step 2 |

`OPENCLAW_ROOT` and `SLACK_WEBHOOK_URL` are not needed on this server.

### 7. Start Metabase

```bash
cd <my_openclaw_path>/dashboard
docker compose up -d
```

Metabase will be available at `http://<server-ip>:4000`. Complete the initial setup wizard, then:

1. Go to **Settings → Admin → Databases → Add database**
2. Choose **MySQL**
3. Set host to `host.docker.internal`, port `3306`, user/password from step 2
4. Add `expense` as one database, repeat for `mails_monitor`

Metabase re-syncs hourly — new data from the nightly pull is automatically picked up.

To stop:

```bash
docker compose stop
```

---

## Updating

To update Metabase to a new version:

```bash
cd <my_openclaw_path>/dashboard
docker compose stop
docker compose pull
docker compose up -d
```
