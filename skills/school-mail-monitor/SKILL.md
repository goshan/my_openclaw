---
name: school-mail-monitor
description: >
  Monitor school-related emails from Veracross (m@mail1.veracross.com) and ISSH (@issh.ac.jp). 
  Use when: cron triggers "check school emails", user asks about school emails, school notices, or ISSH messages. 
  Reformats emails with title, summary, and action items, then delivers to Slack #mail-report channel.
metadata:
  openclaw:
    emoji: "🏫"
    requires:
      bins:
        - sqlite3
        - gog
---

# School Mail Monitor

Monitor and summarize emails from school-related senders, then deliver formatted reports to Slack.

## Database

Location: `~/.openclaw/workspace/school_mail_monitor.db`

### Tables

**processed_emails** — deduplication tracking
```sql
id, message_id (UNIQUE), subject, sender, received_at, processed_at
```

**scan_state** — remembers where we left off
```sql
id (always 1), last_scan_time
```

---

## WORKFLOW

### Step 1: Get the last scan time

```bash
sqlite3 ~/.openclaw/workspace/school_mail_monitor.db "SELECT last_scan_time FROM scan_state WHERE id = 1;"
```

This returns a datetime like `2026-03-25 09:00:00`. Convert it to a Gmail search-compatible format.

### Step 2: Search Gmail for new emails

Use `gog gmail messages search` with the after: filter based on last scan time.

For emails since a specific date (YYYY/MM/DD):

```bash
gog gmail messages search "from:m@mail1.veracross.com after:YYYY/MM/DD" --max 20 --json --account $GOG_ACCOUNT
```

```bash
gog gmail messages search "from:@issh.ac.jp after:YYYY/MM/DD" --max 20 --json --account $GOG_ACCOUNT
```

Note: Gmail `after:` filter uses date only (YYYY/MM/DD), not datetime. Use the date portion of last_scan_time.

If last_scan_time is `2026-03-25 09:00:00`, search with `after:2026/03/25`.

### Step 3: Check for duplicates

For each email found, check if it's already processed:

```bash
sqlite3 ~/.openclaw/workspace/school_mail_monitor.db "SELECT COUNT(*) FROM processed_emails WHERE message_id = '<message_id>';"
```

Skip if count > 0.

### Step 4: Get full email content

For each new (unprocessed) email:

```bash
gog gmail get <message_id> --json --account $GOG_ACCOUNT
```

Extract: subject, from, date, body text.

### Step 5: Reformat each email

For each email, produce a formatted summary following this structure:

```
📧 [Title/Subject]
━━━━━━━━━━━━━━━━━━━━
From: [sender name and email]
Date: [received date]

📝 Summary
[2-4 sentence summary of the email body in the CHINESE.
Translate the email body If the email is in English or Japanese.]

⚡ Actions Required
[List any action items, deadlines, or things the recipient needs to do.
If none, write "No action required."]
```

### Step 6: Record processed emails

After successfully processing each email:

```bash
sqlite3 ~/.openclaw/workspace/school_mail_monitor.db "INSERT OR IGNORE INTO processed_emails (message_id, subject, sender, received_at) VALUES ('<message_id>', '<subject>', '<sender_email>', '<received_date>');"
```

### Step 7: Update last scan time

After processing ALL emails in this batch:

```bash
sqlite3 ~/.openclaw/workspace/school_mail_monitor.db "UPDATE scan_state SET last_scan_time = datetime('now', 'localtime') WHERE id = 1;"
```

### Step 8: Send to Slack #mail-report

Combine all formatted email summaries into one message and send to the Slack channel using the `message` tool:
if the request comes from chat, send message to that channel, if it's a cron job, send message to the channel specified by cron setting `--to "channel:CHANNEL_ID"`.

```
🏫 School Email Report — [today's date]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[formatted email 1]

[formatted email 2]

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📬 Total: X new email(s) processed
"
```

If no new emails found, tell user for chat, do NOT send a message to Slack for cron job(skip silently).

---

## Formatting Rules

- **Language**: Always summarize in Chinese. School emails may be in English, Japanese, or mixed, if so translate it to Chinese.
- **Length**: Keep summaries concise — 2-4 sentences max.
- **Actions**: Be specific about deadlines. Example: "Submit permission form by March 28" not "There is a form to submit."
- **Multiple emails**: Group them in one Slack message, separated by blank lines and dividers.
- **HTML emails**: Many school emails are HTML-heavy. Focus on extracting the actual text content and ignore HTML formatting, headers, footers, and tracking pixels.

## Common Email Types from These Senders

**Veracross (m@mail1.veracross.com):**
- School announcements and newsletters
- Event notifications
- Grade/progress reports
- Attendance notices
- System notifications

**ISSH (@issh.ac.jp):**
- Teacher communications
- Administrative notices
- Event/activity announcements
- PTA/parent communications
- Schedule changes

## Error Handling

- If Gmail search fails, report error and do NOT update last_scan_time
- If a single email fails to parse, skip it, log the error, and continue with others
- Always use INSERT OR IGNORE for deduplication safety
- Only update last_scan_time after successful processing (not on error)

## Manual Commands

User can also ask:
- "Check school emails" — run the full workflow manually
