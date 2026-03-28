#!/bin/bash

# -f, disable globbing (filename expansion)
set -ef

echo "=== Deploy ==="
echo ""

HOME_DIR=$(cd "$(dirname "$0")/.." &> /dev/null && pwd)
SKILL_DIR="$HOME/.openclaw/workspace/skills"

echo "Installing skills..."
cat $HOME_DIR/config.json | jq -r '.skills[]' | while read -r skill; do
  echo "  - $skill"
  mkdir -p "$SKILL_DIR/$skill"
  cp "$HOME_DIR/skills/$skill/SKILL.md" "$SKILL_DIR/$skill/SKILL.md"
done
echo "Skills installed to $SKILL_DIR"
echo ""

echo "Installing Cron jobs..."
channel_id=$(cat $HOME_DIR/config.json | jq -r '.cron.slack_channel_id')
cat $HOME_DIR/config.json | jq -c '.cron.jobs[]' | while read -r job; do
  name=$(echo $job | jq -r '.name')
  schedule=$(echo $job | jq -r '.schedule')
  message=$(echo $job | jq -r '.message')

  echo "  - $name"
  if [[ -f "$HOME_DIR/tmp/cron_id_$name" ]]; then
    cron_id=$(cat "$HOME_DIR/tmp/cron_id_$name")
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
    | jq -r '.id' > "$HOME_DIR/tmp/cron_id_$name"
done
echo "Cron installed"
echo ""

echo "Restart OpenClaw"
systemctl --user restart openclaw-gateway

echo "In Slack, send 'new' to start a fresh session"
echo ""
