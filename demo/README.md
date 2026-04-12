# Demo: MeshSwarm RFP — Competing Implementations

End-to-end proof-of-concept of the `multivator-skills` framework. Two independent Claude Code agent teams each responded to a realistic RFP, then a judge agent evaluated both proposals and produced a synthesized recommendation.

## 1. RFP Input

**[mesh-swarm.md](mesh-swarm.md)** — A self-organizing AIoT mesh network for smart home security and environmental control. The RFP specifies a five-tier device hierarchy (battery leaf nodes through cloud), capability discovery, intelligence tiering, privacy-by-default operation, and air-gapped resilience.

## 2. Execution

Each implementor agent worked independently under the team constitution defined in `multivator-skills/.claude/rules/`. The process:

1. **Implementor A** and **Implementor B** each received the same RFP spec.
2. Each produced a full set of design artifacts: architecture approach, interface definitions, cost analysis, power analysis, privacy analysis, test strategy, and a self-review.
3. A **judge agent** scored both implementations across eight weighted axes and issued a verdict.
4. A **team lead** synthesized the final summary and recommended next steps.

See **[claude-agent-teams-paper.md](claude-agent-teams-paper.md)** for a writeup on the competing-implementors-and-judge architecture and lessons learned.

## 3. Implementor Artifacts

### [Implementor A](implementor-a/) — Conservative

| Document | Description |
|----------|-------------|
| [APPROACH.md](implementor-a/APPROACH.md) | Architecture and design approach |
| [INTERFACES.md](implementor-a/INTERFACES.md) | Interface definitions and API contracts |
| [COST-ANALYSIS.md](implementor-a/COST-ANALYSIS.md) | Cost breakdown and estimates |
| [POWER-ANALYSIS.md](implementor-a/POWER-ANALYSIS.md) | Power consumption analysis |
| [PRIVACY-ANALYSIS.md](implementor-a/PRIVACY-ANALYSIS.md) | Privacy and security considerations |
| [TEST-STRATEGY.md](implementor-a/TEST-STRATEGY.md) | Testing strategy and plan |
| [SELF-REVIEW.md](implementor-a/SELF-REVIEW.md) | Team's self-assessment |

### [Implementor B](implementor-b/) — Experimental

| Document | Description |
|----------|-------------|
| [APPROACH.md](implementor-b/APPROACH.md) | Architecture and design approach |
| [INTERFACES.md](implementor-b/INTERFACES.md) | Interface definitions and API contracts |
| [COST-ANALYSIS.md](implementor-b/COST-ANALYSIS.md) | Cost breakdown and estimates |
| [POWER-ANALYSIS.md](implementor-b/POWER-ANALYSIS.md) | Power consumption analysis |
| [PRIVACY-ANALYSIS.md](implementor-b/PRIVACY-ANALYSIS.md) | Privacy and security considerations |
| [TEST-STRATEGY.md](implementor-b/TEST-STRATEGY.md) | Testing strategy and plan |
| [SELF-REVIEW.md](implementor-b/SELF-REVIEW.md) | Team's self-assessment |

## 4. Results

### [VERDICT.md](VERDICT.md) — Judge Evaluation

The judge scored both implementations across eight weighted axes:

| Axis | Weight | A | B |
|---|---|---|---|
| Intelligence-to-Power Ratio | 0.25 | 8 | 9 |
| Ease of Use & Setup | 0.15 | 8 | 7 |
| Scenario Test Quality | 0.15 | 7 | 9 |
| Privacy & Resilience | 0.15 | 8 | 9 |
| Consumer Cost | 0.10 | 7 | 8 |
| Correctness | 0.10 | 8 | 7 |
| Innovation | 0.05 | 5 | 8 |
| Minimal Footprint | 0.05 | 9 | 7 |
| **Weighted Total** | | **7.60** | **8.15** |

**Decision: SYNTHESIZE** — Neither design clearly dominated. The judge recommended using A's proven, simple foundation with B's best innovations layered on top.

### [SUMMARY.md](SUMMARY.md) — Synthesized Recommendation

The final recommendation takes A's networking stack, rule-based security engine, and explicit code style as the foundation, then layers on B's typed event system, event sourcing audit log, policy propagation, scene engine, anomaly scoring, differential privacy, and discrete event simulator. See SUMMARY.md for the full integration path and open questions.
