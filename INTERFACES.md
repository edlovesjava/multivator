# INTERFACES.md — Core C++ API Surface (Conservative Track)

## Overview

The API is organized around four concepts:
1. **Node** — the identity and lifecycle of a device
2. **Capability** — what a node can do (sense, actuate, compute)
3. **Transport** — how nodes communicate (ESP-NOW, Wi-Fi)
4. **State** — the shared key-value store

All APIs are compile-time configured via `#define` flags in `meshswarm_config.h`. Leaf nodes compile only the transport and capability code they need.

---

## 1. Node Lifecycle

```cpp
// meshswarm_config.h — compile-time tier selection
#define MESHSWARM_TIER 0  // 0=leaf, 1=smart_leaf, 2=edge, 3=hub

// meshswarm_node.h
enum class NodeTier : uint8_t {
    LEAF = 0,        // Tier 0: battery, sense/actuate only
    SMART_LEAF = 1,  // Tier 1: battery, local filtering/detection
    EDGE = 2,        // Tier 2: mains, inference + leaf coordination
    HUB = 3          // Tier 3: mains, aggregation + reasoning
};

struct NodeConfig {
    const char* node_name;          // Human-readable name, e.g. "pir_kitchen"
    NodeTier tier;
    const char* room;               // Room assignment, e.g. "kitchen"
    uint32_t sleep_duration_us;     // Deep sleep duration (Tier 0/1 only)
    uint16_t listen_window_ms;      // Command listen window (Tier 0/1 only)
    uint8_t espnow_channel;         // Wi-Fi channel for ESP-NOW (default: 1)
};

class MeshSwarmNode {
public:
    // Initialize node with config. Call once in setup().
    // Returns false if hardware init fails.
    bool begin(const NodeConfig& config);

    // Main loop tick. Call in loop().
    // For Tier 0/1: processes pending work, then enters deep sleep.
    // For Tier 2/3: processes incoming messages, runs state machine.
    void update();

    // Get this node's unique ID (derived from ESP32 MAC address)
    uint32_t getNodeId() const;

    // Get current tier
    NodeTier getTier() const;

    // Request deep sleep (Tier 0/1). Wakes on GPIO or timer.
    void requestSleep();

    // Check if node should sleep (all work drained)
    bool shouldSleep() const;
};
```

### Minimal Tier 0 Leaf Node Example

```cpp
#include "meshswarm_node.h"
#include "meshswarm_capability.h"

MeshSwarmNode node;
PIRSensorCapability pir(GPIO_NUM_4);

void setup() {
    NodeConfig config = {
        .node_name = "pir_hallway",
        .tier = NodeTier::LEAF,
        .room = "hallway",
        .sleep_duration_us = 0,  // wake on GPIO only
        .listen_window_ms = 100,
        .espnow_channel = 1
    };
    node.begin(config);
    node.addCapability(&pir);
}

void loop() {
    node.update();  // reads PIR, sends event, sleeps
}
```

---

## 2. Capability System

```cpp
// meshswarm_capability.h

// Base class for all capabilities (sensor, actuator, compute)
enum class CapabilityType : uint8_t {
    SENSOR,
    ACTUATOR,
    COMPUTE
};

struct CapabilityDescriptor {
    const char* name;           // e.g. "pir", "temperature", "light.switch"
    CapabilityType type;
    const char* unit;           // e.g. "celsius", "boolean", "lux" (sensors only)
    float min_value;            // valid range (sensors only)
    float max_value;
};

class Capability {
public:
    virtual ~Capability() = default;

    // Return capability descriptor for advertisement
    virtual const CapabilityDescriptor& describe() const = 0;

    // Called by node.update() on each tick
    virtual void poll() = 0;

    // Check if capability has pending data to send
    virtual bool hasEvent() const = 0;

    // Serialize event to buffer. Returns bytes written.
    // Buffer is pre-allocated by transport layer (max 200 bytes).
    virtual size_t serializeEvent(uint8_t* buffer, size_t max_len) const = 0;

    // Clear pending event after successful transmission
    virtual void clearEvent() = 0;
};

// --- Concrete sensor example ---

class PIRSensorCapability : public Capability {
public:
    explicit PIRSensorCapability(gpio_num_t pin);

    const CapabilityDescriptor& describe() const override;
    void poll() override;
    bool hasEvent() const override;
    size_t serializeEvent(uint8_t* buffer, size_t max_len) const override;
    void clearEvent() override;

private:
    gpio_num_t pin_;
    bool triggered_ = false;
    uint32_t trigger_timestamp_ = 0;
};

// --- Concrete actuator example ---

class ActuatorCapability : public Capability {
public:
    // Handle incoming command. Returns true if executed successfully.
    virtual bool executeCommand(const uint8_t* cmd, size_t cmd_len) = 0;
};

class RelayActuator : public ActuatorCapability {
public:
    explicit RelayActuator(gpio_num_t pin);

    const CapabilityDescriptor& describe() const override;
    void poll() override;
    bool hasEvent() const override;  // state-change ack
    size_t serializeEvent(uint8_t* buffer, size_t max_len) const override;
    void clearEvent() override;
    bool executeCommand(const uint8_t* cmd, size_t cmd_len) override;

private:
    gpio_num_t pin_;
    bool current_state_ = false;
    bool state_changed_ = false;
};
```

### Adding a New Sensor Type

To add a new sensor (e.g., soil moisture), a developer:
1. Subclasses `Capability`
2. Implements `describe()`, `poll()`, `hasEvent()`, `serializeEvent()`, `clearEvent()`
3. Instantiates it and calls `node.addCapability(&mySensor)` in `setup()`

No framework changes, no registration macros, no code generation. Five virtual methods.

---

## 3. Transport Layer

```cpp
// meshswarm_transport.h

// Message types in the protocol
enum class MessageType : uint8_t {
    CAPABILITY_ADVERTISE = 0x01,  // Node announces its capabilities
    SENSOR_EVENT         = 0x02,  // Sensor data from leaf → edge
    ACTUATOR_COMMAND     = 0x03,  // Command from hub → edge → leaf
    ACTUATOR_ACK         = 0x04,  // Acknowledgment from actuator
    STATE_UPDATE         = 0x05,  // Key-value state change
    STATE_SYNC           = 0x06,  // Full state sync (on join)
    OTA_ANNOUNCE         = 0x07,  // Firmware update available
    OTA_CHUNK            = 0x08,  // Firmware data chunk
    PING                 = 0x09,  // Heartbeat / liveness check
    PONG                 = 0x0A   // Heartbeat response
};

// Fixed-size message header (12 bytes)
struct __attribute__((packed)) MessageHeader {
    uint8_t  magic;          // 0xMS — protocol identifier
    uint8_t  version;        // Protocol version (currently 1)
    uint8_t  msg_type;       // MessageType enum
    uint8_t  flags;          // Reserved
    uint32_t src_node_id;    // Sender node ID
    uint32_t dst_node_id;    // Destination (0xFFFFFFFF = broadcast)
};

// Transport interface — abstracts ESP-NOW vs Wi-Fi
class Transport {
public:
    virtual ~Transport() = default;

    // Initialize transport. Returns false on failure.
    virtual bool begin(uint8_t channel) = 0;

    // Send message to a specific node or broadcast
    virtual bool send(uint32_t dst_node_id, const uint8_t* data, size_t len) = 0;

    // Register callback for incoming messages
    using ReceiveCallback = void(*)(const uint8_t* data, size_t len);
    virtual void onReceive(ReceiveCallback cb) = 0;

    // Poll for incoming messages (call in update loop)
    virtual void poll() = 0;
};

// ESP-NOW transport for Tier 0/1/2
class EspNowTransport : public Transport {
public:
    bool begin(uint8_t channel) override;
    bool send(uint32_t dst_node_id, const uint8_t* data, size_t len) override;
    void onReceive(ReceiveCallback cb) override;
    void poll() override;

    // ESP-NOW specific: set encryption key for peer
    bool setPeerKey(const uint8_t mac[6], const uint8_t key[16]);
};

// Wi-Fi UDP transport for Tier 2/3
class WiFiUdpTransport : public Transport {
public:
    bool begin(uint8_t channel) override;  // channel ignored, uses Wi-Fi
    bool send(uint32_t dst_node_id, const uint8_t* data, size_t len) override;
    void onReceive(ReceiveCallback cb) override;
    void poll() override;

    // Wi-Fi specific
    bool connectToNetwork(const char* ssid, const char* password);
};
```

---

## 4. State Store

```cpp
// meshswarm_state.h

// A single state entry
struct StateEntry {
    char key[32];           // e.g. "room.living.temp"
    uint8_t value[64];      // serialized value
    uint8_t value_len;
    uint32_t version;       // monotonic, hub-assigned
    uint32_t origin_node;   // node that produced this value
    uint32_t timestamp;     // hub-assigned epoch seconds
};

// State store (hub maintains full store; edge/leaf maintain subset)
class StateStore {
public:
    // Set a value. On non-hub nodes, queues for transmission to hub.
    bool set(const char* key, const void* value, size_t len);

    // Convenience setters
    bool setInt(const char* key, int32_t value);
    bool setFloat(const char* key, float value);
    bool setBool(const char* key, bool value);

    // Get a value. Returns false if key not found.
    bool get(const char* key, void* value, size_t max_len, size_t* actual_len) const;
    bool getInt(const char* key, int32_t* value) const;
    bool getFloat(const char* key, float* value) const;
    bool getBool(const char* key, bool* value) const;

    // Register a callback for state changes on a key pattern
    // Pattern supports trailing wildcard: "room.living.*"
    using WatchCallback = void(*)(const char* key, const StateEntry& entry);
    bool watch(const char* pattern, WatchCallback cb);

    // Remove a watch
    void unwatch(const char* pattern);

    // Get version of a key (for delta sync)
    uint32_t getVersion(const char* key) const;

    // Apply a state update from the network (called by transport layer)
    bool applyUpdate(const StateEntry& entry);

    // Get all entries newer than a given version (for sync)
    size_t getEntriesSince(uint32_t since_version, StateEntry* out, size_t max_entries) const;

private:
    static constexpr size_t MAX_ENTRIES = 256;  // Tier 3 hub
    // Tier 0/1 compile with MAX_ENTRIES = 16
    // Tier 2 compile with MAX_ENTRIES = 64
    StateEntry entries_[MAX_ENTRIES];
    size_t count_ = 0;
};
```

---

## 5. Security Detection (Hub Tier 3 Only)

```cpp
// meshswarm_security.h (compiled only for MESHSWARM_TIER >= 3)

enum class SecurityEvent : uint8_t {
    MOTION_DETECTED,
    PERSON_DETECTED,
    ANIMAL_DETECTED,
    DOOR_OPENED,
    DOOR_CLOSED,
    PRESENCE_START,
    PRESENCE_END,
    UNUSUAL_ACTIVITY
};

enum class PresenceIntent : uint8_t {
    UNKNOWN,
    PASSING_THROUGH,
    SETTLING_IN
};

struct RoomState {
    bool occupied;
    uint32_t occupied_since;        // epoch seconds
    PresenceIntent intent;
    uint8_t motion_count_1min;      // motion events in last 60s
    bool person_confirmed;          // camera confirmed person
    bool preferences_activated;
};

class SecurityEngine {
public:
    // Configure settling-in threshold (default: 180 seconds / 3 minutes)
    void setSettlingThreshold(uint32_t seconds);

    // Process incoming event from state store
    void processEvent(const char* room, SecurityEvent event, uint32_t timestamp);

    // Poll — advances timers, checks for settling-in transitions
    void update(uint32_t current_time);

    // Get current room state
    const RoomState* getRoomState(const char* room) const;

    // Register callback for security decisions
    using AlertCallback = void(*)(const char* room, SecurityEvent event,
                                   const RoomState& state);
    void onAlert(AlertCallback cb);

    // Register callback for automation triggers
    using AutomationCallback = void(*)(const char* room, PresenceIntent intent);
    void onPresenceIntent(AutomationCallback cb);

private:
    static constexpr size_t MAX_ROOMS = 16;
    RoomState rooms_[MAX_ROOMS];
    char room_names_[MAX_ROOMS][16];
    size_t room_count_ = 0;

    uint32_t settling_threshold_s_ = 180;

    // Anomaly detection: hourly event histogram per room
    // 7 days * 24 hours = 168 bins per room
    uint16_t event_histogram_[MAX_ROOMS][168];

    AlertCallback alert_cb_ = nullptr;
    AutomationCallback automation_cb_ = nullptr;
};
```

---

## 6. Putting It Together — Hub Node Example

```cpp
#include "meshswarm_node.h"
#include "meshswarm_capability.h"
#include "meshswarm_state.h"
#include "meshswarm_security.h"

MeshSwarmNode node;
StateStore state;
SecurityEngine security;

void onAlert(const char* room, SecurityEvent event, const RoomState& rs) {
    if (event == SecurityEvent::PERSON_DETECTED && !rs.preferences_activated) {
        // Unknown person, no household beacon — potential intruder
        state.setBool("alert.intruder", true);
        state.set("alert.room", room, strlen(room));
        // Actuator command will be dispatched by hub orchestrator
    }
}

void onPresenceIntent(const char* room, PresenceIntent intent) {
    if (intent == PresenceIntent::SETTLING_IN) {
        // Activate room preferences via actuator commands
        char key[32];
        snprintf(key, sizeof(key), "room.%s.prefs_active", room);
        state.setBool(key, true);
    }
}

void setup() {
    NodeConfig config = {
        .node_name = "hub_main",
        .tier = NodeTier::HUB,
        .room = "utility",
        .sleep_duration_us = 0,
        .listen_window_ms = 0,
        .espnow_channel = 1
    };
    node.begin(config);
    security.setSettlingThreshold(180);  // 3 minutes
    security.onAlert(onAlert);
    security.onPresenceIntent(onPresenceIntent);
}

void loop() {
    node.update();
    security.update(millis() / 1000);
}
```

---

## Design Principles Reflected in the API

1. **No dynamic allocation in hot paths**: All arrays are fixed-size, compile-time configured per tier.
2. **No RTTI, no exceptions**: Pure virtual dispatch only. Error codes, not exceptions.
3. **Compile-time tier selection**: `#define MESHSWARM_TIER` gates which code is compiled. A Tier 0 node binary does not contain SecurityEngine or WiFiUdpTransport.
4. **Explicit ownership**: No shared pointers, no reference counting. Node owns capabilities. Hub owns state store and security engine.
5. **Five-method capability interface**: Adding a new sensor/actuator is straightforward — implement five virtual methods, no framework magic.
6. **Flat message format**: 12-byte header + payload. No protobuf, no JSON on the wire between nodes. ArduinoJson used only for hub REST API and configuration.
