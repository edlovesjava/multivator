# RFP: MeshSwarm — Self-Organizing AIoT Mesh Network

## Problem Statement

We need an intelligent, self-organizing mesh network for smart home security and environmental control. The core principle is **distributing intelligence across a hierarchy of devices** — from low-power/low-cost sensors and actuators at the edge, through smarter aggregation nodes on mains power, up to cloud services (including Claude) for complex reasoning.

The vision: you plug in a smarter device and it automatically discovers, coordinates, and elevates the capabilities of the dumber devices around it. A presence sensor on its own just detects motion. Paired with a camera node it can distinguish a cat from a human. Connected to a mains-powered hub with more compute, it can learn normal behavior patterns and flag a potential break-in. Escalated to cloud, it can reason about ambiguous situations and coordinate a response.

The mesh layer currently exists as a PoC ([MeshSwarm](https://github.com/edlovesjava/MeshSwarm), [iotmesh](https://github.com/edlovesjava/iotmesh)) using painlessMesh on ESP32. But the networking substrate is an open question — Zigbee, Thread, custom ESP32 mesh, or a hybrid are all valid. The implementors should evaluate and justify their choice.

### Primary Use Case: Smart Home Security & Environment

A network of heterogeneous devices providing:
- **Security**: cameras with object detection (cat vs human), presence/motion detection, door/window sensors, distinguishing normal behavior from unusual activity (potential break-in), alert/alarm actuation
- **Environmental control**: temperature/humidity sensing, soil moisture, HVAC control (raise/lower temp), lighting, volume control
- **Voice interaction**: speech-to-text, voice command invocation of actuators
- **Intelligence hierarchy**: local edge inference where possible, escalation to more capable nodes or cloud when needed

## Requirements

### Must Have
- [ ] Self-organizing mesh: nodes discover peers, negotiate roles, and form a network with zero manual configuration
- [ ] Self-healing: network recovers from node failures, reroutes, re-elects coordinators automatically
- [ ] Capability discovery: nodes advertise what they can do (sense, actuate, compute) and the network utilizes them accordingly
- [ ] Intelligence tiering: distribute processing appropriate to each node's power and compute budget
  - **Tier 0 — Leaf nodes**: long-duration battery (months), minimal function — sense/actuate and report, sleep aggressively
  - **Tier 1 — Smart leaf nodes**: shorter battery life (days/weeks), more function — signal filtering, basic object detection, limited vocabulary voice recognition
  - **Tier 2 — Edge nodes**: mains-powered, local inference — camera object detection (cat vs human), pattern recognition, coordinate nearby leaf nodes
  - **Tier 3 — Hub/Gateway**: mains-powered with more compute, aggregation, behavior learning, offline reasoning — must function fully air-gapped
  - **Tier 4 — Cloud/Server** (optional): most powerful reasoning, remote monitoring, model updates — enhances but never required
- [ ] Distributed state synchronization across nodes with deterministic conflict resolution
- [ ] Smart home security: detect presence, distinguish animal from human, identify normal vs suspicious patterns, trigger alerts
- [ ] Environmental sensing and actuation: read sensors, control actuators (light switches, HVAC temperature, media device volume/power via IR or smart control, alarms)
- [ ] ESP32-based (ESP32, ESP32-S3, ESP32-C3 variants)
- [ ] Clean API: adding a new sensor or actuator node type should be straightforward

### Should Have
- [ ] Power optimization for battery leaf nodes (deep sleep, wake-on-event, minimal mesh participation)
- [ ] Camera integration with lightweight on-device object detection (person vs pet vs vehicle)
- [ ] Voice interaction: limited vocabulary recognition at edge tier, fuller speech-to-text at hub tier, voice-triggered actuator invocation
- [ ] OTA firmware updates propagated through the mesh
- [ ] Security: encrypted mesh traffic, node authentication
- [ ] Gateway redundancy and failover
- [ ] Telemetry aggregation and trend detection at hub tier
- [ ] Optional cloud/server connectivity for enhanced reasoning and remote monitoring (system must work without it)

### Must Not
- [ ] Must not require cloud connectivity for basic mesh operation and local automation
- [ ] Must not require manual device pairing or network configuration
- [ ] Must not assume all nodes are equivalent — the design must handle heterogeneous capabilities gracefully
- [ ] Must not send user data (camera feeds, presence patterns, sensor readings) off the local network without explicit user opt-in
- [ ] Must not create persistent external connections that expand the attack surface when running air-gapped
- [ ] Must not fail catastrophically on power interruption or connectivity loss — must recover gracefully with no data leakage

## Evaluation Priorities

The winning implementation maximizes intelligence while minimizing power consumption for equivalent response time. Implementations are judged on:

- [x] **Intelligence-to-power ratio** — the primary metric. For a given scenario, which implementation delivers smarter behavior using less energy? Smarter detection at lower power wins.
- [x] **Ease of use and setup** — plug in a device and it works. Zero configuration. A non-technical person should be able to add a node.
- [x] **Scenario test quality** — implementations must demonstrate concrete, testable scenarios:
  - **Intruder vs cat**: PIR triggers, camera activates — system correctly distinguishes human intruder from pet. Alert on intruder, ignore the cat.
  - **Presence intent — settling in vs passing through**: Person enters a room and sits down → system activates their preferences (lighting, temperature, media). Person walks in briefly to grab keys and leaves → system does not activate preferences. The system must infer intent from behavior duration/pattern, not just presence.
- [x] **Privacy and resilience** — the system must protect user data by default. No data leaves the local network unless the user explicitly opts in. Must handle intermittent power and connectivity interruptions gracefully without data loss or exposing attack surface. Every external connection is a risk vector for hackers and data marketers — the architecture should minimize these by design, not by configuration.
- [x] **Consumer cost** — total system cost matters. Evaluate BOM cost per node tier, total cost for a realistic deployment (e.g., 3-bedroom home), and cost to add incremental capability. Cheaper at equivalent functionality wins.
- [x] **Correctness** — self-healing, capability discovery, and state convergence must work reliably under failure scenarios
- [ ] **Innovation** — novel approaches to intelligence distribution and presence intent are valued
- [ ] **Minimal footprint** — leaf nodes are constrained; hub nodes less so

## Open Design Decisions

These are genuinely open. Implementors should explore the solution space, justify their choices, and explain why alternatives were rejected or deemed not applicable.

1. **Mesh networking substrate**: painlessMesh (current PoC), Zigbee, Thread, ESP-NOW, a hybrid approach, or something else entirely. What are the tradeoffs for a heterogeneous device network? Is one mesh protocol sufficient or does the hierarchy need different protocols at different tiers?

2. **Distributed intelligence architecture**: Intelligence is distributed across power/capability tiers. Low-power devices handle specialty tasks (signal-to-noise filtering, basic object detection, limited vocabulary voice recognition). Higher-power local nodes handle more complex reasoning but remain offline-capable (air-gapped). Cloud/server connectivity enables the most powerful reasoning but must not be required. How does the system compose intelligence across these tiers? How does a capable node discover and leverage nearby less-capable nodes? How do nodes negotiate who handles which inference tasks?

3. **Power budget tradeoffs**: Devices span a spectrum from long-duration low-power battery (months on coin cell, minimal function) through shorter-battery higher-function (days/weeks, more sensing/compute) to mains-powered (always-on, full capability). How does the architecture handle this spectrum? What capabilities are practical at each power tier? How does a device's power budget determine its role in the mesh?

4. **Security and anomaly detection model**: How to go from raw sensor data (PIR trigger, camera frame, door sensor) to actionable security intelligence (this is a cat, this is normal, this might be a break-in)? Where does each stage of that inference pipeline run?

5. **State synchronization at scale**: How to keep distributed state consistent across heterogeneous nodes with different wake cycles, compute budgets, and network connectivity? Broadcast, gossip, delta-sync, event sourcing, or something else?

6. **Connectivity tiers — air-gapped local vs cloud**: The system must function fully offline (air-gapped local network). Cloud/server connectivity is an optional enhancement for more powerful reasoning, remote monitoring, and model updates. How does the system degrade gracefully across connectivity states: fully air-gapped → local server available → cloud available? What capabilities are unlocked at each level?

7. **Actuator coordination**: The system controls real-world actuators: light switches, HVAC (raise/lower temperature), media device remote control (volume, source, power), alarms, cameras, door locks. When a security event or automation rule triggers, how are responses coordinated across multiple actuators? Who orchestrates? How are actuator capabilities discovered and abstracted (e.g., IR blaster for legacy devices vs smart switch vs relay)?

8. **Privacy vs functionality tradeoff**: The system handles sensitive data (camera feeds, presence patterns, daily routines). How is privacy preserved by default? What data never leaves the device, what stays on the local mesh, and what (if anything) goes to cloud? How does the system resist compromise — if one node is physically captured or a network boundary is breached? How does it handle intermittent power loss or connectivity interruptions without leaking state or creating exploitable windows? What functionality is the user giving up to maintain full privacy, and how is that tradeoff made transparent?

9. **Consumer cost optimization**: What is the minimum viable hardware at each tier? Can commodity off-the-shelf components be used? What is the realistic total cost for a starter deployment and for a full-home deployment? How does the architecture minimize cost without sacrificing the core value proposition?

## Constraints

### Hard Constraints
- Platform: ESP32 family (ESP-IDF / Arduino framework)
- Language: C++ (Arduino-compatible)
- Must compile with PlatformIO
- Must support heterogeneous node hardware (from ESP32-C3 Mini to ESP32-S3 with camera)

### Soft Constraints
- Prefer: leveraging existing proven protocols (Zigbee, Thread) over fully custom networking — but justify either direction
- Prefer: compile-time feature selection so leaf nodes don't carry hub-tier code
- Avoid if possible: dynamic memory allocation in hot paths on constrained nodes
- Avoid if possible: designs that require all nodes to run the same firmware

## Definition of Done

### Core
- [ ] At least 3 node types demonstrated: leaf sensor (battery, e.g. PIR or door sensor), edge node (mains, e.g. camera + local inference), hub/gateway (aggregation + offline reasoning)
- [ ] Plug-in discovery works: powering on a new node results in automatic mesh join and capability advertisement within 30 seconds
- [ ] Self-healing demonstrated: network recovers from any single node failure within 15 seconds
- [ ] System operates fully air-gapped; optional cloud connectivity demonstrated as enhancement (even if mocked)

### Scenario Tests
- [ ] **Intruder vs cat**: motion detected → camera activated → object classified → intruder triggers alarm/notification, cat is ignored. Must pass reliably with test images/simulated input.
- [ ] **Settling in vs passing through**: person enters room and remains >N minutes → room preferences activated (lights, temp, media). Person enters and leaves within <N minutes → no preference activation. The threshold/approach and how intent is inferred is an open design decision.
- [ ] **Environmental control**: temperature exceeds threshold → HVAC actuator adjusts. Occupant leaves room → system returns to energy-saving state.

### Power & Intelligence
- [ ] Battery leaf node achieves >24 hours on 500mAh LiPo
- [ ] Power consumption measured and documented per node tier for each scenario
- [ ] Intelligence-to-power analysis: for each scenario, document what inference runs where, energy cost, and response time

### Privacy & Resilience
- [ ] Privacy audit: document what data exists at each tier, where it is stored, what leaves the device, what leaves the mesh — default must be "nothing leaves local network"
- [ ] Resilience test: system recovers correctly from sudden power loss mid-operation (no corrupt state, no data leakage)
- [ ] Resilience test: system handles intermittent connectivity (mesh fragmentation, gateway offline) without exposing attack surface
- [ ] Threat model documented: what happens if a node is physically captured? If the mesh is sniffed? If a rogue node joins?

### Cost
- [ ] BOM cost per node tier documented with specific components
- [ ] Total cost estimate for starter deployment (e.g., 1 room: hub + 2-3 sensors + 1 actuator)
- [ ] Total cost estimate for full home deployment (e.g., 3-bedroom: hub + sensors/actuators per room)
- [ ] Cost-per-added-capability analysis (what does it cost to add one more room, one more sensor type?)

### Quality
- [ ] Unit tests for state sync, capability discovery, and presence-intent logic (runnable on host)
- [ ] Integration test for mesh healing and coordinator election
- [ ] Architecture documented: what runs where, why, and how the tiers interact
- [ ] Setup documented: a new user can go from unboxing to working system with minimal steps

## Context

### Relevant files / modules
- `MeshSwarm` repo — existing mesh library (core mesh, state, election, watchers)
- `iotmesh` repo — PoC with example node types (button, LED, observer, PIR, DHT11)
- Ideabase concept docs:
  - `ideeabase/projects/aiot/infrastructure/mesh-swarm.md` — current mesh design
  - `ideeabase/projects/aiot/health-hub/health-hub-concept.md` — hub/gateway concept
  - `ideeabase/ideas/aiot/exploration-directions.md` — edge AI directions
  - `ideeabase/ideas/concepts/fingertop-computing.md` — wearable integration context
  - `ideeabase/ideas/concepts/smart-fabrics.md` — distributed sensing context

### Prior art / failed approaches
- ESP-NOW peer-to-peer: works for 1:1 but doesn't scale, no multi-hop, no discovery
- BLE to phone/hub: range limited, requires explicit pairing, phone dependency
- painlessMesh PoC: works for basic mesh but doesn't address intelligence tiering, power heterogeneity, or security use cases

### Edge AI directions (from ideabase — inform architecture, implement what's feasible)
- Distributed anomaly detection: each node detects locally, shares alerts via state
- Consensus sensing: multiple nodes vote on environmental state
- Swarm coordination: emergent behavior from local rules + shared state
- Federated inference: split model across nodes, aggregate at hub
