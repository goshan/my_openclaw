#!/bin/bash
set -e

echo "=== Setup ==="
echo ""

HOME_DIR=$(cd "$(dirname "$0")/.." &> /dev/null && pwd)
SKILL_DIR="$HOME/.openclaw/workspace/skills"

# Create folders
echo "create new folders"
mkdir -p $SKILL_DIR
mkdir -p "$HOME_DIR/data"
mkdir -p "$HOME_DIR/tmp"

echo ""

# Initialize database
$HOME_DIR/tools/init_db.sh

# Deploy
$HOME_DIR/tools/deploy.sh

echo "=== Setup Complete ==="
