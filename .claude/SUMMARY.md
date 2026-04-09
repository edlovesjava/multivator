# MeshSwarm RFP — Team Summary

## Outcome: SYNTHESIZE

Neither design clearly dominated. The judge scored **A: 7.60** vs **B: 8.15** (weighted) and recommended synthesizing both — using A's proven, simple foundation with B's best innovations layered on top.

## Verdict: Full details in [VERDICT.md](VERDICT.md)

## The Synthesized Design

**Foundation from A (Conservative):**
- ESP-NOW (leaf→edge) + Wi-Fi direct (edge→hub) — no risky ESP-MESH-LITE
- Rule-based security engine with explicit state machine — works from day 1
- Hub-and-spoke state sync with flat KV store — simple, verifiable
- Flat 12-byte message format — minimal overhead
- Explicit C++ style — no templates, no RTTI, no exceptions

**Enhancements from B (Experimental):**
- Typed event system (MotionEvent, PersonDetectionEvent, etc.) — compile-time safety
- Event sourcing as audit log alongside KV state — for post-incident review
- Downward policy propagation — hub pushes sleep/alert/inference policies to lower tiers
- Scene engine with priority arbitration (SAFETY > CRITICAL > COMFORT > ECO)
- Anomaly scoring as advisory annotation (not decision-maker)
- Differential privacy for cloud opt-in data
- Discrete event simulator + property-based tests

**Excluded from B:**
- ESP-MESH-LITE (too risky)
- Automatic capability composition (too complex for V1)
- Predictive sleep as default (opt-in only after 14+ day learning)
- Builder pattern / lambda handlers (too complex for embedded)

## Gaps Identified by Judge

1. OTA firmware update protocol unspecified
2. Time synchronization in air-gapped mode
3. User interface design (setup, monitoring, configuration)
4. Household member identification (known vs unknown person)
5. Regulatory/safety (FCC/CE, mains relay safety)
6. Hub single point of failure — no automatic promotion
7. Camera low-light performance for night security

## Key Open Questions

- Should the hub be a Raspberry Pi instead of ESP32?
- ESP-NOW 20-peer encryption limit in large deployments?
- Bootstrap mode behavior during first 7 days?
- Voice nodes: battery or mains?
- Firmware versioning across heterogeneous node types?

## Recommended Next Steps

1. Decide hub hardware (ESP32-S3 vs RPi Zero 2 W)
2. Build the synthesized architecture starting from A's codebase
3. Prototype the intruder-vs-cat and settling-in-vs-passing-through scenarios
4. Design the user setup experience
5. Address OTA and time sync before scaling beyond PoC
