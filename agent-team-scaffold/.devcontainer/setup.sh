#!/usr/bin/env bash
set -euo pipefail

echo "==> Claude Agent Team Lab: setup"

# Install project deps
if [ -f "package.json" ]; then
  echo "==> Installing Node dependencies..."
  npm install
fi

# Ensure we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ERROR: /workspace must be a git repository."
  exit 1
fi

# Create output directory
mkdir -p .claude

echo ""
echo "==> Setup complete."
echo "    To run: bash scripts/start-team.sh specs/my-feature.md"
echo "    Or in Claude Code: 'Launch the agent team for specs/my-feature.md'"
