# My OpenClaw: Personal Automation System

This repository contains the source of truth for a personal automation and monitoring system built on **OpenClaw**. It orchestrates AI-driven "skills" to automate expense tracking and school communication monitoring.

## System Overview

OpenClaw acts as the execution engine, while this repository defines:
- **Skills**: AI workflows (in `skills/`) that process unstructured data (emails, images, text).
- **Tools**: Shared CLI utilities (in `tools/`) for data fetching, extraction, and database interaction.
- **Infrastructure**: Deployment, backup, and database initialization scripts (in `bins/`).

## Tech Stack

- **Platform**: [OpenClaw](https://openclaw.dev) (AI-powered task runner)
- **Database**: MySQL (accessed remotely via `$MYSQL_HOST`; currently co-hosted on the dashboard server)
- **Email**: Gmail (via `gog` CLI)
- **Messaging**: Slack (Incoming Webhooks)
- **Languages**: Bash, Python3, SQL
- **Environment**: Linux (Ubuntu) on server

## Runtime Environment & Paths

- **System Root**: `/home/ubuntu/my_openclaw/` (stored in `$MY_OPENCLAW_ROOT`)
- **OpenClaw Home**: `$HOME/.openclaw/workspace/` (stored in `$OPENCLAW_ROOT`)
- **MySQL**: Remote server at `$MYSQL_HOST`. Databases: `mails_monitor`, `expense`
- **Tool Path**: `/usr/local/bin/` (all tools in `tools/` are copied here by `deploy.sh`)
- **Backups**: `/home/ubuntu/my_openclaw/backup/` (rolling 3 most recent backups)

## Repository Structure

```
├── deploy_config.json      # Master configuration for enabled skills, tools, and cron jobs
├── bins/                   # Management and deployment scripts
│   ├── setup.sh            # Initial system setup and environment configuration
│   ├── deploy.sh           # Deploy tools, skills, and update crontab/openclaw-cron
│   ├── init_db.sh          # Create MySQL databases and tables
│   └── backup.sh           # Snapshot databases (mysqldump), skills, and crontab
├── tools/                  # Reusable CLI utilities (deployed to /usr/local/bin/)
│   ├── mail/               # Gmail fetching and parsing
│   ├── database/           # Parameterized MySQL execution (mysql_exec)
│   └── skills/             # Skill-specific command-line helpers
├── skills/                 # AI skill definitions
│   ├── expenses-track/     # Multi-modal expense tracking logic
│   └── school-mail-monitor/# School inbox summarization logic
└── dashboard/              # Dashboard server setup (MySQL + Metabase Docker)
```

## Database Schemas

### `mails_monitor` (Email Deduplication)
- **`processed_emails`**: Tracks message IDs to prevent double-processing.
  - Columns: `id, message_id VARCHAR(255) UNIQUE, subject, sender, received_at DATETIME, processed_at DATETIME`
- **`scan_state`**: Stores the timestamp of the last successful scan per sender.
  - Columns: `sender VARCHAR(255) PK, last_scan_time DATETIME`

### `expense` (Finances)
- **`payment_methods`**: Master table for tracking payment types.
  - `1`: Lexus (VISA), `2`: Amazon (Mastercard), `3`: PayPay (QR), `4`: Cash
- **`transactions`**: The ledger for all expenses.
  - Columns: `id, payment_method_id, date DATE, store, amount DECIMAL(12,2) (JPY), category, note, created_at DATETIME`

## Core Skills

### 1. Expense Tracking (`expenses-track`)
- **Automation**: Fetches notification emails from `info@tscubic.com` and `statement@vpass.ne.jp` daily.
- **Multi-modal**: Processes receipt photos (Cash) and PayPay screenshots via AI image analysis.
- **Categorization**: Auto-assigns categories (Food, Groceries, Shopping, Transport, Dining, etc.) based on store name keywords.
- **Reporting**: Daily summaries at 8 AM; monthly deep-dives on the 1st of each month.

### 2. School Mail Monitoring (`school-mail-monitor`)
- **Target Senders**: Veracross (`veracross.com`) and ISSH (`@issh.ac.jp`).
- **Workflow**: Fetches emails, generates 2-4 sentence summaries in **Chinese**, extracts action items/deadlines, and posts to Slack channel `#mail-report`.
- **Schedule**: 8 AM, 12 PM, 6 PM, 10 PM daily.

## Deployment & Maintenance

| Command | Description |
|---------|-------------|
| `bash bins/setup.sh` | Full initial setup (folders, DBs, environment) |
| `bash bins/deploy.sh` | Applies changes to `deploy_config.json`, redeploys tools/skills, and refreshes cron |
| `bash bins/backup.sh` | Manual snapshot of all system state (runs automatically during deploy) |

## Developer & AI Guidelines

### 1. Environment Variables
Mandatory in `env` file:
- `$MY_OPENCLAW_ROOT`: This repo root.
- `$OPENCLAW_ROOT`: OpenClaw installation root.
- `$GOG_ACCOUNT`: Gmail account for `gog`.
- `$GOG_KEYRING_PASSWORD`: gog keyring passphrase.
- `$SLACK_WEBHOOK_URL`: Webhook for automated reports.
- `$MYSQL_HOST`: Dashboard server IP (MySQL runs there).
- `$MYSQL_PORT`: MySQL port (default `3306`).
- `$MYSQL_USER`: MySQL user.
- `$MYSQL_PASSWORD`: MySQL password.

### 2. SQL Best Practices
- **NEVER** use direct `mysql` CLI calls with string interpolation in scripts.
- **ALWAYS** use `mysql_exec` for parameterized queries to prevent injection.
  - Usage: `mysql_exec <database_name> <query> [arg1 arg2 ...]`
  - Uses `%s` placeholders: `mysql_exec expense "SELECT * FROM transactions WHERE id = %s" "$id"`
- Database names (`mails_monitor`, `expense`) are hardcoded in scripts — do not use env vars for them.

### 3. Adding New Skills
1. Create `skills/<new-skill>/SKILL.md`.
2. (Optional) Add supporting scripts to `tools/skills/<new-skill>/`.
3. Add the skill and its tools to `deploy_config.json`.
4. Run `bash bins/deploy.sh`.

### 4. Git Hygiene
- **Gitignore**: The `env` file and `backup/` must never be committed.
- **Permissions**: All scripts in `bins/` and `tools/` must have `+x` permissions.
