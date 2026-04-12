# Design: RFP Authoring Skill

## Status: Draft

## Problem

The RFP is the single highest-leverage artifact in the multivator process. A weak RFP produces weak bids — bidders fill ambiguity with guesses instead of insight. A strong RFP channels divergence into the design questions that actually matter.

Writing a good RFP is hard. The author knows what they want but may not know:
- What's a hard constraint vs a preference they'd trade away
- Which decisions are genuinely open vs already decided in their head
- What context a bidder needs that the author takes for granted
- Where the real tensions are that would benefit from competing proposals

The mesh-swarm RFP worked because the author had deep domain knowledge and knew the template well. We need a skill that gets any author to that level of clarity through guided Q&A.

## Goal

A `/rfp` skill that conducts an interactive interview with the human, references their source documents, and progressively builds a complete RFP. The output is a ready-to-bid spec file.

---

## Skill Workflow

### Phase 1: Seed

The skill starts by gathering raw material. It asks the human for:

1. **The one-sentence pitch** — "What are we building and why?"
2. **Source documents** — existing docs, repos, design notes, ideabase entries, prior art, anything relevant. The skill reads and indexes these.
3. **Who cares about this?** — stakeholders, users, operators. This shapes evaluation priorities.

From the seed, the skill generates an initial **problem statement draft** and confirms it with the human before proceeding.

### Phase 2: Requirements Discovery (Q&A)

The skill walks through requirement categories, asking targeted questions. It doesn't just ask "what are your requirements?" — it proposes requirements based on the source documents and asks the human to confirm, modify, or reject.

**Must Have** — The skill drafts candidates from source docs:
> "Based on your mesh-swarm repo, it looks like self-organizing discovery is core. Is this a must-have: *Nodes discover peers and form a network with zero manual configuration within 30 seconds*?"

**Should Have** — The skill identifies capabilities mentioned but not emphasized:
> "Your ideabase mentions voice interaction. Is that a must-have, should-have, or out of scope for this RFP?"

**Must Not** — The skill probes for constraints the author hasn't stated:
> "Your privacy notes are strong. Should we make this explicit: *Must not send user data off the local network without explicit opt-in*?"

**Anti-requirements** — Things that sound like requirements but aren't:
> "You mentioned cloud connectivity. Is cloud a requirement or an optional enhancement? If optional, should the system work fully without it?"

### Phase 3: Evaluation Priorities

The skill presents the standard evaluation axes and asks the human to rank them. It also proposes domain-specific axes based on the source material:

> "Given the IoT context, I'd suggest adding **intelligence-to-power ratio** as a primary evaluation axis — smarter behavior per watt. Where would you rank that?"

The skill pushes back on "everything is top priority":
> "You've marked 6 of 8 axes as high priority. Bidders need to make trade-offs — if correctness and innovation conflict, which wins? If cost and performance conflict?"

### Phase 4: Open Design Decisions

This is where the skill earns its keep. It identifies decisions the author might think are settled but are actually open, and decisions the author left vague that need to be explicitly flagged as open.

The skill reads source docs and asks:
> "Your PoC uses painlessMesh. Is that a hard constraint or an open decision? If a bidder proposed Thread or Zigbee instead, would you consider it?"

> "You describe 4 device tiers. Is the tier structure fixed, or could a bidder propose 3 tiers or 5?"

> "Your state sync approach isn't specified. Should I flag this as an open design decision? This is likely where bidders will diverge most."

The skill explicitly labels each open decision with **why it's open** — what tension makes it interesting:
> "Open: Mesh protocol choice. *Why*: the device hierarchy spans battery sensors to mains hubs — one protocol may not optimally serve both ends."

### Phase 5: Constraints and Context

**Hard constraints** — The skill asks pointed questions:
> "What's non-negotiable? Language, platform, existing systems it must integrate with, things it absolutely cannot use?"

**Soft constraints** — Preferences that can be overridden:
> "Are there preferences you'd trade away if a bidder justified it? 'Prefer X but open to Y if...'?"

**Context** — The skill pulls from source documents:
> "I found these relevant files in your repos: [list]. Should I reference them in the RFP? Are there failed approaches bidders should know about?"

### Phase 6: Definition of Done and Bid Requirements

The skill drafts measurable completion criteria and asks the human to validate:
> "For the intruder-vs-cat scenario, what's 'pass'? Correctly classifying 5 test images? Real-time on ESP32-S3? Both?"

It also defines the **required bid artifacts** (per the bid packet design):
> "Based on this RFP's evaluation priorities, I'd recommend requiring these bid artifacts: APPROACH.md, INTERFACES.md, COST-ANALYSIS.md, POWER-ANALYSIS.md, PRIVACY-ANALYSIS.md, SELF-REVIEW.md. Any to add or remove?"

### Phase 7: Profile Suggestion

Based on the RFP's open design decisions and evaluation priorities, the skill suggests which bidder profiles would produce the most useful divergence:

> "This RFP has tension between power efficiency and intelligence capability. I'd suggest 3 bidders:
> - **Razor** — will optimize aggressively for power, may sacrifice smarts
> - **Mad Max** — will push intelligence to the edge, may burn more power
> - **Nightwatch** — will prioritize operational resilience and self-healing
>
> This gives you a power-optimized bid, an intelligence-maximized bid, and a production-hardened bid to compare. Agree, or different mix?"

### Phase 8: Assembly and Review

The skill assembles the complete RFP from all phases, writes it to `specs/<slug>.md`, and presents it for final review:

> "Here's the assembled RFP. Read through it as if you're a bidder seeing it for the first time. What's confusing? What's missing? What would you assume that isn't stated?"

---

## Source Document Handling

The skill reads source documents the human provides and uses them throughout the interview — not just as background, but as active material to propose requirements, identify tensions, and surface context.

### What counts as a source document
- Existing repos (READMEs, code, tests)
- Design docs, concept notes, ideabase entries
- Prior RFPs or specs
- Chat logs, meeting notes, brainstorm outputs
- External references (papers, specs, competitor analysis)

### How the skill uses them
- **Extract implied requirements**: "Your code already handles X — is that a requirement or incidental?"
- **Identify gaps**: "Your design doc mentions Y but your code doesn't implement it — is Y in scope?"
- **Surface prior decisions**: "In this commit message you ruled out BLE. Should that go in Prior Art / Failed Approaches?"
- **Ground open questions**: "Your ideabase has 3 different proposals for state sync. Flag this as an open decision?"

### What the skill does NOT do
- Invent requirements the source documents don't support
- Assume source documents are current (it asks: "Is this still accurate?")
- Include source document content verbatim — it references and summarizes

---

## Interaction Principles

1. **One question at a time when it matters, batched when it doesn't.** Constraint discovery can be rapid-fire. Open design decisions need individual attention.

2. **Propose, don't ask open-ended.** "Is self-healing a must-have?" beats "What are your requirements?" The skill drafts and the human edits — that's faster and produces better results.

3. **Push back on vagueness.** "Low latency" → "What does low mean? Under 100ms? Under 1s? For which operations?" The RFP must be specific enough that bidders don't have to guess, or explicitly flag the ambiguity as an open decision.

4. **Push back on false precision.** If the author specifies "p99 < 47ms" but can't justify why 47, the skill suggests making it an open question or widening the range.

5. **Flag hidden decisions.** When the author states something as fact that is actually a design choice, surface it: "You said 'using MQTT.' Is MQTT decided, or is the messaging protocol an open question?"

6. **Show progress.** After each phase, show what's been captured so far. The human should see the RFP taking shape incrementally, not just get a dump at the end.

7. **Know when to stop.** A 3-page RFP for a rate limiter is overkill. A 1-page RFP for a mesh network is underbaked. The skill scales depth to problem complexity.

---

## Invocation

```
/rfp                          # Start from scratch
/rfp specs/mesh-swarm.md      # Review/improve an existing RFP
/rfp --from docs/concept.md   # Seed from a source document
```

---

## Open Questions

1. **RFP complexity gauge** — Should the skill estimate how many bidders and which profiles before the human asks? Or wait for Phase 7?

2. **Template evolution** — As we author more RFPs, the template itself may need new sections. Should the skill be able to suggest template changes when it encounters patterns the template doesn't cover?

3. **Multi-session authoring** — Complex RFPs may take more than one session. Should the skill save intermediate state so the human can pick up where they left off?

---

## Related Skills

- **`/rfp-tighten`** (separate skill) — After round 1 bids surface RFP gaps, reads the judge's gap analysis and bidder assumptions, then conducts a focused Q&A with the human to produce a versioned RFP (v1.1) with clarifications. See DESIGN-bidder-profiles.md § RFP Versioning for the versioning model.
