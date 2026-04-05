#!/bin/bash

set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env"

MYSQL_CMD="mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWORD"

echo "Init DB..."

$MYSQL_CMD mails_monitor << 'SQL'
CREATE TABLE IF NOT EXISTS processed_emails (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  message_id   VARCHAR(125) NOT NULL UNIQUE,
  subject      TEXT,
  sender       VARCHAR(255),
  received_at  DATETIME,
  processed_at DATETIME DEFAULT NOW()
) CHARACTER SET utf8mb4;

CREATE TABLE IF NOT EXISTS scan_state (
  sender         VARCHAR(125) PRIMARY KEY,
  last_scan_time DATETIME NOT NULL
) CHARACTER SET utf8mb4;
SQL

echo "  - mails_monitor"

$MYSQL_CMD expense << 'SQL'
CREATE TABLE IF NOT EXISTS payment_methods (
  id                   INT PRIMARY KEY,
  name                 VARCHAR(100) NOT NULL,
  notification_sender  VARCHAR(255)
) CHARACTER SET utf8mb4;

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
) CHARACTER SET utf8mb4;

INSERT IGNORE INTO payment_methods (id, name, notification_sender) VALUES
  (1, 'Lexus',   'info@tscubic.com'),
  (2, 'Amazon',  'statement@vpass.ne.jp'),
  (3, 'PayPay',  'screenshot'),
  (4, 'Cash',    'receipt');
SQL

echo "  - expense"

echo "Database initialized"
echo ""
