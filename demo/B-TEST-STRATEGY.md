# TEST-STRATEGY.md -- Experimental Track (Implementor B)

## Testing Philosophy

Testing a distributed embedded system requires multiple layers: host-native unit tests for logic, hardware-in-the-loop integration tests for protocol correctness, and simulation-based scenario tests for end-to-end behavior. We push ambitiously into simulation and property-based testing while keeping the test infrastructure practical.

---

## Layer 1: Host-Native Unit Tests

All business logic runs on the host (x86/ARM64) with hardware abstracted behind interfaces. This enables fast iteration without flashing hardware.

### What runs on host

| Module | Test Focus | Framework |
|--------|-----------|-----------|
| Anomaly scoring engine | Score calculation, pattern learning, threshold behavior | GoogleTest |
| Event store | Append, read, compaction, circular buffer wrap | GoogleTest |
| Scene engine | Priority arbitration, conflict resolution, activation/deactivation | GoogleTest |
| Security reasoning | Intruder detection state machine, presence intent timing | GoogleTest |
| Policy system | Policy evaluation, expiry, override semantics | GoogleTest |
| Capability manifest | Serialization, deserialization, capability matching | GoogleTest |
| State conflict resolution | Lamport timestamp ordering, hub sequencing, merge on recovery | GoogleTest |

### Property-based tests (novel)

Using a lightweight property-based testing approach (random input generation + invariant checking):

**Anomaly scoring properties:**
- `forall events e: 0.0 <= score(e) <= 1.0` (score always in range)
- `forall normal_pattern p: after learning p for 7 days, score(event_matching_p) < 0.3` (learned patterns score low)
- `forall event e outside learned pattern: score(e) > 0.5` (deviations score high)
- `score is monotonic with deviation: if |e1 - mean| > |e2 - mean| then score(e1) >= score(e2)` (more deviation = higher score)

**Event store properties:**
- `forall sequence of appends: readSince(0) returns all events in order`
- `after compact(t): no events with timestamp < t remain`
- `head() is monotonically increasing`
- `circular buffer: after MAX_EVENTS+N appends, oldest N events are gone`

**Scene priority properties:**
- `forall scenes s1, s2 where s1.priority > s2.priority: s1's actuator values win for overlapping actuators`
- `activating then deactivating a scene returns to previous state`
- `SAFETY priority always wins, regardless of activation order`

**State sync properties:**
- `forall concurrent updates u1, u2 to same key: after merge, exactly one wins (deterministic)`
- `forall network partition + heal: all nodes converge to same state`

### Test harness for embedded code on host

```cpp
// test_harness.h -- mock hardware interfaces for host testing

class MockGPIO {
public:
    void digitalWrite(gpio_num_t pin, uint8_t val) { state_[pin] = val; }
    uint8_t digitalRead(gpio_num_t pin) { return state_[pin]; }
    void simulateTrigger(gpio_num_t pin) { state_[pin] = 1; interrupt_fired_[pin] = true; }
private:
    std::map<gpio_num_t, uint8_t> state_;
    std::map<gpio_num_t, bool> interrupt_fired_;
};

class MockTransport {
public:
    // Simulate sending -- stores message in outbox
    bool send(uint32_t dst, const uint8_t* data, size_t len);

    // Simulate receiving -- delivers from inbox
    void injectMessage(uint32_t src, const uint8_t* data, size_t len);

    // Inspect what was sent
    const std::vector<Message>& outbox() const;
};

class MockClock {
public:
    void advance(uint32_t ms);
    uint32_t now() const;
};
```

---

## Layer 2: Hardware-in-the-Loop Integration Tests

These require actual ESP32 hardware but automate the test execution via serial commands.

### Mesh Formation Test

**Setup:** 3-5 ESP32 dev boards connected to a test host via USB serial.

**Test script (Python, running on host):**
```python
def test_mesh_formation():
    # Power on all nodes
    nodes = [SerialNode(port) for port in discover_serial_ports()]
    
    # Wait for mesh to form
    time.sleep(30)  # 30s per spec
    
    # Verify all nodes discovered each other
    for node in nodes:
        peers = node.query("mesh.peers")
        assert len(peers) == len(nodes) - 1, f"Node {node.id} sees {len(peers)} peers, expected {len(nodes)-1}"
    
    # Verify hub/edge election
    hub_nodes = [n for n in nodes if n.query("mesh.role") == "hub"]
    assert len(hub_nodes) == 1, "Exactly one hub expected"
```

### Self-Healing Test

```python
def test_self_healing():
    nodes = [SerialNode(port) for port in discover_serial_ports()]
    wait_for_mesh(nodes, timeout=30)
    
    # Kill one node (disable USB power via relay)
    relay.power_off(nodes[2].port)
    
    # Wait for healing
    time.sleep(15)  # 15s per spec
    
    # Verify remaining nodes still connected
    alive = [n for n in nodes if n != nodes[2]]
    for node in alive:
        peers = node.query("mesh.peers")
        assert nodes[2].id not in peers, "Dead node should be removed"
        assert len(peers) == len(alive) - 1, "Remaining nodes should see each other"
    
    # Power node back on
    relay.power_on(nodes[2].port)
    time.sleep(30)
    
    # Verify it rejoins
    for node in nodes:
        peers = node.query("mesh.peers")
        assert len(peers) == len(nodes) - 1, "Recovered node should rejoin"
```

### Power Measurement Test

```python
def test_tier0_power():
    # INA219 current sensor inline with battery
    ina = INA219(i2c_address=0x40)
    node = SerialNode(LEAF_PORT)
    
    # Measure deep sleep current
    node.command("enter_sleep")
    time.sleep(5)
    sleep_current = ina.read_current_ua()
    assert sleep_current < 15, f"Sleep current {sleep_current}uA exceeds 15uA target"
    
    # Trigger PIR and measure active current
    trigger_pir_via_gpio(PIR_SIMULATE_PIN)
    samples = ina.sample_current_ma(duration_ms=100, rate_hz=1000)
    peak = max(samples)
    active_duration = len([s for s in samples if s > 5]) / 1000  # seconds above 5mA
    
    assert peak < 200, f"Peak current {peak}mA too high"
    assert active_duration < 0.015, f"Active duration {active_duration}s exceeds 15ms target"
```

---

## Layer 3: Scenario Simulation (Novel)

Full system simulation on host using a discrete event simulator. This allows testing complex multi-node scenarios without hardware.

### Simulation Framework

```cpp
// simulator.h

class MeshSimulator {
public:
    // Add simulated nodes with specified capabilities
    SimNode& addNode(const char* name, Tier tier, const char* zone,
                     std::initializer_list<CapTag> caps);
    
    // Simulate physical events
    void triggerMotion(const char* zone);
    void triggerDoorOpen(const char* zone);
    void triggerDoorClose(const char* zone);
    void setTemperature(const char* zone, float celsius);
    void personEntersZone(const char* zone);
    void personLeavesZone(const char* zone);
    void catEntersZone(const char* zone);
    
    // Time control
    void advanceTime(uint32_t ms);
    void runUntilIdle();  // advance until no pending events
    
    // Inspection
    const std::vector<EmittedEvent>& events() const;
    const std::vector<ActuatorCommand>& actuatorLog() const;
    SimNode& node(const char* name);
};
```

### Scenario Test: Intruder vs Cat

```cpp
TEST(ScenarioTest, IntruderVsCat) {
    MeshSimulator sim;
    
    // Set up a realistic zone
    sim.addNode("pir_front", Tier::LEAF, "front-door", {CAP_PIR});
    sim.addNode("cam_front", Tier::EDGE, "front-door", {CAP_CAMERA_RGB, CAP_PERSON_DETECT});
    sim.addNode("door_front", Tier::LEAF, "front-door", {CAP_DOOR_CONTACT});
    sim.addNode("alarm", Tier::LEAF, "front-door", {CAP_BUZZER});
    sim.addNode("hub", Tier::HUB, "hub", {});
    
    // Let system learn normal patterns for 7 simulated days
    for (int day = 0; day < 7; day++) {
        // Simulate normal daily activity
        sim.advanceTime(hours(8));   // morning
        sim.personEntersZone("front-door");
        sim.triggerDoorOpen("front-door");
        sim.advanceTime(seconds(5));
        sim.personLeavesZone("front-door");
        sim.triggerDoorClose("front-door");
        sim.advanceTime(hours(10)); // out all day
        sim.personEntersZone("front-door");
        sim.triggerDoorOpen("front-door");
        sim.advanceTime(seconds(5));
        sim.personLeavesZone("front-door");
        sim.triggerDoorClose("front-door");
        sim.advanceTime(hours(6));  // evening at home
    }
    
    sim.clearEventLog();
    
    // --- Test 1: Cat triggers PIR at 2am ---
    sim.advanceTime(hours(2));
    sim.catEntersZone("front-door");  // this triggers PIR + camera classifies "cat"
    sim.runUntilIdle();
    
    auto alerts = sim.eventsOfType<SecurityAlert>();
    EXPECT_EQ(alerts.size(), 0) << "Cat should not trigger security alert";
    
    auto buzzer_cmds = sim.actuatorCommandsFor("alarm");
    EXPECT_EQ(buzzer_cmds.size(), 0) << "Alarm should not sound for cat";
    
    sim.clearEventLog();
    
    // --- Test 2: Human intruder at 2am, no door unlock ---
    sim.advanceTime(minutes(30));
    sim.personEntersZone("front-door");  // PIR + camera classifies "person"
    // Note: door NOT opened (no unlock event) -- abnormal entry
    sim.runUntilIdle();
    
    alerts = sim.eventsOfType<SecurityAlert>();
    ASSERT_GE(alerts.size(), 1) << "Intruder should trigger security alert";
    EXPECT_GE(alerts[0].level, SecurityAlert::HARD) << "Should be at least HARD alert";
    
    buzzer_cmds = sim.actuatorCommandsFor("alarm");
    EXPECT_GE(buzzer_cmds.size(), 1) << "Alarm should sound for intruder";
}
```

### Scenario Test: Settling In vs Passing Through

```cpp
TEST(ScenarioTest, SettlingInVsPassingThrough) {
    MeshSimulator sim;
    
    sim.addNode("pir_living", Tier::LEAF, "living-room", {CAP_PIR});
    sim.addNode("cam_living", Tier::EDGE, "living-room", {CAP_CAMERA_RGB, CAP_PERSON_DETECT});
    sim.addNode("light_living", Tier::LEAF, "living-room", {CAP_DIMMER});
    sim.addNode("ir_living", Tier::LEAF, "living-room", {CAP_IR_BLASTER});
    sim.addNode("hub", Tier::HUB, "hub", {});
    
    // Define room preferences
    sim.hub().defineScene("evening-living", ScenePriority::COMFORT, {
        {CAP_DIMMER, "set", 60.0f},
        {CAP_IR_BLASTER, "temp", 21.0f}
    });
    
    // --- Test 1: Passing through (grab keys, leave in 30s) ---
    sim.personEntersZone("living-room");
    sim.advanceTime(seconds(30));
    sim.personLeavesZone("living-room");
    sim.runUntilIdle();
    
    auto scene_activations = sim.sceneActivations("living-room", "evening-living");
    EXPECT_EQ(scene_activations.size(), 0) 
        << "Passing through should NOT activate room preferences";
    
    auto dimmer_cmds = sim.actuatorCommandsFor("light_living");
    EXPECT_EQ(dimmer_cmds.size(), 0)
        << "Lights should not change for passing through";
    
    sim.clearEventLog();
    
    // --- Test 2: Settling in (sit down, stay 5 minutes) ---
    sim.personEntersZone("living-room");
    sim.advanceTime(seconds(180));  // 3 minutes -- settling threshold
    sim.runUntilIdle();
    
    auto presence = sim.eventsOfType<PresenceEvent>();
    ASSERT_GE(presence.size(), 1);
    EXPECT_EQ(presence.back().intent, PresenceEvent::SETTLING_IN);
    
    scene_activations = sim.sceneActivations("living-room", "evening-living");
    EXPECT_GE(scene_activations.size(), 1)
        << "Settling in SHOULD activate room preferences";
    
    dimmer_cmds = sim.actuatorCommandsFor("light_living");
    EXPECT_GE(dimmer_cmds.size(), 1)
        << "Lights should be set to 60% for settling in";
    EXPECT_FLOAT_EQ(dimmer_cmds.back().value, 60.0f);
}
```

### Scenario Test: Environmental Control

```cpp
TEST(ScenarioTest, EnvironmentalControl) {
    MeshSimulator sim;
    
    sim.addNode("temp_bed", Tier::LEAF, "bedroom", {CAP_TEMPERATURE, CAP_HUMIDITY});
    sim.addNode("pir_bed", Tier::LEAF, "bedroom", {CAP_PIR});
    sim.addNode("ir_bed", Tier::LEAF, "bedroom", {CAP_IR_BLASTER});
    sim.addNode("hub", Tier::HUB, "hub", {});
    
    // --- Test 1: Temperature exceeds threshold -> HVAC adjusts ---
    sim.setTemperature("bedroom", 28.0f);  // above 26C threshold
    sim.runUntilIdle();
    
    auto hvac_cmds = sim.actuatorCommandsFor("ir_bed");
    ASSERT_GE(hvac_cmds.size(), 1);
    EXPECT_STREQ(hvac_cmds.back().command, "cool");
    
    sim.clearEventLog();
    
    // --- Test 2: Occupant leaves -> energy-saving mode ---
    sim.personEntersZone("bedroom");
    sim.advanceTime(minutes(5));
    sim.personLeavesZone("bedroom");
    sim.advanceTime(minutes(5));  // grace period
    sim.runUntilIdle();
    
    hvac_cmds = sim.actuatorCommandsFor("ir_bed");
    // Should have sent energy-saving command (e.g., raise setpoint)
    bool found_eco = false;
    for (const auto& cmd : hvac_cmds) {
        if (strcmp(cmd.command, "eco") == 0 || cmd.value > 26.0f) {
            found_eco = true;
            break;
        }
    }
    EXPECT_TRUE(found_eco) << "Should enter energy-saving mode when room vacated";
}
```

---

## Layer 4: Stress and Chaos Tests

### State Sync Under Partition

```cpp
TEST(StressTest, StateSyncAfterPartition) {
    MeshSimulator sim;
    // Create 3 edge nodes and a hub
    auto& hub = sim.addNode("hub", Tier::HUB, "hub", {});
    auto& edge1 = sim.addNode("edge1", Tier::EDGE, "zone-a", {});
    auto& edge2 = sim.addNode("edge2", Tier::EDGE, "zone-b", {});
    auto& edge3 = sim.addNode("edge3", Tier::EDGE, "zone-c", {});
    
    // Generate events across zones
    for (int i = 0; i < 100; i++) {
        sim.triggerMotion("zone-a");
        sim.triggerMotion("zone-b");
        sim.advanceTime(seconds(1));
    }
    sim.runUntilIdle();
    
    // Partition: disconnect edge2 from hub
    sim.partitionNode("edge2");
    
    // Generate more events while partitioned
    for (int i = 0; i < 50; i++) {
        sim.triggerMotion("zone-a");
        sim.triggerMotion("zone-b");  // edge2 buffers these locally
        sim.advanceTime(seconds(1));
    }
    
    // Heal partition
    sim.healPartition("edge2");
    sim.advanceTime(seconds(10));  // allow sync
    sim.runUntilIdle();
    
    // Verify: hub has all events from all zones
    auto hub_events = hub.eventStore().readSince(0);
    auto edge2_events = edge2.localEventCount();
    
    // All edge2's buffered events should now be in hub
    EXPECT_GE(hub_events.size(), 200 + 50)  // pre-partition + partitioned events
        << "Hub should have all events after partition heals";
}
```

### Rapid Node Join/Leave

```cpp
TEST(StressTest, RapidNodeChurn) {
    MeshSimulator sim;
    sim.addNode("hub", Tier::HUB, "hub", {});
    sim.addNode("edge1", Tier::EDGE, "zone-a", {});
    
    // Rapidly add and remove leaf nodes
    for (int i = 0; i < 20; i++) {
        char name[16];
        snprintf(name, sizeof(name), "leaf_%d", i);
        sim.addNode(name, Tier::LEAF, "zone-a", {CAP_PIR});
        sim.advanceTime(seconds(2));
        
        if (i > 5) {
            char old_name[16];
            snprintf(old_name, sizeof(old_name), "leaf_%d", i - 5);
            sim.removeNode(old_name);
        }
        sim.advanceTime(seconds(1));
    }
    sim.runUntilIdle();
    
    // Hub should have exactly the currently-alive nodes registered
    auto registry = sim.hub().nodeRegistry();
    EXPECT_EQ(registry.activeCount(), 7);  // hub + edge + 5 recent leaves
}
```

---

## Layer 5: Synthetic Data for ML Model Validation

For the person-vs-pet classification model (MobileNet-V2 INT8 on ESP32-S3):

### Test Image Dataset

Generate synthetic test images using a curated dataset:
- 200 images of people at various distances, angles, lighting conditions
- 200 images of cats/dogs at various positions
- 100 images of empty rooms / furniture / shadows (false trigger scenarios)
- 50 images of edge cases: person with pet, person partially occluded, cat on furniture at human height

### Model Accuracy Test

```python
def test_person_detection_accuracy():
    model = load_tflite_model("person_detect_int8.tflite")
    
    # Person images -- expect PERSON classification
    person_correct = 0
    for img in load_test_images("test_data/person/"):
        result = model.classify(preprocess(img))
        if result.entity == "PERSON" and result.confidence > 0.6:
            person_correct += 1
    person_accuracy = person_correct / len(person_images)
    
    # Pet images -- expect not-PERSON classification
    pet_correct = 0
    for img in load_test_images("test_data/pets/"):
        result = model.classify(preprocess(img))
        if result.entity != "PERSON" or result.confidence < 0.5:
            pet_correct += 1
    pet_accuracy = pet_correct / len(pet_images)
    
    assert person_accuracy > 0.90, f"Person detection accuracy {person_accuracy} below 90%"
    assert pet_accuracy > 0.85, f"Pet rejection accuracy {pet_accuracy} below 85%"
    
    # Edge cases -- log but don't fail (these inform model improvement)
    for img in load_test_images("test_data/edge_cases/"):
        result = model.classify(preprocess(img))
        log(f"Edge case: {img.name} -> {result.entity} ({result.confidence})")
```

### Inference Latency Test (on device)

```python
def test_inference_latency_on_device():
    node = SerialNode(EDGE_NODE_PORT)
    
    # Send test image via serial and measure inference time
    for img in load_test_images("test_data/person/")[:20]:
        raw = preprocess_for_device(img)
        start = time.time()
        node.command(f"classify {base64.b64encode(raw)}")
        result = node.read_response(timeout=1.0)
        elapsed_ms = (time.time() - start) * 1000
        
        assert elapsed_ms < 500, f"Inference took {elapsed_ms}ms, exceeds 500ms budget"
        assert "entity" in result, "Response should contain entity classification"
```

---

## CI/CD Integration

### Test Pipeline

```
1. Host unit tests (GoogleTest)        -- every commit, <30s
2. Property-based tests                -- every commit, <60s  
3. Scenario simulation tests           -- every commit, <120s
4. Firmware build (PlatformIO)         -- every commit, <180s
5. Model accuracy tests (Python)       -- nightly, <300s
6. Hardware-in-the-loop tests          -- weekly / pre-release, manual trigger
7. Power measurement tests             -- pre-release, manual trigger
```

Steps 1-4 run in CI (GitHub Actions) on every push. Steps 5-7 require hardware or large test data and run on a dedicated test bench.

### PlatformIO Test Configuration

```ini
; platformio.ini
[env:native]
platform = native
build_flags = -DUNIT_TEST -DMESHSWARM_TIER=3
test_framework = googletest
lib_deps = googletest

[env:esp32c3_leaf]
platform = espressif32
board = esp32-c3-devkitm-1
build_flags = -DMESHSWARM_TIER=0
test_framework = unity

[env:esp32s3_edge]
platform = espressif32
board = esp32-s3-devkitc-1
build_flags = -DMESHSWARM_TIER=2
test_framework = unity
```
