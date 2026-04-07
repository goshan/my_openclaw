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
        - mysql_exec
        - expense_report
        - daily_real_state
---

# Morning Briefing

Generate a daily morning briefing. Collect all five sections below, then post the combined output as a single message.

**Location**: Tokyo, Japan

---

## Step 1: Weather Forecast

Fetch weather data from Open-Meteo:

```
https://api.open-meteo.com/v1/forecast?latitude=35.6762&longitude=139.6503&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=Asia%2FTokyo
```

The response contains:
- `current`: live conditions (temperature, apparent temperature, humidity, wind speed, weather_code)
- `daily`: today's forecast (weather_code, max/min temperature)

**WMO weather_code interpretation** (use this to convert the code to a human-readable condition):

| Code | Condition |
|------|-----------|
| 0 | Clear sky |
| 1–3 | Mainly clear / partly cloudy / overcast |
| 45, 48 | Fog |
| 51–55 | Drizzle |
| 61–65 | Rain |
| 71–75 | Snow |
| 80–82 | Rain showers |
| 85–86 | Snow showers |
| 95 | Thunderstorm |
| 96, 99 | Thunderstorm with hail |

Interpret the data into a concise, human-readable weather summary.

---

## Step 2: Currency Rates

Fetch exchange rates from Frankfurter API, including the User-Agent header:

```
GET https://api.frankfurter.app/latest?from=CNY&to=JPY
GET https://api.frankfurter.app/latest?from=USD&to=JPY
Headers: User-Agent: Mozilla/5.0
```

Each response contains a `rates.JPY` field with the rate. Round to 1 decimal place.

---

## Step 3: Expense Report

Run the expense report script:

```bash
expense_report
```

Capture the full stdout output and include it as-is in the briefing.

---

## Step 4: Google Calendar

Fetch today's events from two calendars using `gog`:

```bash
# Personal calendar
gog calendar events primary -a "$GOG_ACCOUNT" --today --plain

# もも家
gog calendar events "sju3uu229khkrjin1k43e78dmk@group.calendar.google.com" -a "$GOG_ACCOUNT" --today --plain

# School Calendar
gog calendar events "issh.ac.jp_kdna6o2b4h1gpd0pj9e30ih57s@group.calendar.google.com" -a "$GOG_ACCOUNT" --today --plain
```

Each command outputs tab-separated columns: `ID  START  END  SUMMARY`. Use the `START` and `SUMMARY` columns for display.

- Merge the results from all calendars and sort by start time.
- For all-day events, show the title without a time.
- For timed events, show the start time (HH:MM) and title.
- If a location is present, append it in parentheses.
- If all calendars return no events, print: `予定なし — no events today.`

---

## Step 5: Real Estate Metrics

Run the script and include its full stdout output as-is:

```bash
daily_real_state
```

---

## Output Format

Combine all sections into one message using this structure:

```
🌅 Good Morning — {YYYY-MM-DD}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌤 Weather · Tokyo
  {condition}, {low}°C – {high}°C
  {any warnings, or omit line if none}
  {Future 3 days forcast}

💱 Currency
  CNY → JPY: {rate}
  USD → JPY: {rate}

{full expense_report output, preserving its own formatting}

📅 Today's Calendar
  {HH:MM} {event title} ({location})   ← timed event
  {event title}                         ← all-day event
  {or "予定なし — no events today."}

🏠 Real Estate Metrics
{full daily_real_statet output, preserving its own formatting}
```
