#!/bin/bash
set -e

echo "=== Setup ==="
echo ""

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env"

# Create folders
echo "create new folders"
mkdir -p "$OPENCLAW_ROOT/workspace/skills"
mkdir -p "$HOME/data"
mkdir -p "$MY_OPENCLAW_ROOT/tmp"
echo ""

# Initialize database
$MY_OPENCLAW_ROOT/bins/init_db.sh

# Deploy
$MY_OPENCLAW_ROOT/bins/deploy.sh

echo "import env to .zshrc"
echo "" >> "$HOME/.zshrc"
echo "# My OpenClaw ENV" >> "$HOME/.zshrc"
echo 'source "$HOME/my_openclaw/env"' >> "$HOME/.zshrc"
echo "=== Setup Complete ==="
