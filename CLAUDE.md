# CLAUDE.md

This repo is the configuration for an OpenClaw personal automation system running on a Linux server (Ubuntu). It manages two AI skills and their supporting infrastructure.

## Repository Layout

```
deploy_config.json      # Source of truth for skills and cron jobs
bins/                   # Deployment and maintenance scripts
tools/                  # Shared utilities used by skills at runtime
skills/                 # Skill definitions (SKILL.md) and scripts
data/                   # Runtime SQLite databases (gitignored)
backup/                 # Rolling backups, 3 most recent (gitignored)
env                     # Environment variables file (gitignored)
```

## Runtime Environment

- Deployed path on server: `/home/ubuntu/openclaw_config/`
- Environment loaded from: `/home/ubuntu/openclaw_config/env`
- Key env vars: `MY_OPENCLAW_ROOT`, `GOG_ACCOUNT`, `SLACK_WEBHOOK_URL`
- Skills are copied to: `$HOME/.openclaw/workspace/skills/`
- Databases live in: `/data/`

## Skills

### school-mail-monitor

**SKILL.md location**: `skills/school-mail-monitor/SKILL.md`

Fetches emails from two school senders and summarizes them in Chinese for a Slack channel.

- Senders: `m@mail1.veracross.com` (Veracross), `@issh.ac.jp` (ISSH)
- Output channel: `#mail-report` (Slack channel ID: `C0APJPJR2MN`)
- Summaries: Always in Chinese, 2–4 sentences per email
- Tool: `$MY_OPENCLAW_ROOT/tools/mail/mail_fetch`

### expenses-track

**SKILL.md location**: `skills/expenses-track/SKILL.md`

Multi-modal expense tracker. Handles email notifications, image uploads (receipts/screenshots), text input, and database queries.

**Payment method IDs** (important — used in `expense_add` script):
- `1` = Lexus VISA (email from `info@tscubic.com`)
- `2` = Amazon Mastercard (email from `statement@vpass.ne.jp`)
- `3` = PayPay (screenshot)
- `4` = Cash (receipt)

**Key scripts**:
- `skills/expenses-track/scripts/expense_add <payment_method_id> <date> <store> <amount> <category> <note>`
- `skills/expenses-track/scripts/report daily|monthly`

**Categories**: Food, Groceries, Shopping, Transport, Dining, Gas/Fuel, Health, Subscription, Utilities, Other

## Tools

### tools/mail/mail_fetch

Bash script. Fetches new Gmail messages from specified senders.

```bash
mail_fetch <sender1> [sender2 ...]
```

- Uses `gog` CLI for Gmail API access
- Tracks processed message IDs in `data/mails_monitor.db` to avoid duplicates
- Defaults to fetching emails from last 5 days on first run
- Outputs path to temp file containing email text, or prints `NO_NEW_EMAILS`
- Max 20 emails per run

### tools/mail/mail_extract

Python3 script. Converts Gmail JSON response to plain text.

```bash
mail_extract <input.json> [output.txt]
```

- Handles multipart MIME, base64url decoding, HTML-to-text conversion

### tools/database/sqlite3_exec

Python3 script. Runs parameterized SQLite queries safely.

```bash
sqlite3_exec <db_file> <query> [arg1 arg2 ...]
```

- Uses `?` placeholders — never concatenate user values directly into queries
- Required for any SQLite operation in skill scripts to prevent injection

## Databases

### data/mails_monitor.db

```sql
processed_emails (message_id TEXT PRIMARY KEY, subject, sender, received_at)
scan_state (sender TEXT PRIMARY KEY, last_scan_at TEXT)
```

### data/expense.db

```sql
payment_methods (id INTEGER PRIMARY KEY, name TEXT, notification_sender TEXT)
transactions (id, payment_method_id, date TEXT, store TEXT, amount REAL, category TEXT, note TEXT, created_at TEXT)
```

Date format: `YYYY-MM-DD`. Amount in JPY.

## Deployment

```bash
bash bins/setup.sh      # First-time setup
bash bins/deploy.sh     # Re-deploy after changes
bash bins/backup.sh     # Manual backup
```

`deploy.sh` reads `deploy_config.json` for:
- Which skill directories to copy
- Cron jobs to register (OpenClaw-type via `openclaw cron add`, system-type via crontab)

Cron job timezone: `Asia/Tokyo`.

## Conventions

- All scripts use `MY_OPENCLAW_ROOT` to build absolute paths of this repo — never hardcode `/home/ubuntu/openclaw_config/`
- The `env` file is sourced at the start of each cron job; ensure new env vars are added there
- When adding a new skill: add the directory under `skills/`, add the name to `deploy_config.json`, run `deploy.sh`
- When modifying a cron schedule: edit `deploy_config.json`, then run `deploy.sh` (it removes old jobs and re-adds)
- Backups keep only the last 3 — don't rely on backup/ for long-term history; use git
