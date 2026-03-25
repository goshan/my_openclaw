---
name: expenses-tracker
description: >
  Track credit card expenses across 3 cards and cash payment (Lexus VISA, Amazon Mastercard, PayPay JCB, Cash).
  Use when: user asks about expenses, spending, card transactions, daily/weekly/monthly reports, or says "check card emails", "scan receipt", "expense report", "how much did I spend".
  Also triggered by cron jobs for automated email checking and daily reports.
metadata:
  openclaw:
    emoji: "💳"
    requires:
      bins:
        - sqlite3
        - gog
---

# Expenses Tracker

Track expenses across 3 credit cards and cash payment with automated email detection and manual receipt scanning.

## Database

Location: `~/.openclaw/workspace/expenses.db`

### Cards
| id | name | notification sender |
|----|------|-------------------|
| 1 | Lexus | info@tscubic.com (TS CUBIC) |
| 2 | Amazon | statement@vpass.ne.jp (Vpass/SMBC) |
| 3 | PayPay | paypaycard-info@mail.paypay-card.co.jp |
| 4 | Cash | NULL |

### Schema
```sql
cards: id, name, email_sender
transactions: id, card_id, date, store, amount, currency, category, note, source, email_id, created_at
```

The `email_id` column stores Gmail message IDs to prevent duplicate processing. A UNIQUE index enforces this.

---

## MODE 1: Automated Email Checking

When asked to "check card emails" or triggered by cron:

### Step 1: Search Gmail for card notification emails

```bash
gog gmail messages search "from:info@tscubic.com OR from:statement@vpass.ne.jp OR from:mail.paypay-card.co.jp newer_than:2d" --max 20 --json --account $GOG_ACCOUNT
```

For each email found, get the full message content:

```bash
gog gmail messages get <message_id> --json --account $GOG_ACCOUNT
```

Only 

### Step 2: Check if already processed

Before processing, check the email_id against the database:

```bash
sqlite3 ~/.openclaw/workspace/expenses.db "SELECT COUNT(*) FROM transactions WHERE email_id = '<message_id>';"
```

If count > 0, skip this email (already processed).

### Step 3: Identify the card from sender

- `info@tscubic.com` → card_id = 1 (Lexus Financial VISA)
- `statement@vpass.ne.jp` → card_id = 2 (Amazon Mastercard)
- `paypaycard-info@mail.paypay-card.co.jp` or forwarded from `mail.paypay-card.co.jp` → card_id = 3 (PayPay JCB)

### Step 4: Parse the email body

Each card issuer uses different email formats. Extract these fields:

**TS CUBIC (Lexus VISA) — from info@tscubic.com:**
- Look for: ご利用金額, ご利用日, ご利用先, カード名称
- Amount may include yen symbol (¥) or 円

**Vpass/SMBC (Amazon MC) — from statement@vpass.ne.jp:**
- Look for: ご利用金額, ご利用日時, ご利用先
- May contain multiple transactions in one email

**PayPay Card (JCB) — from paypaycard-info@mail.paypay-card.co.jp:**
- Look for: ご利用金額, ご利用日, ご利用先
- Note: forwarded from Yahoo Mail, may have forwarding headers
- Store name may show as "JCB国内加盟店" — this is normal, the real store name appears later in the statement

### Step 5: Insert into database

```bash
sqlite3 ~/.openclaw/workspace/expenses.db "INSERT OR IGNORE INTO transactions (card_id, date, store, amount, currency, category, items, tax, note, source, email_id) VALUES (CARD_ID, 'YYYY-MM-DD', 'STORE_NAME', AMOUNT, 'JPY', 'CATEGORY', NULL, NULL, NULL, 'email', 'GMAIL_MESSAGE_ID');"
```

Use `INSERT OR IGNORE` to safely handle duplicates (the UNIQUE index on email_id prevents double-inserts).

### Step 6: Report results

After processing all emails, summarize:
```
💳 Email Check Complete
━━━━━━━━━━━━━━━━━━━━
New transactions found: X
Already processed: Y
Errors: Z

New entries:
  • Lexus VISA — ¥3,000 at Store A (2026-03-24)
  • PayPay JCB — ¥500 at Lawson (2026-03-24)
```

### Category Auto-Detection

Assign categories based on store name keywords:
- コンビニ, Lawson, ファミマ, セブン, 7-Eleven → Food
- スーパー, イオン, ライフ, まいばすけっと → Groceries
- Amazon, アマゾン → Shopping
- Suica, PASMO, JR, 電車 → Transport
- レストラン, 食堂, 居酒屋, マクドナルド → Dining
- ガソリン, ENEOS, Shell, 出光 → Gas/Fuel
- 薬局, マツモトキヨシ, ドラッグ → Health
- Netflix, Spotify, YouTube, サブスク → Subscription
- 電気, ガス, 水道, NHK → Utilities
- Other for anything that doesn't match

---

## MODE 2: Manual Receipt Scanning

When user uploads a receipt image in Slack:

1. The imageModel automatically processes the image (configured separately)
2. Extract: store name, date, items, total, tax
3. Ask which card was used if not mentioned
4. Card detection from user message:
   - "Lexus", "レクサス", "VISA" → card_id = 1
   - "Amazon", "アマゾン", "Mastercard" → card_id = 2
   - "PayPay", "ペイペイ", "JCB" → card_id = 3
5. Show parsed data and ask "Is this correct?" before inserting
6. Insert with source = 'receipt'

---

## MODE 3: Manual Text Entry

When user says something like "spent 1500 yen at Lawson with PayPay card":

1. Parse: amount, store, card
2. Insert with source = 'manual'
3. Confirm:
```
✅ Recorded: ¥1,500 at Lawson (PayPay JCB) — Food
```

---

## Reports

### DAILY REPORT (cron: every day at 9 AM JST)

Query yesterday's transactions AND this month's accumulated total.

**Yesterday's details:**
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT c.name AS card, t.store, t.amount, t.category
FROM transactions t
JOIN cards c ON t.card_id = c.id
WHERE t.date = date('now', '-1 day', 'localtime')
ORDER BY c.name, t.amount DESC;
"
```

**Yesterday's subtotals by card:**
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT c.name AS card, c.brand,
       COUNT(*) AS txns,
       printf('¥%,.0f', SUM(t.amount)) AS total
FROM transactions t
JOIN cards c ON t.card_id = c.id
WHERE t.date = date('now', '-1 day', 'localtime')
GROUP BY t.card_id
ORDER BY SUM(t.amount) DESC;
"
```

**Month-to-date accumulated total (include in every daily report):**
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT c.name AS card,
       COUNT(*) AS txns,
       printf('¥%,.0f', SUM(t.amount)) AS month_total
FROM transactions t
JOIN cards c ON t.card_id = c.id
WHERE t.date >= date('now', 'start of month', 'localtime')
GROUP BY t.card_id
ORDER BY SUM(t.amount) DESC;
"
```

```bash
sqlite3 ~/.openclaw/workspace/expenses.db "
SELECT printf('¥%,.0f', COALESCE(SUM(amount), 0)) AS grand_total
FROM transactions
WHERE date >= date('now', 'start of month', 'localtime');
"
```

**Daily report format:**

```
💳 Daily Expense Report — [yesterday's date]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔵 Lexus Financial (VISA)
  • Store A — ¥3,000 (Food)
  • Store B — ¥1,500 (Transport)
  Subtotal: ¥4,500

🟠 Amazon (Mastercard)
  • Amazon.co.jp — ¥8,900 (Shopping)
  Subtotal: ¥8,900

🟢 PayPay (JCB)
  • Convenience store — ¥500 (Food)
  Subtotal: ¥500

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 Yesterday Total: ¥13,900

📊 Month-to-Date ([month name])
  🔵 Lexus Financial: ¥45,000 (12 txns)
  🟠 Amazon: ¥32,000 (8 txns)
  🟢 PayPay: ¥18,000 (25 txns)
  ━━━━━━━━━━━━━━━━━━
  📈 Accumulated Total: ¥95,000
```

If no transactions yesterday: "No expenses recorded yesterday. 🎉" (still show the month-to-date section)

---

### MONTHLY REPORT (cron: 1st of every month at 9 AM JST)

Reports on the PREVIOUS month's data (e.g., on April 1st, report March data).

**Last month's totals by card:**
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT c.name AS card, c.brand,
       COUNT(*) AS txns,
       printf('¥%,.0f', SUM(t.amount)) AS total
FROM transactions t
JOIN cards c ON t.card_id = c.id
WHERE t.date >= date('now', 'start of month', '-1 month', 'localtime')
  AND t.date < date('now', 'start of month', 'localtime')
GROUP BY t.card_id
ORDER BY SUM(t.amount) DESC;
"
```

**Last month's grand total:**
```bash
sqlite3 ~/.openclaw/workspace/expenses.db "
SELECT printf('¥%,.0f', COALESCE(SUM(amount), 0)) AS grand_total
FROM transactions
WHERE date >= date('now', 'start of month', '-1 month', 'localtime')
  AND date < date('now', 'start of month', 'localtime');
"
```

**Last month's top spending categories:**
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT category,
       COUNT(*) AS txns,
       printf('¥%,.0f', SUM(amount)) AS total
FROM transactions
WHERE date >= date('now', 'start of month', '-1 month', 'localtime')
  AND date < date('now', 'start of month', 'localtime')
GROUP BY category
ORDER BY SUM(amount) DESC
LIMIT 10;
"
```

**Last month's top stores:**
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT store,
       COUNT(*) AS visits,
       printf('¥%,.0f', SUM(amount)) AS total
FROM transactions
WHERE date >= date('now', 'start of month', '-1 month', 'localtime')
  AND date < date('now', 'start of month', 'localtime')
GROUP BY store
ORDER BY SUM(amount) DESC
LIMIT 10;
"
```

**Monthly report format:**

```
📊 Monthly Expense Report — [last month name] [year]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💳 By Card
  🔵 Lexus Financial (VISA): ¥45,000 (12 txns)
  🟠 Amazon (Mastercard): ¥32,000 (8 txns)
  🟢 PayPay (JCB): ¥18,000 (25 txns)

🏷️ Top Categories
  1. Food — ¥28,000
  2. Shopping — ¥22,000
  3. Transport — ¥15,000
  4. Dining — ¥12,000
  5. Utilities — ¥8,000

🏪 Top Stores
  1. Amazon.co.jp — ¥18,000 (5 visits)
  2. Lawson — ¥8,500 (15 visits)
  3. Seiyu — ¥6,000 (4 visits)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 Grand Total: ¥95,000
```

---

### FLEXIBLE DATE QUERIES

For any user request about a custom time range ("last week", "last 3 days", "this week", "March", etc.), use these SQLite date patterns:

**Date filter patterns:**
| User says | SQL WHERE clause |
|-----------|-----------------|
| today | `date = date('now', 'localtime')` |
| yesterday | `date = date('now', '-1 day', 'localtime')` |
| last 7 days / this week | `date >= date('now', '-7 days', 'localtime')` |
| last week (Mon-Sun) | `date >= date('now', 'weekday 1', '-14 days', 'localtime') AND date < date('now', 'weekday 1', '-7 days', 'localtime')` |
| last 30 days | `date >= date('now', '-30 days', 'localtime')` |
| this month | `date >= date('now', 'start of month', 'localtime')` |
| last month | `date >= date('now', 'start of month', '-1 month', 'localtime') AND date < date('now', 'start of month', 'localtime')` |
| specific month (e.g. March 2026) | `date >= '2026-03-01' AND date < '2026-04-01'` |
| specific date range | `date >= 'YYYY-MM-DD' AND date <= 'YYYY-MM-DD'` |

**Template for any date range query:**

Summary by card:
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT c.name AS card, c.brand,
       COUNT(*) AS txns,
       printf('¥%,.0f', SUM(t.amount)) AS total
FROM transactions t
JOIN cards c ON t.card_id = c.id
WHERE {DATE_FILTER}
GROUP BY t.card_id
ORDER BY SUM(t.amount) DESC;
"
```

Details:
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT t.date, c.name AS card, t.store, t.amount, t.category
FROM transactions t
JOIN cards c ON t.card_id = c.id
WHERE {DATE_FILTER}
ORDER BY t.date DESC, t.amount DESC;
"
```

Grand total:
```bash
sqlite3 ~/.openclaw/workspace/expenses.db "
SELECT printf('¥%,.0f', COALESCE(SUM(amount), 0)) AS total
FROM transactions
WHERE {DATE_FILTER};
"
```

By category:
```bash
sqlite3 -header -column ~/.openclaw/workspace/expenses.db "
SELECT category, COUNT(*) AS txns, printf('¥%,.0f', SUM(amount)) AS total
FROM transactions
WHERE {DATE_FILTER}
GROUP BY category
ORDER BY SUM(amount) DESC;
"
```

Replace `{DATE_FILTER}` with the appropriate clause from the table above.

---

## For Japanese Text in Emails

- 合計 / 合計金額 = Total
- 小計 = Subtotal
- 税 / 消費税 = Tax
- 店名 / ご利用先 = Store name
- ご利用金額 = Transaction amount
- ご利用日 / ご利用日時 = Transaction date
- Date formats: YYYY/MM/DD, YYYY年MM月DD日, MM/DD

## Error Handling

- If email parsing fails, involve the error into the response to users including title of email and skip that email (don't crash the whole batch)
- If amount can't be parsed, ask the user
- If card can't be determined, ask the user
- If Gmail search fails, report the error and suggest checking gog auth status
- Always use INSERT OR IGNORE to prevent duplicate entries
