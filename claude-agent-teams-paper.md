# Competing Implementors and a Judge: Architecture Design with Claude Code Agent Teams

## 1. Introduction

Architecture decisions are expensive. Not because the final answer is expensive, but because generating and fairly evaluating multiple approaches requires parallel effort from experienced engineers who could be building instead of debating. A team that needs to choose between, say, event sourcing and a key-value store for distributed state must typically do one of two things: pick one approach early (and hope it was right), or invest days of calendar time having multiple engineers prototype and compare alternatives.

The first path risks anchoring bias -- the team commits to whatever approach the most senior engineer proposes first. The second path is thorough but slow, and it is difficult to ensure that the competing approaches receive truly independent evaluation, free from groupthink or the social dynamics of the team that produced them.

This paper describes a framework that uses Claude Code's agent team tooling to run competing architecture tracks in parallel, with an impartial AI judge scoring the results against a weighted rubric. Two AI implementors, working in isolated git worktrees with no visibility into each other's work, produce full design deliverables from the same Request for Proposals (RFP) specification. A judge agent then reads both sets of deliverables and produces a scored verdict: pick one, synthesize both, or reject both.

The entire cycle -- two competing architectures, detailed analysis documents, scored evaluation, and a synthesis recommendation -- completes in roughly 20 minutes. We demonstrate this with a real case study: designing a self-organizing AIoT mesh network for smart home security and environmental control.

This is not a sales pitch. The approach has clear limitations, which we address. But for the class of problems where multiple valid architectural paths exist and the cost of choosing wrong is high, running parallel AI tracks with a structured evaluation can produce results that are better than either track alone.

## 2. The Framework: Competing Implementors + Judge

### Team Topology

The framework defines four roles:

| Role | Agent Type | Philosophy |
|------|-----------|------------|
| **Team Lead** | User's main Claude Code session | Orchestrates, decomposes, assigns, coordinates |
| **Implementor A** | Isolated worktree agent | Conservative: proven patterns, minimal complexity, deterministic behavior |
| **Implementor B** | Isolated worktree agent | Experimental: performance-first, modern patterns, novel approaches |
| **Judge** | Non-isolated agent (reads both worktrees) | Scores against weighted rubric, recommends verdict |

The philosophical split between implementors is deliberate. Implementor A is instructed to optimize for "long-term maintainability over cleverness" -- minimal dependencies, explicit logic, defensive coding, small surface area. Implementor B optimizes for "performance, expressiveness, and exploring what's possible" -- it is permitted to introduce new dependencies, propose fundamentally different architectures, and push ambitious testing strategies.

This forced divergence is the core mechanism. Without it, two AI agents given the same prompt tend to converge on similar solutions. The explicit philosophical directives ensure that the two tracks make genuinely different design choices, which in turn ensures the judge has meaningfully different approaches to compare.

### RFP-Driven Work

All work starts from a structured Request for Proposals specification. The RFP template has six sections, each serving a specific purpose:

**Problem Statement.** Defines what the system must accomplish and why. This grounds both implementors in the same problem understanding and prevents them from solving different problems.

**Requirements (Must / Should / Must Not).** Three-tier requirements with explicit priority. "Must have" items are non-negotiable. "Should have" items are valuable but can be traded off. "Must not" items define hard constraints. The must-not list is particularly important -- it prevents both implementors from taking shortcuts that would violate core principles (e.g., "must not require cloud connectivity for basic operation").

**Evaluation Priorities with Weights.** Each priority is weighted, and checked priorities are scored. This is the rubric the judge uses. By defining weights upfront, the RFP author controls what matters. A security-critical system might weight correctness at 0.25 and innovation at 0.05. A research prototype might reverse those weights.

**Open Design Decisions.** This section lists the genuinely open questions where the implementors should explore the solution space. Each decision is framed as a question, not an answer. This is critical: if the RFP pre-decides the technology choices, the competing tracks will converge. The decisions must be truly open for divergence to occur.

**Constraints.** Hard constraints (platform, language, build system) and soft constraints (preferences that can be overridden with justification). These bound the solution space without predetermining the architecture.

**Definition of Done.** Concrete, verifiable acceptance criteria. Both implementors and the judge use these to assess completeness.

### How the Team Lead Orchestrates

The Team Lead (the user's main Claude Code session) reads the RFP and creates three tasks:

1. "Implement: Conservative track" -- assigned to Implementor A
2. "Implement: Experimental track" -- assigned to Implementor B
3. "Judge implementations" -- blocked until both above complete

Both implementor tasks are spawned in parallel. Each implementor receives the full RFP text, their role directive (conservative or experimental), and the evaluation weights. They work in isolated git worktrees and cannot see each other's output.

Each implementor follows a defined workflow: read the RFP, write an APPROACH.md explaining their design choices before building anything, implement the solution, write tests, then write a SELF-REVIEW.md honestly assessing their own weaknesses and where the other approach might be better. This self-review step is remarkably valuable -- it gives the judge additional signal about which risks each implementor is aware of versus blind to.

When both implementors complete, the Team Lead spawns the Judge with paths to both worktrees. The Judge reads all deliverables, scores each implementation on the rubric axes, and writes a VERDICT.md with its decision.

### The Judge's Options

The judge can render one of four verdicts:

- **PICK A** -- Implementation A is clearly better on weighted criteria
- **PICK B** -- Implementation B is clearly better on weighted criteria
- **SYNTHESIZE** -- Both have complementary strengths; the judge specifies exactly what to take from each and how to integrate them
- **REJECT BOTH** -- Neither adequately addresses the RFP; the judge specifies what was missed

The SYNTHESIZE verdict, as we will see in the case study, often produces the most valuable outcome -- a design that neither implementor would have produced alone.

## 3. The Tooling: Claude Code Native Teams

The framework is implemented entirely using Claude Code's built-in team tools. No external orchestration layer, no custom scripts, no additional infrastructure.

**TeamCreate** creates the team and its shared task list. The team has a name (derived from the RFP slug) and a description.

**TaskCreate / TaskUpdate / TaskList** provide shared task tracking with dependencies and ownership. Tasks have statuses (not_started, in_progress, completed), owners (agent names), and descriptions. The judge's task is created with a dependency on both implementor tasks, ensuring it only activates after both are done.

**Agent with isolation: "worktree"** spawns each implementor in an isolated git worktree. This is the key isolation mechanism: each implementor gets a fresh copy of the repository in a separate directory. They can write files, create branches, and make commits without affecting each other or the main workspace. The implementors literally cannot see each other's work.

**SendMessage** enables inter-agent communication. Implementors notify the Team Lead when they complete. The Team Lead sends the judge the paths to both worktrees. After the verdict, the Team Lead collects the result and writes a summary.

**TeamDelete** cleans up the team and task directories when work is complete. Agent worktrees with changes are preserved for merging.

The Team Lead is the user's main Claude Code session, acting as orchestrator. It does not implement anything -- it decomposes, assigns, monitors, and coordinates. The agents run in the background and report back when done.

## 4. Case Study: MeshSwarm AIoT Mesh Network

### The RFP

The MeshSwarm RFP specified a self-organizing mesh network for smart home security and environmental control. The core concept: a hierarchy of heterogeneous devices -- from coin-cell-powered motion sensors to mains-powered camera nodes to a central hub -- that automatically discover each other, negotiate roles, and distribute intelligence across the network.

The problem statement outlined four capabilities: security (camera-based person vs. pet detection, intruder detection), environmental control (temperature, lighting, HVAC), voice interaction, and an intelligence hierarchy where local edge inference handles most decisions without cloud dependency.

The evaluation priorities, with weights, were:

| Priority | Weight | Description |
|----------|--------|-------------|
| Intelligence-to-power ratio | 0.25 | Smarter behavior using less energy wins |
| Ease of use & setup | 0.15 | Zero configuration; non-technical user can add a node |
| Scenario test quality | 0.15 | Concrete, testable scenarios demonstrated |
| Privacy & resilience | 0.15 | Data stays local by default; handles failures gracefully |
| Consumer cost | 0.10 | Total system cost for realistic deployments |
| Correctness | 0.10 | Self-healing, capability discovery, state convergence |
| Innovation | 0.05 | Novel approaches valued |
| Minimal footprint | 0.05 | Constrained leaf nodes respected |

Nine design decisions were left genuinely open: mesh networking substrate, distributed intelligence architecture, power budget tradeoffs, security and anomaly detection model, state synchronization at scale, connectivity tiers, actuator coordination, privacy vs. functionality tradeoff, and consumer cost optimization.

### What Implementor A Designed (Conservative Track)

Implementor A produced a design optimized for "proven protocols, minimal complexity, deterministic behavior, and maximum reliability." Their key choices across the nine open design decisions:

**Mesh networking:** ESP-NOW for leaf-to-edge communication plus Wi-Fi for edge/hub/cloud connectivity. Leaf nodes use ESP-NOW as fire-and-forget transmitters -- they wake, send a packet, and sleep. No mesh participation, no routing overhead. Edge nodes bridge ESP-NOW to Wi-Fi. The choice explicitly rejected painlessMesh (too power-hungry for battery nodes), Zigbee/Thread (require additional radio hardware not present on standard ESP32), and BLE Mesh (large stack footprint).

**Intelligence architecture:** A fixed, hierarchical pipeline with compile-time-determined capabilities at each tier. No dynamic task negotiation. Tier 0/1 nodes run threshold filters, Tier 2 runs TFLite Micro person detection, Tier 3 runs a rule-based state machine for security decisions. As the approach document stated: "In a home security system, deterministic behavior is worth more than flexibility."

**Security detection:** An explicit state machine with named states and transitions. Intruder detection combined PIR triggers, camera person classification, and BLE beacon absence. Settling-in vs. passing-through used a simple presence duration timer (configurable, default 3 minutes). Anomaly detection used a rolling histogram of event frequency per room per hour-of-day (7 days x 24 hours = 168 bins), flagging events outside 2 standard deviations.

**State synchronization:** Hub-and-spoke with a versioned key-value store. The hub is the single source of truth. Last-writer-wins conflict resolution with hub-ordered timestamps.

**Privacy:** Camera frames never leave the device -- a hard architectural constraint. No persistent storage on leaf or edge nodes. Hub stores only aggregates with a 7-day rolling window. No external connections by default. Physical node approval via button press on the hub.

**Cost:** $59 starter deployment (1 hub + 1 camera + 2 PIR sensors + 1 temp sensor), $249 full home (26 nodes). Based on Seeed XIAO development modules.

### What Implementor B Designed (Experimental Track)

Implementor B described their design as a "neuromorphic hierarchy" modeled on biological nervous systems. Their defining insight: "Most smart home systems waste power by shipping raw data upward. This design inverts that -- intelligence flows downward as policy; data flows upward only as exceptions."

**Mesh networking:** A hybrid approach using ESP-NOW for leaf-to-edge plus ESP-MESH-LITE (Wi-Fi-based) for edge-to-hub. ESP-MESH-LITE is Espressif's production mesh with self-organizing tree topology, providing multi-hop routing and native IP connectivity between edge and hub. This was the design's highest-risk choice.

**Intelligence architecture:** Reactive event cascade with downward policy propagation. Higher tiers push policies downward so lower tiers can act autonomously. For example, the hub tells an edge node: "Between 23:00-06:00, any human detection in zone front-door is alert-level-3." Edge nodes maintain a capability graph for their zone and compose inference pipelines automatically from available hardware -- PIR + Camera = motion-triggered visual classification.

**Security detection:** A three-stage pipeline with a continuous anomaly score (0.0-1.0) rather than binary classification. The hub maintains a Temporal Event Graph -- a sliding window of events with timestamps, zones, and classifications. Scores above 0.7 trigger soft alerts (notification); above 0.9 trigger hard alerts (alarm). Thresholds are user-adjustable. The system learns household patterns over 7 days.

**State synchronization:** Event sourcing with tier-appropriate projections. The hub maintains an authoritative event log (circular buffer, ~1MB, ~24h). Edge nodes subscribe to zone-scoped projections. Leaf nodes are stateless. Conflict resolution uses Lamport timestamps with hub sequencing.

**Privacy:** Shared the same camera-frames-never-leave-device constraint. Added differential privacy for cloud opt-in data -- behavioral patterns are noised using Laplace mechanism before transmission, with a configurable epsilon (default 1.0). Hub storage encrypted at rest with mandatory user passphrase. Traffic padding with dummy packets to obscure event timing.

**Cost:** $55 starter deployment, $217 full home. Achieved lower costs by specifying bare ESP32 modules ($1.50 for ESP32-C3-MINI-1) rather than development boards, with custom PCBs.

### Where the Designs Diverged (and Converged)

The designs converged on several fundamental choices: ESP-NOW for leaf-to-edge communication, camera frames never leaving the device, no cloud dependency for core operation, and TFLite Micro for on-device person detection. These convergences are informative -- they suggest these choices are near-optimal for the problem constraints, not just one team's preference.

The genuinely divergent choices were:

| Decision | Implementor A | Implementor B |
|----------|--------------|--------------|
| Edge-to-hub networking | Wi-Fi direct | ESP-MESH-LITE (Wi-Fi mesh) |
| Intelligence model | Fixed pipeline, rule-based | Event cascade, policy propagation, anomaly scoring |
| State synchronization | Hub-and-spoke KV store | Event sourcing with tier projections |
| Security reasoning | Explicit state machine | Continuous anomaly scoring with temporal graph |
| Actuator coordination | Sequential hub-dispatched commands | Scene engine with priority arbitration |
| API style | Explicit structs, virtual dispatch, raw bytes | Fluent builder, typed events, lambda handlers |
| Testing approach | Unit tests + on-device scenarios | Discrete event simulator + property-based tests |
| Learning | None (static rules) | Adaptive thresholds, predictive sleep scheduling |

### The Judge's Scoring

The judge scored both implementations on eight axes with the RFP-defined weights:

| Axis | Weight | Impl A | Impl B |
|------|--------|--------|--------|
| Intelligence-to-Power Ratio | 0.25 | 8 | 9 |
| Ease of Use & Setup | 0.15 | 8 | 7 |
| Scenario Test Quality | 0.15 | 7 | 9 |
| Privacy & Resilience | 0.15 | 8 | 9 |
| Consumer Cost | 0.10 | 7 | 8 |
| Correctness | 0.10 | 8 | 7 |
| Innovation | 0.05 | 5 | 8 |
| Minimal Footprint | 0.05 | 9 | 7 |
| **Weighted Total** | **1.00** | **7.60** | **8.15** |

### The Verdict: SYNTHESIZE

The judge rendered a SYNTHESIZE verdict, concluding: "The strongest product would synthesize both, using A's simpler networking and rule-based security as the foundation while adopting B's superior state model, event system, and policy architecture."

The integration path specified exactly what to take from each design:

**From A (foundation):** ESP-NOW + Wi-Fi direct networking (avoiding B's risky ESP-MESH-LITE), the rule-based security engine as the primary decision maker (works from day 1 with no learning period), hub-and-spoke state topology, flat 12-byte message format, and the explicit C++ code style.

**From B (enhancements):** Event sourcing as an audit log alongside A's KV store (for post-incident review), the typed event system replacing raw byte serialization, policy propagation for hub-to-edge configuration, the scene engine with priority arbitration for actuator coordination, anomaly scoring as an advisory annotation alongside A's rules, differential privacy for cloud opt-in data, and the discrete event simulator plus property-based tests.

**Explicitly excluded from B:** ESP-MESH-LITE (too risky), automatic capability composition (too complex for V1), predictive sleep as default (opt-in only after 14+ day learning period), and the builder pattern with lambda handlers (too complex for embedded targets).

This synthesis is notably aligned with Implementor B's own self-review, which concluded: "The strongest design would combine conservative track's simpler networking... rule-based security engine as the primary path... experimental track's event sourcing state model... policy propagation... typed event system... anomaly scoring as a secondary/advisory system alongside rules."

### Gaps Neither Implementor Addressed

The judge identified seven gaps that neither design handled adequately:

1. **OTA firmware updates.** Both mentioned OTA via hourly listen windows but neither designed the protocol -- chunking over ESP-NOW's 250-byte payload, CRC verification, rollback on failure, version management.

2. **Time synchronization.** Both relied on "hub-assigned timestamps" without specifying how time is synchronized across nodes in air-gapped mode (no NTP). Temporal reasoning depends on consistent timestamps.

3. **User interface.** Both punted to "local web UI" without designing the experience. For non-technical users, setup and monitoring are critical.

4. **Household member identification.** Both mentioned BLE beacons but neither integrated them into the core design. Distinguishing known from unknown persons is fundamental to reducing false alarms.

5. **Regulatory and safety considerations.** Neither addressed FCC/CE certification for ESP32 radios or safety implications of controlling mains-powered actuators.

6. **Hub single point of failure.** A acknowledged this weakness, B offered partial mitigation (edge nodes can operate zones independently), but neither designed automatic hub role promotion.

7. **Camera low-light performance.** Both specified the OV2640 (2MP) without discussing IR illumination or classification accuracy in darkness -- exactly when intruder detection matters most.

The judge also raised provocative open questions, including: "Should the hub be an ESP32 at all?" -- noting that a Raspberry Pi Zero 2 W at $15 would provide 512MB RAM and a full Linux stack, potentially outgrowing the ESP32-S3 for the hub's aggregation and reasoning role.

## 5. Analysis: What Worked and What Didn't

### The Value of Forced Divergence

The explicit philosophical directives -- conservative vs. experimental -- produced genuinely different designs. This was not a trivial outcome. The nine open design decisions yielded different answers on six of them (mesh topology, intelligence model, state synchronization, security reasoning, actuator coordination, and testing approach). Both converged on ESP-NOW for leaf communication, camera frame locality, and overall privacy posture -- convergences that strengthen confidence in those choices.

Without the forced divergence, there is a strong likelihood that both agents would have produced variations on the same theme. The conservative/experimental framing gave each agent permission to make choices that were internally consistent with a design philosophy, rather than trying to find a single "best" answer.

### The Value of Honest Self-Review

Both implementors wrote self-reviews that accurately identified their own weaknesses. Implementor A acknowledged the hub as a single point of failure, the lack of learning/adaptation, and ESP-NOW's limitations (no multi-hop, 20-peer encryption limit). Implementor B admitted that hybrid protocol complexity was the "biggest engineering risk," that predictive sleep scheduling was unproven, and that automatic capability composition risked combinatorial explosion.

More notably, both implementors identified where the other approach might be better. Implementor A wrote: "If the experimental approach distributes the SecurityEngine across Tier 2 nodes, it eliminates the SPOF." Implementor B wrote: "I would start with the conservative track's simpler protocol stack and only add mesh-lite if range or routing proves insufficient."

This mutual awareness gave the judge high-quality signal for the synthesis verdict. The self-reviews functioned as a form of adversarial collaboration, where each agent anticipated the other's strengths.

### The Synthesis as the Most Valuable Outcome

The SYNTHESIZE verdict produced a design superior to either individual track. A's foundation (proven networking, rule-based security, simple state sync) addresses B's highest-risk bets. B's enhancements (typed events, event sourcing audit log, policy propagation, scene engine, anomaly scoring as advisory) address A's acknowledged weaknesses (no adaptation, static intelligence, sequential actuator dispatch).

The excluded items from B (ESP-MESH-LITE, automatic capability composition, predictive sleep as default) represent a deliberate risk reduction that neither implementor would have applied to their own design -- they were committed to their philosophical track. It took an external evaluator to identify which experimental innovations were worth the risk and which were not.

### Gaps the Judge Surfaced

The seven gaps identified by the judge represent a distinct category of value. These are not weaknesses in either design -- they are issues that neither implementor thought to address, likely because they fell outside the scope that each agent prioritized. OTA firmware updates, time synchronization, and user interface design are "infrastructure" concerns that tend to be invisible during architecture discussions focused on the primary problem domain.

The judge's role as a reader of both designs, rather than a producer of either, gave it the perspective to notice what was missing.

### Limitations

**Design-only scope.** Both tracks produced architecture documents, interface definitions, analysis papers, and test strategies -- not running code. The designs are plausible and internally consistent, but they have not been validated against real hardware. ESP-NOW and Wi-Fi coexistence, TFLite Micro inference latency on ESP32-S3, and deep sleep current draw are all claims that require physical measurement.

**No hardware validation.** Power analysis figures are derived from datasheets and published community measurements, not oscilloscope traces. The difference between datasheet current and measured current on a real board with a real sensor can be significant.

**Judge scoring is subjective.** The weighted scores (A: 7.60, B: 8.15) are the judge's assessment, not objective measurements. A different judge, or the same judge with a different prompt, might score differently. The scores are useful as relative comparisons and as structured reasoning, not as absolute quality measures.

**Single problem instance.** This case study demonstrates the framework on one RFP. The approach may work differently for problems with fewer open design decisions, less room for philosophical divergence, or requirements that strongly constrain the solution space.

### The Speed Advantage

The complete cycle -- two competing architectures with detailed power analysis, cost analysis, privacy analysis, test strategy, and self-review, plus a scored verdict with synthesis recommendation and gap analysis -- completed in approximately 20 minutes of wall-clock time.

A comparable human process would involve: multiple senior engineers producing competing designs (days to weeks), a review meeting to compare them (hours, plus scheduling overhead), and a decision process that may involve politics, authority dynamics, and anchoring bias. The AI approach eliminates the social dynamics and compresses the calendar time, though it substitutes AI judgment for human expertise.

## 6. When to Use This Approach

### Good For

**Architecture decisions with multiple valid paths.** When reasonable engineers would disagree on the right approach -- event sourcing vs. CRUD, microservices vs. monolith, REST vs. GraphQL, hub-and-spoke vs. peer-to-peer -- the framework generates and evaluates both sides.

**Technology selection.** Evaluating competing technologies (e.g., which mesh protocol, which database, which ML framework) with a structured comparison across weighted criteria.

**Design reviews.** Running a competing track as a "second opinion" on an existing design, to surface alternatives and identify blind spots.

**Exploring solution spaces.** When the problem is well-defined but the solution space is large and the cost of choosing wrong is high.

### Less Suited For

**Well-understood problems with clear solutions.** If the team already knows the right architecture, running competing tracks wastes time. A CRUD API for a simple data model does not benefit from philosophical divergence.

**Pure implementation work.** The framework produces designs, not production code. For tasks where the architecture is settled and the work is implementation, a single agent is more efficient.

**Tasks requiring physical testing.** The MeshSwarm case study illustrates this limitation -- the competing designs are plausible but unvalidated against real hardware. For problems where the answer depends on measurement (performance benchmarks, hardware compatibility, user testing), the framework produces hypotheses, not conclusions.

### The RFP Quality Matters

The quality of the output is bounded by the quality of the input. An RFP with vague requirements, pre-decided design choices, or missing evaluation weights will produce designs that are vague, convergent, or unranked respectively.

The most important RFP section is "Open Design Decisions." If this section lists questions that are genuinely open -- where a reasonable engineer could argue for multiple answers -- the framework produces useful divergence. If the decisions are implicitly pre-decided by the constraints or the problem statement, the implementors will converge regardless of their philosophical directives.

## 7. Practical Guide

### Setting Up the Scaffold

The scaffold consists of a set of Claude Code rule files that define each agent's role:

- `00-team-constitution.md` -- Defines the team topology, communication protocol, task tracking, and golden rules (implementors never see each other's worktrees, disagreement is a feature).
- `01-implementor-a.md` -- Conservative track directives: minimal dependencies, explicit code, defensive patterns.
- `02-implementor-b.md` -- Experimental track directives: performance-first, modern patterns, innovation welcomed.
- `03-judge.md` -- Scoring rubric axes, verdict options, output format.
- `04-team-lead.md` -- Orchestration workflow: create team, parse RFP, spawn agents, collect verdict, report.

Place these in `.claude/rules/` in your project. The Team Lead workflow is triggered by asking Claude Code to "launch the agent team" for a given RFP spec file.

### Writing a Good RFP

From the MeshSwarm demo, several principles emerge:

**Be specific about the problem, open about the solution.** The MeshSwarm RFP defined exactly what the system needed to do (detect intruders, distinguish cats from humans, infer settling-in intent) but left how to do it as nine open decisions. This produced genuine divergence.

**Weight your evaluation priorities honestly.** The MeshSwarm RFP weighted intelligence-to-power ratio at 0.25 and innovation at 0.05. This told both implementors and the judge what matters most. If you secretly care more about innovation than you stated in the weights, the verdict will not match your preferences.

**Include must-not requirements.** The MeshSwarm RFP's must-not list ("must not require cloud connectivity," "must not send user data off the local network without explicit opt-in") shaped both designs more than any positive requirement. Must-not items define the solution space boundary.

**Define concrete scenarios in the Definition of Done.** "Intruder vs. cat" and "settling in vs. passing through" gave both implementors specific test cases to design against, which made the judge's comparison meaningful.

### Tuning Evaluation Weights

Different problem types benefit from different weight distributions:

- **Security-critical system:** Weight correctness (0.25) and privacy/resilience (0.20) heavily. Innovation (0.05) and cost (0.05) take back seats.
- **Consumer product:** Weight ease of use (0.25) and cost (0.20) heavily. Minimal footprint matters less.
- **Research prototype:** Weight innovation (0.25) and scenario test quality (0.20). Operational risk tolerance is higher.
- **Performance-sensitive system:** Weight a custom "performance" axis (0.25) and correctness (0.20). Maintainability is still important but secondary.

### Interpreting SYNTHESIZE Verdicts

A SYNTHESIZE verdict is not "take half of A and half of B." The judge's integration path specifies exactly which components come from each track and why. In the MeshSwarm case, the synthesis took 5 elements from A (networking, security engine, state topology, message format, code style) and 8 from B (typed events, event sourcing audit log, policy propagation, scene engine, anomaly scoring, differential privacy, simulator, property tests), while explicitly excluding 4 elements from B that were deemed too risky.

To build the integrated design:

1. Start with the foundation track's codebase (typically A's, due to its simpler structure).
2. Layer in the enhancement track's components in the order specified by the integration path.
3. Validate at each step that the added component does not conflict with the foundation.
4. Address the gaps the judge identified -- these are now the priority backlog items.

The synthesis verdict also serves as a design document. Its rationale section explains why each element was included or excluded, providing the "why" behind the architecture that is often lost in conventional decision-making processes.

## Conclusion

The competing-implementor-plus-judge framework is not a replacement for human architectural judgment. It is a tool for generating, structuring, and evaluating the options that feed into that judgment. The MeshSwarm case study demonstrates that two AI agents with divergent philosophical directives will make genuinely different design choices, that their self-reviews provide honest signal about risks and tradeoffs, and that a judge evaluating both tracks against a weighted rubric can produce a synthesis recommendation that is better than either track alone.

The framework's most distinctive contribution is the synthesis verdict. Neither Implementor A nor Implementor B would have proposed a design that combined A's simple networking with B's typed event system, A's rule-based security with B's anomaly scoring as advisory, or A's explicit code style with B's scene engine. The synthesis emerged from the structured comparison of two approaches that were designed to disagree.

For technical leaders evaluating AI-assisted development, the practical takeaway is this: when you face an architecture decision with multiple valid paths, the cost of running two competing AI tracks and a judge is roughly 20 minutes and a well-written RFP. The output is not a final answer, but a structured exploration of the solution space that surfaces tradeoffs, identifies blind spots, and produces a recommended path that is informed by genuine alternatives. That is often worth more than a single design, no matter how good.
