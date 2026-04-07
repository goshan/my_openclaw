# my_openclaw

Personal automation configuration for [OpenClaw](https://openclaw.dev) — an AI-powered task runner that integrates with Slack, email, and other services.

This repo is the single source of truth for all OpenClaw skills, cron jobs, shared tools, and deployment scripts. Skills can automate anything: monitoring inboxes, tracking finances, sending reports, processing images, or interacting with external APIs — all triggered on a schedule or via Slack.

---

## Requirements

- [OpenClaw](https://openclaw.dev) installed and running
- `mysql-client`, `python3`, `python3-pip`, `jq`, `curl`, `gog`
- Python: `mysql-connector-python` (installed by `setup.sh` via pip)
- Any skill-specific dependencies (documented per skill)
- A configured `env` file (see below)

---

## gog Setup

`gog` is a CLI tool for Gmail API access, used by `mail_fetch`. Install and authenticate it before running setup.

### Installation

**Homebrew** (macOS):
```bash
brew install gogcli
```

**Download bin file** (Linux server, arm64 or amd64 version)
```bash
curl -L https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_amd64.tar.gz -o gogcli.tar.gz
tar -xzf gogcli.tar.gz
mv gog /usr/local/bin/gog
chmod +x /usr/local/bin/gog
```


**Build from Source** (Linux server):
```bash
git clone https://github.com/steipete/gogcli.git
cd gogcli
make
# Move binary to PATH, e.g.:
sudo mv bin/gog /usr/local/bin/gog
```

**Verify**
```bash
gog --version
v0.12.0 (c18c58c 2026-03-09T05:53:14Z)
```

### Google Cloud OAuth Credentials

1. Create a project at https://console.cloud.google.com/projectcreate
2. Enable the required APIs:
   - Gmail API: https://console.cloud.google.com/apis/api/gmail.googleapis.com
   - Google Drive API: https://console.cloud.google.com/apis/api/drive.googleapis.com
3. Configure OAuth consent screen: https://console.cloud.google.com/auth/branding
4. Publish the app to production: https://console.cloud.google.com/auth/audience
4. Create an OAuth client at https://console.cloud.google.com/auth/clients (type: **Desktop app**) and download the JSON file

### Store and Authorize

```bash
gog auth credentials ~/Downloads/client_secret_....json
```

For headless/remote server (no browser on server), use the manual flow:

```bash
gog auth add <you>@gmail.com --services user --manual
```

- The CLI prints an auth URL — open it in a local browser
- After approval, copy the full redirect URL from the browser address bar
- Paste it back into the terminal when prompted

Here a password might be reuqired as the following, This is used for the refresh token that is stored securely in your system keychain.
```bash
Enter passphrase to unlock "/root/.config/gogcli/keyring":
```
Also set the password you typed to `GOG_KEYRING_PASSWORD` in the `env` file.

### Test

```bash
export GOG_ACCOUNT=you@gmail.com
gog gmail labels list
```

---

## MySQL Setup

MySQL runs on a separate server. This server only needs the client tools to connect to it remotely.

### Install mysql-client and pip3

```bash
sudo apt update
sudo apt install -y mysql-client python3-pip
```

Set `MYSQL_HOST` in your `env` file to the MySQL server's IP address.
And also the other mysql related variables like `MYSQL_PORT`, `MYSQL_USER`, and `MYSQL_PASSWORD`

---

## Setup

```bash
# 1. Clone the repo
git clone <repo-url> ~/my_openclaw
cd ~/my_openclaw

# 2. Create the env file
cp env.example env
# Edit env with your values

# 3. Run setup (creates dirs, initializes DBs, deploys skills + cron jobs)
bash bins/setup.sh
```

---

## Skills

Skills are self-contained AI workflows defined by a `SKILL.md` file and optional supporting scripts. Each skill is registered in `deploy_config.json` and deployed to the OpenClaw workspace.

### school-mail-monitor

Monitors school-related inboxes, summarizes new emails in Chinese, and posts to Slack.

**Cron schedule**: 8am, 12pm, 6pm, 10pm (Asia/Tokyo)

### expenses-track

Tracks spending across credit cards, QR payments, and cash. Supports automated email parsing, receipt/screenshot scanning, manual text entry, and on-demand queries.

---

## Project Structure

```
my_openclaw/
├── deploy_config.json          # Skills list, tools, and cron job definitions
├── env                         # Environment variables (gitignored)
├── bins/
│   ├── setup.sh                # Initial setup
│   ├── deploy.sh               # Deploy skills and cron jobs to OpenClaw
│   ├── init_db.sh              # Initialize MySQL databases
│   └── backup.sh               # Backup skills, crontab, and databases
├── tools/                      # Shared utilities deployed to /usr/local/bin/, available to all skills
│   ├── mail/
│   │   ├── mail_fetch          # Fetch email messages (bash)
│   │   └── mail_extract        # Extract text from email JSON (python3)
│   ├── database/
│   │   └── mysql_exec          # Safe parameterized MySQL runner (python3)
│   └── skills/
│       └── expense-track/
│           ├── expense_add     # Insert a transaction record
│           └── expense_report  # Generate daily/monthly expense reports (auto-detected)
├── skills/
│   ├── school-mail-monitor/
│   │   └── SKILL.md
│   └── expenses-track/
│       └── SKILL.md
└── dashboard/                  # Dashboard VPS setup (see dashboard/README.md)
    ├── docker-compose.yml      # Metabase Docker setup
    └── README.md               # Dashboard server setup instructions
```

New skills go in `skills/<skill-name>/` with a `SKILL.md` and any supporting scripts. Register the skill name in `deploy_config.json`, then run `deploy.sh`.

---

## Shared Tools

Tools under `tools/` are deployed to `/usr/local/bin/` and available to all skills at runtime.

| Tool | Description |
|------|-------------|
| `tools/mail/mail_fetch` | Fetch new messages from an inbox, with deduplication |
| `tools/mail/mail_extract` | Convert raw email JSON to plain text |
| `tools/database/mysql_exec` | Run parameterized MySQL queries safely |

---

## Data & Databases

Databases run on MySQL. Each skill that needs persistence manages its own database. Current databases:

- `mails_monitor` — Email deduplication (processed IDs, last scan time)
- `expense` — Expense transactions and payment methods

---

## Deployment

```bash
bash bins/deploy.sh     # Deploy skills and cron jobs (auto-backs up first)
bash bins/backup.sh     # Manual backup (keeps last 3)
```

`deploy_config.json` is the source of truth — edit it to add/remove skills or reschedule jobs, then redeploy.

---

## Environment Variables

Stored in `env` file

| Variable | Description |
|----------|-------------|
| `MY_OPENCLAW_ROOT` | Absolute path to this repo root |
| `OPENCLAW_ROOT` | Absolute path to the root of OpenClaw in server |
| `GOG_KEYRING_PASSWORD` | gog script env for auth |
| `GOG_ACCOUNT` | gog use this as google account |
| `MYSQL_HOST` | MySQL server IP |
| `MYSQL_PORT` | MySQL server port (usually `3306`) |
| `MYSQL_USER` | MySQL user |
| `MYSQL_PASSWORD` | MySQL password |

---

## Dashboard

The `dashboard/` directory contains everything needed to run the Metabase visualization server. 
Currently the MySQL server is also running on this machine.

See **[dashboard/README.md](dashboard/README.md)** for the complete setup guide.

