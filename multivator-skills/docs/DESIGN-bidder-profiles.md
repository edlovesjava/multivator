# Design: Composable Bidder Profiles

## Status: Draft

## Problem

The current system hardcodes two implementors with fixed personas (conservative vs aggressive). This limits divergence to a single axis and caps the number of competing proposals at two. Real RFPs benefit from more than two perspectives, and the axes of divergence that matter vary by problem domain.

## Goal

Extend the framework to support N bidders, each assigned a distinct **profile** composed from a catalog of **traits**. Maximize meaningful divergence across proposals while keeping the system predictable and the judge's job tractable.

Additionally, enforce true isolation between bidders and formalize the **bid packet** — the self-contained bundle of work products each bidder produces.

---

## Lesson from the POC

In our first run, both implementors wrote to the shared root filesystem (`APPROACH.md`, `B-APPROACH.md`, etc. side by side). This meant:
- Bidders could read each other's in-progress work, undermining independent thinking
- Output files needed naming conventions (the `B-` prefix) to avoid collisions
- There was no clean boundary defining "what a bidder produced"

The worktree isolation was _specified_ in the rules but not _enforced_ by the output structure. The fix is twofold: enforce worktree isolation at spawn time, and define a standard **bid packet** that each bidder produces entirely within their own worktree.

---

## Bid Packets

A **bid** is the complete, self-contained bundle of work products a bidder delivers. Each bid lives entirely within the bidder's isolated worktree — no writing to shared paths, no awareness of other bidders' output.

### Bid structure

```
<worktree-root>/
  bid/
    APPROACH.md          # Always required — design rationale
    SELF-REVIEW.md       # Always required — honest self-assessment
    ...                  # Additional artifacts as declared by the RFP
    src/                 # Implementation code
    tests/               # Test suite
```

The specific artifacts beyond `APPROACH.md` and `SELF-REVIEW.md` are defined by the RFP's `Required Bid Artifacts` section (see RFP-Defined Bid Requirements below).

### Bid rules

1. **All bid output goes under `bid/`** in the bidder's worktree. No writing outside this directory.
2. **No `B-` prefixes or bidder-specific naming.** Every bidder uses the same file names. Isolation comes from the worktree, not from naming conventions.
3. **The bid is the unit of evaluation.** The judge receives paths to N `bid/` directories. Everything needed to evaluate the proposal must be inside.
4. **Bids are immutable once submitted.** When a bidder marks their task complete, their bid is frozen. No late edits.

### What the judge receives

```yaml
bids:
  - bidder: "the_pragmatist"
    path: "/tmp/worktree-abc123/bid/"
  - bidder: "the_innovator"
    path: "/tmp/worktree-def456/bid/"
  - bidder: "the_operator"
    path: "/tmp/worktree-ghi789/bid/"
```

The judge reads each `bid/` directory independently, scores against the rubric, then compares.

---

## Isolation Model

### During bidding

```
Main workspace (Team Lead + Judge)
    |
    +-- worktree-a/  (Bidder A only — no visibility into B or C)
    |     +-- bid/
    |
    +-- worktree-b/  (Bidder B only — no visibility into A or C)
    |     +-- bid/
    |
    +-- worktree-c/  (Bidder C only — no visibility into A or B)
          +-- bid/
```

- Each bidder is spawned with `isolation: "worktree"`, creating a separate git worktree
- The bidder's prompt contains **only** the RFP spec and their profile — no references to other bidders' worktree paths
- Bidders communicate only with the Team Lead (to ask clarifying questions or report completion), never with each other
- The shared task list shows task status but **not** other bidders' work products

### After bidding

- The Team Lead collects all worktree paths from the Agent results
- The Judge is spawned with read access to all `bid/` directories
- Only after the verdict is written does anyone (Team Lead, user) see all bids together

### Why this matters

Isolation isn't just a nice-to-have — it's what makes the divergence real. If bidders can see each other's work:
- They unconsciously anchor on each other's choices
- "Different" approaches converge toward a consensus middle
- The judge ends up comparing variations on a theme instead of genuinely distinct proposals

The value of N bidders comes from N independent explorations of the solution space. Leaking information between them collapses that space.

---

## Trait Catalog

A **trait** is an independent axis of design philosophy. Each trait has a spectrum of named positions. Not every trait needs to be specified in every profile — unspecified traits are left to the bidder's judgment.

| Trait | Positions | What it governs |
|-------|-----------|-----------------|
| `risk_tolerance` | `proven_only` / `cautious` / `pragmatic` / `adventurous` / `bleeding_edge` | Willingness to use new tech, unproven patterns, novel architectures |
| `dependency_philosophy` | `stdlib_purist` / `minimal` / `pragmatic` / `best_tool` / `ecosystem_maximalist` | How freely the bidder pulls in external packages |
| `abstraction_style` | `concrete` / `explicit` / `balanced` / `DRY` / `framework_builder` | Preference for inline clarity vs reusable abstractions |
| `performance_posture` | `correctness_first` / `balanced` / `hot_path_optimized` / `benchmark_driven` | Where performance sits relative to other concerns |
| `api_surface` | `minimal` / `narrow` / `balanced` / `ergonomic` / `kitchen_sink` | How much interface to expose |
| `scaling_model` | `single_process` / `vertical` / `balanced` / `horizontal` / `fully_distributed` | Assumptions about deployment topology |
| `error_philosophy` | `fail_fast` / `defensive` / `balanced` / `resilient` / `self_healing` | How the system handles failure |
| `testing_style` | `unit_focused` / `integration_heavy` / `property_based` / `chaos` / `formal` | What kinds of tests the bidder writes |
| `ops_posture` | `dev_simplicity` / `log_and_hope` / `balanced` / `observable` / `production_hardened` | Investment in monitoring, alerting, runbooks |
| `cost_sensitivity` | `ignore` / `aware` / `optimized` / `frugal` / `penny_pinching` | How aggressively the bidder optimizes for cost |

### Extending the catalog

New traits can be added as the framework encounters new problem domains. A trait is worth adding when:
- It represents a genuine design tension (not just good/bad)
- Different positions lead to structurally different implementations
- The RFP's open questions touch on it

---

## Profile Catalog

A **profile** is a named composition of trait positions plus a **success criterion** (one sentence describing what "good" looks like from this bidder's perspective). Profiles should be opinionated enough to force real divergence but coherent enough to produce a sound proposal.

### Starter profiles

```yaml
steady_eddie:
  name: "Steady Eddie"
  description: "Boring technology, done well"
  traits:
    risk_tolerance: proven_only
    dependency_philosophy: minimal
    abstraction_style: explicit
    error_philosophy: fail_fast
    testing_style: unit_focused
    ops_posture: balanced
  success_criterion: >
    A senior engineer should read this in 10 minutes and understand every decision.

mad_max:
  name: "Mad Max"
  description: "Explore what's possible"
  traits:
    risk_tolerance: adventurous
    dependency_philosophy: best_tool
    abstraction_style: DRY
    performance_posture: hot_path_optimized
    testing_style: property_based
  success_criterion: >
    An engineer should encounter at least one idea they hadn't considered.

nightwatch:
  name: "Nightwatch"
  description: "Production-first thinking"
  traits:
    risk_tolerance: cautious
    error_philosophy: self_healing
    testing_style: chaos
    ops_posture: production_hardened
    scaling_model: horizontal
  success_criterion: >
    An SRE should look at this and feel confident it won't page them at 3am.

razor:
  name: "Razor"
  description: "Smallest possible footprint"
  traits:
    dependency_philosophy: stdlib_purist
    abstraction_style: concrete
    api_surface: minimal
    cost_sensitivity: penny_pinching
    scaling_model: single_process
  success_criterion: >
    The entire system should be understandable from a single file and deployable with a single command.

blueprint:
  name: "Blueprint"
  description: "Design for the next five years"
  traits:
    risk_tolerance: pragmatic
    abstraction_style: framework_builder
    api_surface: ergonomic
    scaling_model: fully_distributed
    ops_posture: observable
  success_criterion: >
    The system should gracefully accommodate requirements that haven't been written yet.

proof:
  name: "Proof"
  description: "Correctness above all else"
  traits:
    risk_tolerance: cautious
    performance_posture: correctness_first
    error_philosophy: fail_fast
    testing_style: formal
    abstraction_style: explicit
  success_criterion: >
    It should be possible to reason about this system's behavior from its types and contracts alone.
```

### Custom profiles

The RFP author or team lead can compose ad-hoc profiles by specifying traits directly. This is useful when the RFP has a domain-specific tension (e.g., privacy vs UX, cost vs latency) that the starter profiles don't capture.

---

## Profile Selection

### How many bidders?

| RFP complexity | Open design questions | Recommended bidders |
|---------------|----------------------|-------------------|
| Narrow/tactical | 1-2 | 2 |
| Moderate | 3-4 | 3 |
| Architectural | 5+ | 3-4 |
| Exploratory/research | unbounded | 4-5 |

More than 5 bidders likely hits diminishing returns — the judge's comparison overhead grows faster than the solution-space coverage.

### Selection strategies

**Manual** — The RFP author names the profiles they want:
```yaml
bidders:
  - the_pragmatist
  - the_innovator
  - the_operator
```

**Auto-divergent** — The team lead reads the RFP's open questions, identifies which traits they stress, and selects profiles that maximize distance along those traits. For example, an RFP with open questions about scaling and failure modes would get profiles that diverge on `scaling_model` and `error_philosophy`.

**Hybrid** — The RFP author specifies one or two profiles and says "fill the rest for maximum divergence." The team lead picks complementary profiles.

---

## Prompt Generation

Currently, each implementor has a static rule file (`01-implementor-a.md`, `02-implementor-b.md`). With N bidders, we replace these with a single **implementor template** that gets filled from the profile.

### Template structure

```markdown
# Implementor: {{name}} — "{{profile.description}}"

## Identity

You are **{{name}}**. You work in an isolated git worktree.

## Philosophy

{{#each profile.traits}}
- **{{trait_name}}**: {{position_description}}
{{/each}}

## Success Criterion

{{profile.success_criterion}}

## Differentiation Directive

You are one of {{n}} bidders. Your profile emphasizes: {{profile.description}}.
Other bidders exist with different philosophies. Do NOT try to cover all bases.
Lean into your profile's strengths. A proposal that tries to be everything
is worse than one that commits fully to a coherent point of view.

## Workflow

1. Read the RFP spec.
2. Write `APPROACH.md` — your design rationale, grounded in your profile's values.
3. Implement in your worktree.
4. Write tests consistent with your testing style.
5. Write `SELF-REVIEW.md` — honestly assess your trade-offs and where other
   approaches might beat yours.
6. Mark complete and notify the Team Lead.
```

### What changes in the rules directory

```
.claude/rules/
  00-team-constitution.md    # updated: N bidders, dynamic profiles
  01-implementor-template.md # NEW: replaces per-implementor rules
  02-judge.md                # updated: N-way comparison
  03-team-lead.md            # updated: profile selection, N spawns
```

---

## RFP-Defined Bid Requirements

The RFP is the source of truth for what a bid must contain. The bid packet structure isn't hardcoded in the framework — it's declared by each RFP.

### RFP artifact declaration

Each RFP includes a `## Required Bid Artifacts` section:

```yaml
required_artifacts:
  - APPROACH.md          # Always required — design rationale
  - SELF-REVIEW.md       # Always required — honest self-assessment
  - INTERFACES.md        # API contracts
  - COST-ANALYSIS.md     # Cost breakdown
  - THREAT-MODEL.md      # Security analysis (domain-specific)

optional_artifacts:
  - MIGRATION-PLAN.md
  - POWER-ANALYSIS.md
  - PRIVACY-ANALYSIS.md
```

The framework enforces a minimal baseline (`APPROACH.md` + `SELF-REVIEW.md` are always required), but beyond that the RFP author decides what the bid must contain. The judge scores completeness against these declared requirements — a bid missing a required artifact is penalized.

Bidders may include additional materials beyond what's required. A bidder who volunteers a `THREAT-MODEL.md` when it wasn't asked for is demonstrating initiative, not violating scope — and the judge can credit that.

---

## RFP Versioning and Clarifications

### Principle: the RFP stands on its own

The RFP document should contain everything a bidder needs to produce a proposal. Clarifications during the bidding process are limited to **interpretation of what's already in the RFP** — no new requirements, no scope changes, no moving goalposts.

### Assumptions and caveats in bids

When a bidder encounters ambiguity or insufficient information in the RFP, they don't block — they proceed with documented assumptions:

```markdown
## Assumptions (in APPROACH.md)

- **A1**: RFP says "low latency" — we interpret this as p99 < 50ms
  based on the stated IoT context.
- **A2**: RFP doesn't specify auth mechanism — we assume mTLS
  between mesh nodes based on the security requirements in §3.
- **A3**: "Scale" is unquantified — we design for 500 nodes based
  on the "smart home" framing, not campus/industrial scale.
```

Each assumption is:
- **Labeled** (A1, A2...) so the judge can reference them
- **Grounded** in the RFP text where possible
- **Scoped** to a specific design decision

### Judge's role in surfacing RFP gaps

When the judge evaluates bids, they explicitly check:
1. Did different bidders make **contradictory assumptions** about the same ambiguity?
2. Did any assumption lead to a **fundamentally different architecture** that wouldn't survive if the assumption were wrong?
3. Are there ambiguities that **every bidder struggled with**?

These go into a new section of the verdict:

```markdown
## RFP Gaps Identified

| Gap | Bidders affected | Assumptions made | Impact |
|-----|-----------------|------------------|--------|
| Latency target unspecified | All | A: <50ms, B: <200ms, C: <1s | Architecturally divergent — A built real-time, C built batch |
| Auth mechanism undefined | A, B | Both assumed mTLS | Low — converged independently |
| Node count/scale unclear | All | Range: 50 to 10,000 | High — drives cost and topology |

## Recommendation
Issue RFP v1.1 clarifying: latency target, expected node count.
Re-bid with the_pragmatist and the_operator only (narrowed field).
```

### RFP versioning

When the judge (or Team Lead) determines that ambiguities are significant enough to invalidate the comparison, the RFP gets versioned:

```
specs/
  mesh-swarm-v1.0.md    # Original
  mesh-swarm-v1.1.md    # Clarifications from round 1
```

Version changes are strictly additive clarifications or constraint tightening — the problem statement doesn't change. The changelog is inline:

```markdown
## Changelog
- **v1.1** (post round 1): Clarified latency target as p99 < 100ms.
  Added node scale: 200-500 nodes. Auth: mTLS required between tiers.
  No new requirements — all clarifications of existing sections.
```

### The re-bid cycle

```
RFP v1.0 → N bidders → Judge → Gaps identified
                                    |
                          RFP v1.1 (clarifications only)
                                    |
                         Narrowed bidders → Judge → Verdict
```

Re-bids use the `NARROW AND RE-BID` verdict. The Team Lead:
1. Versions the RFP with clarifications
2. Selects a narrowed set of profiles (informed by round 1)
3. Spawns fresh bidders — they see the updated RFP but **not** round 1 bids
4. The judge evaluates the new bids on their own merit

This mirrors real procurement: round 1 surfaces what the RFP author didn't know they needed to specify, round 2 gets sharper bids against a tighter spec.

---

## Judge Scaling

With 2 bidders, the judge does a single pairwise comparison. With N:

### Scoring phase (unchanged)
Score each bidder independently against the rubric. This scales linearly.

### Comparison phase (new)
After scoring, the judge:
1. Ranks bidders by weighted total
2. Does pairwise deep-comparison of the top 2-3
3. Considers synthesis across any subset, not just all-or-nothing

### Verdict options (extended)

| Verdict | Meaning |
|---------|---------|
| `PICK <name>` | One bidder is clearly best |
| `SYNTHESIZE <names>` | Cherry-pick from named subset; integration path specified |
| `NARROW AND RE-BID` | Top 2-3 are close; re-run with refined RFP constraints |
| `REJECT ALL` | No bidder adequately addresses the RFP |

`NARROW AND RE-BID` is new — with more bidders, the first round might surface insights that tighten the requirements, making a focused second round more valuable than forcing a pick.

---

## Team Lead Changes

The team lead's workflow becomes:

1. **Parse RFP** — identify open questions and stated priorities
2. **Select profiles** — manual, auto-divergent, or hybrid
3. **Generate implementor prompts** — fill template from each profile
4. **Spawn N agents in parallel** — each with `isolation: "worktree"`
5. **Collect results** — wait for all N to complete
6. **Spawn judge** — pass all N worktree paths
7. **Report** — write SUMMARY.md with verdict and merge instructions

---

## Open Questions

1. **Trait interactions** — Some trait combinations are incoherent (e.g., `stdlib_purist` + `ecosystem_maximalist`). Do we validate profiles for coherence, or trust the author?

2. **Domain-specific traits** — Some RFPs have tensions specific to their domain (privacy vs personalization, latency vs cost). Should the trait catalog support ephemeral per-RFP traits, or should those be handled in the RFP's open questions?

3. **Profile evolution** — As we run more RFPs, we'll learn which profiles produce useful divergence and which don't. How do we capture that? A scoring history per profile?

4. **Re-bidding mechanics** — If the judge says `NARROW AND RE-BID`, what does the second round look like? Same profiles with tighter constraints? New profiles informed by round 1?

5. **Cost control** — N bidders means N times the compute. Should the team lead estimate cost before spawning and confirm with the user?

6. **Bid packet extensibility** — Resolved: the RFP defines minimum required artifacts (see RFP-Defined Bid Requirements below). Bidders may include supplemental materials beyond the minimum.

7. **Clarification protocol** — Resolved: see RFP Versioning and Clarifications below.

---

## Migration Path

1. Build trait catalog and starter profiles as YAML/MD in `multivator-skills/profiles/`
2. Build implementor template to replace static rule files
3. Update team lead rules for profile selection and N-way spawning
4. Update judge rules for N-way comparison
5. Keep backward compat: 2-bidder conservative/aggressive is just `the_pragmatist` + `the_innovator`
