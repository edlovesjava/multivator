#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/start-team.sh specs/my-rfp.md
#
# Launches a Claude Code session that orchestrates the agent team
# using native TeamCreate/Agent tooling.

SPEC_FILE="${1:-}"

if [ -z "$SPEC_FILE" ]; then
  echo "Usage: bash scripts/start-team.sh <path-to-rfp.md>"
  echo "Example: bash scripts/start-team.sh specs/my-feature.md"
  exit 1
fi

if [ ! -f "$SPEC_FILE" ]; then
  echo "ERROR: Spec file not found: $SPEC_FILE"
  exit 1
fi

echo ""
echo "==> Agent Team Lab"
echo "    Spec: $SPEC_FILE"
echo ""

# Ensure output directory exists
mkdir -p .claude

# Launch Claude Code with the team lead prompt
echo "==> Starting Claude Code as Team Lead..."
echo "    Claude will create the team, spawn agents, and orchestrate the workflow."
echo ""

claude --print "Launch the competing-implementor agent team for the RFP at ${SPEC_FILE}. Follow the workflow in .claude/rules/04-team-lead.md: create the team, parse the RFP, spawn both implementors in parallel with worktree isolation, wait for completion, spawn the judge, and write the final SUMMARY.md."
