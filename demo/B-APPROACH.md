# APPROACH.md -- Experimental Track (Implementor B)

## Design Philosophy

This design pushes the intelligence-to-power ratio by treating the mesh not as a flat network of peers, but as a **neuromorphic hierarchy** -- modeled loosely on biological nervous systems. Leaf nodes are sensory neurons (fire-and-forget signals), edge nodes are spinal reflexes (fast local decisions), hubs are the cortex (pattern recognition, learning), and cloud is extended cognition (deep reasoning when available). Each tier processes and compresses information before escalating, so higher tiers receive semantic signals, not raw data.

The key insight: most smart home systems waste power by shipping raw data upward. This design inverts that -- **intelligence flows downward as policy; data flows upward only as exceptions**.

---

## Decision 1: Mesh Networking Substrate

### Choice: Hybrid -- ESP-NOW for leaf-to-edge + ESP-MESH-LITE (Wi-Fi) for edge-to-hub

No single protocol optimally serves all tiers. The hierarchy naturally splits into two networking domains:

**Leaf tier (Tier 0/1) to Edge tier (Tier 2): ESP-NOW**
- 1ms latency, no connection overhead -- leaf nodes wake, fire a packet, and sleep immediately
- 250-byte payload is sufficient for sensor events (type, value, timestamp, node ID)
- No association/handshake -- critical for battery nodes that sleep 99.9% of the time
- Peer discovery via broadcast on a known channel; edge nodes listen continuously (mains-powered)
- Range: ~200m line-of-sight, ~50m through walls
- Power: ~30uA average for a node that wakes every 10s, vs ~80mA sustained for Wi-Fi mesh participation

**Edge tier (Tier 2) to Hub (Tier 3): ESP-MESH-LITE (Wi-Fi based)**
- Edge nodes are mains-powered -- Wi-Fi power cost is irrelevant
- High bandwidth needed for camera inference results, model updates, telemetry aggregation
- ESP-MESH-LITE is Espressif's production mesh built on Wi-Fi -- self-organizing, self-healing, tree topology
- Hub acts as root node; edge nodes form the mesh tree
- Native IP connectivity means hub can bridge to LAN/cloud without protocol translation

**Why not alternatives:**
- **painlessMesh**: Good for PoC but builds on ESP-IDF's Wi-Fi -- too power-hungry for battery leaves. Also limited throughput and no native IP bridging.
- **Thread/OpenThread**: Excellent protocol but requires 802.15.4 radio (not present on standard ESP32). ESP32-H2 supports it but is immature and limits hardware choices.
- **Zigbee**: Same 802.15.4 hardware issue. Also, Zigbee's application profiles are opinionated and don't map well to our capability-discovery model.
- **BLE Mesh**: High overhead for connection-oriented communication, poor for streaming data, 30+ second provisioning per node.
- **ESP-NOW only**: No multi-hop routing natively. We'd have to build our own routing layer.

**What we give up:** Hybrid means two protocol stacks, two discovery mechanisms, and edge nodes must bridge between them. This adds firmware complexity on Tier 2 nodes. The tradeoff is justified because edge nodes are mains-powered and run on ESP32-S3 with ample flash/RAM.

---

## Decision 2: Distributed Intelligence Architecture

### Choice: Reactive Event Cascade with Downward Policy Propagation

```
Cloud (Tier 4)          <-- Deep reasoning, model training, remote alerts
  | policy/exceptions
Hub (Tier 3)            <-- Behavior learning, pattern aggregation, rule engine
  | semantic events / policies
Edge (Tier 2)           <-- Real-time inference (object detection, audio classification)
  | compressed signals / wake triggers
Smart Leaf (Tier 1)     <-- Signal filtering, threshold detection, keyword spotting
  | raw events
Leaf (Tier 0)           <-- Sense/actuate, report raw values
```

**Key mechanism: Event Cascade**

1. Leaf fires raw event upward (e.g., PIR triggered, door opened)
2. Edge node receives event, runs local inference if capable (e.g., camera captures frame, runs person-detection model)
3. Edge produces semantic event (e.g., "human detected, confidence 0.87, zone: front-door")
4. Hub receives semantic event, evaluates against learned behavior patterns and active rules
5. Hub produces action (e.g., "trigger alert level 2" or "ignore -- matches resident pattern")
6. Hub pushes action downward to relevant actuators

**Key mechanism: Policy Propagation**

Higher tiers push *policies* downward so lower tiers can act autonomously:
- Hub tells edge: "Between 23:00-06:00, any human detection in zone front-door is alert-level-3"
- Edge tells leaf: "Wake camera on PIR trigger only if PIR confidence > threshold"
- This means most events are handled locally without escalation

**Capability Negotiation**

When a node joins, it broadcasts a capability manifest:
```
{
  node_id: uint32,
  tier: uint8,
  capabilities: [CAP_PIR, CAP_CAMERA_RGB, CAP_INFERENCE_PERSON_DETECT, ...],
  power_source: MAINS | BATTERY,
  battery_pct: uint8,
  compute_budget: uint16  // MIPS equivalent, self-reported
}
```

The nearest higher-tier node registers it and assigns it to a **zone** (spatial grouping). Zones are the unit of coordination -- a zone might be "front-door" or "living-room". Zone membership is inferred from which edge node can hear the leaf (signal strength), confirmed by the user if ambiguous.

**Intelligence Composition (Novel)**

When a zone has multiple devices, the edge node composes their capabilities into inference pipelines automatically:
- PIR + Camera = motion-triggered visual classification
- PIR + Door sensor = entry detection with direction inference
- Temp + Humidity + Occupancy = comfort-aware HVAC control
- Microphone + Speaker = voice command loop

The edge node maintains a **capability graph** for its zone and generates composite inference pipelines. Rather than hardcoded automation rules, the system discovers what intelligence is *possible* given available hardware and assembles it.

**Rejected alternatives:**
- **Federated inference** (splitting a model across nodes): Too complex for the latency requirements. A person walks past in 2 seconds -- we can't afford 500ms of inter-node model-fragment coordination.
- **Consensus sensing** (nodes vote on state): Useful for environmental readings (temperature agreement) but too slow for security events. We use it selectively for environmental data, not security.
- **Flat peer intelligence**: Doesn't match hardware reality and wastes power on battery nodes.

---

## Decision 3: Power Budget Tradeoffs

### Choice: Aggressive Sleep with Wake Chains and Predictive Scheduling

| Tier | Power Source | Active | Sleep | Wake Strategy | Role |
|------|-------------|--------|-------|---------------|------|
| 0 | CR2032 / 2xAAA | 80mA | 10uA | Interrupt (GPIO) | Sense, report, sleep |
| 1 | 500mAh LiPo | 160mA | 25uA | Interrupt + periodic (10s) | Filter, threshold, keyword |
| 2 | Mains (5V/2A) | 500mA | N/A | Always on | Inference, coordination |
| 3 | Mains (5V/3A) | 1.5A | N/A | Always on | Learning, aggregation |

**Wake Chains**: When a Tier 0 node fires, it can wake a Tier 1 node via ESP-NOW wake packet. The Tier 1 node can then wake additional sensors in the zone for corroboration. Only the minimum number of nodes are active at any time.

**Battery life estimates:**
- Tier 0 (CR2032, 220mAh): ~8 months at 10 events/hour, 50ms active per event
- Tier 0 (2xAAA, 1200mAh): ~18 months same duty cycle
- Tier 1 (500mAh LiPo): ~5 days with periodic wake + inference; ~14 days with interrupt-only wake

**Novel: Predictive Sleep Scheduling**
The hub learns activity patterns (e.g., "no one comes through the front door between 1am-5am on weekdays") and pushes sleep policies to leaf nodes: "sleep deep 01:00-05:00, wake only on interrupt, skip periodic check-ins." This can extend Tier 1 battery life by 40-60% during predictable quiet periods. The hub uses a simple per-zone hourly activity histogram (7 days x 24 hours = 168 bins) to identify reliably quiet windows.

See `B-POWER-ANALYSIS.md` for full budget.

---

## Decision 4: Security and Anomaly Detection Model

### Choice: Three-Stage Pipeline with Temporal Reasoning and Continuous Anomaly Scoring

**Stage 1 -- Signal (Tier 0/1, <10ms)**
Raw sensor to binary event. PIR fires, door contact opens, glass-break audio detected. No intelligence, just edge detection. Runs on the sensor itself.

**Stage 2 -- Classification (Tier 2, <500ms)**
Sensor event + context to classified entity. Camera frame to "cat" or "human" or "vehicle". Audio clip to "speech" or "glass break" or "ambient". Runs on ESP32-S3 with TFLite Micro. Model: MobileNet-V2 quantized to INT8, ~300KB, ~200ms inference at 240MHz.

**Stage 3 -- Reasoning (Tier 3, <2s)**
Classified events + temporal history + learned patterns to security decision.

The hub maintains a **Temporal Event Graph**: a sliding window of events with timestamps, locations (zones), and classifications. Pattern matching produces decisions:

```
IF human_detected(zone=front_door, time=02:30)
   AND NOT door_unlocked(zone=front_door, window=[-30s, +5s])
   AND NOT resident_pattern_match(time, zone)
THEN alert_level = CRITICAL
     actions = [alarm_on, lights_on(zone=exterior), notify_user, camera_record]
```

**Intruder vs Cat**: Solved at Stage 2. The camera node runs person-vs-pet classification. If PIR triggers but camera classifies "cat", the event is downgraded to informational. If "human" with no matching unlock event, escalate to Stage 3.

**Novel: Continuous Anomaly Score (0.0-1.0)**
Rather than binary "intruder/not-intruder", each event gets a continuous anomaly score based on deviation from learned patterns. The hub learns:
- Typical times of entry/exit per zone
- Typical sequence patterns (door unlock -> door open -> motion -> lights)
- Typical dwell times per zone

Events that deviate get higher anomaly scores. Score > 0.7 triggers soft alert (notification). Score > 0.9 triggers hard alert (alarm). Thresholds are user-adjustable. This eliminates hard-coded rules for normal/abnormal and adapts to each household's patterns over time.

---

## Decision 5: State Synchronization at Scale

### Choice: Event Sourcing with Tier-Appropriate Projections

**Not a flat key-value store.** The existing MeshSwarm PoC synchronizes a KV store across all nodes -- this doesn't scale with heterogeneous nodes that sleep at different times.

**Event Log (Hub, Tier 3)**: The authoritative event log lives on the hub. Every state change is an event with a monotonic sequence number, timestamp, origin node, and payload. The hub persists this to flash (circular buffer, ~1MB, ~24h of events at typical rates).

**Projections (per tier):**
- **Tier 2 (Edge)**: Maintains a zone-scoped projection -- only events relevant to its zone. Subscribes to hub event stream via Wi-Fi mesh. Can operate independently if hub is temporarily unreachable.
- **Tier 1 (Smart Leaf)**: Receives only *policies* and *direct commands* -- never the full event stream. State is push-only from its parent edge node.
- **Tier 0 (Leaf)**: Stateless. Fires events, receives direct commands. No sync overhead.

**Conflict Resolution**: Events are ordered by (hub_sequence_number, origin_node_id). The hub is the single sequencer. If the hub is down, edge nodes buffer events locally with their own sequence numbers; on hub recovery, events are merged using Lamport timestamps and node ID as tiebreaker.

**Consistency Model**: Eventual consistency with causal ordering within a zone. The critical invariant is that actuator commands are idempotent -- applying the same command twice produces the same result.

**Why not CRDT?** CRDTs add complexity for state types beyond simple counters and sets. Event-sourcing gives us a complete audit trail (valuable for security review) and natural compaction (project only what each tier needs).

---

## Decision 6: Connectivity Tiers -- Air-Gapped Local vs Cloud

### Choice: Four Connectivity States with Graceful Capability Stacking

```
State 0: Mesh Only (no hub)
  - Edge nodes coordinate zones independently
  - Basic automation rules (hardcoded defaults)
  - No learning, no history, no cross-zone coordination
  - Security: detect + alert locally (buzzer/lights)

State 1: Hub Available (air-gapped LAN)  [DESIGNED-FOR STATE]
  - Full functionality: learning, pattern recognition, cross-zone coordination
  - Local dashboard via hub's web server
  - Event history, anomaly scoring, behavior learning
  - Voice commands (on-device STT via hub)

State 2: Local Server Available (optional, on-premise)
  - GPU-accelerated inference (better models, faster classification)
  - Longer history retention (disk vs flash)
  - Multi-hub coordination (multiple buildings/floors)

State 3: Cloud Available (optional, explicit opt-in)
  - LLM-powered reasoning for ambiguous situations
  - Remote monitoring and alerts (phone notifications)
  - Model updates and retraining
  - Aggregate anonymized data for improving models (opt-in)
```

Each higher state ADDS capability but NEVER becomes required. The system is designed for State 1 as baseline. Degradation is seamless: if cloud drops, you lose remote notifications but keep all local intelligence. If hub drops, edge nodes keep running zones independently.

---

## Decision 7: Actuator Coordination

### Choice: Zone-Scoped Scenes with Priority Arbitration

**Scenes** are named collections of actuator states: "night-mode", "away-mode", "movie-time", "intruder-alert". Priority levels: SAFETY > CRITICAL > COMFORT > ECO > DEFAULT. Higher-priority scenes override lower when they conflict.

**Actuator Abstraction**: Each actuator node advertises its control interface via capability manifest. The edge/hub sends semantic commands ("lights to 60%") and the actuator translates to its specific protocol (GPIO PWM, IR code, smart plug API, relay toggle).

**IR Blaster Integration**: For legacy devices, a dedicated actuator node with an IR LED learns and replays IR codes. It advertises capabilities dynamically: "I can control: POWER, VOLUME, SOURCE for device 'living-room-tv'". The hub treats it identically to any other actuator.

**Coordination**: Hub (or edge if hub unavailable) is the scene orchestrator. Sends actuator commands in parallel, expects ACK within 2s, retries once on failure, then logs.

---

## Decision 8: Privacy vs Functionality Tradeoff

### Choice: Data Minimization by Design + Differential Privacy for Cloud

**Core principle: Process at the lowest tier possible; transmit summaries, not raw data.**

| Data Type | Generated At | Processed At | Stored At | Leaves Device? |
|-----------|-------------|-------------|-----------|----------------|
| Camera frames | Tier 2 | Tier 2 | Never stored | NO -- only classification results propagate |
| Audio | Tier 1/2 | Tier 1/2 | Never stored | NO -- only transcription/classification |
| PIR events | Tier 0 | Tier 2 | Hub event log | Event metadata only |
| Presence patterns | Hub (derived) | Hub | Hub (encrypted) | Only with explicit cloud opt-in |
| Temp/humidity | Tier 0 | Hub | Hub time series | Only with explicit cloud opt-in |

**Camera frames never leave the camera node** -- this is a hard architectural constraint, not a configuration option. The ESP32-S3 captures, classifies, and discards.

**Novel: Differential Privacy for Cloud Opt-In**
If the user opts into cloud model improvement, the system applies local differential privacy to behavioral patterns before transmission. Instead of "resident arrives at 17:32 daily", it sends a noised histogram: "activity spike in zone front-door between 17:00-18:00, noise epsilon=1.0". This provides statistical utility while making individual behavior reconstruction infeasible.

**Physical Capture Threat Model:**
- Hub storage encrypted at rest (AES-256, key from user passphrase + hardware ID)
- Leaf/edge nodes store no persistent sensitive data
- If a leaf is captured: attacker gets mesh network key but no user data. Mitigation: key rotation, node revocation via hub.
- Mesh encryption: ESP-NOW uses CCMP (AES-128), Wi-Fi mesh uses WPA2, both enabled by default.

---

## Decision 9: Consumer Cost Optimization

### Choice: Commodity ESP32 Modules with Aggressive Tier Differentiation

| Tier | Target Hardware | Est. BOM |
|------|----------------|----------|
| 0 - Leaf | ESP32-C3 Mini + sensor + battery | $4-6 |
| 1 - Smart Leaf | ESP32-S3 Mini + mic + LiPo | $8-12 |
| 2 - Edge | ESP32-S3 + OV2640 + PSRAM + PSU | $12-18 |
| 3 - Hub | ESP32-S3-WROOM-1 N16R8 + SD + PSU | $20-30 |
| Actuator | ESP32-C3 + relay/IR LED + PSU | $5-10 |

**Starter (1 room):** Hub + camera + 2 PIR + door sensor + smart plug = ~$63
**Full home (3-bedroom):** Hub + 4 cameras + 6 PIR + 8 door/window + 4 temp + 2 mic + 6 actuators = ~$247
**Add a room:** ~$30-40 incremental

See `B-COST-ANALYSIS.md` for detailed BOM and component choices.

---

## Summary of Experimental Choices

| Decision | Conventional | Our Choice | Risk |
|----------|-------------|------------|------|
| Mesh protocol | Single protocol (painlessMesh) | Hybrid ESP-NOW + ESP-MESH-LITE | Medium |
| Intelligence | Flat, all nodes equal | Neuromorphic hierarchy with event cascade | Low |
| State sync | Full KV replication | Event sourcing with tier-appropriate projections | Medium |
| Anomaly detection | Rule-based binary | Continuous anomaly scoring with temporal graphs | Medium |
| Power | Fixed duty cycles | Predictive sleep scheduling from learned patterns | High |
| Privacy | Encrypt and hope | Frames never leave device + differential privacy | Low |
| Capability discovery | Manual configuration | Automatic composition from capability manifests | Medium |
