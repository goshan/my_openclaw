---
name: expenses-track
description: >
  Track credit card expenses across 2 cards, QR code payment PayPay and cash payment (Lexus VISA, Amazon Mastercard, PayPay JCB, Cash).
  Use when: user upload receipt image or paypay screenshot, send expense-like info such as amount, store or asks about expenses, spending, card transactions, or says "expense report", "how much did I spend".
  Also cron job can use this skill to fetch card usage emails
metadata:
  openclaw:
    emoji: "💳"
    requires:
      bins:
        - sqlite3
        - gog
---

# Expenses Tracker

Track expenses across 2 credit cards, QR code payment and cash payment with automated email detection and manual receipt/screenshot scanning.

## Database

Location: `$MY_OPENCLAW_ROOT/data/expense.db`

### Payment Methods

A master table for all kinds of payments

| id | name | notification sender |
|----|------|-------------------|
| 1 | Lexus | info@tscubic.com (TS CUBIC) |
| 2 | Amazon | statement@vpass.ne.jp (Vpass) |
| 3 | PayPay | screenshot |
| 4 | Cash | receipt |

### Transactions

Record all payment transactions from cards, paypay or cash.

Schema:

```sql
CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_method_id INTEGER NOT NULL,
  date TEXT NOT NULL,           -- expense happened date, %Y-%m-%d
  store TEXT,                   -- store name
  amount REAL NOT NULL,         -- expense amount, unit is JPY
  category TEXT,                -- category generated based on store
  note TEXT,                    -- memo for additional information
  created_at TEXT DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
);
```

## Scripts

Scripts that will be used in this skill

### mail_fetch

Fetch new messages in my Gmail account with a provided mail sender list, also manage a database to save processed mails for deduplication
Usage: mail_fetch <sender1> <sender2> ...
These <sender>s don't need to be a full mail address, it can be part of address, ex. a postfix from `@` like `@gmail.com`, etc
Output: Save all email content to a temp file, and print the file path to the stdout
Notes: max fetching number is: 20
Location: `$MY_OPENCLAW_ROOT/tools/mail/mail_fetch`

### expense_add

Insert a transaction record into the expense database.
Usage: expense_add <payment_method_id> <date> <store> <amount> <category> <note>
  date:     'YYYY/MM/DD', 'YYYY-MM-DD', or either with ' HH:mm' — stored as YYYY-MM-DD
Location: `$MY_OPENCLAW_ROOT/skills/expenses-track/scripts/expense_add`

---

## MODE 1: Automated Email Checking

When asked to "check card emails" or triggered by cron:

### Step 1: Run the script to fetch expense emails for 2 cards

```bash
$MY_OPENCLAW_ROOT/tools/mail/mail_fetch "info@tscubic.com" "statement@vpass.ne.jp"
```

This fetches all new emails sent by "info@tscubic.com" "statement@vpass.ne.jp" after last fetch date, deduplicates, and output clean content text to a temp file. The temp file path is printed by stdout as 'Save all emails content to file: <temp_file_path>'
If output says `NO_NEW_EMAILS`, skip step 2 and 3, go to step 4 directly.

### Step 2: Parse email content and extract expense fields

Read the temp file got at step 1, for each email in the file, use the following rule to determine if it's a expense related mail or not.
- Mail from `info@tscubic.com`, the mail subject would be sth like "ご利用のお知らせ[レクサスカード]" or "家族カードのご利用のお知らせ[レクサスカード]"
- Mail from `statement@vpass.ne.jp`, the mail subject would be sth like "ご利用のお知らせ【三井住友カード】" or "ご利用明細のお知らせ【三井住友カード】"
Otherwise, this is not a expense report mail, just skip it.

For each expense report mail, extract the expense transaction fields based on the following rules.
- payment_method_id
  - `info@tscubic.com` -> 1 (Lexus VISA)
  - `statement@vpass.ne.jp` -> 2 (Amazon Mastercard)
- date: look for content about '利用日'
- store: look for content about '利用先'
- amount: look for content about '利用金額'
  - if the unit is not yen, ¥, or 円, then detect the currency and convert the amount to JPY with the latest currency, then record the original amount, unit, and currency as <note>
- category: Assign categories based on store name keywords
  - コンビニ, Lawson, ファミマ, セブン, 7-Eleven → Food
  - スーパー, イオン, ライフ, まいばすけっと → Groceries
  - Amazon, アマゾン → Shopping
  - Suica, PASMO, JR, 電車 → Transport
  - レストラン, 食堂, 居酒屋, マクドナルド, スターバックス → Dining
  - ガソリン, ENEOS, Shell, 出光 → Gas/Fuel
  - 薬局, マツモトキヨシ, ドラッグ → Health
  - Netflix, Spotify, YouTube, サブスク → Subscription
  - 電気, ガス, 水道, NHK → Utilities
  - Other for anything that doesn't match
- note
  - if the original amount unit was not JPY, and a currency conversion hapened, record the amount, unit, currency to this field
  - any other important information or memo that needs to be recorded, set to NULL if there is no

### Step 3: Run the script to insert transaction record

For each extracted transaction data, insert to sqlite3 database by the following command

```bash
$MY_OPENCLAW_ROOT/skills/expenses-track/scripts/expense_add "<payment_method_id>" "<date>" "<store>" "<amount>" "<category>" "<note>"
```

### Step 4: Report results

After processing all emails, summarize with this format:

```
💳 Email Check Complete
━━━━━━━━━━━━━━━━━━━━
New transactions found: X
New entries:
  • Lexus VISA — ¥3,000 at Store A (YYYY-MM-DD)
  • Amazon Mastercard — ¥500 at Store B (YYYY-MM-DD)
```

New entries shows each transaction

If the request comes from user chat, send message to that channel, if it's a cron job, send message to the channel specified by cron setting `--to`.

---

## MODE 2: Manual Receipt or Screenshot Scanning

When user uploads an image in Slack:

### Step 1: Processes the image

The imageModel automatically processes the image (configured separately)

Extract transaction fields based on this strategy
- payment_method_id
  - A regular receipt photo -> Cash
  - A Paypay app screenshot -> PayPay
  - If can't be determined, ask user directly instead of guessing
- store
  - For a receipt, it's usually at the bottom or left bottom
  - For PayPay, it at the top of the image, with an store icon
  - If can't be determined, use 'Unknown', no need to ask 
- date
  - For a receipt, it's usually in the top right side.
  - For a PayPay screenshot, it's in the top, just under the store icon
  - Convert the format to YYYY/MM/DD.
  - If can't be determined, ask user directly instead of guessing
- amount
  - use the same rule as MODE 1 Step 2.
  - If can't be determined, ask the user directly instead of guessing
- category: use the same rule as MODE 1 Step 2
- note: use the same rule as MODE 1 Step 2

### Step 2: Show parsed data and ask "Is this correct?" before inserting

### Step 3: Run the script to insert to table transaction

Exactly the same command in MODE 1 Step 3

### Step 4: Report to user

Use this format

```
✅ Transaction Recorded: ¥1,500 at Lawson (PayPay) — Food
```

---

## MODE 3: Manual Text Entry

When user says something like "spent 1500 yen at Lawson with PayPay":

### Step 1: Parse to generate the transaction fields

- payment_method
  - if no info from user input, use 'Cash' as default
  - paypay or sth like this -> 'PayPay'
  - user may say 'iD' or 'id' or "ID" -> 'Amazon Mastercard'
- date
  - message date, also use format YYYY/MM/DD
- store
  - 'Unknown' as default if no user input, no need to confirm
- amount
  - use the same rule as MODE 1 Step 2
  - If can't be determined, ask the user directly instead of guessing
- category: use the same rule as MODE 1 Step 2
- note: use the same rule as MODE 1 Step 2

### Step 2: Run the script to insert to table transaction

Exactly the same command in MODE 1 Step 3

### Step 3: Report to user

Exactly the same as MODE 2 Step 4

---

## MODE 4: FLEXIBLE DATE QUERIES

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
sqlite3 -header -column $MY_OPENCLAW_ROOT/data/expense.db "
SELECT pm.name AS payment_method,
       COUNT(*) AS txns,
       printf('¥%,.0f', SUM(t.amount)) AS total
FROM transactions t
JOIN payment_methods pm ON t.payment_method_id = pm.id
WHERE {DATE_FILTER}
GROUP BY t.payment_method_id
ORDER BY SUM(t.amount) DESC;
"
```

Details:
```bash
sqlite3 -header -column $MY_OPENCLAW_ROOT/data/expense.db "
SELECT t.date, pm.name AS payment_method, t.store, t.amount, t.category
FROM transactions t
JOIN payment_methods pm ON t.payment_method_id = pm.id
WHERE {DATE_FILTER}
ORDER BY t.date DESC, t.amount DESC;
"
```

Grand total:
```bash
sqlite3 $MY_OPENCLAW_ROOT/data/expense.db "
SELECT printf('¥%,.0f', COALESCE(SUM(amount), 0)) AS total
FROM transactions
WHERE {DATE_FILTER};
"
```

By category:
```bash
sqlite3 -header -column $MY_OPENCLAW_ROOT/data/expense.db "
SELECT category, COUNT(*) AS txns, printf('¥%,.0f', SUM(amount)) AS total
FROM transactions
WHERE {DATE_FILTER}
GROUP BY category
ORDER BY SUM(amount) DESC;
"
```

Replace `{DATE_FILTER}` with the appropriate clause from the table above.

You can also decide what query to use based on the schema of table `transactions` in `$MY_OPENCLAW_ROOT/data/expense.db`.
