#!/bin/bash

echo "Backup..."

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env"

OPENCLAW_CRON="$OPENCLAW_ROOT/cron/jobs.json"
OPENCLAW_SKILL="$OPENCLAW_ROOT/workspace/skills"
BACKUP_DIR="$MY_OPENCLAW_ROOT/backup"
TIME=$(date "+%Y%m%d%H%M%S")

mkdir -p $BACKUP_DIR

env_backup="$BACKUP_DIR/env_$TIME.bak"
cp "$OPENCLAW_ROOT/.env" $env_backup
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR"/env_*.bak | sort -r | tail -n +4 | xargs -I {} rm -- "{}"
echo "  - .env -> $env_backup"

skill_backup="$BACKUP_DIR/skills_$TIME.bak"
cp -r "$OPENCLAW_SKILL/" "$skill_backup"
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR"/skills_*.bak | sort -r | tail -n +4 | xargs -I {} rm -rf -- "{}"
echo "  - skills -> $skill_backup"

crontab_backup="$BACKUP_DIR/crontab_$TIME.bak"
crontab -l > $crontab_backup
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR"/crontab_*.bak | sort -r | tail -n +4 | xargs -I {} rm -- "{}"
echo "  - crontab -> $crontab_backup"

openclaw_cron_backup="$BACKUP_DIR/openclaw_jobs_$TIME.bak.json"
cp $OPENCLAW_CRON $openclaw_cron_backup
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR"/openclaw_jobs_*.bak.json | sort -r | tail -n +4 | xargs -I {} rm -- "{}"
echo "  - openclaw jobs -> $openclaw_cron_backup"

db_backup="$BACKUP_DIR/data_$TIME.sql"
mysqldump -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
  --databases mails_monitor expense \
  --single-transaction \
  > "$db_backup"
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR"/data_*.sql | sort -r | tail -n +4 | xargs -I {} rm -- "{}"
echo "  - database -> $db_backup"

echo "Backup finished"
echo ""
