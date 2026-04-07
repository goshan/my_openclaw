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

Fetch exchange rates from Frankfurter API:

```
https://api.frankfurter.app/latest?from=CNY&to=JPY
https://api.frankfurter.app/latest?from=USD&to=JPY
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

Fetch today's data with location labels and period-over-period comparisons:

```bash
mysql_exec real_state "
  SELECT
    l.label,
    t.average                                                        AS avg_today,
    t.count                                                          AS count_today,
    ROUND((t.average - w.average) / w.average * 100, 1)             AS wow_pct,
    ROUND((t.average - m.average) / m.average * 100, 1)             AS mom_pct,
    ROUND((t.average - y.average) / y.average * 100, 1)             AS yoy_pct
  FROM daily_metrics t
  JOIN  locations l ON l.code = t.location_code
  LEFT JOIN daily_metrics w ON w.location_code = t.location_code AND w.date = t.date - INTERVAL 7 DAY
  LEFT JOIN daily_metrics m ON m.location_code = t.location_code AND m.date = t.date - INTERVAL 1 MONTH
  LEFT JOIN daily_metrics y ON y.location_code = t.location_code AND y.date = t.date - INTERVAL 1 YEAR
  WHERE t.date = %s
  ORDER BY l.layer, l.label
" "$(date +%Y-%m-%d)"
```

Columns: `label`, `avg_today`, `count_today`, `wow_pct` (week-over-week %), `mom_pct` (month-over-month %), `yoy_pct` (year-over-year %).

- Format each row as: `{label}: avg ¥{avg_today} ({count_today} listings) | WoW {wow_pct}% MoM {mom_pct}% YoY {yoy_pct}%`
- If a comparison value is EMPTY or NULL (no data for that period), show `—` instead of a percentage.
- If the result is empty, print: `データ未準備 — real estate metrics not yet available for today.`

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
  {table rows, or "データ未準備 — real estate metrics not yet available for today."}
```
