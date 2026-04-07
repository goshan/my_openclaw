# CLAUDE.md

This repo is the configuration for an OpenClaw personal automation system running on a Linux server (Ubuntu). It manages two AI skills, a system-level morning briefing script, and their supporting infrastructure.

## Repository Layout

```
deploy_config.json      # Source of truth for skills and cron jobs
bins/                   # Deployment and maintenance scripts
tools/                  # Shared utilities used by skills at runtime
skills/                 # Skill definitions (SKILL.md) and scripts
backup/                 # Rolling backups, 3 most recent (gitignored)
env                     # Environment variables file (gitignored)
dashboard/              # MySQL DB visualization running in another server
```

## Runtime Environment

- Deployed path on server: `/home/ubuntu/my_openclaw/`
- Environment loaded from: `/home/ubuntu/my_openclaw/env`
- Key env vars: `MY_OPENCLAW_ROOT`, `GOG_ACCOUNT`, `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `SLACK_WEBHOOK_URL`
- Skills are copied to: `$HOME/.openclaw/workspace/skills/`
- Databases: MySQL (remote server on `$MYSQL_HOST`). Databases: `mails_monitor`, `expense`, and `real_state`. Currently co-hosted on the dashboard server.

## Skills

### school-mail-monitor

**SKILL.md location**: `skills/school-mail-monitor/SKILL.md`

Fetches emails from two school senders and summarizes them in Chinese for a Slack channel.

- Senders: `veracross.com` (Veracross), `@issh.ac.jp` (ISSH)
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
- `expense_add <payment_method_id> <date> <store> <amount> <category> <note> [--currency CODE]`
- `expense_report` (auto-detects daily or monthly based on current date)

**Categories**: Food, Groceries, Shopping, Transport, Dining, Gas/Fuel, Health, Subscription, Utilities, Kids/Education, Other

## Tools

### tools/mail/mail_fetch

Bash script. Fetches new Gmail messages from specified senders.

```bash
mail_fetch <sender1> [sender2 ...]
```

- Uses `gog` CLI for Gmail API access
- Tracks processed message IDs in MySQL `mails_monitor` database to avoid duplicates
- Defaults to fetching emails from last 5 days on first run
- Outputs path to temp file containing email text, or prints `NO_NEW_EMAILS`
- Max 20 emails per run

### tools/mail/mail_extract

Python3 script. Converts Gmail JSON response to plain text.

```bash
mail_extract <input.json> [output.txt]
```

- Handles multipart MIME, base64url decoding, HTML-to-text conversion

### tools/database/mysql_exec

Python3 script. Runs parameterized MySQL queries safely.

```bash
mysql_exec <database_name> <query> [arg1 arg2 ...]
```

- First argument is the database name (e.g. `mails_monitor`, `expense`)
- Uses `%s` placeholders — never concatenate user values directly into queries
- Reads connection from env vars: `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`
- Required for any MySQL operation in skill scripts to prevent injection

### tools/skills/expense-track/expense_add

Bash script. Inserts a transaction record into the `expense` database.

```bash
expense_add <payment_method_id> <date> <store> <amount> <category> <note> [--currency CODE]
```

- `date`: `YYYY/MM/DD` or `YYYY-MM-DD` (with optional ` HH:mm`) — stored as `YYYY-MM-DD`
- `--currency`: ISO 4217 code (default: JPY). If non-JPY, fetches live rate and converts to JPY automatically; appends original amount to note
- If rate fetch fails, stores raw amount and marks note with "currency conversion failed"

### tools/skills/expense-track/expense_report

Python3 script. Generates an expense summary and prints JSON to stdout.

```bash
expense_report
```

- Auto-detects mode: **daily** on days 2–31 (reports yesterday), **monthly** on the 1st (reports last month)
- Daily output includes per-card transactions, subtotals, grand total, and month-to-date accumulated total with dashboard URL
- Monthly output includes per-card totals and grand total with dashboard URL

### tools/real_state/daily_real_state

Python3 script. Fetches today's real estate metrics from the `real_state` database.

```bash
daily_real_state
```

- Queries `real_state.daily_metrics` joined with `real_state.locations`
- Outputs JSON array with label, avg price, count, and DoD/WoW/MoM/YoY change percentages
- Used by `morning_briefing` to populate the real estate section

### tools/morning-briefing/morning_briefing

Python3 script. Generates and posts the daily morning briefing. Run as a system cron job at 8am Asia/Tokyo.

```bash
morning_briefing
```

- Weather: Tokyo forecast (wttr.in API)
- Currency: CNY→JPY and USD→JPY (frankfurter.app API)
- Expense: runs `expense_report` and includes its output
- Calendar: today's events from 3 Google Calendars (personal, もも家, School) via `gog`
- Real estate: queries `real_state.daily_metrics` for today; says data not ready if empty
- If `SLACK_WEBHOOK_URL` is set, POSTs output to Slack; otherwise prints to stdout

## Databases

### mails_monitor

```sql
processed_emails (message_id VARCHAR(255) UNIQUE, subject, sender, received_at DATETIME, processed_at DATETIME)
scan_state (sender VARCHAR(255) PRIMARY KEY, last_scan_time DATETIME)
```

### expense

```sql
payment_methods (id INT PRIMARY KEY, name VARCHAR(100), notification_sender VARCHAR(255))
transactions (id, payment_method_id, date DATE, store VARCHAR(255), amount DECIMAL(12,2), category VARCHAR(100), note TEXT, created_at DATETIME)
```

Date format: `YYYY-MM-DD`. Amount in JPY.

### real_state

```sql
locations (code VARCHAR(50) PRIMARY KEY, label VARCHAR(255), layer INT)
daily_metrics (date DATE, location_code VARCHAR(50), average DECIMAL(15,2), count INT, PRIMARY KEY (date, location_code))
```

Populated externally (not written to by skills). Read by `daily_real_state` for the morning briefing.

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

## Dashboard (Data Visualization)

The dashboard server serves a dual role: it hosts MySQL (the primary database that the main server writes to remotely) and runs Metabase for visualization.

- `dashboard/docker-compose.yml` — Runs Metabase on port 4000. Metabase connects to the host MySQL via `host.docker.internal`.
- `dashboard/README.md` — Full setup guide for the dashboard server, including MySQL remote access configuration.

## Conventions

- All scripts use `MY_OPENCLAW_ROOT` to build absolute paths of this repo — never hardcode `/home/ubuntu/my_openclaw/`
- The `env` file is sourced at the start of each cron job; ensure new env vars are added there
- Database names `mails_monitor` and `expense` are hardcoded in scripts — do not use env vars for them
- When adding a new skill: add the directory under `skills/`, add the name to `deploy_config.json`, run `deploy.sh`
- When modifying a cron schedule: edit `deploy_config.json`, then run `deploy.sh` (it removes old jobs and re-adds)
- Backups keep only the last 3 — don't rely on backup/ for long-term history; use git
