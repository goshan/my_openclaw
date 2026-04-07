---
name: morning-briefing
description: >
  Daily morning briefing with weather forecast, currency rates, expense summary, calendar events, and real estate metrics.
  Triggered by cron at 8am every day.
metadata:
  openclaw:
    emoji: "🌅"
    requires:
      bins:
        - gog
        - expense_report
        - daily_real_state
        - morning_briefing
---

# Morning Briefing

## Step 1: Run the briefing script

```bash
morning_briefing
```

Capture the full stdout output.

## Step 2: Translate and post

Translate the entire output into **Chinese (中文)**, preserving all numbers, symbols, and formatting. Post the translated result as a single message.
