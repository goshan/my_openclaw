#!/bin/bash
DB_PATH="${HOME}/.openclaw/workspace/expenses.db"

sqlite3 "$DB_PATH" << 'SQL'
CREATE TABLE IF NOT EXISTS cards (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  email_sender TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  store TEXT,
  amount REAL NOT NULL,
  currency TEXT DEFAULT 'JPY',
  category TEXT,
  note TEXT,
  source TEXT DEFAULT 'manual',
  email_id TEXT,
  created_at TEXT DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY (card_id) REFERENCES cards(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_email_id ON transactions(email_id);

INSERT OR REPLACE INTO cards (id, name, brand, email_sender) VALUES
  (1, 'Lexus', 'info@tscubic.com'),
  (2, 'Amazon', 'statement@vpass.ne.jp'),
  (3, 'PayPay', 'paypaycard-info@mail.paypay-card.co.jp'),
  (4, 'Cash', NULL);
SQL

echo "Database initialized at $DB_PATH"
sqlite3 "$DB_PATH" "SELECT id, name, brand, email_sender FROM cards;"
