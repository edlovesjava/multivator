# SELF-REVIEW.md -- Experimental Track (Implementor B)

## Honest Self-Assessment

### What This Design Gets Right

1. **Intelligence-to-power ratio is genuinely strong.** The event cascade + policy propagation model means most intelligence runs on mains-powered nodes while battery nodes do the minimum. The Tier 0 power numbers (8.8 uA average, 34 months on CR2032) are achievable with ESP-NOW's connectionless transmit.

2. **Privacy architecture is sound by construction.** Camera frames never leaving the device is an architectural constraint, not a configuration option. This is harder to accidentally break than a "privacy mode" toggle.

3. **Event sourcing is the right state model.** For a security system, having a complete audit trail matters. The tier-appropriate projections (full log on hub, zone-scoped on edge, stateless on leaf) match the hardware constraints naturally.

4. **The capability composition idea is genuinely novel.** Automatically discovering that PIR + Camera = motion-triggered classification, rather than hardcoding it, makes the system truly self-organizing at the intelligence layer, not just the network layer.

---

### Risks and Where the Conservative Track May Be Better

#### Risk 1: Hybrid Protocol Complexity (Medium-High)

Running ESP-NOW and ESP-MESH-LITE simultaneously on edge nodes is the biggest engineering risk. While both use the ESP32's Wi-Fi radio, they operate in different modes and can interfere. Specifically:
- ESP-NOW and Wi-Fi STA mode can coexist, but both must be on the same channel
- ESP-MESH-LITE assigns channels dynamically -- this could conflict with the fixed ESP-NOW channel
- The edge node firmware must manage two protocol stacks, two discovery mechanisms, and bridge between them

**Where conservative is better:** A simpler approach (ESP-NOW everywhere, or Wi-Fi only for upper tiers) avoids this complexity entirely. If the hybrid approach proves unreliable in testing, falling back to the conservative design's simpler protocol stack would be prudent.

**What would need to be proven:** A working prototype demonstrating stable dual-protocol operation on an ESP32-S3 for 72+ hours under load.

#### Risk 2: Predictive Sleep Scheduling (Medium)

The idea of pushing learned sleep policies to Tier 1 nodes is novel but unproven. Risks:
- **Safety concern:** If the hub incorrectly predicts a quiet period and a real intrusion happens during that window, the Tier 1 node might miss periodic check-ins (though interrupt-driven wake still works)
- **Staleness:** Patterns change (vacations, guests, schedule changes). The system needs to detect pattern drift and fall back to conservative wake schedules
- **Complexity:** Adding a learning loop between hub and leaf nodes adds an interaction path that must be tested thoroughly

**Where conservative is better:** Fixed wake schedules are simpler, predictable, and never miss events. The battery life improvement (30-50%) may not justify the added complexity and risk.

**What would need to be proven:** That interrupt-only wake during predicted quiet periods never degrades detection latency for actual security events. This requires months of field testing.

#### Risk 3: Automatic Capability Composition (Medium)

The capability graph and automatic pipeline assembly is the most ambitious feature. Risks:
- **Combinatorial explosion:** With many capabilities per zone, the number of possible pipelines grows factorially. Needs bounded search.
- **Unexpected compositions:** The system might compose capabilities in ways that don't make semantic sense (e.g., soil moisture + camera = ???). Needs a compatibility matrix.
- **Debugging difficulty:** When an automated pipeline misbehaves, it's harder to diagnose than a hardcoded rule.

**Where conservative is better:** Explicit, hardcoded pipelines are trivially debuggable. "PIR triggers camera" is one line of code. Automatic composition requires a framework.

**What would need to be proven:** That the capability compatibility matrix covers real-world sensor combinations without producing nonsensical pipelines. Start with hardcoded pipelines and add automatic composition as a layer on top.

#### Risk 4: Continuous Anomaly Scoring (Low-Medium)

The anomaly scoring system (0.0-1.0) is more nuanced than binary classification but harder to calibrate:
- **Cold start:** During the first 7 days, the system has no learned patterns. All events score ~0.5 (unknown). This means no meaningful security for the first week.
- **Threshold tuning:** Users may not understand what epsilon=0.7 vs 0.9 means. The UI must translate this into "how sensitive is the alarm?"
- **False positives:** A score-based system can generate more nuisance alerts than a simple rule-based one, especially during pattern changes

**Where conservative is better:** A rule-based state machine (person + no-unlock + nighttime = alert) works immediately with zero learning period and is fully predictable.

**What would need to be proven:** That the learning period can be bootstrapped with reasonable defaults (e.g., "assume 07:00-22:00 is active, 22:00-07:00 is quiet") so the system provides useful security from day one.

#### Risk 5: Differential Privacy Overhead (Low)

The differential privacy mechanism for cloud data is theoretically sound but adds engineering effort:
- Implementing Laplace noise correctly requires a cryptographic random number generator
- Privacy budget tracking adds state that must persist across reboots
- Testing DP properties requires statistical tests (not just unit tests)

**Where conservative is better:** Simply not sending data to the cloud (the default) achieves perfect privacy with zero complexity. DP is only relevant for the opt-in cloud enhancement.

**What would need to be proven:** Formal verification or statistical testing that the DP implementation actually provides the claimed privacy guarantees at the specified epsilon.

---

### What Would Need to Be Proven Before Production

1. **Dual-protocol stability:** ESP-NOW + ESP-MESH-LITE coexistence on ESP32-S3 under real-world conditions (72h+ soak test with active inference and frequent events)

2. **Inference accuracy on ESP32-S3:** MobileNet-V2 INT8 person detection at OV2640's resolution (SVGA, 800x600). Need >90% person detection, >85% cat rejection on a diverse test set

3. **Event store durability:** Circular buffer on flash survives 10,000+ power cycles without corruption (flash wear leveling via LittleFS must be validated)

4. **Anomaly engine cold start:** System must provide useful security during the learning period. Propose: hardcoded "safe defaults" rules active during first 7 days, gradually blending with learned patterns

5. **Real-world power measurements:** The calculated power figures (8.8 uA average for Tier 0) need validation on actual hardware with actual sensors. Sensor quiescent current and LDO overhead often surprise in practice

6. **Scale testing:** Simulate 30+ nodes (realistic full-home deployment) and verify that ESP-NOW channel doesn't become congested, hub can process the event rate, and state sync remains responsive

---

### If I Were Starting Over

1. I would **start with the conservative track's simpler protocol stack** (ESP-NOW + Wi-Fi direct, no ESP-MESH-LITE) and only add mesh-lite if range or routing proves insufficient

2. I would **implement hardcoded capability pipelines first**, then add automatic composition as an optional enhancement layer -- not as the primary mechanism

3. I would **ship the rule-based security engine first** and add anomaly scoring as a parallel system that runs alongside, building confidence before it becomes the primary decision maker

4. I would keep the **event sourcing architecture** -- it's the right foundation regardless of what runs on top

5. I would keep the **policy propagation mechanism** -- intelligence flowing downward is genuinely better than every tier discovering policy independently

### The Synthesis Path

The strongest design would combine:
- Conservative track's **simpler networking** (ESP-NOW + Wi-Fi, no mesh-lite)
- Conservative track's **rule-based security engine** as the primary path
- Experimental track's **event sourcing state model** (better than flat KV for security audit)
- Experimental track's **policy propagation** (better power optimization than fixed schedules)
- Experimental track's **typed event system** (better API than raw bytes)
- Experimental track's **anomaly scoring as a secondary/advisory system** alongside rules
- Experimental track's **privacy architecture** (camera frames never leave device + differential privacy for cloud)
- Conservative track's **explicit, readable code style** over the experimental track's framework-heavy abstractions

This would produce a system that is immediately functional (rules), progressively smarter (anomaly learning), and architecturally sound (event sourcing, typed events, policy propagation) without the highest-risk bets (dual protocol, automatic composition).
