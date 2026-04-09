# PRIVACY-ANALYSIS.md -- Experimental Track (Implementor B)

## Data Flow Audit

### What Data Exists and Where

| Data Type | Source | Processing Location | Storage | Retention | Leaves Local Network? |
|-----------|--------|-------------------|---------|-----------|----------------------|
| Camera frames (raw pixels) | Tier 2 camera | Tier 2 camera (on-chip) | **Never stored** | 0 (discarded after inference) | **Never** |
| Audio samples (raw PCM) | Tier 1 microphone | Tier 1 node (on-chip) | **Never stored** | 0 (discarded after classification) | **Never** |
| PIR trigger events | Tier 0 sensor | Tier 2 edge | Hub event log | 24h (circular buffer) | No (unless cloud opt-in) |
| Door open/close events | Tier 0 sensor | Tier 2 edge | Hub event log | 24h | No (unless cloud opt-in) |
| Temperature/humidity | Tier 0 sensor | Hub | Hub time series | 7 days | No (unless cloud opt-in) |
| Person detection results | Tier 2 inference | Hub | Hub event log | 24h | No (unless cloud opt-in) |
| Presence patterns | Hub (derived) | Hub | Hub pattern store | Rolling 7 days | No (unless cloud opt-in) |
| Anomaly scores | Hub (derived) | Hub | Hub event log | 24h | No (unless cloud opt-in) |
| Voice transcriptions | Tier 1/Hub | Hub | **Never stored** | 0 (command executed, text discarded) | **Never** |
| Scene/preference state | Hub | Hub | Hub config store | Persistent | No |
| Mesh network keys | All nodes | Local | Node NVS (encrypted) | Persistent | **Never** |
| Node capability manifests | All nodes | Edge/Hub | Hub registry | Persistent | No |

### Key Privacy Invariants

1. **Raw camera frames never leave the camera node.** They are captured into a frame buffer, processed by TFLite Micro inference, and the buffer is reused. No frame is ever transmitted over ESP-NOW, Wi-Fi, or any other channel. Only classification results (entity type, confidence, bounding box coordinates) are transmitted.

2. **Raw audio never leaves the microphone node.** Audio is processed in a streaming buffer for keyword spotting or local STT. Only the recognized keyword ID or transcribed command text is transmitted. The audio buffer is a rolling window that is continuously overwritten.

3. **Voice transcriptions are ephemeral.** When speech-to-text runs on the hub, the resulting text is parsed for commands, the command is executed, and the text is discarded. No conversation logs are maintained.

4. **The hub stores only derived/aggregate data.** Event logs contain structured events (type, time, zone, classification result), not raw sensor data. The pattern store contains hourly activity histograms, not individual event sequences.

5. **Nothing leaves the local network by default.** There is no background telemetry, no phone-home, no update check, no analytics. Cloud connectivity is explicitly opt-in and per-data-type.

---

## Threat Model

### Threat 1: Physical Capture of a Leaf Node

**Scenario:** Attacker physically removes a Tier 0/1 node from the premises.

**What they get:**
- ESP32 firmware (can be read via JTAG/UART if flash encryption is not enabled)
- ESP-NOW pre-shared encryption key for that node's parent edge node
- Node ID and zone assignment

**What they do NOT get:**
- Any user data (no persistent storage of sensor data on leaf nodes)
- Hub encryption key or stored patterns
- Other nodes' keys (each node has a unique PSK with its parent)
- The ability to impersonate the hub (hub-to-node communication uses a separate key)

**Mitigation:**
- Enable ESP32 flash encryption (eFuse-based, irreversible) on production nodes
- Hub can revoke a captured node by blacklisting its node ID
- Hub can trigger network-wide key rotation after a suspected compromise
- Tier 0/1 nodes should use secure boot to prevent firmware tampering

### Threat 2: Physical Capture of the Hub

**Scenario:** Attacker steals the hub device.

**What they get (without passphrase):**
- Encrypted flash contents (AES-256, key derived from user passphrase + chip eFuse ID)
- Hardware (ESP32-S3 module, SD card)

**What they get (with passphrase):**
- Event log (last 24h of structured events)
- Activity patterns (7-day hourly histograms per zone)
- Scene/preference configurations
- Node registry (what devices exist, their capabilities, zone assignments)
- All mesh encryption keys

**Mitigation:**
- User must set a passphrase during initial setup (enforced, no default)
- Passphrase is never stored -- it's used to derive the encryption key and then discarded from RAM
- After 5 failed passphrase attempts via the local web UI, hub locks for 1 hour
- SD card contents are encrypted with the same derived key
- Consider: hardware security module (e.g., ATECC608A) for key storage, adds ~$1 to BOM

### Threat 3: Mesh Traffic Sniffing

**Scenario:** Attacker with a Wi-Fi/ESP-NOW receiver monitors mesh traffic.

**What they can observe:**
- Encrypted ESP-NOW packets (AES-128 CCMP)
- Encrypted Wi-Fi mesh traffic (WPA2)
- Traffic patterns (timing, frequency, packet sizes)

**What they can infer from traffic analysis:**
- Approximate number of nodes
- Activity patterns (when packets are sent correlates with when events occur)
- Node wake/sleep patterns

**Mitigation:**
- Encryption prevents content inspection
- **Novel: Traffic padding** -- edge nodes send dummy packets at random intervals (1-5 per minute) to obscure real event timing. This costs ~0.5 mA average on edge nodes (mains-powered, acceptable).
- Packet sizes are padded to fixed lengths (64, 128, or 250 bytes) to prevent size-based content inference

### Threat 4: Rogue Node Injection

**Scenario:** Attacker adds a malicious ESP32 to the mesh.

**Defense layers:**
1. **ESP-NOW encryption**: Rogue node doesn't have the PSK, so it cannot decrypt or produce valid encrypted packets
2. **Node registration**: Hub maintains an allowlist of registered node IDs. Unregistered nodes are ignored.
3. **Provisioning protocol**: New nodes must be provisioned via physical button press on hub + button press on new node within a 30-second window. This prevents remote node injection.
4. **Anomaly detection**: Hub monitors for unexpected node IDs, unusual traffic patterns, or capability claims that don't match known hardware

### Threat 5: Network Boundary Breach (Hub Internet Connection)

**Scenario:** Attacker compromises the hub's internet connection (if cloud opt-in is enabled).

**Defense layers:**
1. **Outbound-only connections**: Hub initiates HTTPS POST to a configured endpoint. No inbound connections from the internet. No persistent WebSocket or MQTT.
2. **Certificate pinning**: Hub validates the cloud endpoint's TLS certificate against a pinned public key
3. **Minimal data surface**: Even with cloud opt-in, only selected data categories are transmitted (alerts, environmental summaries). Raw frames and audio never leave.
4. **Differential privacy**: Cloud-bound behavioral data is noised before transmission (see below)
5. **Air-gap mode**: User can disable cloud at any time via physical switch on hub. This immediately terminates all outbound connections.

### Threat 6: Power Loss / Connectivity Interruption

**Scenario:** Power goes out mid-operation.

**Data leak risk:** Minimal.
- Hub event log is write-ahead: events are persisted to flash before being processed. On power recovery, the log is consistent.
- No in-flight data is lost -- ESP-NOW is fire-and-forget (leaf doesn't wait for ACK for data persistence, only for delivery).
- Hub re-encrypts its flash on boot (passphrase re-entry required after power loss, unless user configures auto-unlock via hardware key)
- **No cleartext data is ever written to flash.** All persistent writes go through the encryption layer.

**Connectivity interruption risk:** None.
- If mesh fragments, each edge node continues operating its zone independently
- Buffered events sync when connectivity restores -- no data is dropped
- No external connections are opened during recovery (no "phone home on boot")

---

## Differential Privacy for Cloud Data (Novel)

When a user opts into cloud connectivity for model improvement or remote monitoring, behavioral data is protected by local differential privacy before transmission.

### Mechanism

Instead of transmitting individual events:
```
// NEVER sent: individual events
{ "event": "person_detected", "zone": "front-door", "time": "17:32:15" }
```

The hub aggregates into noised histograms:
```
// What IS sent (with noise):
{
  "zone": "front-door",
  "period": "2026-04-08",
  "activity_histogram": [0, 0, 0, 0, 0, 1, 3, 12+noise, 8+noise, ...],
  "epsilon": 1.0,
  "noise_mechanism": "laplace"
}
```

### Parameters

- **Epsilon (privacy budget):** Default 1.0 (strong privacy). User-adjustable from 0.1 (very strong, less useful) to 5.0 (weaker, more useful for model training).
- **Noise mechanism:** Laplace noise added independently to each histogram bin
- **Aggregation period:** Minimum 1 hour. Data is never transmitted at event-level granularity.
- **Composition tracking:** Hub tracks cumulative privacy budget spent per zone per day. When daily budget is exhausted, no more data is transmitted until the next day.

### What This Protects Against

- **Re-identification:** Individual arrival/departure times cannot be reconstructed from noised histograms
- **Pattern inference:** Activity patterns are blurred sufficiently that specific routines are not recoverable
- **Linkage attacks:** Without individual timestamps, correlating this data with other sources (e.g., car GPS, phone location) is computationally infeasible at epsilon <= 1.0

### What This Costs

- **Functionality:** Cloud models trained on noised data are slightly less accurate than those trained on raw data. At epsilon=1.0, expected accuracy reduction is ~5-10% for pattern recognition tasks.
- **Utility for remote monitoring:** Real-time alerts still work (they're separate from the DP pipeline -- alerts are immediate, not aggregated). The DP pipeline only affects historical pattern data sent for model improvement.

---

## Privacy vs Functionality Summary

| Functionality | Privacy Cost | User Control |
|---------------|-------------|--------------|
| Local automation (scenes, rules) | None -- all local | Always on |
| Intruder detection | None -- inference on-device | Always on |
| Presence intent (settling in) | None -- temporal logic on hub | Always on |
| Voice commands | None -- STT on hub, text discarded | Always on |
| Activity history (local dashboard) | Low -- stored on hub, encrypted | Hub passphrase |
| Remote alerts (push notifications) | Minimal -- alert type + zone sent to cloud | Per-alert opt-in |
| Remote dashboard | Medium -- summary data sent to cloud | Explicit opt-in |
| Model improvement | Low (with DP) -- noised histograms | Explicit opt-in + epsilon control |
| Camera cloud recording | **Not supported** | N/A -- architectural constraint |

The user gives up **nothing** for full local functionality. Cloud features provide incremental value (remote alerts, better models) at a controlled, transparent privacy cost.
