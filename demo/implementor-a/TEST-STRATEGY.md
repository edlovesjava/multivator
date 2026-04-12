# TEST-STRATEGY.md — Conservative Track

## Testing Philosophy

Tests must be **deterministic, fast, and runnable without hardware**. The majority of logic — state management, security rules, presence intent, anomaly detection — is pure C++ with no hardware dependencies. These run on the host (x86/ARM) via PlatformIO's native environment.

Hardware-dependent tests (transport, GPIO, camera) run on-device but are structured so that the logic under test is separated from the HAL.

---

## Test Pyramid

```
            ┌─────────────┐
            │  Scenario    │  3-5 tests, on-device or HIL
            │  (end-to-end)│
            ├─────────────┤
            │  Integration │  10-15 tests, native + device
            │  (multi-unit)│
            ├─────────────┤
            │  Unit Tests  │  50+ tests, all native (host)
            │  (per module) │
            └─────────────┘
```

---

## Unit Tests (Host-Native, PlatformIO `native` env)

All unit tests compile and run on the development machine. No ESP32 hardware required. Uses a lightweight test framework (Unity, already a PlatformIO dependency).

### State Store Tests

| Test | Description |
|------|-------------|
| `test_set_get_int` | Set an integer key, read it back, verify value |
| `test_set_get_float` | Set a float key, read it back, verify precision |
| `test_set_get_bool` | Set a boolean key, read it back |
| `test_overwrite` | Set a key, overwrite it, verify new value and incremented version |
| `test_key_not_found` | Get a nonexistent key, verify returns false |
| `test_max_entries` | Fill store to MAX_ENTRIES, verify next set fails gracefully |
| `test_apply_update_newer` | Apply a state update with higher version, verify it's accepted |
| `test_apply_update_older` | Apply a state update with lower version, verify it's rejected |
| `test_watch_callback` | Register a watcher on a key, set the key, verify callback fires |
| `test_watch_wildcard` | Register watcher on "room.*", set "room.living.temp", verify callback fires |
| `test_get_entries_since` | Insert entries with versions 1-10, query since version 5, verify returns 5 entries |
| `test_delta_sync` | Simulate two stores, sync deltas, verify convergence |

### Security Engine Tests

| Test | Description |
|------|-------------|
| `test_motion_creates_room` | Process MOTION_DETECTED for unknown room, verify room is created |
| `test_presence_start` | Process MOTION_DETECTED, verify room marked occupied |
| `test_settling_in_timer` | Process MOTION_DETECTED, advance clock 180s, verify intent = SETTLING_IN |
| `test_passing_through` | Process MOTION_DETECTED, then PRESENCE_END at 60s, verify intent = PASSING_THROUGH |
| `test_settling_threshold_config` | Set threshold to 120s, verify settling triggers at 120s not 180s |
| `test_person_detected_no_beacon` | Process PERSON_DETECTED without household beacon, verify alert fires |
| `test_animal_detected_no_alert` | Process ANIMAL_DETECTED, verify no alert fires |
| `test_person_detected_with_beacon` | Process PERSON_DETECTED with household beacon present, verify no alert |
| `test_anomaly_histogram` | Feed 7 days of regular events, then inject off-pattern event, verify UNUSUAL_ACTIVITY |
| `test_room_preferences_on_settling` | Verify automation callback fires on SETTLING_IN with correct room |
| `test_no_preferences_on_passing` | Verify automation callback does NOT fire on PASSING_THROUGH |

### Capability Descriptor Tests

| Test | Description |
|------|-------------|
| `test_pir_descriptor` | Verify PIR capability descriptor has correct name, type, unit |
| `test_relay_descriptor` | Verify relay capability descriptor |
| `test_serialize_event` | Create PIR event, serialize, verify binary format matches spec |
| `test_deserialize_event` | Feed binary buffer, deserialize, verify fields |

### Message Protocol Tests

| Test | Description |
|------|-------------|
| `test_header_pack` | Pack a MessageHeader, verify byte layout matches spec (12 bytes) |
| `test_header_unpack` | Unpack bytes into MessageHeader, verify fields |
| `test_capability_advertise_msg` | Serialize a capability advertisement, verify structure |
| `test_actuator_command_msg` | Serialize an actuator command, verify structure |
| `test_unknown_message_type` | Receive message with unknown type, verify graceful ignore |

---

## Integration Tests (Native + On-Device)

### Capability Discovery Integration (Native)

Simulates the full discovery flow without hardware:

```
test_discovery_flow:
    1. Create a mock hub (StateStore + SecurityEngine)
    2. Create 3 mock leaf node descriptors (PIR, temp, door)
    3. Simulate capability advertisements arriving at hub
    4. Verify hub registers all 3 nodes with correct capabilities
    5. Simulate one node going offline (no heartbeat for 60s)
    6. Verify hub marks node as offline
    7. Simulate node coming back online
    8. Verify hub re-registers node
```

### State Synchronization Integration (Native)

```
test_state_sync_convergence:
    1. Create hub StateStore with 10 entries
    2. Create edge StateStore with 0 entries
    3. Simulate full sync: hub sends all entries to edge
    4. Verify edge has all 10 entries with correct versions
    5. Update 3 entries at hub (version bump)
    6. Simulate delta sync: hub sends entries since edge's last version
    7. Verify edge has updated values
    8. Simulate conflicting update from edge (different value, same key)
    9. Verify hub applies last-writer-wins and edge receives correction
```

### Coordinator Failover Integration (On-Device, 3 ESP32s)

```
test_coordinator_failover:
    1. Power on 3 nodes: hub + 2 edge nodes
    2. Verify hub is coordinator (lowest ID by design)
    3. Power off hub
    4. Verify edge nodes detect hub offline within 15s
    5. Verify edge nodes elect new coordinator (lowest remaining ID)
    6. Power on hub
    7. Verify hub reclaims coordinator role
    8. Verify all state is consistent after recovery
```

---

## Scenario Tests

### Scenario 1: Intruder vs Cat Detection

**Setup**: PIR sensor (Tier 0) + Camera (Tier 2) + Hub (Tier 3)

**Test with simulated input** (host-native):

```
test_intruder_vs_cat_simulated:
    1. Create SecurityEngine
    2. Inject MOTION_DETECTED event for "living_room"
    3. Inject PERSON_DETECTED event (simulating camera classification)
    4. Verify alert callback fires with PERSON_DETECTED
    5. Verify state has "alert.intruder" = true

test_cat_not_alert_simulated:
    1. Create SecurityEngine
    2. Inject MOTION_DETECTED event for "living_room"
    3. Inject ANIMAL_DETECTED event (simulating camera classification)
    4. Verify alert callback does NOT fire
    5. Verify state does NOT have "alert.intruder" = true
```

**Test with real hardware** (on-device):

```
test_intruder_vs_cat_hardware:
    1. PIR sensor triggers (real motion or simulated GPIO toggle)
    2. Camera node captures frame
    3. Run TFLite person detection on test images:
       a. Image of a person → expect "person" classification
       b. Image of a cat → expect "not person" classification
    4. Hub receives classification and applies rules
    5. Verify correct alert/no-alert outcome
    6. Measure end-to-end latency (target: <5 seconds)
    7. Measure power consumed by each tier during scenario
```

**Test image corpus**: 10 person images + 10 cat images + 10 empty room images from public datasets (COCO subset). Images resized to 96x96 for TFLite Micro person detection model. Expected accuracy: >90% on this test set.

### Scenario 2: Settling In vs Passing Through

**Test with simulated input** (host-native):

```
test_settling_in_simulated:
    1. Create SecurityEngine with 180s threshold
    2. Inject MOTION_DETECTED at T=0
    3. Inject MOTION_DETECTED at T=30s (person still in room)
    4. Inject MOTION_DETECTED at T=60s
    5. Inject MOTION_DETECTED at T=120s
    6. Advance clock to T=180s
    7. Call update()
    8. Verify intent = SETTLING_IN
    9. Verify automation callback fired (preferences activated)

test_passing_through_simulated:
    1. Create SecurityEngine with 180s threshold
    2. Inject MOTION_DETECTED at T=0
    3. Inject PRESENCE_END at T=45s (person left room)
    4. Verify intent = PASSING_THROUGH
    5. Verify automation callback did NOT fire

test_edge_case_exactly_at_threshold:
    1. Create SecurityEngine with 180s threshold
    2. Inject MOTION_DETECTED at T=0
    3. Advance clock to T=179s → verify still UNKNOWN
    4. Advance clock to T=180s → verify SETTLING_IN
```

**Test with real hardware** (on-device):

```
test_settling_in_hardware:
    1. PIR sensor detects continuous motion for 4 minutes
    2. Hub tracks presence duration
    3. At 3 minutes, verify room preferences activate
    4. Verify actuator commands sent (light on, temp adjust)

test_passing_through_hardware:
    1. PIR sensor detects motion, then no motion for 60s
    2. Hub tracks presence ending before threshold
    3. Verify room preferences NOT activated
    4. Verify no actuator commands sent
```

### Scenario 3: Environmental Control

**Test with simulated input** (host-native):

```
test_temp_threshold_hvac:
    1. Create SecurityEngine + StateStore
    2. Set state "room.living.temp" = 22.0
    3. Set automation rule: if temp > 24.0, send HVAC "cool" command
    4. Update state "room.living.temp" = 24.5
    5. Verify HVAC actuator command generated
    6. Verify command targets correct room actuator

test_unoccupied_energy_saving:
    1. Room is occupied, preferences active (lights on, temp 22°C)
    2. Inject PRESENCE_END
    3. After 5 minutes with no motion, verify energy-saving mode:
       - Lights command: off
       - HVAC command: setback temp (e.g., 18°C)
```

---

## What's Testable on Host vs Hardware

| Component | Host (Native) | Hardware (ESP32) |
|-----------|:------------:|:----------------:|
| StateStore | Yes | Yes |
| SecurityEngine | Yes | Yes |
| Message serialization/deserialization | Yes | Yes |
| Capability descriptors | Yes | Yes |
| Anomaly detection histogram | Yes | Yes |
| Presence intent state machine | Yes | Yes |
| ESP-NOW transport | No | Yes |
| Wi-Fi transport | No | Yes |
| Camera capture + inference | No | Yes |
| GPIO/sensor reading | No | Yes |
| Deep sleep/wake | No | Yes |
| Power measurement | No | Yes (external meter) |
| Multi-node mesh healing | No | Yes (3+ devices) |
| End-to-end scenarios | Simulated | Yes |

**Target**: >80% of tests run on host with no hardware. This enables CI/CD and fast development iteration.

---

## PlatformIO Test Configuration

```ini
; platformio.ini test environments

[env:native]
platform = native
test_framework = unity
build_flags =
    -DMESHSWARM_TIER=3
    -DUNIT_TEST
    -DMAX_ENTRIES=256

[env:native_leaf]
platform = native
test_framework = unity
build_flags =
    -DMESHSWARM_TIER=0
    -DUNIT_TEST
    -DMAX_ENTRIES=16

[env:esp32s3_test]
platform = espressif32
board = esp32-s3-devkitc-1
framework = arduino
test_framework = unity
build_flags =
    -DMESHSWARM_TIER=2
    -DINTEGRATION_TEST
```

---

## Test Execution Plan

| Phase | Environment | Tests | When |
|-------|-------------|-------|------|
| 1. Unit tests | `native` | All state, security, protocol tests | Every commit (CI) |
| 2. Tier-specific unit tests | `native_leaf` | Verify leaf node constraints (small state store) | Every commit (CI) |
| 3. Integration (simulated) | `native` | Discovery, sync, scenario simulations | Every commit (CI) |
| 4. On-device unit tests | `esp32s3_test` | Same tests, verify they pass on real hardware | Weekly / pre-release |
| 5. Multi-node integration | 3+ ESP32 devices | Mesh healing, coordinator election, discovery | Pre-release |
| 6. Scenario tests (hardware) | Full deployment | Intruder/cat, settling/passing, environmental | Pre-release |
| 7. Power measurement | Per-tier devices | Current measurement with USB power meter | Per-tier, once |

---

## Success Criteria

| Criterion | Target |
|-----------|--------|
| Unit test count | >50 |
| Unit test pass rate | 100% |
| Host-testable coverage | >80% of logic |
| Intruder vs cat accuracy (test images) | >90% |
| Settling vs passing correctness | 100% (deterministic state machine) |
| Mesh healing recovery time | <15 seconds |
| CI test runtime | <30 seconds (native tests) |
