#!/bin/bash
set -e

echo "=== School Mail Monitor Setup ==="
echo ""

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" &> /dev/null && pwd)
SKILL_DIR="$HOME/.openclaw/workspace/skills/school-mail-monitor"

# 1. Install skill
echo "1. Installing skill..."
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/../SKILL.md" "$SKILL_DIR/SKILL.md"
echo "   Skill installed to $SKILL_DIR"

# 2. Initialize database
echo ""
echo "2. Initializing database..."
bash "$SCRIPT_DIR/init_db.sh"

# 3. Remind about Slack channel ID
echo ""
echo "3. IMPORTANT: You need your Slack #mail-report channel ID."
echo "   In Slack: right-click #mail-report → 'View channel details' → scroll to bottom → copy Channel ID (starts with C)"
echo "   Then update the cron job below with the actual channel ID."
echo ""

# 4. Cron job
echo "4. Set up cron job (slack CHANNEL_ID is required in this step)"
printf "slack CHANNEL_ID: "
read -r channel_id

openclaw cron add \
  --name "Check school emails" \
  --cron "0 8,12,18,22 * * *" \
  --tz "Asia/Tokyo" \
  --session isolated \
  --model "openrouter/google/gemini-2.5-flash-lite" \
  --message "Check for new school emails using the school-mail-monitor skill. Search Gmail for emails from m@mail1.veracross.com and @issh.ac.jp since the last scan time stored in the database. For each new email: summarize it, extract action items, and format per the skill instructions. Send the formatted report to Slack #mail-report channel ($channel_id). Update the scan state after processing." \
  --announce \
  --channel slack \
  --to "channel:$channel_id"

# 5. Restart
echo "5. Restart OpenClaw:"
systemctl --user restart openclaw-gateway

echo "6. In Slack, send 'new' to start a fresh session"
echo "   Then test with: 'Check school emails'"
echo ""
echo "=== Setup Complete ==="
