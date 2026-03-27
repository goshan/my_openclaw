#!/bin/bash

HOME_DIR=$(cd "$(dirname "$0")/.." &> /dev/null && pwd)
MAIL_DB_PATH="$HOME_DIR/databases/mails_monitor.db"

echo "=== Init DB ==="
echo ""

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
  id INTEGER PRIMARY KEY CHECK (id = 1),
  sender TEXT NOT NULL,
  last_scan_time TEXT NOT NULL
);
SQL

echo "Database initialized at $MAIL_DB_PATH"
