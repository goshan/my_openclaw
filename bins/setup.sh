#!/bin/bash
set -e

echo "=== Setup ==="
echo ""

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env"
SKILL_DIR="$OPENCLAW_ROOT/workspace/skills"

# Create folders
echo "create new folders"
mkdir -p $SKILL_DIR
mkdir -p "$MY_OPENCLAW_ROOT/data"
mkdir -p "$MY_OPENCLAW_ROOT/tmp"

echo ""

# Initialize database
$MY_OPENCLAW_ROOT/tools/init_db.sh

# Deploy
$MY_OPENCLAW_ROOT/tools/deploy.sh

echo "=== Setup Complete ==="
