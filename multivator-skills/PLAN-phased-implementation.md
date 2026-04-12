# Phased Implementation Plan

## Principle: Fail Fast, Fix Fast

Each phase produces something testable. We run it on a real RFP, see what breaks, fix it, then move on. No phase depends on a future phase being perfect. Every phase improves the framework independently — if we stop after any phase, we still have something better than what we started with.

---

## What We Have Today (Phase 0 — Baseline)

**Working:**
- 2-bidder flow (conservative + experimental) with judge
- Rule files in `.claude/rules/` (constitution, 2 implementors, judge, team lead)
- RFP template + 2 example specs (mesh-swarm, rate-limit-queue)
- One complete demo run with full output (MeshSwarm)

**Known problems from the PoC:**
- Bidders can see each other's work (worktree isolation specified but not enforced in output structure)
- Output uses `B-` prefix naming hack instead of proper isolation
- Hardcoded to exactly 2 bidders
- RFP authoring requires the user to already know the template well
- No way to test competing implementations of a settled design

---

## Phase 1: Bid Packets and Real Isolation

**What:** Enforce the bid packet structure and worktree isolation that the PoC proved was needed.

**Build:**
- Update `00-team-constitution.md` — add bid packet rules (all output under `bid/`, no `B-` prefixes, standard file names)
- Update `01-implementor-a.md` and `02-implementor-b.md` — add `bid/` directory requirement to workflow
- Update `03-judge.md` — judge receives paths to `bid/` directories, not individual files
- Update `04-team-lead.md` — team lead collects worktree paths and passes `bid/` paths to judge

**Test:** Re-run the MeshSwarm RFP (or the simpler rate-limit-queue RFP) with the updated rules. Verify:
- [ ] Each bidder writes only to `bid/` in their worktree
- [ ] No `B-` prefixed files anywhere
- [ ] Judge can read both `bid/` directories independently
- [ ] Verdict references bid paths, not file name conventions

**Why first:** This is the lowest-risk change with the most structural value. It fixes a real problem from the PoC and establishes the output contract that everything else builds on. If this doesn't work, we learn immediately with zero wasted effort on later phases.

**Estimated effort:** Small — rule file edits only, no new infrastructure.

---

## Phase 2: Implementor Template + 3-Bidder Run

**What:** Replace the two static implementor rule files with a single template, and run a 3-bidder test.

**Build:**
- Create `01-implementor-template.md` — parameterized template with placeholders for name, philosophy, traits, success criterion, differentiation directive
- Create `multivator-skills/profiles/` directory with 3 starter profiles as YAML:
  - `steady_eddie.yaml` (from DESIGN-bidder-profiles.md)
  - `mad_max.yaml`
  - `nightwatch.yaml`
- Update `04-team-lead.md` — team lead reads profile YAMLs, fills template, spawns N agents
- Update `03-judge.md` — judge handles N-way comparison (score each independently, rank, compare top 2-3)

**Do NOT build yet:**
- Full trait catalog (10 traits) — start with 3-4 traits that actually matter
- Auto-divergent profile selection — manual selection only
- Profile coherence validation
- All 6 starter profiles — 3 is enough to test N-bidder

**Test:** Run rate-limit-queue RFP with 3 bidders (Steady Eddie, Mad Max, Nightwatch). Verify:
- [ ] Template produces coherent, distinct implementor prompts
- [ ] 3 bidders produce genuinely different proposals (not just variations)
- [ ] Judge handles 3-way comparison without getting confused
- [ ] Verdict correctly references all 3 bidders
- [ ] Time/cost is acceptable (does 3x vs 2x matter?)

**Why second:** This is the core architectural change — N bidders instead of 2. But we're testing it with the *minimum viable version* (3 hardcoded profiles, manual selection). We learn whether N-bidder divergence actually works before investing in the full trait catalog and auto-selection.

**Key question to answer:** Does a 3rd bidder add meaningful signal, or is it just noise? If the judge struggles with 3-way comparison, we need to fix the judge rubric before going further.

**Estimated effort:** Medium — new template, 3 profile files, rule file updates.

---

## Phase 3: RFP Authoring Skill (Minimal)

**What:** Build a minimal `/rfp` skill that guides the user through writing an RFP. Start with the interview flow, skip the source document indexing.

**Build:**
- Implement `/rfp` as a Claude Code skill with phases:
  - Phase 1 (Seed): One-sentence pitch + who cares
  - Phase 2 (Requirements): Propose must/should/must-not, user confirms/edits
  - Phase 4 (Open Decisions): Surface decisions, label why they're open
  - Phase 5 (Constraints): Hard vs soft
  - Phase 6 (DoD): Measurable acceptance criteria
  - Phase 8 (Assembly): Write to `specs/<slug>.md`

**Do NOT build yet:**
- Phase 3 (Evaluation Priorities) — use defaults, let user edit after
- Phase 7 (Profile Suggestion) — depends on Phase 2 profiles being validated
- Source document reading/indexing — too complex for v1
- Multi-session authoring

**Test:** Use `/rfp` to author a brand-new RFP for a real problem (not MeshSwarm — something fresh). Then manually compare it against the RFP template to see if it's complete and clear. Then run it through the 3-bidder flow from Phase 2 and see if bidders struggle with ambiguity.

- [ ] Skill produces a complete RFP that fills the template
- [ ] User finds the interview faster than writing from the template
- [ ] Bidders don't hit excessive ambiguity (test by reading their Assumptions sections)
- [ ] The interview takes < 15 minutes for a moderate-complexity problem

**Why third:** RFP quality is the highest-leverage input. But we needed to validate the N-bidder flow first (Phase 2) because the `/rfp` skill's Profile Suggestion phase (Phase 7) depends on knowing whether profiles work. We skip that phase for now and add it after Phase 2 is validated.

**Key question to answer:** Does guided authoring produce better RFPs than template-filling? Measure by comparing bidder assumption counts — fewer assumptions means a clearer RFP.

**Estimated effort:** Medium-large — skill implementation with multi-phase interview logic.

---

## Phase 4: RFP Review Skill (2 Reviewers)

**What:** Build `/rfp-review` with 2 of the 4 reviewers: the Bidder reviewer and the Reasonableness reviewer. These two give the most actionable feedback with the least effort.

**Build:**
- Implement `/rfp-review` skill that spawns 2 agents in parallel:
  - **Bidder reviewer**: "Can I build this? What's ambiguous? What's missing?"
  - **Reasonableness reviewer**: "Is this worth the multivator process? How many bids? Which profiles?"
- Output: `specs/<slug>-REVIEW.md` with both assessments + top 3 findings

**Do NOT build yet:**
- Product Designer reviewer — valuable but not critical for the fail-fast loop
- QA reviewer — structural quality checks can come later
- Synthesis across all 4 reviewers

**Test:** Run `/rfp-review` on the RFP produced in Phase 3. Then run the same RFP through bidding. Compare:
- [ ] Review findings predict actual bidder struggles (ambiguities, missing info)
- [ ] Reasonableness reviewer's bid count recommendation is sensible
- [ ] Profile recommendations (if Phase 2 profiles exist) are justified
- [ ] Review completes in < 5 minutes
- [ ] At least 1 finding is something the author didn't anticipate

**Why fourth:** Review validates the RFP before we spend compute on bidding. But it only matters once we have a reliable bidding flow (Phase 2) and a way to author RFPs (Phase 3) to review. Building review first would mean reviewing RFPs by hand for a process that's still shaky.

**Key question to answer:** Does pre-bid review reduce re-bid cycles? If the reviewer catches what the judge would later flag as an RFP gap, we've saved a round of bidding.

**Estimated effort:** Small-medium — 2 agents with focused prompts, simpler than the full 4-reviewer panel.

---

## Phase 5: Competing Implementations (Minimal)

**What:** Build the ADR extraction + locked-choice implementor flow. Test with 2 decisions, 2 options each (4 permutations max).

**Build:**
- Add decision extraction to Team Lead workflow — read a design doc, propose ADRs with options
- Create ADR template format (YAML as specified in DESIGN-competing-implementations.md)
- Create locked-choice implementor template (distinct from the profile-based template)
- Add lock directive to implementor prompt
- Add basic automated metrics collection (build succeeds, tests pass, LOC, dep count)
- Extend judge rubric for implementation evaluation (code quality, choice fitness, operational readiness)

**Do NOT build yet:**
- Permutation pruning (fractional factorial) — with 4 permutations, just run all
- Automated benchmarking — too complex, rely on agent self-reported metrics
- `ESCALATE` verdict — test whether it's needed first
- `/implement` skill — orchestrate manually via Team Lead
- Shared scaffolding — let each implementor start from scratch

**Test:** Take the MeshSwarm synthesized design. Extract 2 decisions (event store backend, policy propagation protocol — from the example in DESIGN-competing-implementations.md). Run 4 competing implementations. Evaluate:
- [ ] Lock directive holds — no implementor deviates from assigned choices
- [ ] 4 implementations produce meaningfully different code
- [ ] Automated metrics successfully collected
- [ ] Judge can compare 4 implementations on the adapted rubric
- [ ] At least one permutation reveals a surprise (good or bad) that wasn't obvious from the design

**Why fifth:** This is the newest, most speculative design. It depends on having a mature enough bidding flow (Phases 1-2) to produce designs worth implementing. Running it too early risks testing a shaky implementation phase against a shaky design phase — you won't know which one broke.

**Key question to answer:** Does building multiple implementations with locked choices produce better decisions than just picking one and iterating? The answer might be "not always" — and that's a valid finding that shapes when we recommend this phase.

**Estimated effort:** Large — new template, metrics collection, judge rubric extension, orchestration logic.

---

## Phase 6: Fill In and Harden

Only after Phases 1-5 are validated and we've learned from real runs:

**From Phase 2:**
- Full trait catalog (expand from 3-4 traits to the full 10)
- Remaining starter profiles (Razor, Blueprint, Proof)
- Auto-divergent profile selection
- Profile coherence validation

**From Phase 3:**
- Source document reading/indexing
- Evaluation Priorities phase (with push-back on "everything is high priority")
- Profile Suggestion phase (now that profiles are validated)
- Multi-session authoring

**From Phase 4:**
- Product Designer reviewer
- QA reviewer
- Cross-reviewer synthesis
- Conflict highlighting between reviewers

**From Phase 5:**
- Permutation pruning strategies (fractional factorial, corner cases)
- `ESCALATE` verdict
- `/implement` skill
- Shared scaffolding option
- CI integration for competing implementations

**New:**
- `/rfp-tighten` skill — post-round-1 RFP refinement
- RFP versioning (v1.0 → v1.1 with clarifications)
- Re-bid cycle orchestration
- Cost estimation before spawning N agents
- Profile scoring history (which profiles produce useful divergence)

---

## Phase Dependencies

```
Phase 1 (Bid Packets)
   |
   v
Phase 2 (N-Bidder + Profiles)
   |
   +-------+
   v       v
Phase 3   Phase 4         <- can run in parallel
(RFP      (RFP Review)
 Author)
   |       |
   +---+---+
       v
Phase 5 (Competing Implementations)
       |
       v
Phase 6 (Harden + Fill)
```

Phases 3 and 4 can be built in parallel since they're independent — one creates RFPs, the other reviews them. But testing them together (author an RFP, then review it, then bid on it) gives the best end-to-end signal.

---

## Test RFP Schedule

Each phase needs a real RFP to test against. Reusing the same RFP across phases helps control for variables, but we also need fresh RFPs to avoid overfitting.

| Phase | Test RFP | Why |
|-------|----------|-----|
| 1 | rate-limit-queue (existing) | Simple, fast, validates bid packets without complexity noise |
| 2 | rate-limit-queue + mesh-swarm | Simple one for smoke test, complex one for real divergence test |
| 3 | New RFP (authored via skill) | Must be fresh — the whole point is testing the authoring process |
| 4 | The Phase 3 RFP | Review what we just authored, then bid on it |
| 5 | MeshSwarm synthesized design | Has known open decisions, validated design to implement against |

---

## What "Done" Looks Like Per Phase

**Phase 1 done:** We can run the existing 2-bidder flow with proper bid packet isolation. Output is clean, judge reads `bid/` directories.

**Phase 2 done:** We can run 3+ bidders with distinct profiles. The judge produces a meaningful N-way verdict. We have data on whether 3 bidders adds signal over 2.

**Phase 3 done:** A user can run `/rfp` and produce a complete, bid-ready RFP through guided Q&A in under 15 minutes.

**Phase 4 done:** `/rfp-review` catches at least one non-obvious issue per RFP that would otherwise surface during bidding.

**Phase 5 done:** We can take a design, extract ADRs, and run competing implementations that produce measurably different working code. The judge picks a winner based on code, not proposals.

**Phase 6 done:** The full pipeline — author RFP, review it, bid with N profiles, extract ADRs from winning design, implement competing permutations, evaluate — runs end-to-end.

---

## Risks and Mitigations

| Risk | Phase | Mitigation |
|------|-------|------------|
| 3rd bidder adds noise, not signal | 2 | Start with 3, measure. If noisy, the system works fine at 2 + profiles for philosophical diversity |
| Guided RFP authoring takes too long | 3 | Build with "fast mode" (batch questions) vs "thorough mode" (one at a time). Default to fast |
| RFP review findings are too generic | 4 | Tune reviewer prompts based on first run. If still generic, the value may not justify the compute |
| Lock directive doesn't hold — agents deviate | 5 | Strengthen lock directive language. Add post-hoc check: did the implementation actually use the assigned choice? |
| Competing implementations produce similar code despite different choices | 5 | The choices aren't different enough. Pick higher-contrast options or accept that the decision doesn't matter much (which is itself a useful finding) |
| Compute cost of N permutations is too high | 5 | Cap at 4 permutations for Phase 5. Pruning comes in Phase 6 |
| End-to-end pipeline is too slow | 6 | Each phase should complete in < 30 min. If not, parallelize more aggressively or reduce bidder/permutation count |
