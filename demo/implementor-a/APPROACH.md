# APPROACH.md — Conservative Track (Implementor A)

## Design Philosophy

This design prioritizes **proven protocols, minimal complexity, deterministic behavior, and maximum reliability**. Every choice favors battle-tested technology over novel approaches, explicit logic over clever abstractions, and predictable failure modes over optimistic architectures.

---

## Design Decisions

### 1. Mesh Networking Substrate

**Choice: ESP-NOW for leaf-to-edge communication + Wi-Fi for edge/hub/cloud connectivity**

ESP-NOW is ESP32-native, requires no external radio hardware, operates on the 2.4 GHz band with low latency (~1ms), supports broadcast and unicast, and has been shipping in production ESP32 firmware for years. It avoids the complexity of a full mesh routing stack on constrained Tier 0/1 nodes.

**Architecture:**
- **Tier 0/1 (leaf nodes)** use ESP-NOW to send reports to their nearest Tier 2 edge node. They do not participate in mesh routing. They wake, transmit, and sleep.
- **Tier 2 (edge nodes)** act as ESP-NOW receivers and Wi-Fi clients. They aggregate leaf data and forward to the hub over the local Wi-Fi network.
- **Tier 3 (hub)** runs on Wi-Fi, receives from edge nodes, and optionally connects to Tier 4 cloud.
- **Discovery** uses ESP-NOW broadcast: leaf nodes broadcast a capability advertisement on boot; edge nodes listen and register them.

**Why not painlessMesh?** painlessMesh requires all nodes to maintain the mesh topology, which is expensive for battery nodes. It does not support deep sleep well — rejoining the mesh takes seconds and significant power. It's fine for always-on nodes but incompatible with months-long battery life.

**Why not Zigbee/Thread?** These require additional radio hardware (e.g., 802.15.4 transceiver) since ESP32 has only 2.4 GHz Wi-Fi/BLE radios. The ESP32-H2 supports Thread natively, but it lacks Wi-Fi, making it unsuitable as an edge node. Adding a Zigbee coordinator (e.g., CC2652) to the hub adds cost and complexity. For a system already committed to ESP32, using ESP32-native protocols is simpler and cheaper.

**Why not BLE Mesh?** BLE Mesh on ESP32 is functional but has higher latency, limited throughput, and the ESP-IDF BLE Mesh stack is large (~200KB flash). ESP-NOW achieves the same goals with a fraction of the footprint.

**Alternatives rejected:**
- Full mesh on all tiers: unnecessary power drain on leaves
- Thread + border router: requires ESP32-H2 or external 802.15.4 radio
- Hybrid Zigbee + Wi-Fi: two radio stacks, double the complexity

---

### 2. Distributed Intelligence Architecture

**Choice: Hierarchical pipeline with explicit escalation**

Intelligence is not distributed as a peer network. It flows upward through a fixed pipeline:

```
Tier 0/1 (sense/filter) → Tier 2 (classify/correlate) → Tier 3 (reason/decide) → Tier 4 (enhance)
```

Each tier has a **fixed, compile-time-determined** set of capabilities. There is no dynamic task negotiation or runtime capability discovery for inference — only for sensor/actuator registration.

- **Tier 0/1** runs threshold filters and signal conditioning (e.g., PIR debounce, temperature averaging). Output: events ("motion detected", "temp=23.5C").
- **Tier 2** runs lightweight inference (e.g., TFLite Micro person detection on ESP32-S3 with camera). Output: classified events ("person detected", "cat detected").
- **Tier 3** runs temporal reasoning (e.g., presence duration tracking, behavior pattern matching against known routines). Output: decisions ("intruder alert", "activate room preferences").
- **Tier 4** (optional) runs complex reasoning, model updates, remote monitoring.

**Escalation logic** is simple: if a tier cannot resolve an event with sufficient confidence, it forwards the event plus context to the next tier up. Confidence thresholds are compile-time configurable.

**Why not dynamic task negotiation?** Dynamic negotiation requires consensus protocols, adds latency, and creates hard-to-debug failure modes. In a home security system, deterministic behavior is worth more than flexibility. A PIR sensor should always send its events to the same edge node, not negotiate at runtime which peer should handle it.

**Why not federated inference?** Splitting a model across multiple ESP32s requires reliable low-latency inter-node communication during inference. ESP-NOW's ~250 byte payload and potential packet loss make this impractical. Better to run complete small models on capable nodes than partial large models across unreliable links.

---

### 3. Power Budget Tradeoffs

**Choice: Aggressive sleep with scheduled wake windows**

See `POWER-ANALYSIS.md` for full budget. Summary:

- **Tier 0**: Deep sleep with GPIO wake (PIR interrupt, reed switch). Wake → read → transmit → sleep. Target: 6-12 months on 2xAA or CR123A.
- **Tier 1**: Deep sleep with periodic wake (e.g., every 5s for audio sampling). Target: 1-4 weeks on 500mAh LiPo.
- **Tier 2**: Always-on, mains-powered. No power optimization needed.
- **Tier 3**: Always-on, mains-powered. No power optimization needed.

**Key tradeoff**: Tier 0/1 nodes do NOT maintain any mesh state. They are fire-and-forget transmitters. This means they cannot receive commands (e.g., OTA updates) unless they have a scheduled listen window. The conservative choice is to have Tier 0 nodes wake periodically (e.g., once per hour) and listen for 100ms for any pending commands. This costs minimal power but enables OTA and configuration updates.

---

### 4. Security and Anomaly Detection Model

**Choice: Pipeline classification with explicit state machine**

The detection pipeline:

1. **Tier 0/1 — Event generation**: PIR triggers, door sensor open/close, camera motion detect. Raw events with timestamps.
2. **Tier 2 — Object classification**: ESP32-S3 runs TFLite Micro person detection model (~250KB). Binary output: person/not-person. No cloud dependency.
3. **Tier 3 — Behavior reasoning**: State machine tracks room occupancy and event sequences.
   - **Intruder detection**: PIR trigger + person-classified + no recognized BLE beacon from household member → escalate to alert.
   - **Cat vs human**: PIR trigger + not-person-classified → suppress alert.
   - **Settling in vs passing through**: Presence duration timer. If person remains in room >N minutes (configurable, default 3), trigger room preference activation. If person leaves within N minutes, no activation.

The state machine is explicit, readable C++ with named states and transitions. No ML for behavior reasoning at Tier 3 — just rules and timers. This is deliberate: rule-based logic is debuggable, testable, and predictable. ML-based behavior learning is deferred to Tier 4 as an optional enhancement.

**Anomaly detection**: The hub maintains a rolling histogram of event frequency per room per hour-of-day (7 days, 24 hours = 168 bins per room). Events outside 2 standard deviations of the historical mean trigger an "unusual activity" flag. This is simple, statistically grounded, and requires minimal storage.

---

### 5. State Synchronization at Scale

**Choice: Hub-and-spoke with versioned key-value store**

State synchronization is NOT peer-to-peer. The hub (Tier 3) is the single source of truth.

- Leaf/edge nodes **push** state updates to the hub (via ESP-NOW → edge → Wi-Fi → hub).
- The hub **pushes** relevant state to edge nodes (via Wi-Fi).
- Edge nodes **push** relevant state to leaf nodes during their listen windows (via ESP-NOW).

Each state entry is a key-value pair with:
- `key`: string (e.g., "room.living.temp", "room.living.occupied")
- `value`: serialized value (int, float, bool, string)
- `version`: monotonically increasing uint32, assigned by hub
- `origin`: node ID that produced the value
- `timestamp`: hub-assigned timestamp (hub is time authority)

**Conflict resolution**: Hub always wins. If two nodes update the same key, the hub applies last-writer-wins with hub-ordered timestamps. This is simple and deterministic.

**Why not gossip/CRDT?** Gossip protocols assume always-on peers and converge probabilistically. CRDTs add implementation complexity. For a home network with <100 nodes and a reliable mains-powered hub, hub-and-spoke is simpler and faster to converge.

**Why not the existing MeshSwarm distributed state?** MeshSwarm's peer-to-peer state sync assumes all nodes participate equally. This conflicts with Tier 0/1 nodes that sleep 99.9% of the time. Hub-and-spoke accommodates heterogeneous wake cycles naturally.

**Scale limit**: This architecture comfortably handles ~100 nodes with ~1000 state keys. Beyond that, partition state by room/zone. For a home deployment, this is more than sufficient.

---

### 6. Connectivity Tiers — Air-Gapped Local vs Cloud

**Choice: Three discrete connectivity modes with explicit capability gates**

| Mode | What Works | What Doesn't |
|------|-----------|--------------|
| **Air-gapped** (no internet) | All sensing, classification, rule-based automation, alerts (local siren/display) | Remote notifications, cloud reasoning, model updates |
| **Local server** (LAN server available) | Above + richer UI dashboard, longer-term data storage, more complex reasoning models | Remote access, push notifications to phone |
| **Cloud connected** (internet available) | Above + remote monitoring, push notifications, cloud AI reasoning, OTA model updates | — |

The system **starts air-gapped** and each connectivity tier is additive. There is no "degraded mode" — each mode is a complete, functional system. Cloud adds capabilities; it never replaces local ones.

**Implementation**: The hub has a `connectivity_state` enum: `AIR_GAPPED`, `LAN_SERVER`, `CLOUD`. Feature gates check this state. Cloud features are compiled in but gated at runtime. Air-gapped operation is the default and requires no configuration.

---

### 7. Actuator Coordination

**Choice: Hub-orchestrated command dispatch with actuator capability registry**

Actuators register with the hub at boot, advertising their capabilities:

```
{ "node_id": 42, "type": "actuator", "capabilities": ["light.switch", "light.dim"], "room": "living" }
```

When a rule or decision triggers an action (e.g., "activate living room preferences"), the hub:
1. Looks up actuators in the target room from its registry.
2. Constructs commands for each actuator based on its capability type.
3. Sends commands via the edge node → ESP-NOW path.
4. Waits for acknowledgment (with timeout and retry).

**Coordination is sequential and deterministic**: the hub sends commands one at a time with confirmation. No distributed transaction, no two-phase commit. If an actuator doesn't respond after 3 retries, the hub logs a failure and continues with the remaining actuators.

**Actuator abstraction**: Each actuator type implements a simple interface: `execute(command)` → `ack/nack`. The hub doesn't know how an IR blaster works vs a smart relay — it just sends the command to the right capability endpoint.

---

### 8. Privacy vs Functionality Tradeoff

**Choice: Privacy-by-default with explicit opt-in for each data flow**

See `PRIVACY-ANALYSIS.md` for full data flow audit. Summary:

- **Camera frames never leave the device**. The ESP32-S3 camera node runs classification locally and outputs only classification results ("person", "cat", "no detection"). Raw frames are discarded after processing. No frame buffer is stored.
- **Presence data stays on the local mesh**. Room occupancy state is synced to the hub but never transmitted externally.
- **The hub stores only aggregate data**: event counts, hourly histograms, current state. No raw sensor streams are persisted.
- **Cloud connectivity is opt-in per data type**: the user explicitly selects which data categories (alerts, environmental summaries, presence patterns) can be sent to cloud.
- **No persistent external connections**: cloud sync is push-only on event, not a persistent WebSocket or MQTT connection. The hub initiates HTTPS POST requests to a configured endpoint. No inbound connections from the internet.

**Physical capture threat**: If a node is physically captured, it contains only its own state (current sensor reading, node credentials). It does not contain mesh-wide state, other nodes' data, or encryption keys for other nodes. Each node has a unique pre-shared key for ESP-NOW encryption with its parent edge node.

---

### 9. Consumer Cost Optimization

**Choice: Commodity ESP32 modules with minimal external components**

See `COST-ANALYSIS.md` for full BOM. Summary:

| Tier | Representative Hardware | Estimated Unit Cost |
|------|------------------------|-------------------|
| Tier 0 | ESP32-C3 Mini + PIR/reed switch + 2xAA battery holder | $4-6 |
| Tier 1 | ESP32-S3 + PDM microphone + LiPo + charge circuit | $10-15 |
| Tier 2 | ESP32-S3-CAM + OV2640 camera + USB-C power | $8-12 |
| Tier 3 | ESP32-S3 + microSD + Ethernet (optional) + USB-C power | $12-18 |

**Starter deployment** (1 room): 1 hub + 1 camera + 2 PIR sensors + 1 smart relay = ~$35-50
**Full home** (3-bedroom): 1 hub + 3 cameras + 8 PIR sensors + 4 door sensors + 3 relays + 2 temp sensors = ~$110-170

These costs assume purchasing development modules (e.g., Seeed XIAO ESP32-S3). Custom PCBs would reduce per-unit cost by ~30% at volume (>100 units).

---

## Summary of Conservative Choices

| Decision | Conservative Choice | Why |
|----------|-------------------|-----|
| Mesh | ESP-NOW + Wi-Fi (no external radios) | Native to ESP32, proven, no extra hardware |
| Intelligence | Fixed pipeline, no dynamic negotiation | Deterministic, debuggable |
| Detection | Rule-based state machine at hub | Testable, predictable, no training data needed |
| State sync | Hub-and-spoke, not peer-to-peer | Simple, works with sleeping nodes |
| Privacy | Frames never leave device, opt-in cloud | Strongest default privacy posture |
| Connectivity | Air-gapped default, additive cloud | No dependency on external services |
| Cost | Commodity ESP32 modules | Lowest possible BOM |
