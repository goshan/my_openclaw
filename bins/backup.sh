#!/bin/bash

echo "=== Backup ==="
echo ""

HOME_DIR=$(cd "$(dirname "$0")/.." &> /dev/null && pwd)
OPENCLAW_DIR="$HOME/.openclaw"
OPENCLAW_CRON="$OPENCLAW_DIR/cron/jobs.json"
OPENCLAW_SKILL="$OPENCLAW_DIR/workspace/skills"
BACKUP_DIR="$HOME_DIR/backup"
TIME=$(date "+%Y%m%d%H%M%S")

mkdir -p $BACKUP_DIR

skill_backup="$BACKUP_DIR/skills_$TIME.bak"
cp -r "$OPENCLAW_SKILL/" "$skill_backup"
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR/skills_*.bak" | sort -r | tail -n +4 | xargs -I {} rm -rf -- "{}"
echo "Backup skills to $skill_backup"
echo ""

crontab_backup="$BACKUP_DIR/crontab_$TIME.bak"
crontab -l > $crontab_backup
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR/crontab_*.bak" | sort -r | tail -n +4 | xargs -I {} rm -- "{}"
echo "Backup crontab to $crontab_backup"
echo ""

openclaw_cron_backup="$BACK_DIR/openclaw_jobs_$TIME.bak.json"
cp $OPENCLAW_CRON $openclaw_cron_backup
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR/openclaw_jobs_*.bak.json" | sort -r | tail -n +4 | xargs -I {} rm -- "{}"
echo "Backup openclaw cron jobs to $openclaw_cron_backup"
echo ""

db_backup="$BACKUP_DIR/data_$TIME.bak"
cp -r "$HOME_DIR/data/" "$db_backup"
# only keep the latest 3 backups
printf '%s\n' "$BACKUP_DIR/data_*.bak" | sort -r | tail -n +4 | xargs -I {} rm -rf -- "{}"
echo "Backup database to $db_backup"
echo ""

echo "Backup finished"
echo ""
