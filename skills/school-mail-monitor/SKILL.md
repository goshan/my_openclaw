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

### mail_fetch

Fetch new messages in my Gmail account with a provided mail sender list, also manaage a database to save processed mails for deduplication
Usage: mail_fetch <sender1> <sender2> ...
These <sender>s don't need to be a full mail address, it can be part of address, ex. a postfix from `@` like `@gmail.com`, etc
Output: The content text of all newly fetched mails will be printed as stdout 
Notes: max fetching number is: 20
Location: `$OPENCLAW_CONFIG_HOME/tools/mail_fetch`

---

## WORKFLOW

### Step 1: Run the script

```bash
$OPENCLAW_CONFIG_HOME/tools/mail/mail_fetch "m@mail1.veracross.com" "@issh.ac.jp"
```

This fetches all new emails sent by "m@mail1.veracross.com" and "@issh.ac.jp" after last fetch date, deduplicates, and output clean content text to stdout.
If output says `NO_NEW_EMAILS`, skip step 2 and go to step 3 directly.


### Step 2: Summarize each email and send to slack (THIS IS YOUR JOB)

For each email in the output, create a summary with the following format:

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


### Step 3: Send the workflow result to slack

Next, send the summary of each email to the Slack channel using the `message` tool.

Last, send the summary of this execution to slack with the following format.
Attention: No matter if there are new mails or not, always send the this summary to slack

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Executed_at: YYYY-MM-DD
📬 Total: X new email(s) processed
```

If the request comes from user chat, send message to that channel, if it's a cron job, send message to the channel specified by cron setting `--to`.

---

## Formatting Rules

- **Language**: Always summarize in Chinese. School emails may be in English, Japanese, or mixed, if so translate it to Chinese.
- **Length**: Keep summaries concise — 2-4 sentences max.
- **Actions**: Be specific about deadlines. Example: "Submit permission form by March 28" not "There is a form to submit."
- **Multiple emails**: Group them in one Slack message, separated by blank lines and dividers.
- **HTML emails**: Many school emails are HTML-heavy. `mail_fetch` script has already extract the text from json and convert html to plain text. No need to parse html any more.

## Manual Commands

User can also ask questions directly in chat

- "Check school emails" -> User can ask to check the latest new emails from school in chat, then run the full workflow mnually
- "Explain more details for a summarized mail" -> Anwser user's question based on this content of plain text file. If you lost the extracted email content, you can use the following steps to re-fetch
  - Fetch mail content by `gog gmail get <message_id> --account $GOG_ACCOUNT` and save it to a json file.
  - extract the json to a plain text by `$OPENCLAW_CONFIG_HOME/tools/mail/mail_extract <gmail_json_file>.json <plain_text_content_file>.txt`
