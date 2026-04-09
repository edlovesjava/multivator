# INTERFACES.md -- Core C++ API Surface (Experimental Track)

## Design Goals

The API optimizes for **expressiveness and composability**. Key differences from a conventional approach:
1. Capabilities are composable -- the system auto-discovers what intelligence pipelines are possible
2. Event cascade is type-safe -- events carry semantic types, not raw bytes
3. Policies flow downward as first-class objects, not ad-hoc configuration
4. Zero-copy where possible -- sensor data stays in-place through the processing pipeline

---

## 1. Node Lifecycle -- Fluent Builder Pattern

```cpp
// meshswarm.h -- single include for all tiers

enum class Tier : uint8_t { LEAF = 0, SMART_LEAF = 1, EDGE = 2, HUB = 3 };
enum class PowerSource : uint8_t { BATTERY_COIN, BATTERY_LIPO, MAINS };

class MeshNode {
public:
    // Builder-style configuration
    static MeshNode create(const char* name, Tier tier);

    MeshNode& inZone(const char* zone);
    MeshNode& withPower(PowerSource src, uint16_t capacity_mah = 0);
    MeshNode& onChannel(uint8_t ch);

    // Add capabilities -- variadic, type-safe
    template<typename Cap, typename... Args>
    Cap& addCapability(Args&&... args);

    // Lifecycle
    bool begin();      // Initialize hardware, join mesh, advertise capabilities
    void update();     // Main loop tick
    void sleep();      // Enter deep sleep (Tier 0/1 only)

    // Identity
    uint32_t id() const;
    Tier tier() const;
    const char* zone() const;

    // Event subscription (for edge/hub nodes processing events from others)
    template<typename EventT>
    void on(void(*handler)(const EventT& event, const NodeContext& ctx));

    // Policy push (for hub/edge pushing policies downward)
    void pushPolicy(uint32_t target_node, const Policy& policy);
    void pushZonePolicy(const char* zone, const Policy& policy);
};
```

### Minimal Tier 0 Leaf -- 12 lines

```cpp
#include "meshswarm.h"

auto node = MeshNode::create("pir_hallway", Tier::LEAF)
    .inZone("hallway")
    .withPower(PowerSource::BATTERY_COIN);

void setup() {
    node.addCapability<PIRSensor>(GPIO_NUM_4);
    node.begin();  // joins mesh, advertises CAP_PIR, sleeps between triggers
}

void loop() {
    node.update();  // reads PIR, fires event upward, sleeps
}
```

### Smart Leaf with Keyword Spotting -- still simple

```cpp
#include "meshswarm.h"

auto node = MeshNode::create("mic_kitchen", Tier::SMART_LEAF)
    .inZone("kitchen")
    .withPower(PowerSource::BATTERY_LIPO, 500);

void setup() {
    auto& mic = node.addCapability<I2SMicrophone>(I2S_NUM_0, PIN_BCLK, PIN_LRCK, PIN_DIN);
    auto& kws = node.addCapability<KeywordSpotter>(mic, keywords::LIGHTS_ON | keywords::LIGHTS_OFF);
    node.begin();
}

void loop() {
    node.update();
}
```

Note how `KeywordSpotter` takes a reference to `I2SMicrophone` -- capabilities can depend on other capabilities. The system resolves this dependency graph at `begin()`.

---

## 2. Event System -- Typed Events, Not Raw Bytes

```cpp
// events.h

// Base event -- all events carry origin, timestamp, zone
struct Event {
    uint32_t origin_node;
    uint32_t timestamp_ms;
    const char* zone;
    float anomaly_score;  // 0.0-1.0, filled by hub's anomaly engine
};

// Tier 0/1 events -- raw sensor signals
struct MotionEvent : Event {
    gpio_num_t sensor_pin;
    bool triggered;
};

struct DoorEvent : Event {
    enum State : uint8_t { CLOSED, OPEN } state;
};

struct EnvironmentEvent : Event {
    float temperature_c;
    float humidity_pct;
};

struct AudioEvent : Event {
    enum Class : uint8_t { AMBIENT, SPEECH, GLASS_BREAK, KEYWORD } classification;
    uint8_t keyword_id;      // valid only if classification == KEYWORD
    float confidence;
};

// Tier 2 events -- classified/semantic
struct PersonDetectionEvent : Event {
    enum Entity : uint8_t { NONE, PERSON, CAT, DOG, VEHICLE, UNKNOWN } entity;
    float confidence;
    struct { uint16_t x, y, w, h; } bounding_box;
};

struct PresenceEvent : Event {
    enum Intent : uint8_t { UNKNOWN, PASSING_THROUGH, SETTLING_IN } intent;
    uint32_t duration_s;
};

// Tier 3 events -- security decisions
struct SecurityAlert : Event {
    enum Level : uint8_t { INFO, SOFT, HARD, CRITICAL } level;
    const char* description;
    uint8_t recommended_actions;  // bitmask: ALARM | LIGHTS | NOTIFY | RECORD | LOCK
};
```

### Event Handlers -- Pattern Matching Style

```cpp
// On an edge node (Tier 2), handling events from leaf nodes in its zone:

void setup() {
    auto node = MeshNode::create("edge_frontdoor", Tier::EDGE)
        .inZone("front-door");

    auto& cam = node.addCapability<Camera>(CAMERA_MODEL_OV2640);
    auto& detector = node.addCapability<PersonDetector>(cam);  // depends on camera

    // When PIR fires in our zone, activate camera + run detection
    node.on<MotionEvent>([&](const MotionEvent& ev, const NodeContext& ctx) {
        if (ev.triggered) {
            auto frame = cam.capture();
            auto result = detector.classify(frame);
            ctx.emit(PersonDetectionEvent{
                .entity = result.entity,
                .confidence = result.confidence,
                .bounding_box = result.bbox
            });
            // Frame is discarded here -- never stored, never transmitted
        }
    });

    node.begin();
}
```

---

## 3. Capability System -- Composable and Self-Describing

```cpp
// capability.h

// Capability tags for the manifest system
enum class CapTag : uint16_t {
    // Sensors
    CAP_PIR             = 0x0001,
    CAP_DOOR_CONTACT    = 0x0002,
    CAP_TEMPERATURE     = 0x0003,
    CAP_HUMIDITY        = 0x0004,
    CAP_CAMERA_RGB      = 0x0010,
    CAP_MICROPHONE      = 0x0020,
    CAP_SOIL_MOISTURE   = 0x0030,
    CAP_LIGHT_LEVEL     = 0x0031,

    // Inference
    CAP_PERSON_DETECT   = 0x0100,
    CAP_KEYWORD_SPOT    = 0x0101,
    CAP_ANOMALY_SCORE   = 0x0102,
    CAP_STT_FULL        = 0x0103,

    // Actuators
    CAP_RELAY           = 0x0200,
    CAP_DIMMER          = 0x0201,
    CAP_IR_BLASTER      = 0x0202,
    CAP_BUZZER          = 0x0203,
    CAP_SPEAKER         = 0x0204,
    CAP_SERVO           = 0x0205,
};

// Every capability implements this interface
class ICapability {
public:
    virtual ~ICapability() = default;

    // Self-description for the capability manifest
    virtual CapTag tag() const = 0;
    virtual const char* name() const = 0;

    // Lifecycle
    virtual bool init() = 0;          // Called during node.begin()
    virtual void tick() = 0;          // Called during node.update()

    // Dependency declaration (optional)
    virtual CapTag depends_on() const { return static_cast<CapTag>(0); }
};

// Sensor capabilities produce events
template<typename EventT>
class Sensor : public ICapability {
public:
    using EventType = EventT;
    using Handler = void(*)(const EventT&);

    void onEvent(Handler h) { handler_ = h; }

protected:
    void emit(const EventT& ev) { if (handler_) handler_(ev); }

private:
    Handler handler_ = nullptr;
};

// Actuator capabilities accept commands
class Actuator : public ICapability {
public:
    // Semantic command execution
    virtual bool execute(const char* command, float value = 0) = 0;

    // Command enumeration for discovery
    virtual uint8_t commandCount() const = 0;
    virtual const char* commandName(uint8_t idx) const = 0;
};
```

### Adding a New Sensor -- Soil Moisture Example

```cpp
// soil_moisture.h
class SoilMoistureSensor : public Sensor<EnvironmentEvent> {
public:
    explicit SoilMoistureSensor(adc_channel_t channel)
        : channel_(channel) {}

    CapTag tag() const override { return CapTag::CAP_SOIL_MOISTURE; }
    const char* name() const override { return "soil_moisture"; }

    bool init() override {
        adc1_config_width(ADC_WIDTH_BIT_12);
        adc1_config_channel_atten(channel_, ADC_ATTEN_DB_11);
        return true;
    }

    void tick() override {
        int raw = adc1_get_raw(channel_);
        float moisture_pct = (4095.0f - raw) / 4095.0f * 100.0f;

        if (abs(moisture_pct - last_reading_) > 2.0f) {  // >2% change
            last_reading_ = moisture_pct;
            emit(EnvironmentEvent{
                .temperature_c = 0,  // not applicable
                .humidity_pct = moisture_pct  // repurpose humidity field
            });
        }
    }

private:
    adc_channel_t channel_;
    float last_reading_ = 0;
};

// Usage:
// node.addCapability<SoilMoistureSensor>(ADC1_CHANNEL_0);
```

---

## 4. Policy System -- Intelligence Flows Downward

```cpp
// policy.h

enum class PolicyType : uint8_t {
    SLEEP_SCHEDULE,     // when to deep-sleep vs stay awake
    ALERT_LEVEL,        // what alert level to apply to detections
    SCENE_ACTIVATE,     // activate a scene in a zone
    THRESHOLD_ADJUST,   // adjust sensor thresholds
    INFERENCE_GATE,     // enable/disable inference triggers
};

struct Policy {
    PolicyType type;
    uint32_t valid_from;    // epoch seconds (0 = immediate)
    uint32_t valid_until;   // epoch seconds (0 = indefinite)
    uint8_t payload[32];    // type-specific data
};

// Concrete policy examples:

struct SleepPolicy {
    uint8_t hour_start;     // 0-23
    uint8_t hour_end;       // 0-23
    bool interrupt_only;    // true = skip periodic wakes
    // Pushed by hub to Tier 1 nodes during quiet hours
};

struct AlertLevelPolicy {
    uint8_t base_level;     // default alert level for zone
    uint8_t escalation;     // escalation behavior
    // Pushed by hub to edge nodes: "front-door is alert-level-3 after 23:00"
};

struct InferenceGatePolicy {
    uint16_t trigger_cap;       // CapTag that triggers inference
    uint16_t inference_cap;     // CapTag to activate
    float confidence_threshold; // minimum confidence to escalate
    // Example: "activate CAP_PERSON_DETECT when CAP_PIR fires, escalate if conf > 0.6"
};
```

### Policy in Action -- Hub Pushes Quiet-Hours Policy

```cpp
// hub_main.cpp

void updateSleepPolicies() {
    // Hub learned: zone "front-door" is quiet 01:00-05:00 on weekdays
    SleepPolicy quiet_hours = {
        .hour_start = 1,
        .hour_end = 5,
        .interrupt_only = true
    };

    Policy p = {
        .type = PolicyType::SLEEP_SCHEDULE,
        .valid_from = next_weekday_01am(),
        .valid_until = next_weekday_05am()
    };
    memcpy(p.payload, &quiet_hours, sizeof(quiet_hours));

    hub.pushZonePolicy("front-door", p);
    // All Tier 1 nodes in "front-door" zone will skip periodic wakes 01:00-05:00
}
```

---

## 5. Zone and Scene System

```cpp
// zone.h

struct Zone {
    char name[16];
    uint32_t node_ids[16];  // nodes in this zone
    uint8_t node_count;
    CapTag available_caps[32]; // union of all capabilities in zone
    uint8_t cap_count;
};

// scene.h

enum class ScenePriority : uint8_t {
    DEFAULT = 0,
    ECO = 1,
    COMFORT = 2,
    CRITICAL = 3,
    SAFETY = 4
};

struct ActuatorTarget {
    CapTag actuator_type;
    char command[16];
    float value;
};

struct Scene {
    char name[24];
    ScenePriority priority;
    ActuatorTarget targets[8];
    uint8_t target_count;
};

class SceneEngine {
public:
    // Register a scene
    void defineScene(const Scene& scene);

    // Activate a scene in a zone
    // Higher priority scenes override lower for conflicting actuators
    void activate(const char* zone, const char* scene_name);

    // Deactivate
    void deactivate(const char* zone, const char* scene_name);

    // Get the effective command for an actuator given all active scenes
    bool resolveCommand(const char* zone, CapTag actuator,
                        char* cmd_out, float* val_out) const;
};
```

### Scene Definition Example

```cpp
Scene intruder_alert = {
    .name = "intruder-alert",
    .priority = ScenePriority::SAFETY,
    .targets = {
        { CapTag::CAP_RELAY,      "on",    1.0f },   // all lights on
        { CapTag::CAP_BUZZER,     "alarm", 1.0f },   // sound alarm
        { CapTag::CAP_DIMMER,     "set",   100.0f }, // full brightness
    },
    .target_count = 3
};

Scene evening_comfort = {
    .name = "evening",
    .priority = ScenePriority::COMFORT,
    .targets = {
        { CapTag::CAP_DIMMER,     "set",  60.0f },  // 60% brightness
        { CapTag::CAP_IR_BLASTER, "temp", 21.0f },  // HVAC to 21C
    },
    .target_count = 2
};
```

---

## 6. Event Sourcing State

```cpp
// event_store.h (Hub only, compiled out for lower tiers)

struct StoredEvent {
    uint64_t sequence;          // monotonic, hub-assigned
    uint32_t timestamp;         // epoch seconds
    uint32_t origin_node;
    uint8_t  event_type;        // discriminator
    uint8_t  payload[64];       // serialized event
    uint8_t  payload_len;
};

class EventStore {
public:
    // Append an event (hub assigns sequence number)
    uint64_t append(uint32_t origin, uint8_t type,
                    const uint8_t* payload, uint8_t len);

    // Read events since a sequence number (for edge node sync)
    size_t readSince(uint64_t since_seq, StoredEvent* out, size_t max) const;

    // Read events in a time window for a zone
    size_t readWindow(const char* zone, uint32_t from_time,
                      uint32_t to_time, StoredEvent* out, size_t max) const;

    // Compact: remove events older than retention period
    void compact(uint32_t before_timestamp);

    // Current head sequence number
    uint64_t head() const;

private:
    // Circular buffer on flash (SPIFFS/LittleFS)
    static constexpr size_t MAX_EVENTS = 8192;  // ~1MB at ~128B/event
    uint64_t head_seq_ = 0;
};
```

---

## 7. Anomaly Scoring Engine (Hub Only)

```cpp
// anomaly.h

class AnomalyEngine {
public:
    // Feed an event for anomaly scoring
    // Returns anomaly score 0.0 (normal) to 1.0 (highly anomalous)
    float score(const StoredEvent& event);

    // Update learned patterns (called periodically, e.g. hourly)
    void updatePatterns();

    // Get the activity histogram for a zone (for predictive sleep)
    const uint16_t* getActivityHistogram(const char* zone) const;

    // Configure alert thresholds
    void setSoftAlertThreshold(float t);   // default 0.7
    void setHardAlertThreshold(float t);   // default 0.9

private:
    // Per-zone, per-hour-of-week activity counts
    // 168 bins (7 days x 24 hours) per zone, max 16 zones
    struct ZonePattern {
        char name[16];
        uint16_t histogram[168];     // event counts per hour-slot
        float mean;
        float stddev;
    };
    ZonePattern zones_[16];
    uint8_t zone_count_ = 0;

    float soft_threshold_ = 0.7f;
    float hard_threshold_ = 0.9f;
};
```

---

## 8. Putting It All Together -- Hub Node

```cpp
#include "meshswarm.h"
#include "event_store.h"
#include "anomaly.h"

auto hub = MeshNode::create("hub_main", Tier::HUB)
    .inZone("hub")
    .withPower(PowerSource::MAINS);

EventStore events;
AnomalyEngine anomaly;
SceneEngine scenes;

void setup() {
    scenes.defineScene(intruder_alert);
    scenes.defineScene(evening_comfort);

    // Security: human detected at edge tier
    hub.on<PersonDetectionEvent>([](const PersonDetectionEvent& ev, const NodeContext& ctx) {
        float score = anomaly.score(/* ... */);
        ev.anomaly_score = score;

        if (ev.entity == PersonDetectionEvent::PERSON && score > 0.9f) {
            scenes.activate(ev.zone, "intruder-alert");
            ctx.emit(SecurityAlert{
                .level = SecurityAlert::CRITICAL,
                .description = "Unrecognized person detected",
                .recommended_actions = 0xFF  // all actions
            });
        }
    });

    // Presence intent: settling in vs passing through
    hub.on<MotionEvent>([](const MotionEvent& ev, const NodeContext& ctx) {
        static uint32_t zone_entry_time[16] = {};
        // ... presence duration tracking ...
        // If duration > 180s and person confirmed:
        //   scenes.activate(ev.zone, "evening");
        //   ctx.emit(PresenceEvent{.intent = PresenceEvent::SETTLING_IN});
    });

    // Environmental: HVAC control
    hub.on<EnvironmentEvent>([](const EnvironmentEvent& ev, const NodeContext& ctx) {
        if (ev.temperature_c > 26.0f) {
            // Find IR blaster actuator in zone, send cool command
        }
    });

    hub.begin();
}

void loop() {
    hub.update();
    anomaly.updatePatterns();  // internally rate-limited
}
```

---

## Design Principles Reflected in the API

1. **Typed events over raw bytes**: Compile-time type safety for event handlers. A MotionEvent handler cannot accidentally receive an EnvironmentEvent.
2. **Capability composition**: Capabilities can depend on other capabilities (KeywordSpotter depends on Microphone, PersonDetector depends on Camera). The framework resolves the dependency graph.
3. **Policy as first-class**: Sleep schedules, alert levels, and inference gates are explicit objects that flow downward through the hierarchy, not ambient configuration.
4. **Builder pattern for node setup**: Fluent API makes node configuration readable and self-documenting.
5. **Lambda event handlers**: Modern C++ lambdas with captures for concise, inline event processing.
6. **Zero-copy camera pipeline**: Camera frame is captured, classified, and discarded in the event handler. The frame pointer is never stored or transmitted.
7. **Compile-time tier exclusion**: EventStore, AnomalyEngine, and SceneEngine are compiled only for Tier 3. Tier 0 binary contains only the transport layer and its sensor capability.
