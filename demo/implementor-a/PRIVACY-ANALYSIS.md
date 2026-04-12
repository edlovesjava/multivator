# PRIVACY-ANALYSIS.md — Conservative Track

## Design Principle

**Privacy by default, functionality by opt-in.** The system is designed so that the most private configuration is the zero-configuration default. Every expansion of data flow requires explicit user action.

---

## Data Flow Audit

### What Data Exists at Each Tier

| Tier | Data Created | Data Stored | Data Transmitted |
|------|-------------|-------------|-----------------|
| **Tier 0 (leaf)** | Raw sensor reading (PIR trigger, temp, door state) | Nothing persistent — RAM only, cleared on sleep | Event message (type + value + timestamp) via ESP-NOW to nearest edge |
| **Tier 1 (smart leaf)** | Audio samples, processed VAD/keyword output | Nothing persistent — audio discarded after processing | Recognized keyword ID (not audio) via ESP-NOW to edge |
| **Tier 2 (edge + camera)** | Camera frames, classification results | Nothing persistent — frames discarded after inference | Classification result only ("person"/"cat"/"none") via Wi-Fi to hub |
| **Tier 3 (hub)** | Aggregated state, event history, anomaly histogram | Current state (key-value store), 7-day rolling event histogram on microSD | Nothing external by default |
| **Tier 4 (cloud)** | Whatever the hub sends (opt-in only) | Depends on cloud service | Outbound HTTPS only, user-selected data categories |

### Critical Privacy Properties

1. **Camera frames NEVER leave the camera node.** The ESP32-S3 captures a frame, runs TFLite Micro person detection, and discards the frame. Only the classification label ("person", "cat", "none") and confidence score are transmitted. There is no frame buffer, no recording, no streaming capability.

2. **Audio samples NEVER leave the microphone node.** The ESP32-S3 processes audio locally for keyword spotting. Only the recognized keyword ID is transmitted. Raw audio is discarded immediately after processing.

3. **No persistent storage on leaf/edge nodes.** Tier 0/1/2 nodes have no filesystem, no flash logging, no SD card. If physically captured, they contain only their current RAM state (which is wiped on power loss) and their firmware.

4. **Hub stores only aggregate data.** The hub's microSD contains:
   - Current state key-value pairs (room temperatures, occupancy booleans)
   - 7-day rolling event histogram (counts per hour, not individual events)
   - Configuration data (room names, thresholds, automation rules)
   - No raw sensor data, no camera frames, no audio

5. **No external connections by default.** The hub does not connect to the internet. It operates on the local Wi-Fi network only. There is no MQTT broker, no cloud API endpoint, no phone-home telemetry.

---

## Threat Model

### Threat 1: Physical Capture of a Leaf Node

**Attack**: Adversary physically removes a Tier 0/1 sensor from the home.

**What they get**:
- Firmware binary (including hardcoded node name and room assignment)
- Pre-shared ESP-NOW encryption key for this node's link to its parent edge node
- Current RAM state (if powered — lost on power removal)

**What they DON'T get**:
- Other nodes' encryption keys (each node has a unique key)
- Mesh-wide state
- Historical data (leaf nodes store nothing)
- Hub credentials or Wi-Fi password (leaf nodes use ESP-NOW, not Wi-Fi)

**Mitigation**: Compromised node's key can be revoked at the hub. The edge node stops accepting messages from the captured node's MAC address. Other nodes are unaffected.

**Residual risk**: Attacker can read the firmware and understand the protocol. This is acceptable — security through obscurity is not a valid defense. The encryption keys are the secret, not the protocol.

### Threat 2: Physical Capture of an Edge Node

**Attack**: Adversary physically removes a Tier 2 camera/edge node.

**What they get**:
- Firmware with person detection model
- ESP-NOW keys for all leaf nodes paired to this edge (stored in flash)
- Wi-Fi credentials (SSID + password, stored in flash for Wi-Fi connection to hub)
- Current RAM state

**What they DON'T get**:
- Camera footage (no storage)
- Historical data
- Hub state or other edge nodes' keys

**Mitigation**:
- Wi-Fi password should be changed after edge node theft is detected
- Hub revokes all ESP-NOW keys associated with the captured edge node
- Leaf nodes paired to that edge automatically discover and pair with another edge node on next wake cycle

**Residual risk**: Wi-Fi credentials are exposed. This is inherent to any Wi-Fi device. Users should use a dedicated IoT VLAN/SSID if possible.

### Threat 3: Physical Capture of the Hub

**Attack**: Adversary physically takes the hub.

**What they get**:
- All state data on microSD (room names, current temperatures, occupancy, 7-day histograms)
- Wi-Fi credentials
- All node registration data
- Configuration and automation rules

**What they DON'T get**:
- Camera footage (never stored)
- Audio recordings (never stored)
- Cloud credentials (none if air-gapped)

**Mitigation**:
- microSD data can be encrypted with a user-provided passphrase (AES-256)
- Without passphrase, the hub refuses to boot and requires factory reset
- Hub physical security is the user's responsibility (it's mains-powered and typically installed in a utility area)

**Residual risk**: If the hub is captured before the user can respond, the attacker has recent home occupancy patterns. This is mitigated by the 7-day rolling window — no long-term history.

### Threat 4: Network Sniffing (Passive)

**Attack**: Adversary sniffs ESP-NOW or Wi-Fi traffic.

**ESP-NOW**: Encrypted with per-link 128-bit CCMP keys (AES-128 in CCM mode, hardware-accelerated). Traffic analysis can reveal transmission timing (and therefore event frequency) but not content.

**Wi-Fi (edge ↔ hub)**: Standard WPA2/WPA3 encryption. Same security as any Wi-Fi traffic.

**Mitigation for traffic analysis**: Leaf nodes can optionally send decoy heartbeat packets at random intervals to mask real event timing. This costs minimal additional power (~0.001 mAh per decoy, 1-2 per hour).

### Threat 5: Rogue Node Injection

**Attack**: Adversary introduces a fake node into the network.

**Defense**: New nodes must be approved at the hub. The default mode requires physical confirmation:
1. New node broadcasts capability advertisement.
2. Hub displays new node on its status output (OLED/serial/web UI).
3. User presses a physical button on the hub within 60 seconds to approve.
4. Hub generates and distributes the ESP-NOW key for the new node.

**Without approval**: The node's broadcasts are ignored. It cannot join the network, read state, or send commands.

**Tradeoff**: This conflicts slightly with "zero configuration" — but we argue that a single button press on the hub is the minimum viable user action for security. Fully automatic pairing with no confirmation would allow trivial rogue node attacks.

### Threat 6: Power Loss / Connectivity Interruption

**Attack/Failure**: Power outage or Wi-Fi disruption.

**Behavior**:
- Leaf nodes: Unaffected (battery powered, no persistent state to corrupt)
- Edge nodes: Restart on power restore, re-register with hub, resume normal operation. No state to lose.
- Hub: On power restore, reads state from microSD, resumes. The state store uses write-ahead logging with CRC32 checksums — incomplete writes are detected and rolled back.
- No data leakage: There are no external connections to drop or half-complete. No cached credentials in RAM-only buffers. No open sockets to exploit during restart.

**Recovery time**: Hub recovers from power loss in <10 seconds (boot + read microSD + re-establish Wi-Fi). Edge nodes recover in <5 seconds. Leaf nodes recover on next wake cycle (immediate for GPIO-wake nodes).

---

## Data Classification

| Data Category | Sensitivity | Where It Exists | Retention | External Transmission |
|---------------|------------|----------------|-----------|----------------------|
| Camera frames | HIGH | Tier 2 RAM only | <3 seconds | NEVER |
| Audio samples | HIGH | Tier 1 RAM only | <100 ms | NEVER |
| Classification results | MEDIUM | Tier 2 → Hub | Current state only | Only if cloud opt-in |
| Presence/occupancy | MEDIUM | Hub state + histogram | 7-day rolling | Only if cloud opt-in |
| Temperature/humidity | LOW | Hub state | Current value only | Only if cloud opt-in |
| Door open/close events | MEDIUM | Hub histogram | 7-day rolling count | Only if cloud opt-in |
| Automation rules | LOW | Hub microSD | Persistent | Never (local config only) |
| Node registration | LOW | Hub microSD | Persistent | Never |

---

## Privacy vs Functionality Tradeoffs

| Feature | Privacy Cost | User Opt-in Required? |
|---------|------------|----------------------|
| Local automation (lights, HVAC) | None — all local | No |
| Intruder detection + local alarm | None — all local | No |
| Camera-based person detection | None — frames stay on device | No |
| Remote monitoring via phone | Alerts sent to cloud endpoint | Yes — per data category |
| Cloud AI reasoning | Event context sent to cloud | Yes — explicit per event type |
| Long-term trend analysis | Requires >7 day retention | Yes — increases hub storage retention |
| Voice assistant integration | Voice commands forwarded to cloud STT | Yes — explicit opt-in |

**What the user gives up in full-privacy (air-gapped) mode**:
- No remote access (must be on local network)
- No push notifications to phone
- No cloud-based reasoning for ambiguous situations
- No automatic model updates
- 7-day maximum event history

**How the tradeoff is made transparent**: The hub's configuration interface (serial console or local web UI) shows a simple privacy dashboard:
- Green: "All data stays local" (air-gapped)
- Yellow: "Alerts sent to [endpoint]" (cloud alerts opt-in)
- Red: "Sensor data sent to [endpoint]" (cloud data opt-in)

Each data category has an independent toggle. No "accept all" option.

---

## Summary

The conservative privacy posture:
1. Raw sensor data (frames, audio) never leaves the originating device
2. No persistent storage on leaf/edge nodes
3. Hub stores only aggregates with a 7-day rolling window
4. No external connections by default
5. Physical node capture exposes only that node's credentials, not the whole network
6. New node admission requires physical confirmation
7. Every external data flow requires explicit, per-category user opt-in
