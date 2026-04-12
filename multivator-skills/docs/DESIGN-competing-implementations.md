# Design: Competing Implementations via ADR Permutation

## Status: Draft

## Problem

The RFP + bidder profiles flow produces strong *designs* — but designs are hypotheses. The bidder profiles diverge on philosophy (conservative vs adventurous, minimal vs ecosystem-rich), which produces useful breadth at the design stage. But when the winning design lands, it still contains unresolved architectural decisions: "use SQL or NoSQL," "synchronous or event-driven," "monolith or services." These decisions are best resolved by building both options and comparing working code, not by debating further.

Today, the framework's output is a design document (or synthesis). Validating that design still requires a single implementation track where the hard choices are made by one engineer (or agent) based on judgment. If that judgment is wrong, the cost surfaces late.

## Goal

Add a **competing implementations** phase that sits downstream of the RFP/bidding flow. After the design converges, extract the critical architectural decisions (ADRs) with their discrete options, enumerate the permutations worth testing, and spawn parallel implementor agents — each locked to a specific set of choices — to build competing implementations. Evaluate actual working code rather than proposals.

---

## How It Relates to the Existing Flow

```
RFP
 |
 v
Bidder Profiles (diverge on philosophy)
 |
 v
Judge → PICK / SYNTHESIZE → Winning Design
 |
 v
 +--[NEW]-- Decision Extraction
 |              |
 |              v
 |          ADR Options Matrix
 |              |
 |              v
 |          Permutation Selection
 |              |
 |              v
 |          Competing Implementations (diverge on specific choices)
 |              |
 |              v
 |          Evaluation (tests, benchmarks, metrics)
 |              |
 |              v
 |          Implementation Verdict
 v
Final Implementation
```

The bidding phase answers *"what should we build?"* — philosophy-level divergence on architecture, patterns, and priorities.

The competing implementations phase answers *"how should we build it?"* — choice-level divergence on specific technologies, data models, protocols, and patterns within an agreed-upon design.

These are complementary, not redundant. You can also skip the bidding phase entirely and go straight to competing implementations when the design is already settled but the implementation choices aren't.

---

## Decision Extraction

After the design phase produces a winner (or synthesis), the Team Lead (or a dedicated **Architect** agent) reads the design and extracts the critical decision points — the places where the design says "we need X" but doesn't specify *which* X.

### What counts as an extractable decision

A decision is worth extracting when:
1. **There are discrete, enumerable options** — not a continuous spectrum. "SQL vs NoSQL vs graph" is extractable. "How much caching" is not.
2. **The choice is structurally significant** — it affects the shape of the code, not just a config flag. Database engine choice changes schema design, query patterns, deployment. Log level does not.
3. **Reasonable engineers would disagree** — if there's an obvious right answer, it's not a real decision.
4. **The options are independently implementable** — you can build a working system with any of the choices. If option B requires option A as a prerequisite, they're not independent.

### ADR format

Each extracted decision follows a lightweight ADR (Architecture Decision Record) format:

```yaml
decisions:
  - id: ADR-001
    title: "Data storage engine"
    context: >
      The design requires persistent state for user sessions and device registry.
      Read-heavy workload, ~10k records, queried by multiple keys.
    options:
      - id: sqlite
        label: "SQLite"
        description: "Embedded, zero-config, proven. Single-writer limitation."
      - id: dynamodb
        label: "DynamoDB"
        description: "Managed, scales horizontally. Requires AWS. Query patterns constrained by key design."
      - id: redis
        label: "Redis with persistence"
        description: "Fast, flexible data structures. Requires separate process. Durability trade-offs."
    constraints:
      - "Must support concurrent reads from multiple processes"
    evaluation_criteria:
      - "Query latency under load"
      - "Operational complexity"
      - "Data integrity guarantees"

  - id: ADR-002
    title: "Inter-service communication"
    options:
      - id: rest
        label: "REST/HTTP"
        description: "Synchronous, well-understood, easy to debug."
      - id: grpc
        label: "gRPC"
        description: "Binary protocol, code-gen, streaming. Steeper tooling curve."
      - id: events
        label: "Event-driven (NATS/SQS)"
        description: "Async, decoupled. Eventually consistent. Harder to trace."
    constraints:
      - "Must support request-reply for user-facing operations"
    evaluation_criteria:
      - "Latency p99"
      - "Debuggability"
      - "Failure mode complexity"
```

### Extraction can be automated or manual

- **Automated**: The Team Lead reads the winning design's `APPROACH.md` and the judge's `VERDICT.md`, identifies where the design uses phrases like "we recommend X but Y is viable," "this choice depends on," or "open question," and proposes an ADR matrix.
- **Manual**: The user specifies the decisions and options directly. ("I want to compare SQLite vs Postgres for this, and REST vs gRPC for the API layer.")
- **Hybrid**: The system proposes, the user edits.

---

## Permutation Selection

With K decisions and each having Nk options, the full permutation space is N1 x N2 x ... x NK. This blows up fast:

| Decisions | Options each | Permutations |
|-----------|-------------|--------------|
| 2         | 2           | 4            |
| 2         | 3           | 9            |
| 3         | 2           | 8            |
| 3         | 3           | 27           |
| 4         | 3           | 81           |

Running 27+ competing implementations is wasteful. We need strategies to prune.

### Pruning strategies

**Incompatible combinations**: Some option pairs are structurally incompatible or nonsensical. Mark these as exclusions:
```yaml
exclusions:
  - [ADR-001:sqlite, ADR-003:multi_region]  # SQLite can't do multi-region
```

**Orthogonal testing (fractional factorial)**: When decisions are mostly independent, you don't need full coverage. A fractional factorial design tests each option against a representative mix of others. For 3 decisions with 3 options each, instead of 27 permutations, 9 carefully chosen combinations can cover all pairwise interactions.

**Corner cases only**: Pick the most divergent combinations — the extremes of the decision space. If you're choosing between {simple, moderate, complex} on two axes, test {simple+simple, simple+complex, complex+simple, complex+complex}. Skip the middle.

**User-directed**: The user picks the 3-5 combinations they care about. Most practical for domain experts who know which combinations are interesting.

### Recommended limits

| Permutations | Action |
|-------------|--------|
| 2-4         | Run all |
| 5-8         | Run all if compute budget allows, otherwise prune |
| 9-16        | Use fractional factorial or corner cases |
| 17+         | Mandatory pruning — user selects or system uses fractional factorial |

---

## Implementor Agents

Each implementor agent receives:

1. **The winning design** — the full `APPROACH.md` / synthesis from the bidding phase (or the design doc if bidding was skipped)
2. **The ADR matrix** — all decisions with all options, so they understand the full landscape
3. **Their assigned choices** — the specific option for each decision they must implement
4. **A lock directive** — they must implement their assigned choices, not deviate

### Lock directive

```markdown
## Your Assigned Choices

You MUST implement the following specific options. These are not suggestions —
they are your assignment. Do not substitute alternatives, even if you believe
a different choice would be better. The purpose of this exercise is to evaluate
these specific combinations against each other.

- **ADR-001 (Data storage)**: SQLite
- **ADR-002 (Communication)**: gRPC
- **ADR-003 (Auth)**: JWT with refresh tokens

If an assigned choice creates a genuine technical impossibility (not just
inconvenience), document the blocker in BLOCKERS.md and notify the Team Lead.
Do not silently switch to an alternative.
```

### What differs from bidder profiles

| Aspect | Bidder Profiles | Competing Implementations |
|--------|----------------|--------------------------|
| **Divergence axis** | Philosophy / values | Specific technical choices |
| **Agent freedom** | High — profile guides but doesn't dictate | Low — choices are locked |
| **Output** | Design documents + analysis | Working code + tests |
| **Evaluation** | Judge reads proposals | Automated metrics + judge reads code |
| **When used** | Before design is settled | After design, before implementation |
| **What it answers** | "What should we build?" | "Which specific technologies/patterns?" |

### Implementor template

```markdown
# Implementor: {{permutation_id}} — {{permutation_summary}}

## Identity

You are implementing permutation **{{permutation_id}}** of the agreed design.
You work in an isolated git worktree.

## The Design

{{winning_design_content}}

## Your Assigned Choices

{{#each assigned_choices}}
- **{{decision.title}}**: {{option.label}} — {{option.description}}
{{/each}}

## Lock Directive

You MUST use the assigned options above. Do not substitute alternatives.
If a choice creates a genuine impossibility, document it in BLOCKERS.md.

## Workflow

1. Read the design and your assigned choices.
2. Write `APPROACH.md` — explain how you'll implement the design
   with your specific choices. Note any interesting interactions
   between your assigned options.
3. Implement working code.
4. Write tests — focus on the areas where your choices create
   distinctive behavior.
5. Write `METRICS.md` — capture measurable outcomes:
   - Lines of code
   - Number of dependencies
   - Test count and coverage
   - Build time
   - Any benchmarks you can run
6. Write `SELF-REVIEW.md` — where does this combination shine?
   Where does it struggle? What surprised you?
7. Mark complete and notify the Team Lead.
```

---

## Evaluation

This is where competing implementations differ most from the bidding phase. Because the output is working code, evaluation can be partially automated.

### Automated metrics (collected by Team Lead or a Metrics agent)

```yaml
metrics:
  build:
    - build_succeeds: bool
    - build_time_ms: number
    - dependency_count: number
    - binary_size_bytes: number

  tests:
    - all_tests_pass: bool
    - test_count: number
    - coverage_percent: number

  code:
    - lines_of_code: number
    - file_count: number
    - cyclomatic_complexity: number  # if tooling available

  performance:  # if benchmarks defined
    - throughput_rps: number
    - latency_p50_ms: number
    - latency_p99_ms: number
    - memory_peak_mb: number
```

### Judge evaluation (same judge role, adapted rubric)

The judge still reads code and writes a verdict, but the rubric shifts from design quality to implementation quality:

| Axis | Description |
|------|-------------|
| **Functional completeness** | Does it implement the full design? Any gaps? |
| **Code quality** | Readable, idiomatic, well-structured? |
| **Test quality** | Do the tests actually validate the interesting behavior? |
| **Choice fitness** | How well do the assigned choices serve the design? Friction or synergy? |
| **Operational readiness** | Could you deploy this? Error handling, logging, config? |
| **Surprise factor** | Did this combination reveal something unexpected — good or bad? |

### Verdict options (extended)

| Verdict | Meaning |
|---------|---------|
| `PICK <permutation_id>` | One combination is clearly best |
| `SYNTHESIZE <ids>` | Take specific choices from different permutations |
| `NARROW AND RE-TEST` | Two combinations are close; define additional tests to differentiate |
| `REJECT ALL` | No combination works; the design may need revision |
| `ESCALATE` | The results reveal that a design assumption was wrong; go back to the bidding phase |

`ESCALATE` is new — if every combination of, say, database choice struggles with the same query pattern, the problem might be in the data model (a design issue), not the storage engine (an implementation choice).

---

## Orchestration

### Team Lead workflow

```
1. Receive winning design from bidding phase (or from user)
2. Extract decisions → ADR matrix
3. Present ADR matrix to user for review
4. Generate permutations (apply pruning)
5. Present permutations to user for approval + cost estimate
6. Spawn N implementor agents in parallel (isolation: "worktree")
7. Collect results
8. Run automated metrics collection
9. Spawn judge with all worktree paths + metrics
10. Report verdict
```

### Cost control

Each implementation is a full agent run. With N permutations:

```
Estimated cost = N × (avg_tokens_per_implementation) × token_price
```

The Team Lead should present this estimate before spawning:

```markdown
## Implementation Plan

ADR-001 (Storage): SQLite, Postgres, DynamoDB
ADR-002 (API): REST, gRPC

Permutations after pruning: 5 (excluded: SQLite+multi-region)

Estimated compute: ~5 agent runs
Estimated time: ~15-30 min (parallel)

Proceed? [y/n]
```

---

## Interaction with Bidder Profiles

The two mechanisms compose naturally:

**Phase 1 — Bidding (profiles)**: Diverge on philosophy. "Steady Eddie" proposes a conservative design, "Mad Max" proposes an aggressive one. The judge picks or synthesizes.

**Phase 2 — Implementation (ADR permutations)**: Take the winning design. Extract the remaining open choices. Build 3-5 competing implementations with locked options. Evaluate working code.

You can also skip Phase 1 when:
- The design is already decided (e.g., migrating an existing system)
- There's only one reasonable architecture but multiple valid implementation choices
- The user brings a design doc directly

And skip Phase 2 when:
- The design has no genuinely open implementation choices
- The winning bid was specific enough to implement directly
- Time/budget doesn't justify multiple implementations

---

## Example: End-to-End

### Starting point
The MeshSwarm RFP bidding produced a SYNTHESIZE verdict: use A's networking + B's event system.

### Decision extraction
The synthesized design still has open choices:

```yaml
decisions:
  - id: ADR-001
    title: "Event store backend"
    options:
      - id: append_log
        label: "Append-only log file"
        description: "Simple, no dependencies. Compaction needed."
      - id: sqlite_wal
        label: "SQLite in WAL mode"
        description: "ACID, queryable. Heavier for embedded."
      - id: ring_buffer
        label: "In-memory ring buffer with periodic snapshot"
        description: "Fastest. Loses events on crash between snapshots."

  - id: ADR-002
    title: "Policy propagation protocol"
    options:
      - id: pull
        label: "Edge nodes poll hub on interval"
        description: "Simple, predictable load. Delayed propagation."
      - id: push
        label: "Hub pushes to edges on change"
        description: "Immediate propagation. Hub must track edge state."
      - id: gossip
        label: "Gossip protocol between edges"
        description: "No hub bottleneck. Eventually consistent. Complex."
```

### Permutations (after pruning)
```
P1: append_log + pull      (simplest possible)
P2: sqlite_wal + push      (structured + responsive)
P3: ring_buffer + push     (fastest + responsive)
P4: sqlite_wal + gossip    (structured + decentralized)
```

Excluded: `ring_buffer + gossip` (too much eventual consistency risk for a security system).

### Spawn 4 implementors
Each builds the same synthesized design but with their locked choices. All produce working code, tests, and metrics.

### Evaluation
- Automated: P3 has lowest latency, P1 has fewest LOC, P2 and P4 have best test coverage
- Judge: P2 (SQLite + push) is the best balance — queryable event history for debugging, immediate policy propagation for security responsiveness, acceptable overhead for the ESP32-S3 hub

### Verdict
`PICK P2` with a note: "Adopt P3's ring buffer as a secondary fast path for leaf-to-edge events where crash loss is acceptable."

---

## Open Questions

1. **How deep should implementations go?** Full working code? Skeleton with critical paths implemented? The depth determines cost and evaluation fidelity. Too shallow and you're back to comparing designs. Too deep and you're burning compute on code that gets thrown away.

2. **Shared scaffolding?** Should all permutations start from a common code skeleton (generated from the winning design) with only the decision-affected code varying? This reduces waste but risks anchoring implementations on one structure.

3. **Decision dependencies?** Some choices interact — the database choice affects the API layer's query patterns. Should the ADR matrix capture these interactions explicitly, or let the implementors discover them?

4. **Re-running subsets?** If the judge says `NARROW AND RE-TEST`, do we re-run from scratch or give the narrowed implementations the previous round's feedback?

5. **Integration with CI?** If the project has CI, should the competing implementations run through the real pipeline? This adds evaluation signal but requires each permutation to have a valid build/test setup.

---

## Migration Path

1. Add decision extraction as a Team Lead capability (prompt addition to `04-team-lead.md`)
2. Build the implementor template for locked-choice agents
3. Add automated metrics collection (can be a lightweight script or agent)
4. Extend the judge rubric for implementation-level evaluation
5. Update `00-team-constitution.md` to document the two-phase flow
6. Add a `/implement` skill that takes a design + ADR matrix and runs the competing implementations phase
