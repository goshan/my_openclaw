#!/bin/bash
set -e

echo "=== School Mail Monitor Deploy ==="
echo ""

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" &> /dev/null && pwd)
SKILL_DIR="$HOME/.openclaw/workspace/skills/school-mail-monitor"

echo "Installing skill..."
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/../SKILL.md" "$SKILL_DIR/SKILL.md"
mkdir -p "$SKILL_DIR/bins"
cp "$SCRIPT_DIR/../bins/mail_fetch" "$SKILL_DIR/bins/mail_fetch"
chmod +x "$SKILL_DIR/bins/mail_fetch"
cp "$SCRIPT_DIR/../bins/mail_extract" "$SKILL_DIR/bins/mail_extract"
chmod +x "$SKILL_DIR/bins/mail_extract"
echo "   Skill installed to $SKILL_DIR"

echo "Reinstall Cron"
openclaw cron remove $(cat "$SCRIPT_DIR/../tmp/cron_id") --json > /dev/null
openclaw cron add \
  --name "Check school emails" \
  --cron "0 8,12,18,22 * * *" \
  --tz "Asia/Tokyo" \
  --session isolated \
  --message "Check for new school emails using the school-mail-monitor skill. Search Gmail for emails from m@mail1.veracross.com and @issh.ac.jp since the last scan time stored in the database. For each new email: summarize it, extract action items, and format per the skill instructions. Send the formatted report to Slack #mail-report channel ($channel_id). Update the scan state after processing." \
  --announce \
  --channel slack \
  --to "channel:$(cat "$SCRIPT_DIR/../env/channel_id")" \
  --json \
  | jq -r '.id' > "$SCRIPT_DIR/../tmp/cron_id"

echo "Restart OpenClaw"
systemctl --user restart openclaw-gateway

echo "In Slack, send 'new' to start a fresh session"
echo "   Then test with: 'Check school emails'"
echo ""
echo "=== Deploy Complete ==="
