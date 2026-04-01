#!/bin/bash

MAIL_DB_PATH="$HOME/data/mails_monitor.db"
EXPENSE_DB_PATH="$HOME/data/expense.db"

echo "Init DB..."

sqlite3 "$MAIL_DB_PATH" << 'SQL'
CREATE TABLE IF NOT EXISTS processed_emails (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL UNIQUE,
  subject TEXT,
  sender TEXT,
  received_at TEXT,
  processed_at TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS scan_state (
  sender TEXT PRIMARY KEY,
  last_scan_time TEXT NOT NULL
);
SQL


echo "  - $MAIL_DB_PATH"

sqlite3 "$EXPENSE_DB_PATH" << 'SQL'
CREATE TABLE IF NOT EXISTS payment_methods (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  notification_sender TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_method_id INTEGER NOT NULL,
  date TEXT NOT NULL,           -- expense happened date
  store TEXT,                   -- store name
  amount REAL NOT NULL,         -- expense amount, unit is JPY
  category TEXT,                -- category generated based on store
  note TEXT,                    -- memo for additional information
  created_at TEXT DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
);

INSERT OR IGNORE INTO payment_methods (id, name, notification_sender) VALUES
  (1, 'Lexus', 'info@tscubic.com'),
  (2, 'Amazon', 'statement@vpass.ne.jp'),
  (3, 'PayPay', 'screenshot'),
  (4, 'Cash', 'receipt');
SQL

echo "  - $EXPENSE_DB_PATH"

echo "Database initialized"
echo ""
