# my_openclaw

Personal automation configuration for [OpenClaw](https://openclaw.dev) — an AI-powered task runner that integrates with Slack, email, and other services.

This repo is the single source of truth for all OpenClaw skills, cron jobs, shared tools, and deployment scripts. Skills can automate anything: monitoring inboxes, tracking finances, sending reports, processing images, or interacting with external APIs — all triggered on a schedule or via Slack.

---

## Requirements

- [OpenClaw](https://openclaw.dev) installed and running
- `sqlite3`, `python3`, `jq`, `curl`, `gog`
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

**Cron schedules**: Card scan at 3am, daily report at 8am, monthly report on the 1st

---

## Project Structure

```
my_openclaw/
├── deploy_config.json          # Skills list, tools, and cron job definitions
├── env                         # Environment variables (gitignored)
├── bins/
│   ├── setup.sh                # Initial setup
│   ├── deploy.sh               # Deploy skills and cron jobs to OpenClaw
│   ├── init_db.sh              # Initialize SQLite databases
│   └── backup.sh               # Backup skills, crontab, and databases
├── tools/                      # Shared utilities deployed to /usr/local/bin/, available to all skills
│   ├── mail/
│   │   ├── mail_fetch          # Fetch email messages (bash)
│   │   └── mail_extract        # Extract text from email JSON (python3)
│   ├── database/
│   │   └── sqlite3_exec        # Safe parameterized SQLite runner (python3)
│   ├── drive/
│   │   └── drive_sync          # Upload SQLite DBs to Google Drive (bash)
│   └── skills/
│       └── expense-track/
│           ├── expense_add     # Insert a transaction record
│           └── report          # Generate daily/monthly expense reports
├── skills/
│   ├── school-mail-monitor/
│   │   └── SKILL.md
│   └── expenses-track/
│       └── SKILL.md
└── dashboard/                  # Dashboard VPS setup (see dashboard/README.md)
    ├── db_pull                 # Download DB files from Google Drive (bash)
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
| `tools/database/sqlite3_exec` | Run parameterized SQLite queries safely |
| `tools/drive/drive_sync` | Upload SQLite DB files to Google Drive |

---

## Data & Databases

Runtime databases live in `$HOME/data/` (outside the repo). Each skill that needs persistence manages its own database. Current databases:

- `$HOME/data/mails_monitor.db` — Email deduplication (processed IDs, last scan time)
- `$HOME/data/expense.db` — Expense transactions and payment methods

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
| `GOG_DRIVE_FOLDER_ID` | Google Drive folder ID for DB file sync |
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL for reports |

---

## Dashboard

The `dashboard/` directory contains everything needed to run a separate visualization VPS: a script to pull databases from Google Drive, a Metabase Docker setup, and full setup instructions.

See **[dashboard/README.md](dashboard/README.md)** for the complete setup guide.

