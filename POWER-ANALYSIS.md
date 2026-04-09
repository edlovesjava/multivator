# POWER-ANALYSIS.md — Conservative Track

## Methodology

Power estimates are based on ESP32 family datasheet values and published measurements from the ESP-IDF community. All figures are typical-case; actual values vary with temperature, antenna load, and firmware.

---

## ESP32 Family Power Characteristics

| State | ESP32 | ESP32-S3 | ESP32-C3 |
|-------|-------|----------|----------|
| Active (Wi-Fi TX) | 160-260 mA | 130-240 mA | 110-190 mA |
| Active (CPU only, 160MHz) | 30-68 mA | 22-50 mA | 15-35 mA |
| Active (ESP-NOW TX) | 120-180 mA | 100-160 mA | 80-130 mA |
| Light sleep | 0.8 mA | 0.2-0.8 mA | 0.13 mA |
| Deep sleep (RTC) | 10 uA | 7 uA | 5 uA |
| Deep sleep (GPIO wake) | 10 uA | 7 uA | 5 uA |
| Hibernation | 5 uA | 5 uA | 1 uA |

---

## Tier 0 — Leaf Node (Battery, Months)

**Representative device**: ESP32-C3 Mini + PIR sensor (or reed switch)
**Power source**: 2x AA batteries (3000 mAh @ 3V) or CR123A (1500 mAh @ 3V)

### Duty Cycle Model

| Phase | Duration | Current | Energy per cycle |
|-------|----------|---------|-----------------|
| Deep sleep (GPIO wake) | ~99.95% of time | 5 uA | baseline |
| Wake + read sensor | 5 ms | 20 mA | 0.1 mAh negligible |
| ESP-NOW TX (event report) | 10 ms | 130 mA | 0.00036 mAh |
| Wait for ACK | 15 ms | 80 mA | 0.00033 mAh |
| Return to sleep | 2 ms | 20 mA | negligible |
| **Total per event** | ~32 ms | — | ~0.001 mAh |

### Hourly Listen Window (for OTA/commands)

| Phase | Duration | Current | Energy |
|-------|----------|---------|--------|
| Wake from sleep | 5 ms | 20 mA | negligible |
| ESP-NOW listen | 100 ms | 80 mA | 0.0022 mAh |
| Return to sleep | 2 ms | 20 mA | negligible |
| **Total per hour** | ~107 ms | — | ~0.0025 mAh |

### Battery Life Estimate

**Assumptions**: 20 events/day (typical PIR in a hallway), 24 listen windows/day

| Component | Daily drain |
|-----------|------------|
| Deep sleep (24h) | 0.12 mAh |
| Events (20x) | 0.02 mAh |
| Listen windows (24x) | 0.06 mAh |
| PIR sensor quiescent | ~0.12 mAh (5 uA typical) |
| Voltage regulator quiescent | ~0.24 mAh (10 uA typical) |
| **Total daily** | **~0.56 mAh** |

| Battery | Capacity | Estimated Life |
|---------|----------|---------------|
| 2x AA (3000 mAh) | 3000 mAh | **~14.7 years** (theoretical) |
| CR123A (1500 mAh) | 1500 mAh | **~7.3 years** (theoretical) |
| CR2032 (220 mAh) | 220 mAh | **~13 months** |

**Practical estimate**: Battery self-discharge (~2-5%/year for alkaline, ~1%/year for lithium) limits actual life. Realistic targets:

- **2x AA: 2-4 years** (alkaline self-discharge limited)
- **CR123A: 3-5 years** (lithium primary, low self-discharge)
- **CR2032: 8-12 months** (capacity-limited, suitable for door sensors with <5 events/day)

This comfortably exceeds the "months" requirement.

---

## Tier 1 — Smart Leaf Node (Battery, Days/Weeks)

**Representative device**: ESP32-S3 + PDM microphone + LiPo
**Power source**: 500 mAh LiPo

### Duty Cycle Model — Voice Wake Word Detection

| Phase | Duration | Current | Notes |
|-------|----------|---------|-------|
| Light sleep + mic sampling | Continuous | 1.5 mA | PDM mic ~0.5mA + ESP32-S3 light sleep with periodic DMA |
| Wake word processing (every 100ms) | 50 ms | 35 mA | Simple energy-based VAD, not full inference |
| Full voice processing (on VAD trigger) | 2s | 80 mA | Run small keyword spotting model |
| ESP-NOW TX result | 10 ms | 160 mA | Send recognized command to edge |
| **Weighted average** | — | ~3-5 mA | Depends on VAD trigger rate |

### Battery Life Estimate

| Mode | Average Current | Life on 500mAh |
|------|----------------|----------------|
| Always-listening (light sleep + VAD) | 3 mA | ~7 days |
| Scheduled listening (listen 10min/hour) | 1.5 mA | ~14 days |
| PIR-triggered listening (listen on motion) | 0.5 mA | ~6 weeks |

**Recommendation**: Use PIR-triggered voice listening. Microphone only activates when motion is detected in the room. This achieves the "days/weeks" target while providing useful voice interaction.

The RFP requirement of ">24 hours on 500mAh LiPo" is easily met by all modes.

---

## Tier 2 — Edge Node (Mains Powered)

**Representative device**: ESP32-S3 + OV2640 camera + USB-C power
**Power source**: 5V USB-C (unlimited)

### Power Profile

| Phase | Current @ 5V | Power | Notes |
|-------|-------------|-------|-------|
| Idle (Wi-Fi connected, listening) | 80 mA | 0.4 W | ESP-NOW + Wi-Fi active |
| Camera capture + inference | 250 mA | 1.25 W | 2-3 seconds per frame |
| Peak (Wi-Fi TX + camera + CPU) | 350 mA | 1.75 W | Brief bursts |
| **Typical average** | 100 mA | 0.5 W | Camera triggered by PIR events |

**Annual energy cost**: ~4.4 kWh/year @ 0.5W average ≈ $0.50-0.70/year (US residential rates)

No power optimization needed. The design triggers camera capture only on PIR events from leaf nodes, so the camera is idle most of the time.

---

## Tier 3 — Hub/Gateway (Mains Powered)

**Representative device**: ESP32-S3 + microSD + optional Ethernet
**Power source**: 5V USB-C (unlimited)

### Power Profile

| Phase | Current @ 5V | Power | Notes |
|-------|-------------|-------|-------|
| Idle (Wi-Fi, processing state) | 100 mA | 0.5 W | Always-on baseline |
| Active processing (state machine, rules) | 150 mA | 0.75 W | On event bursts |
| microSD write | 170 mA | 0.85 W | Periodic logging |
| **Typical average** | 120 mA | 0.6 W | |

**Annual energy cost**: ~5.3 kWh/year ≈ $0.60-0.80/year

---

## Intelligence-to-Power Ratio Analysis

### Scenario: Intruder vs Cat Detection

| Step | Where | Power Cost | Time |
|------|-------|-----------|------|
| PIR trigger | Tier 0 leaf | 0.001 mAh (battery) | 32 ms |
| Event → edge node | ESP-NOW TX | included above | included |
| Camera capture + person detection | Tier 2 edge | ~0.17 mAh (mains) | 2-3s |
| Classification result → hub | Wi-Fi TX | ~0.01 mAh (mains) | 50 ms |
| Rule evaluation (intruder vs cat) | Tier 3 hub | ~0.005 mAh (mains) | 10 ms |
| **Total battery cost** | — | **0.001 mAh** | — |
| **Total mains cost** | — | **~0.2 mAh** | — |
| **Total response time** | — | — | **~3 seconds** |

### Scenario: Settling In vs Passing Through

| Step | Where | Power Cost | Time |
|------|-------|-----------|------|
| PIR trigger | Tier 0 leaf | 0.001 mAh (battery) | 32 ms |
| Presence start event → hub | via edge | 0.001 mAh (battery) | 100 ms |
| Timer starts at hub | Tier 3 hub | negligible (mains) | — |
| Continuous presence monitoring | Tier 0 leaf, periodic | 0.001 mAh per event | every 30s |
| Settling-in decision (3 min) | Tier 3 hub | negligible (mains) | 180s |
| **Total battery cost** | — | **~0.007 mAh** | — |
| **Total decision time** | — | — | **180 seconds** (by design) |

---

## Summary

| Tier | Power Source | Average Power | Target Life | Achievable? |
|------|------------|---------------|-------------|-------------|
| 0 | 2xAA / CR123A | <1 mW | Months-years | Yes, comfortably |
| 1 | 500mAh LiPo | 3-5 mW (listening) | Days-weeks | Yes |
| 2 | USB-C mains | 0.5 W | N/A (mains) | N/A |
| 3 | USB-C mains | 0.6 W | N/A (mains) | N/A |

The conservative approach of ESP-NOW (no mesh maintenance overhead) and fire-and-forget leaf nodes delivers the best possible battery life by eliminating all unnecessary radio time.
