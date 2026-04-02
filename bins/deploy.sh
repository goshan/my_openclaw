#!/bin/bash

# -f, disable globbing (filename expansion)
set -ef

echo "=== Deploy ==="
echo ""

SKILL_DIR="$OPENCLAW_ROOT/workspace/skills"
CRONTAB_BAK="$MY_OPENCLAW_ROOT/tmp/crontab.bak"

CRONTAB_START="# --- OPENCLAW MANAGED START (do not edit) ---"
CRONTAB_END="# --- OPENCLAW MANAGED END ---"

# Backup
$MY_OPENCLAW_ROOT/bins/backup.sh

# env file
echo "Applying env..."
grep -v '^#' "$MY_OPENCLAW_ROOT/env" | sed 's/^export //' > "$OPENCLAW_ROOT/.env"
echo "Applied env to $OPENCLAW_ROOT/.env"
echo ""

echo "Installing tools..."
cat $MY_OPENCLAW_ROOT/deploy_config.json | jq -r '.tools[]' | while read -r tool; do
  echo "  - $tool"
  sudo cp "$MY_OPENCLAW_ROOT/tools/$tool" "/usr/local/bin/"
done
user=$(whoami)
sudo bash -c "chown $user /usr/local/bin/*"
echo "Tools installed to /usr/local/bin"
echo ""

echo "Installing skills..."
cat $MY_OPENCLAW_ROOT/deploy_config.json | jq -r '.skills[]' | while read -r skill; do
  echo "  - $skill"
  mkdir -p "$SKILL_DIR/$skill"
  cp "$MY_OPENCLAW_ROOT/skills/$skill/SKILL.md" "$SKILL_DIR/$skill/SKILL.md"
done
echo "Skills installed to $SKILL_DIR"
echo ""

echo "Installing Cron jobs..."
# --- Get current crontab, split into unmanaged + managed ---
crontab_current=$(crontab -l 2>/dev/null || echo "")
echo "$crontab_current" > "$CRONTAB_BAK"

# Extract unmanaged lines (everything outside markers)
crontab_before=$(sed -n "1,/^${CRONTAB_START}/{ /^${CRONTAB_START}/d; p; }" "$CRONTAB_BAK")
crontab_managed=""
crontab_after=$(sed -n "/^${CRONTAB_END}/,\${ /^${CRONTAB_END}/d; p; }" "$CRONTAB_BAK")

while read -r job; do
  name=$(echo $job | jq -r '.name')
  cron_type=$(echo $job | jq -r '.type')
  echo "  - $name ($cron_type)"

  schedule=$(echo $job | jq -r '.schedule')
  if [[ "$cron_type" == "openclaw" ]]; then
    message=$(echo $job | jq -r '.message')
    channel_id=$(echo $job | jq -r '.channel_id')

    if [[ -f "$MY_OPENCLAW_ROOT/tmp/cron_id_$name" ]]; then
      cron_id=$(cat "$MY_OPENCLAW_ROOT/tmp/cron_id_$name")
      openclaw cron remove $cron_id --json > /dev/null
    fi

    openclaw cron add \
      --name "$name" \
      --cron "$schedule" \
      --tz "Asia/Tokyo" \
      --session isolated \
      --message "$message" \
      --announce \
      --channel slack \
      --to "channel:$channel_id" \
      --json \
      | jq -r '.id' > "$MY_OPENCLAW_ROOT/tmp/cron_id_$name"
  elif [[ "$cron_type" == "system" ]]; then
    task=$(echo $job | jq -r '.task')
    log=$(echo $job | jq -r '.log')

    task_cmd="$task"
    if $log; then
      task_cmd+=" >> $HOME/log/${name}.log 2>&1"
    fi
    # Generate new managed block
    crontab_managed+="$schedule /bin/bash -c 'source $MY_OPENCLAW_ROOT/env && $task_cmd'\n"
  fi
done < <(cat $MY_OPENCLAW_ROOT/deploy_config.json | jq -c '.cron.jobs[]')

crontab_new="$crontab_before

$CRONTAB_START

$crontab_managed
$CRONTAB_END
$crontab_after"
printf "$crontab_new" | crontab -

echo "Cron installed"
echo ""

echo "Restart OpenClaw"
systemctl --user restart openclaw-gateway

echo "In Slack, send 'new' to start a fresh session"
echo ""
