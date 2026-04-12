# Claude Agent Team Lab

This project runs a **competing implementors + judge** agent team for RFP-driven development using Claude Code's native TeamCreate/Agent tooling.

## Quick Start

1. Copy the RFP template and fill it in:
   ```bash
   cp specs/RFP-TEMPLATE.md specs/my-feature.md
   # edit specs/my-feature.md
   ```

2. In Claude Code, run:
   ```
   Launch the agent team for specs/my-feature.md
   ```

   Claude Code (acting as Team Lead) will:
   - Create a team with `TeamCreate`
   - Create tasks with `TaskCreate`
   - Spawn Implementor A and B as agents with `isolation: "worktree"`
   - Spawn a Judge agent after both implementors complete
   - Collect the verdict and write SUMMARY.md

## How It Works

```
specs/my-feature.md (RFP)
        |
        v
   Team Lead (your Claude Code session)
        |        uses TeamCreate, TaskCreate, Agent
   +----+----+
   v         v
 Impl A    Impl B       <- isolated worktrees via Agent(isolation: "worktree")
(conservative)  (experimental)
   |         |
   +----+----+
        v
      Judge              <- spawned after both complete, reads both worktrees
        |
        v
  VERDICT.md + SUMMARY.md
```

## Agent Roles

| Role | Philosophy | Agent Type |
|---|---|---|
| **Team Lead** | Orchestrates, decomposes, assigns | Your main Claude Code session |
| **Implementor A** | Minimal deps, explicit code, defensive patterns, strict TypeScript | `Agent(isolation: "worktree", team_name: ...)` |
| **Implementor B** | Performance-first, modern patterns, experimental approaches | `Agent(isolation: "worktree", team_name: ...)` |
| **Judge** | Scores against RFP weights, can recommend synthesis | `Agent(team_name: ...)` |

## Communication

Agents communicate via Claude Code's built-in tools:
- **SendMessage** — direct messages between agents
- **TaskCreate/TaskUpdate/TaskList** — shared task tracking
- Agents are addressed by **name** (e.g., `"implementor-a"`, `"judge"`)

## Key Output Files

| Path | Purpose |
|---|---|
| `specs/` | RFP input files |
| `VERDICT.md` | Judge output with scores and decision |
| `SUMMARY.md` | Team Lead final report |

Each implementor's worktree contains a `bid/` directory with:
- `APPROACH.md` — their design rationale
- `SELF-REVIEW.md` — honest self-assessment
- Source code and tests
- Additional artifacts as required by the RFP

## Reading the Results

```bash
cat SUMMARY.md    # Plain English outcome
cat VERDICT.md    # Full scored breakdown
```

## Merging a Result

The judge's VERDICT.md contains the decision (PICK A, PICK B, SYNTHESIZE, or REJECT BOTH) and the worktree paths/branches to merge from.

## Cleanup

The Team Lead calls `TeamDelete` when work is complete, which removes the team and task directories. Agent worktrees with changes are preserved for merging.
