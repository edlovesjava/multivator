# RFP: <Title>

> Copy this template to `specs/<slug>.md` and fill it in before running the agent team.

---

## Problem Statement

<!--
What problem are we solving? 1–3 paragraphs.
Be honest about constraints and context — agents will read this.
-->

## Requirements

### Must Have
- [ ] ...
- [ ] ...

### Should Have
- [ ] ...

### Must Not
- [ ] ...

## Evaluation Priorities

<!--
Rank these to reflect what actually matters for this problem.
The Team Lead will use these to set judge scoring weights.
-->

- [ ] **Operational simplicity** — easy to run, debug, and operate in production
- [ ] **Performance** — specific throughput/latency targets if known
- [ ] **Maintainability** — new engineers can understand and modify it
- [ ] **Innovation** — open to approaches we haven't considered
- [ ] **Test confidence** — high coverage, regression-safe
- [ ] **Minimal footprint** — few dependencies, small surface area

## Open Design Decisions

<!--
List the decisions you are deliberately leaving open for implementors to resolve.
These are where the interesting divergence will happen.
-->

1. ...
2. ...

## Constraints

### Hard Constraints (non-negotiable)
- Language/runtime: Node.js / TypeScript
- Must integrate with: ...
- Cannot use: ...

### Soft Constraints (preferences, can be overridden with justification)
- Prefer: ...
- Avoid if possible: ...

## Definition of Done

<!--
How will we know it's working? Include measurable criteria where possible.
-->

- [ ] All existing tests pass
- [ ] New tests cover: ...
- [ ] Manually verified: ...

## Context

<!--
Anything else agents should know: existing architecture, prior attempts, why
previous approaches failed, relevant code locations in the repo.
-->

### Relevant files / modules
- `src/...` — ...

### Prior art / failed approaches
- ...

### External references
- ...
