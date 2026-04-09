#!/usr/bin/env bash
set -euo pipefail

# Tear down agent team artifacts
# Usage: bash scripts/teardown-team.sh [--keep-branches]
#
# TeamDelete handles team/task directory cleanup.
# This script cleans up any remaining git worktrees and branches.

KEEP_BRANCHES=false
if [[ "${1:-}" == "--keep-branches" ]]; then
  KEEP_BRANCHES=true
fi

echo "==> Cleaning up agent team artifacts..."

# Remove any leftover worktrees
for WORKTREE in $(git worktree list --porcelain | grep "^worktree " | awk '{print $2}'); do
  if [[ "$WORKTREE" == *".worktrees/"* ]] || [[ "$WORKTREE" == *"/worktrees/"* ]]; then
    git worktree remove --force "$WORKTREE" 2>/dev/null && echo "    Removed worktree: $WORKTREE" || true
  fi
done

# Optionally remove agent branches
if [ "$KEEP_BRANCHES" = false ]; then
  for BRANCH in $(git branch --list "agent/*" 2>/dev/null | tr -d ' *'); do
    git branch -D "$BRANCH" 2>/dev/null && echo "    Deleted branch: $BRANCH" || true
  done
else
  echo "    Branches preserved (--keep-branches)"
fi

# Clean output files
rm -f .claude/VERDICT.md .claude/SUMMARY.md
echo "    Output files cleared"

echo ""
echo "==> Done."
