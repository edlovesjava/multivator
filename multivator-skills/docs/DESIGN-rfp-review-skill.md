# Design: RFP Review Skill

## Status: Draft

## Problem

An RFP can be well-written and still produce bad bids if it's unclear from the perspectives that matter. The author sees their own intent; they can't easily see what a bidder, a product designer, or a QA reviewer would struggle with. We need a review step that stress-tests the RFP from multiple professional perspectives before bids are solicited.

## Goal

A `/rfp-review` skill that evaluates a completed RFP through a panel of reviewer personas, each bringing a distinct professional lens. The output is a structured review with actionable findings the author can address before bidding opens.

---

## Reviewer Panel

Each reviewer reads the same RFP but evaluates it from their professional perspective. They operate independently — like the bidders, isolation produces better signal than consensus.

### The Bidder

**Perspective**: "I have to build this. Can I?"

Evaluates:
- **Clarity of scope** — Can I tell what's in and what's out? Are there requirements that could be read two ways?
- **Feasibility** — Are there requirements that are technically unrealistic given the stated constraints? (e.g., "real-time object detection on a coin-cell ESP32")
- **Missing information** — What do I need to know that isn't here? What would I have to assume?
- **Contradictions** — Do any requirements conflict with each other or with the constraints?
- **Testability** — For each requirement, can I tell when I've met it? Are the acceptance criteria measurable?
- **Effort calibration** — Is this a week of work or a quarter? Does the RFP seem to know?

Output format:
```markdown
## Bidder Review

### Would bid: Yes / With reservations / No
### Confidence I understand the scope: High / Medium / Low

### Ambiguities I'd have to assume my way through
- ...

### Requirements I'd push back on
- ...

### Questions I'd ask in a pre-bid clarification
- ...

### Missing context that would change my approach
- ...
```

### The Product Designer

**Perspective**: "Does this solve the right problem for the right user?"

Evaluates:
- **User clarity** — Who is the user? Is their context well-defined? Would different user assumptions lead to different designs?
- **Problem-solution fit** — Do the requirements actually solve the stated problem, or do they solve an adjacent problem the author drifted toward?
- **Priority coherence** — Do the evaluation priorities match the problem statement? If the problem is "security for a home," but the top priority is "innovation," that's a mismatch.
- **Missing use cases** — Are there obvious user scenarios the RFP doesn't address that would surface during real use?
- **Over-specification** — Has the author prescribed solutions where they should have stated problems? ("Use MQTT" vs "reliable message delivery")
- **User experience gaps** — Setup experience, failure experience, day-2 operations — are these addressed or only the happy path?

Output format:
```markdown
## Product Review

### Problem-solution alignment: Strong / Moderate / Weak

### Who is the user?
<What the RFP says vs what's implied vs what's missing>

### Use cases the RFP misses
- ...

### Where the RFP prescribes solutions instead of problems
- ...

### Priority mismatches
- ...

### UX gaps
- ...
```

### The QA Reviewer

**Perspective**: "Is this RFP well-formed as an RFP? Does it meet its own structural requirements?"

Evaluates:
- **Template completeness** — Are all required sections present and substantive? (Not just "TBD" or a copy of the template placeholder)
- **Requirement quality** — Is each requirement specific, measurable, and testable? SMART-style assessment.
- **Traceability** — Can each evaluation priority be traced to specific requirements? Can each Definition of Done item be traced to a requirement?
- **Consistency** — Do constraints, requirements, and Definition of Done tell the same story? Does the evaluation rubric actually test what the requirements ask for?
- **Gap analysis** — Are there requirements with no acceptance criteria? Acceptance criteria with no requirement? Evaluation axes that nothing maps to?
- **Bid artifact alignment** — Do the required bid artifacts cover the evaluation priorities? (If cost is a priority but COST-ANALYSIS.md isn't required, that's a gap.)

Output format:
```markdown
## QA Review

### RFP completeness: Complete / Has gaps / Incomplete

### Section-by-section assessment
| Section | Status | Issues |
|---------|--------|--------|
| Problem Statement | ... | ... |
| Requirements | ... | ... |
| ... | ... | ... |

### Untestable requirements
- ...

### Traceability gaps
- Requirement without acceptance criteria: ...
- Acceptance criteria without requirement: ...
- Evaluation priority without coverage: ...

### Inconsistencies
- ...
```

### The Reasonableness Reviewer

**Perspective**: "Is this a good use of the multivator process? How should we structure the bidding?"

Evaluates:
- **Scope calibration** — Is this too big for one RFP? Should it be split? Is it too small to justify multiple bids?
- **Divergence potential** — Are the open design decisions genuinely open, or is there an obvious right answer? How many axes of real divergence exist?
- **Bid count recommendation** — Based on the number and nature of open questions, how many bids would produce useful comparison without waste?
- **Profile recommendation** — Which bidder profiles would stress-test the important tensions? Why these and not others?
- **Cost-benefit** — Is the compute cost of N bidders justified by the decision quality? Could a simpler process (one bidder + review) suffice?
- **Risk assessment** — What's the risk of a bad decision here? High-risk decisions justify more bids; low-risk decisions don't need the full process.

Output format:
```markdown
## Reasonableness Review

### Suitable for multivator process: Yes / Overkill / Underbaked

### Scope assessment
<Too big / Right-sized / Too small — and why>

### Divergence analysis
| Open Decision | Genuine divergence potential | Key tension |
|--------------|---------------------------|-------------|
| ... | High / Medium / Low | ... |

### Recommendation
- **Number of bids**: N
- **Recommended profiles**:
  1. **<Profile Name>** — because ...
  2. **<Profile Name>** — because ...
  3. **<Profile Name>** — because ...
- **Rationale**: <Why this mix maximizes useful comparison>

### If this RFP were split
<Suggestion for decomposition, if applicable — or "Not needed">

### Cost-benefit note
<Is the full process worth it here, or would a lighter approach suffice?>
```

---

## Skill Workflow

### Invocation

```
/rfp-review specs/mesh-swarm.md                # Full panel review
/rfp-review specs/mesh-swarm.md --bidder        # Single reviewer
/rfp-review specs/mesh-swarm.md --reasonableness # Single reviewer
```

### Execution

1. **Read the RFP** and any source documents referenced in it
2. **Run all four reviewers** in parallel (or a subset if specified)
3. **Compile findings** into a single review document at `specs/<slug>-REVIEW.md`
4. **Highlight conflicts** between reviewers (e.g., the bidder says "too vague" but the product designer says "appropriately open")
5. **Present a summary** with the top 3-5 actionable items to address before bidding

### Output

```
specs/
  mesh-swarm.md           # The RFP
  mesh-swarm-REVIEW.md    # The panel review
```

The review document includes all four reviewer outputs plus a synthesis:

```markdown
# RFP Review: mesh-swarm

## Panel Summary

### Top findings
1. ...
2. ...
3. ...

### Bid recommendation
<From the reasonableness reviewer — number and profiles>

### Reviewer agreement / disagreement
<Where reviewers aligned vs conflicted>

---

## Bidder Review
...

## Product Review
...

## QA Review
...

## Reasonableness Review
...
```

---

## Implementation Notes

Each reviewer can be implemented as a separate agent spawned in parallel — they're reading the same input independently, which is exactly the pattern we already have for bidders. The synthesis step runs after all four complete.

This is a lightweight version of the bidding process itself: N independent perspectives, then a synthesis. The difference is reviewers don't produce artifacts, just assessments.

---

## Related Skills

- **`/rfp`** — Authors the RFP. Run `/rfp-review` after to validate before bidding.
- **`/rfp-tighten`** — Tightens the RFP after round 1 bids. Can also be informed by `/rfp-review` findings.
