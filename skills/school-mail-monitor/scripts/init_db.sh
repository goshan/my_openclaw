#!/bin/bash

DB_PATH="${HOME}/.openclaw/workspace/school_mail_monitor.db"

sqlite3 "$DB_PATH" << 'SQL'
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
  last_scan_time TEXT NOT NULL
);

-- Initialize last_scan_time to 7 days ago
INSERT OR IGNORE INTO scan_state (id, last_scan_time)
  VALUES (1, datetime('now', '-3 days', 'localtime'));
SQL

echo "Database initialized at $DB_PATH"
sqlite3 "$DB_PATH" "SELECT * FROM scan_state;"
