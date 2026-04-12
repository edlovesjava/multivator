# multivator-skills

A framework for running teams of Claude Code agents that **debate before they converge**. Instead of asking one agent to design and build something, multivator forces genuine divergence — multiple agents with different philosophies independently tackle the same problem, then a judge evaluates the competing proposals against the original spec.

The core bet: agents that are forced to commit to a point of view and defend it produce better outcomes than a single agent trying to cover all bases.

## Why Forced Divergence

When a single agent designs a system, it gravitates toward consensus with itself. Trade-offs get smoothed over. The "obvious" choice wins by default because there's no one arguing for the alternative.

Multivator fights this at every layer:

| Layer | What diverges | What it answers |
|-------|---------------|-----------------|
| **Bidder profiles** | Philosophy — conservative vs experimental vs production-hardened | "What should we build?" |
| **Competing implementations** | Specific technical choices — locked, no deviation allowed | "Which technologies/patterns?" |
| **Adversarial TDD** | Role — tester tries to break it, coder does minimum to fix, reviewer guards the design | "Does this actually work?" |

Each layer can be used independently or composed. The divergence is real because agents are **isolated** — bidders can't see each other's work, implementors are locked to their assigned choices, TDD roles can only edit their own artifacts.

## The Pipeline

```
    /rfp              Author an RFP through guided Q&A
      |
      v
    /rfp-review       Stress-test the RFP from multiple perspectives
      |
      v
    RFP spec          The contract bidders work from
      |
      v
    N Bidders          Isolated worktrees, distinct profiles
    (diverge)          Each produces a bid packet: APPROACH.md, code, tests, SELF-REVIEW.md
      |
      v
    Judge              Scores each bid independently, then compares
      |                Verdict: PICK, SYNTHESIZE, NARROW AND RE-BID, or REJECT ALL
      v
    Winning Design
      |
      v
    ADR Extraction     Identify remaining open technical choices
      |
      v
    Competing Impls    Lock each implementor to specific choices
    (diverge again)    Build working code, not proposals
      |
      v
    Judge              Scores working code + automated metrics
      |                Verdict: PICK, SYNTHESIZE, NARROW AND RE-TEST, REJECT ALL, or ESCALATE
      v
    Final Implementation
```

Not every run uses every stage. A simple problem might just need 2 bidders and a judge. A complex one might go through bidding, implementation, and adversarial TDD.

## Agent Roles

### Team Lead (your Claude Code session)

Orchestrates everything. Parses the RFP, selects bidder profiles, spawns agents, collects results, spawns the judge, writes the summary. Does not implement.

### Bidders (N independent agents, isolated worktrees)

Each bidder gets a **profile** — a composition of traits that governs their design philosophy:

```yaml
steady_eddie:
  description: "Boring technology, done well"
  traits:
    risk_tolerance: proven_only
    dependency_philosophy: minimal
    error_philosophy: fail_fast
  success_criterion: >
    A senior engineer should read this in 10 minutes and understand every decision.

mad_max:
  description: "Explore what's possible"
  traits:
    risk_tolerance: adventurous
    performance_posture: hot_path_optimized
    testing_style: property_based
  success_criterion: >
    An engineer should encounter at least one idea they hadn't considered.

nightwatch:
  description: "Production-first thinking"
  traits:
    error_philosophy: self_healing
    testing_style: chaos
    ops_posture: production_hardened
  success_criterion: >
    An SRE should feel confident it won't page them at 3am.
```

Six starter profiles ship with the framework (Steady Eddie, Mad Max, Nightwatch, Razor, Blueprint, Proof). Custom profiles can be composed from the trait catalog for domain-specific tensions.

Bidders are spawned with `isolation: "worktree"` — they cannot see each other's work. Each produces a **bid packet** under `bid/` in their worktree with standardized file names. No `B-` prefixes, no naming hacks. Isolation comes from the worktree, not conventions.

### Judge

Reads all bid packets after bidders complete. Scores each independently against the RFP's evaluation priorities, then compares:

- **PICK** — one bidder is clearly best
- **SYNTHESIZE** — cherry-pick the best of each; integration path specified
- **NARROW AND RE-BID** — top candidates are close; re-run with a tightened RFP
- **REJECT ALL** — nobody adequately addressed the spec

The judge also surfaces **RFP gaps** — ambiguities that bidders resolved with contradictory assumptions, indicating the spec needs clarification.

### Adversarial TDD Sub-Team (optional, per-implementation)

Inside a single implementation, three agents share one worktree with opposed goals:

- **Tester** — writes failing tests within the spec. Owns `tests/`. Tries to break things.
- **Coder** — makes failing tests pass with the minimum change. Owns `src/`. Does nothing more.
- **Reviewer** — read-only. Guards the design. Decides when to continue, refactor, escalate, or declare done.

Three execution modes, from simplest to most sophisticated:

| Mode | How it works | Best for |
|------|-------------|----------|
| **Round-robin** | Fixed cycle: tester → coder → reviewer. Each decides whether to act or no-op. Two consecutive idle cycles = done. | Most tasks. Trivial to implement — just a loop of Agent calls. |
| **Turn-based** | Reviewer schedules each step explicitly. Formal REVIEW-LOG.md audit trail. | High-stakes, auditable work. |
| **Reactive** | Event-driven handlers. Tester probes on every code change, coder reacts to red, refactorer reshapes on quiet green. | Exploratory work where gaps surface faster with parallelism. |

## Directory Structure

```
multivator-skills/
  .claude/rules/                  # Agent role definitions
    00-team-constitution.md       # Team topology, communication, golden rules
    01-implementor-a.md           # Conservative implementor (Phase 0)
    02-implementor-b.md           # Experimental implementor (Phase 0)
    03-judge.md                   # Judge scoring rubric and verdict format
    04-team-lead.md               # Orchestration workflow
  docs/                            # Design documents and implementation plan
    DESIGN-bidder-profiles.md     # Composable N-bidder profiles, trait catalog, bid packets
    DESIGN-competing-implementations.md  # ADR extraction, locked-choice implementors
    DESIGN-adversarial-tdd.md     # Tester/coder/reviewer sub-team, three execution modes
    DESIGN-rfp-author-skill.md    # /rfp guided authoring skill
    DESIGN-rfp-review-skill.md    # /rfp-review multi-perspective review panel
    PLAN-phased-implementation.md # Six-phase build plan with test criteria
  profiles/                       # (planned) Composable bidder profile YAMLs
  scripts/
    start-team.sh                 # Launch a team run against an RFP
    teardown-team.sh              # Clean up worktrees, branches, output
  specs/
    RFP-TEMPLATE.md               # Starting point for new RFPs
    mesh-swarm.md                 # Example: AIoT mesh network RFP
    example-rate-limit-queue.md   # Example: simpler RFP for testing
  CLAUDE.md                       # Quick-start for Claude Code
```

## Quick Start

### 1. Write an RFP

Copy the template and fill it in:

```bash
cp specs/RFP-TEMPLATE.md specs/my-feature.md
# edit specs/my-feature.md
```

The RFP defines: problem statement, must/should/must-not requirements, evaluation priorities (which become judge scoring weights), open design decisions (where divergence will happen), hard and soft constraints, and definition of done.

### 2. Run the Team

```bash
bash scripts/start-team.sh specs/my-feature.md
```

This launches Claude Code as the Team Lead, which:
1. Creates the agent team
2. Parses the RFP and sets evaluation weights
3. Spawns implementors in parallel (isolated worktrees)
4. Waits for completion
5. Spawns the judge with paths to all bid packets
6. Writes the final verdict and summary

### 3. Read the Results

The judge produces `VERDICT.md` (scored breakdown with rationale) and the team lead writes `SUMMARY.md` (plain-English outcome with merge instructions).

### 4. Clean Up

```bash
bash scripts/teardown-team.sh              # remove worktrees + branches
bash scripts/teardown-team.sh --keep-branches  # keep branches for merging
```

## Design Documents

The framework is designed in layers, each documented separately:

| Document | What it covers |
|----------|----------------|
| [DESIGN-bidder-profiles.md](docs/DESIGN-bidder-profiles.md) | N-bidder system with composable trait-based profiles, bid packet structure, worktree isolation model, RFP-defined artifact requirements, judge scaling for N-way comparison |
| [DESIGN-competing-implementations.md](docs/DESIGN-competing-implementations.md) | Post-design phase: extract ADRs from the winning design, enumerate implementation permutations, lock each implementor to specific choices, evaluate working code with automated metrics |
| [DESIGN-adversarial-tdd.md](docs/DESIGN-adversarial-tdd.md) | Within-implementation divergence: tester/coder/reviewer sub-team with three execution modes (round-robin, turn-based, reactive), refactor sub-loop, escalation channels |
| [DESIGN-rfp-author-skill.md](docs/DESIGN-rfp-author-skill.md) | `/rfp` skill: guided interview that builds an RFP through seed → requirements → priorities → open decisions → constraints → definition of done → profile suggestion → assembly |
| [DESIGN-rfp-review-skill.md](docs/DESIGN-rfp-review-skill.md) | `/rfp-review` skill: four-reviewer panel (Bidder, Product Designer, QA, Reasonableness) that stress-tests an RFP before bidding opens |
| [PLAN-phased-implementation.md](docs/PLAN-phased-implementation.md) | Six-phase build plan: bid packets → N-bidder + profiles → RFP authoring → RFP review → competing implementations → harden and fill |

## Current State

**Phase 0 — Baseline** is working: a 2-bidder flow (conservative vs experimental) with a judge, demonstrated on the MeshSwarm RFP. See the [demo/](../demo/) directory for the full output.

The design documents above describe where the framework is headed. Each phase is designed to be independently valuable — if we stop after any phase, what exists still works.
