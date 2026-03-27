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

Record processed emails metadata
Location: `~/.openclaw/workspace/databases/school_mail_monitor.db`

### Tables

**processed_emails** — deduplication tracking
```sql
id, message_id (UNIQUE), subject, sender, received_at, processed_at
```

**scan_state** — remembers where we left off
```sql
id (always 1), last_scan_time
```

## Email Content file

Record all processed email full content as json file
Location: `~/.openclaw/workspace/emails/<message_id>.json`

---

## WORKFLOW

### Step 1: Fetch all new emails

```bash
~/.openclaw/workspace/skills/school-mail-monitor/bins/mail_fetch
```

This script will do the following steps
- get the `last_scan_time` from database
- fetch all new emails from "m@mail1.veracross.com", "@issh.ac.jp" after `last_scan_date`
- for each fetched email, check database `processed_emails` for duplication
- for each new email
  - print new email id
  - insert the metadata like id, subject, sender, received_at database `processed_emails`
  - save the whole email content as a json file under folder `~/.openclaw/workspace/emails/`, use message_id as the file name
- update `last_scan_time` to the current time, so that next time the script continue the work

### Step 2: Reformat each email

For each email, we have already known the mail id from Step 1, 
so we need to get the full email content from file `~/.openclaw/workspace/emails/<message_id>.json`,
then produce a formatted summary following this structure:

```
📧 [Title/Subject]
━━━━━━━━━━━━━━━━━━━━
From: [sender name and email]
Date: [received date]

📝 Summary
[2-4 sentence summary of the email body in the **CHINESE**.
Translate the email body If the email is in English or Japanese.]

⚡ Actions Required
[List any action items, deadlines, or things the recipient needs to do.
If none, write "No action required."]
```

### Step 3: Send to Slack #mail-report

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

User can also ask questions directly in chat

- "Check school emails" -> User can ask to check the latest new emails from school in chat, then run the full workflow mnually
- "Explain more details for a summarized mail"
  - Checking the extracted email content, give more details to user based on questions
  - if there is no content found in cache or history, then:
    - Check cache and history, if found, then use it to give more details to user
    - Otherwise,
      - Search database by subject to get the email_id. `sqlite3 ~/.openclaw/workspace/databases/school_mail_monitor.db "SELECT message_id FROM processed_emails WHERE subject LIKE '%<subject>%';"`
      - Read file `~/.openclaw/workspace/emails/<message_id>.json` to get mail full content
      - Then anwser user's question based on the mail content
  - If the mail content file doesn't exist in `~/.openclaw/workspace/emails`, then use `gog gmail get <message_id> --account $GOG_ACCOUNT` to get full content again.

