# SELF-REVIEW.md — Conservative Track (Implementor A)

## Honest Self-Assessment

### What This Design Does Well

1. **Predictability**: Every behavior is deterministic. Rule-based security decisions, fixed pipeline intelligence, hub-and-spoke state — there are no probabilistic consensus protocols or dynamic negotiations that could produce surprising behavior. For a home security system, this is the right default.

2. **Power efficiency**: By eliminating mesh participation for Tier 0 nodes entirely (ESP-NOW fire-and-forget instead of mesh routing), battery life is maximized. The theoretical numbers are extreme (years on AA batteries) because there is genuinely almost nothing for a leaf node to do between events.

3. **Privacy posture**: Camera frames never leaving the device is a strong, simple guarantee. There's no "well, it only sends frames when..." conditional. It never sends frames. Period. This is easy to audit and easy to trust.

4. **Testability**: The clear separation of logic from hardware means >80% of tests run on a development machine in <30 seconds. This enables fast iteration and CI.

5. **Cost**: Using only ESP32-native protocols (no additional radio hardware) keeps the BOM at commodity levels. A full home deployment under $250 is competitive.

---

### Weaknesses of the Conservative Approach

#### 1. Hub is a Single Point of Failure

The hub-and-spoke architecture means the hub is critical. If the hub dies:
- No new security decisions are made (edge nodes still classify, but nobody acts on it)
- No state synchronization between edge nodes
- No actuator coordination
- Leaf nodes keep sensing and transmitting to edge nodes, but events accumulate with no response

**Mitigation considered but not adopted**: Hub redundancy (two hubs with leader election). Rejected because it doubles the most expensive node and adds consensus complexity. The conservative bet is that a mains-powered hub with a robust watchdog timer and auto-restart is sufficiently reliable for a home deployment.

**Where the experimental track might do better**: A more distributed architecture where edge nodes can make autonomous security decisions (not just classify) would be more resilient. If the experimental approach distributes the SecurityEngine across Tier 2 nodes, it eliminates the SPOF.

#### 2. No Learning / Adaptation

The rule-based security engine has a fixed settling-in threshold (default 3 minutes). It doesn't learn that the user always spends exactly 45 seconds in the kitchen to make coffee, or that they settle into the living room within 90 seconds. The anomaly histogram detects statistical outliers but doesn't adapt thresholds.

**Where the experimental track might do better**: If it implements online learning at the hub (even simple approaches like adjusting thresholds based on historical patterns), it will deliver more intelligent behavior over time. My design's intelligence is static — it works on day 1 exactly as well as it works on day 365.

#### 3. ESP-NOW Limitations

ESP-NOW has a maximum payload of 250 bytes, supports up to 20 encrypted peers per node, and has no built-in routing (point-to-point or broadcast only). This means:

- **No multi-hop**: A leaf node must be within direct radio range of an edge node. In a large home, this might require additional edge nodes as relays, increasing cost.
- **20-peer limit**: An edge node can have at most 20 encrypted leaf nodes. For most homes this is fine, but a large deployment needs multiple edge nodes.
- **No mesh self-healing at the leaf level**: If a leaf node's parent edge node dies, the leaf has no way to discover an alternative. It will keep transmitting to a dead peer until it's manually reassigned or the edge node comes back.

**Where the experimental track might do better**: A true mesh protocol (Thread, BLE Mesh, or even painlessMesh for always-on nodes) provides multi-hop routing, automatic path discovery, and self-healing at the mesh layer. This is genuinely more resilient for leaf nodes in large deployments.

#### 4. No Dynamic Capability Negotiation

Intelligence is fixed at compile time. A Tier 2 edge node always runs person detection. It can't dynamically decide to offload inference to a nearby Tier 3 hub if the hub has spare capacity, or to another edge node that happens to be idle.

**Where the experimental track might do better**: Dynamic task assignment could better utilize available compute across the network. If one edge node is processing a camera frame and another PIR event arrives, the second event could be routed to an idle edge node. My design simply queues it.

#### 5. Limited Voice Interaction

The conservative approach uses PIR-triggered voice listening with a small keyword vocabulary. This is power-efficient but means voice commands only work when someone is moving in a room. A person lying on the couch saying "lights off" might not trigger the PIR, leaving the mic inactive.

**Where the experimental track might do better**: Always-on low-power voice activity detection (VAD) at the cost of shorter battery life, or a mains-powered voice node that listens continuously.

---

### Tradeoffs I Made Deliberately

| Tradeoff | Chose | Over | Because |
|----------|-------|------|---------|
| Hub centralization | Simplicity | Resilience | A home hub rarely fails; complexity costs more than occasional downtime |
| Rule-based detection | Debuggability | Adaptability | Users can understand and tune explicit rules; ML is a black box |
| ESP-NOW | Low power + simplicity | Multi-hop routing | Most homes fit within single-hop range; edge nodes provide sufficient coverage |
| Fixed intelligence tiers | Predictable behavior | Optimal resource usage | Knowing exactly what runs where is worth the efficiency loss |
| No persistent storage on leaf/edge | Privacy | Forensics | "No data to steal" beats "encrypted data that might be cracked" |
| Physical approval for new nodes | Security | Zero-config purity | One button press is an acceptable UX cost for preventing rogue node injection |

---

### What I'd Change with More Time

1. **Add hub redundancy**: Allow a secondary hub (or promote an edge node to hub role) if the primary hub is unresponsive for >60 seconds. This is the most impactful reliability improvement.

2. **Add adaptive thresholds**: Track per-room average settling time and adjust the threshold. Still rule-based, but the rules would have learned parameters. No ML needed — just exponential moving averages.

3. **Add ESP-NOW relay mode for edge nodes**: Let edge nodes relay ESP-NOW messages from out-of-range leaf nodes to the hub. This adds multi-hop without a full mesh stack.

4. **Add BLE beacon scanning on edge nodes**: Edge nodes could scan for household members' phone BLE beacons to improve intruder detection (known person vs unknown person). Currently the design only classifies person vs animal.

---

### Overall Assessment

This design optimizes for the deployment scenario where a technically competent (but not necessarily expert) user sets up a home system that should "just work" reliably for years. It sacrifices adaptability and resilience-at-scale for simplicity and predictability. For a 3-bedroom home with <30 nodes, these tradeoffs are appropriate. For a commercial building or large estate, the experimental track's approach might scale better.

The strongest aspect of this design is the privacy model — data minimization at every tier with no escape hatches. The weakest aspect is the hub as a single point of failure.
