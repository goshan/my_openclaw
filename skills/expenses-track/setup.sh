#!/bin/bash
# Card Tracker Setup Script
# Run this once to set up everything

set -e

echo "=== Expenses Card Setup ==="
echo ""

# 1. Create skill directory
echo "1. Installing skill..."
SKILL_DIR="$HOME/.openclaw/skills/expenses_card"
mkdir -p "$SKILL_DIR/scripts"
cp SKILL.md "$SKILL_DIR/SKILL.md"
cp scripts/init_db.sh "$SKILL_DIR/scripts/init_db.sh"
chmod +x "$SKILL_DIR/scripts/init_db.sh"
echo "   Skill installed to $SKILL_DIR"

# 2. Initialize database
echo ""
echo "2. Initializing database..."
bash "$SKILL_DIR/scripts/init_db.sh"

# 3. Set up cron jobs
echo ""
echo "3. Setting up cron jobs..."
echo "   Run these commands manually:"
echo ""
echo '   # Email check every 30 minutes'
echo '   openclaw cron add \'
echo '     --name "Check card emails" \'
echo '     --cron "*/30 * * * *" \'
echo '     --tz "Asia/Tokyo" \'
echo '     --session isolated \'
echo '     --message "Check Gmail for new credit card transaction notification emails using the card-tracker skill. Search for emails from info@tscubic.com, statement@vpass.ne.jp, and mail.paypay-card.co.jp from the last 2 days. Parse each new email to extract transaction details (amount, store, date), identify which card it belongs to, and insert into the SQLite database. Skip emails already processed (check email_id). Report what was found." \'
echo '     --announce \'
echo '     --channel slack'
echo ""
echo '   # Daily report at 9 AM JST'
echo '   openclaw cron add \'
echo '     --name "Daily Expense Report" \'
echo '     --cron "0 9 * * *" \'
echo '     --tz "Asia/Tokyo" \'
echo '     --session isolated \'
echo '     --message "Generate the daily expense report using the card-tracker skill. Query the expenses database for yesterday s transactions grouped by card. Also include the month-to-date accumulated total for each card and the grand total. Use the daily report format from the skill." \'
echo '     --announce \'
echo '     --channel slack'
echo ""
echo '   # Monthly report on 1st of every month at 9 AM JST'
echo '   openclaw cron add \'
echo '     --name "Monthly Expense Report" \'
echo '     --cron "0 9 1 * *" \'
echo '     --tz "Asia/Tokyo" \'
echo '     --session isolated \'
echo '     --message "Generate the monthly expense report using the card-tracker skill. Query the expenses database for ALL transactions from LAST month (not current month). Show totals by card, top spending categories, and top stores. Use the monthly report format from the skill." \'
echo '     --announce \'
echo '     --channel slack'
echo ""

# 4. Restart reminder
echo "4. After running the cron commands above, restart OpenClaw:"
echo "   systemctl --user restart openclaw-gateway"
echo ""
echo "5. In Slack, send 'new' to start a fresh session"
echo ""
echo "=== Setup Complete ==="
