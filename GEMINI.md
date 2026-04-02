# My OpenClaw: Personal Automation System

This repository contains the source of truth for a personal automation and monitoring system built on **OpenClaw**. It orchestrates AI-driven "skills" to automate expense tracking and school communication monitoring.

## System Overview

OpenClaw acts as the execution engine, while this repository defines:
- **Skills**: AI workflows (in `skills/`) that process unstructured data (emails, images, text).
- **Tools**: Shared CLI utilities (in `tools/`) for data fetching, extraction, and database interaction.
- **Infrastructure**: Deployment, backup, and database initialization scripts (in `bins/`).

## Tech Stack

- **Platform**: [OpenClaw](https://openclaw.dev) (AI-powered task runner)
- **Database**: SQLite3
- **Email**: Gmail (via `gog` CLI)
- **Messaging**: Slack (Incoming Webhooks)
- **Languages**: Bash, Python3, SQL
- **Environment**: Linux (Ubuntu) on server

## Runtime Environment & Paths

- **System Root**: `/home/ubuntu/my_openclaw/` (stored in `$MY_OPENCLAW_ROOT`)
- **OpenClaw Home**: `$HOME/.openclaw/workspace/` (stored in `$OPENCLAW_ROOT`)
- **Persistent Data**: `$HOME/data/` (SQLite databases)
- **Tool Path**: `/usr/local/bin/` (all tools in `tools/` are symlinked/copied here)
- **Backups**: `/home/ubuntu/my_openclaw/backup/` (Rolling 3 most recent backups)

## Repository Structure

```bash
├── deploy_config.json      # Master configuration for enabled skills, tools, and cron jobs
├── bins/                   # Management and deployment scripts
│   ├── setup.sh            # Initial system setup and environment configuration
│   ├── deploy.sh           # Deploy tools, skills, and update crontab/openclaw-cron
│   ├── init_db.sh          # Create SQLite databases and master tables
│   └── backup.sh           # Snapshot databases, skills, and crontab
├── tools/                  # Reusable CLI utilities (deployed to /usr/local/bin/)
│   ├── mail/               # Gmail fetching and parsing
│   ├── database/           # Parameterized SQL execution
│   ├── drive/              # Google Drive sync (drive_sync: upload DBs)
│   └── skills/             # Skill-specific command-line helpers
├── skills/                 # AI Skill definitions
│   ├── expenses-track/     # Multi-modal expense tracking logic
│   └── school-mail-monitor/# School inbox summarization logic
└── dashboard/              # Dashboard VPS setup (db_pull, Metabase Docker, README)
```

## Database Schemas

### `$HOME/data/mails_monitor.db` (Email Deduplication)
- **`processed_emails`**: Tracks message IDs to prevent double-processing.
  - Columns: `id, message_id, subject, sender, received_at, processed_at`
- **`scan_state`**: Stores the timestamp of the last successful scan per sender.
  - Columns: `sender (PK), last_scan_time`

### `$HOME/data/expense.db` (Finances)
- **`payment_methods`**: Master table for tracking payment types.
  - `1`: Lexus (VISA), `2`: Amazon (Mastercard), `3`: PayPay (QR), `4`: Cash
- **`transactions`**: The ledger for all expenses.
  - Columns: `id, payment_method_id, date (YYYY-MM-DD), store, amount (JPY), category, note, created_at`

## Core Skills

### 1. Expense Tracking (`expenses-track`)
- **Automation**: Fetches notification emails from `info@tscubic.com` and `statement@vpass.ne.jp` daily.
- **Multi-modal**: Processes receipt photos (Cash) and PayPay screenshots via AI image analysis.
- **Categorization**: Auto-assigns categories (Food, Groceries, Shopping, Transport, Dining, etc.) based on store name keywords.
- **Reporting**: Daily summaries at 8 AM; Monthly deep-dives on the 1st of each month.

### 2. School Mail Monitoring (`school-mail-monitor`)
- **Target Senders**: Veracross (`m@mail1.veracross.com`) and ISSH (`@issh.ac.jp`).
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
- `$GOG_KEYRING_PASSWORD`: gog script env for auth.
- `$GOG_DRIVE_FOLDER_ID`: Google Drive folder ID for DB file sync.
- `$SLACK_WEBHOOK_URL`: Webhook for automated reports.

### 2. SQL Best Practices
- **NEVER** use direct `sqlite3` calls with string concatenation in scripts.
- **ALWAYS** use `sqlite3_exec` for parameterized queries to prevent injection.
  - Example: `sqlite3_exec "$DB" "SELECT * FROM t WHERE id = ?" "$id"`

### 3. Adding New Skills
1. Create `skills/<new-skill>/SKILL.md`.
2. (Optional) Add supporting scripts to `tools/skills/<new-skill>/`.
3. Add the skill and its tools to `deploy_config.json`.
4. Run `bash bins/deploy.sh`.

### 4. Git Hygiene
- **Gitignore**: Temporary files in `/tmp/`, and the `env` file must never be committed.
- **Permissions**: All scripts in `bins/` and `tools/` must have `+x` permissions.
