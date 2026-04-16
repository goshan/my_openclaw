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
        - gog
        - mysql
        - mail_fetch
        - mail_extract
        - mysql_exec
        - expense_add
---

# Expenses Tracker

Track expenses across 2 credit cards, QR code payment and cash payment with automated email detection and manual receipt/screenshot scanning.

## Database

MySQL database: `expense`

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
  id                INT AUTO_INCREMENT PRIMARY KEY,
  payment_method_id INT NOT NULL,
  date              DATE NOT NULL,
  store             VARCHAR(255),
  amount            DECIMAL(12,2) NOT NULL,
  category          VARCHAR(100),
  note              TEXT,
  created_at        DATETIME DEFAULT NOW(),
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
Database is `mails_monitor` on the configured MySQL server

### expense_add

Insert a transaction record into the expense database.
Usage: expense_add <payment_method_id> <date> <store> <amount> <category> <note> [--currency CODE]
  date:     'YYYY/MM/DD', 'YYYY-MM-DD', or either with ' HH:mm' — stored as YYYY-MM-DD
  currency: ISO 4217 code (default: JPY). If non-JPY, fetches live rate and converts to JPY.
            Appends "original amount: CURRENCY RAW" to note automatically.
            If the rate fetch fails, stores the raw amount and marks note with "currency conversion failed".
Note: Database is `expense` on the configured MySQL server

---

## MODE 1: Automated Email Checking

When asked to "check card emails" or triggered by cron:

### Step 1: Run the script to fetch expense emails for 2 cards

```bash
mail_fetch "info@tscubic.com" "statement@vpass.ne.jp"
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
  - extract the raw numeric amount and its currency code (e.g. USD, EUR, JPY) by determining marks like '¥', '$', '円', 'yen', etc.
  - do NOT convert — pass the raw amount and currency to `expense_add` via `--currency`
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
  - Moly, Class → Kids/Education
  - Other for anything that doesn't match
- note
  - any other important information or memo that needs to be recorded, set to NULL if there is no
  - do NOT manually construct currency conversion notes — `expense_add` appends them automatically

Attention: There might be some information about `取引結果` or something, and if the value is something like `取引不成立`, then just skip this email and no need to run step 3 for this email.

### Step 3: Run the script to insert transaction record

For each extracted transaction data, insert to MySQL database by the following command

```bash
# JPY (default)
expense_add "<payment_method_id>" "<date>" "<store>" "<amount>" "<category>" "<note>"

# Foreign currency — script fetches live rate and converts to JPY automatically
expense_add "<payment_method_id>" "<date>" "<store>" "<amount>" "<category>" "<note>" --currency <CURRENCY CODE>
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
  - default is today if user didn't mention. also use format YYYY/MM/DD
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

For any user request about a custom time range ("last week", "last 3 days", "this week", "March", etc.), use these MySQL date patterns:

**Date filter patterns:**

| User says | SQL WHERE clause |
|-----------|-----------------|
| today | `date = CURDATE()` |
| yesterday | `date = CURDATE() - INTERVAL 1 DAY` |
| last 7 days / this week | `date >= CURDATE() - INTERVAL 7 DAY` |
| last week (Mon-Sun) | `date >= CURDATE() - INTERVAL (DAYOFWEEK(CURDATE()) + 5) DAY AND date < CURDATE() - INTERVAL (DAYOFWEEK(CURDATE()) - 2) DAY` |
| last 30 days | `date >= CURDATE() - INTERVAL 30 DAY` |
| this month | `date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')` |
| last month | `date >= DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m-01') AND date < DATE_FORMAT(CURDATE(), '%Y-%m-01')` |
| specific month (e.g. March 2026) | `date >= '2026-03-01' AND date < '2026-04-01'` |
| specific date range | `date >= 'YYYY-MM-DD' AND date <= 'YYYY-MM-DD'` |

**Template for any date range query:**

Summary by card:
```bash
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --table expense -e "
SELECT pm.name AS payment_method,
       COUNT(*) AS txns,
       CONCAT('¥', FORMAT(SUM(t.amount), 0)) AS total
FROM transactions t
JOIN payment_methods pm ON t.payment_method_id = pm.id
WHERE {DATE_FILTER}
GROUP BY t.payment_method_id
ORDER BY SUM(t.amount) DESC;
"
```

Details:
```bash
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --table expense -e "
SELECT t.date, pm.name AS payment_method, t.store, t.amount, t.category
FROM transactions t
JOIN payment_methods pm ON t.payment_method_id = pm.id
WHERE {DATE_FILTER}
ORDER BY t.date DESC, t.amount DESC;
"
```

Grand total:
```bash
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --skip-column-names --batch expense -e "
SELECT CONCAT('¥', FORMAT(COALESCE(SUM(amount), 0), 0)) AS total
FROM transactions
WHERE {DATE_FILTER};
"
```

By category:
```bash
mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --table expense -e "
SELECT category, COUNT(*) AS txns, CONCAT('¥', FORMAT(SUM(amount), 0)) AS total
FROM transactions
WHERE {DATE_FILTER}
GROUP BY category
ORDER BY SUM(amount) DESC;
"
```

Replace `{DATE_FILTER}` with the appropriate clause from the table above.

You can also decide what query to use based on the schema of table `transactions` in the `expense` database.


## Error Handling

- If the scripts failed or printed any error message, just post the error information to user and end the flow, NEVER try to process the workflow by reading code or using your own code.
