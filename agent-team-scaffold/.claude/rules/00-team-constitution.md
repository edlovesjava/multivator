# Agent Team Constitution

## Team Topology

This project runs a **competing implementors + judge** agent team using Claude Code's native team tooling.

| Role | Identity | Isolation |
|---|---|---|
| Team Lead | Orchestrates, decomposes tasks, assigns work | Main session (no isolation) |
| Implementor A | Conservative implementation | `isolation: "worktree"` |
| Implementor B | Aggressive/experimental implementation | `isolation: "worktree"` |
| Judge | Evaluates both, synthesizes verdict | No isolation (reads both worktrees) |

## Communication Protocol

Agents communicate using Claude Code's built-in tools:

- **SendMessage** — send a message to another agent by name
- **TaskCreate** — create a new task in the shared task list
- **TaskUpdate** — update task status, assign owners
- **TaskList** — view all tasks and their status

Agents are addressed by their **name** parameter set at spawn time:
- `"implementor-a"`
- `"implementor-b"`
- `"judge"`

The Team Lead is the main session and receives messages automatically.

## Task Tracking

Tasks are managed via `TaskCreate`/`TaskUpdate`/`TaskList` with the team's shared task list. Each task has:
- A title and description
- A status: `not_started`, `in_progress`, `completed`
- An owner (agent name)

## Golden Rules

1. **Implementors never see each other's worktrees** until the judge phase.
2. **All agents write tests** for their implementations.
3. **The judge is the only agent that recommends a merge path.**
4. **No agent force-pushes** to `main` or `master`.
5. **Disagreement is a feature**, not a bug. Implementors should make genuinely different choices.
