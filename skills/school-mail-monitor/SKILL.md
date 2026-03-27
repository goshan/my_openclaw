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

## Scripts

Scripts that will be used in this skill
Location: `$OPENCLAW_CONFIG_HOME/bins`

### mail_fetch

Fetch new messages in my Gmail account with a provided mail sender, also manaage a database for processed mail deduplication and continous work without overlap time
Usage: mail_fetch <sender>, this <sender> doesn't need to be a full mail address, it can be part of address, ex. a postfix from `@` like `@gmail.com`, etc

For inputed email sender, this script will do the following steps
- get the `last_scan_time` from database
- fetch all new emails from the sender after `last_scan_date`
- for each fetched email, check database `processed_emails` for deduplication
- for each new email
  - print new email id
  - insert the metadata like id, subject, sender, received_at database `processed_emails`
  - run script `mail_extract` to extract mail text from json format and convert html into text
  - save the extracted email content as a text file to `/tmp/<message_id>.txt`
- update `last_scan_time` to the current time, so that next time we can continue from new emails for the specified sender

Notes: max fetching number of mails for each sender is: 20

### mail_extract

Used by mail_fetch
Extract readable text from a Gmail message JSON file.
Usage: mail_extract <input.json> [output.txt]
  If output.txt is omitted, prints to stdout.

### sqlite3_exec

Used by mail_fetch
Execute query in sqlite3 with proper charater escape handling
Usage: sqlite3_exec <database_file> <query_text> <arg1> <arg2> ...
  <query_holder> uses `?` as argument holder, example: 'INSERT OR IGNORE INTO processed_emails (message_id, subject, sender, received_at) VALUES (?, ?, ?, ?)'
  the number of remaining arguments should be equal to `?` in query_holder

## Database

Record processed emails metadata
Location: `$OPENCLAW_CONFIG_HOME/data/mails_monitor.db`

### Tables

**processed_emails** — deduplication tracking
```sql
id, message_id (UNIQUE), subject, sender, received_at, processed_at
```

**scan_state** — remembers where we left off
```sql
id, sender, last_scan_time
```
record the last scan time per each email sender

## Email Content file

Record all processed email full content as text file under `/tmp`
Location: `/tmp/<message_id>.txt`

---

## WORKFLOW

### Step 1: Fetch all new emails

```bash
$OPENCLAW_CONFIG_HOME/bins/mail_fetch "m@mail1.veracross.com"
$OPENCLAW_CONFIG_HOME/bins/mail_fetch "@issh.ac.jp"
```

Attention: Don't search mail content text files under `/tmp`, there might be some files generated from previous executions. So only use the output of `mail_fetch` to verify if there is new mail.

### Step 2: Reformat each email and send to slack

For each email, we have already known the mail id from Step 1, 
so we need to get the full email content from file `/tmp/<message_id>.txt`,
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

Next, send the summary of each email to the Slack channel using the `message` tool.
If the request comes from user chat, send message to that channel, if it's a cron job, send message to the channel specified by cron setting `--to "channel:<xxxx>"`.

### Step 3: Send the workflow result to slack

Send the summary of this execution to slack with the following format.
Attention: No matter if there are new mails or not, always send the this summary to slack

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Executed_at: YYYY-MM-DD
📬 Total: X new email(s) processed
```

---

## Formatting Rules

- **Language**: Always summarize in Chinese. School emails may be in English, Japanese, or mixed, if so translate it to Chinese.
- **Length**: Keep summaries concise — 2-4 sentences max.
- **Actions**: Be specific about deadlines. Example: "Submit permission form by March 28" not "There is a form to submit."
- **Multiple emails**: Group them in one Slack message, separated by blank lines and dividers.
- **HTML emails**: Many school emails are HTML-heavy. `mail_fetch` script has already extract the text from json and convert html to plain text. No need to parse html any more.

## Error Handling

- If Gmail search fails, report error and do NOT update last_scan_time
- If a single email fails to parse, skip it, log the error, and continue with others
- Always use INSERT OR IGNORE for deduplication safety
- Only update last_scan_time after successful processing (not on error)

## Manual Commands

User can also ask questions directly in chat

- "Check school emails" -> User can ask to check the latest new emails from school in chat, then run the full workflow mnually
- "Explain more details for a summarized mail"
  - Read file `/tmp/<message_id>.txt` to get mail full content again
  - Then anwser user's question based on the mail content
  - If the mail content file doesn't exist, then use `gog gmail get <message_id> --account $GOG_ACCOUNT`, and `$OPENCLAW_CONFIG_HOME/bins/mail_extract <gmail_json_content_file>.json <gmail_text_content_file>.txt` to get full content again.

