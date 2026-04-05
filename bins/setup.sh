#!/bin/bash
set -e

echo "=== Setup ==="
echo ""

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env"

# Create folders
echo "Creating new folders"
skill_dir="$OPENCLAW_ROOT/workspace/skills"
echo "  - $skill_dir"
mkdir -p "$skill_dir"
log_dir="$HOME/log"
echo "  - $log_dir"
mkdir -p "$log_dir"
tmp_dir="$MY_OPENCLAW_ROOT/tmp"
echo "  - $tmp_dir"
mkdir -p "$tmp_dir"
echo ""

# Install Python dependencies
echo "Installing Python dependencies"
pip3 install mysql-connector-python
echo ""

# Initialize database
$MY_OPENCLAW_ROOT/bins/init_db.sh

# Deploy
$MY_OPENCLAW_ROOT/bins/deploy.sh

echo "=== Setup Complete ==="
