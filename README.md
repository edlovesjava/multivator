# Multivator

A framework for running competing AI architecture tracks in parallel, with an impartial AI judge scoring the results. Two Claude Code agents work in isolated git worktrees from the same RFP specification — one conservative, one experimental — and a judge agent evaluates both against a weighted rubric.

The entire cycle (two competing architectures, detailed analysis documents, scored evaluation, and a synthesis recommendation) completes in roughly 20 minutes.

## How It Works

```
specs/my-feature.md (RFP)
        │
        ▼
   Team Lead (your Claude Code session)
        │
   ┌────┴────┐
   ▼         ▼
 Impl A    Impl B          ← isolated worktrees
(conservative) (experimental)
   │         │
   └────┬────┘
        ▼
      Judge                 ← reads both, scores against rubric
        │
        ▼
  VERDICT.md + SUMMARY.md
```

1. **Write an RFP** — copy the template and define the problem, requirements, and evaluation weights
2. **Launch the team** — Claude Code spawns two implementor agents in isolated worktrees plus a judge
3. **Implementors work independently** — each produces an `APPROACH.md`, implementation, tests, and `SELF-REVIEW.md`
4. **Judge scores both** — evaluates on RFP fidelity, correctness, test quality, maintainability, innovation, and operational risk
5. **Verdict** — PICK A, PICK B, SYNTHESIZE, or REJECT BOTH, with a scored breakdown and merge instructions

## Quick Start

```bash
# 1. Copy and fill in the RFP template
cp agent-team-scaffold/specs/RFP-TEMPLATE.md agent-team-scaffold/specs/my-feature.md

# 2. In Claude Code, launch the team
#    "Launch the agent team for specs/my-feature.md"

# 3. Read the results
cat .claude/SUMMARY.md    # plain English outcome
cat .claude/VERDICT.md    # full scored breakdown
```

See the [agent-team-scaffold](./agent-team-scaffold) for details. Leverages [Claude Code agent teams](https://code.claude.com/docs/en/agent-teams).

## Agent Roles

| Role | Philosophy | Isolation |
|------|-----------|-----------|
| **Team Lead** | Orchestrates, decomposes, assigns | Main Claude Code session |
| **Implementor A** | Minimal deps, explicit code, defensive patterns | Isolated worktree |
| **Implementor B** | Performance-first, modern patterns, experimental | Isolated worktree |
| **Judge** | Scores against RFP weights, recommends verdict | Reads both worktrees |

The philosophical split is deliberate. Without it, two AI agents given the same prompt tend to converge on similar solutions. Explicit directives ensure genuinely different design choices, giving the judge meaningfully different approaches to compare.

## Repository Structure

```
agent-team-scaffold/       # Team scaffold and agent rules
  scripts/                 # start-team.sh, teardown-team.sh
  specs/                   # RFP template and example specs
  .claude/rules/           # Agent role definitions and team constitution
multivator-skills/         # Design docs for bidder profiles and RFP skills
claude-agent-teams-paper.md  # Detailed writeup of the framework
```

## Demo: AIoT Mesh Network

A demo for choosing between architectures for ESP32 devices cooperating in a multilayered AI-for-IoT system.

**RFP:** [mesh-swarm.md](./agent-team-scaffold/specs/mesh-swarm.md)

### Implementor A (Conservative)

- [APPROACH.md](./APPROACH.md)
- [COST-ANALYSIS.md](./COST-ANALYSIS.md)
- [INTERFACES.md](./INTERFACES.md)
- [POWER-ANALYSIS.md](./POWER-ANALYSIS.md)
- [PRIVACY-ANALYSIS.md](./PRIVACY-ANALYSIS.md)
- [SELF-REVIEW.md](./SELF-REVIEW.md)
- [TEST-STRATEGY.md](./TEST-STRATEGY.md)

### Implementor B (Experimental)

- [B-APPROACH.md](./B-APPROACH.md)
- [B-COST-ANALYSIS.md](./B-COST-ANALYSIS.md)
- [B-INTERFACES.md](./B-INTERFACES.md)
- [B-POWER-ANALYSIS.md](./B-POWER-ANALYSIS.md)
- [B-PRIVACY-ANALYSIS.md](./B-PRIVACY-ANALYSIS.md)
- [B-SELF-REVIEW.md](./B-SELF-REVIEW.md)
- [B-TEST-STRATEGY.md](./B-TEST-STRATEGY.md)

## Why This Approach

Architecture decisions are expensive — not because the final answer is expensive, but because generating and fairly evaluating multiple approaches requires parallel effort from experienced engineers. This framework addresses two common failure modes:

- **Anchoring bias** — the team commits to whatever approach the most senior engineer proposes first
- **Slow evaluation** — having multiple engineers prototype and compare takes days and is hard to keep free of groupthink

Running parallel AI tracks with structured evaluation produces results that are often better than either track alone, through forced divergence and impartial scoring.
