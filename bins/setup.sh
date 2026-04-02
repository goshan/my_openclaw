#!/bin/bash
set -e

echo "=== Setup ==="
echo ""

env_path="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env"
source "$env_path"

# Create folders
echo "Creating new folders"
skill_dir="$OPENCLAW_ROOT/workspace/skills"
echo "  - $skill_dir"
mkdir -p "$skill_dir"
data_dir="$HOME/data"
echo "  - $data_dir"
mkdir -p "$data_dir"
tmp_dir="$MY_OPENCLAW_ROOT/tmp"
echo "  - $tmp_dir"
mkdir -p "$tmp_dir"
echo ""

# Initialize database
$MY_OPENCLAW_ROOT/bins/init_db.sh

# Deploy
$MY_OPENCLAW_ROOT/bins/deploy.sh

echo "Importing env to .zshrc"
echo "" >> "$HOME/.zshrc"
echo "# My OpenClaw ENV" >> "$HOME/.zshrc"
echo "source \"$env_path\"" >> "$HOME/.zshrc"
echo "=== Setup Complete ==="
