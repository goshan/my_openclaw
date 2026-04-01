# openclaw_config

Personal automation configuration for [OpenClaw](https://openclaw.dev) — an AI-powered task runner that integrates with Slack, email, and other services.

This repo is the single source of truth for all OpenClaw skills, cron jobs, shared tools, and deployment scripts. Skills can automate anything: monitoring inboxes, tracking finances, sending reports, processing images, or interacting with external APIs — all triggered on a schedule or via Slack.

---

## Requirements

- [OpenClaw](https://openclaw.dev) installed and running
- `sqlite3`, `python3`, `jq`, `curl`, `gog`
- Any skill-specific dependencies (documented per skill)
- A configured `env` file (see below)

---

## Setup

```bash
# 1. Clone the repo
git clone <repo-url> ~/openclaw_config
cd ~/openclaw_config

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
openclaw_config/
├── deploy_config.json          # Skills list and cron job definitions
├── env                         # Environment variables (gitignored)
├── bins/
│   ├── setup.sh                # Initial setup
│   ├── deploy.sh               # Deploy skills and cron jobs to OpenClaw
│   ├── init_db.sh              # Initialize SQLite databases
│   └── backup.sh               # Backup skills, crontab, and databases
├── tools/                      # Shared utilities available to all skills
│   ├── mail/
│   │   ├── mail_fetch          # Fetch email messages (bash)
│   │   └── mail_extract        # Extract text from email JSON (python3)
│   ├── database/
│   │   └── sqlite3_exec        # Safe parameterized SQLite runner (python3)
│   └── skills/
│       └── expense-track/
│           ├── expense_add     # Insert a transaction record
│           └── report          # Generate daily/monthly expense reports
└── skills/
    ├── school-mail-monitor/
    │   └── SKILL.md
    └── expenses-track/
        └── SKILL.md
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
| `SLACK_WEBHOOK_URL` | Slack incoming webhook URL for reports |

