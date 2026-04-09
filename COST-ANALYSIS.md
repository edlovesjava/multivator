# COST-ANALYSIS.md — Conservative Track

## Component Selection Criteria

All components are selected for:
1. Wide availability (Amazon, AliExpress, Mouser/Digikey)
2. Proven ESP32 compatibility with Arduino/PlatformIO
3. Lowest cost at equivalent functionality
4. No proprietary protocols or vendor lock-in

---

## Bill of Materials by Tier

### Tier 0 — Leaf Sensor Node (Battery)

**PIR Motion Sensor Variant**

| Component | Part | Unit Cost (USD) | Notes |
|-----------|------|----------------|-------|
| MCU | ESP32-C3 Mini (Seeed XIAO) | $4.99 | Smallest/cheapest ESP32 with deep sleep |
| Sensor | AM312 PIR module | $0.80 | 3.3V, low quiescent current (<10uA) |
| Power | 2x AA battery holder | $0.30 | 3V direct, no regulator needed for C3 |
| Enclosure | 3D printed or ABS project box | $1.00 | ~60x40x25mm |
| Misc | PCB/protoboard, wires, resistors | $0.50 | — |
| **Total** | | **$7.59** | |

**Door/Window Sensor Variant**

| Component | Part | Unit Cost (USD) | Notes |
|-----------|------|----------------|-------|
| MCU | ESP32-C3 Mini (Seeed XIAO) | $4.99 | — |
| Sensor | MC-38 reed switch | $0.40 | Magnetic, NO/NC |
| Power | CR2032 holder + coin cell | $0.50 | Sufficient for <5 events/day |
| Enclosure | 3D printed, small | $0.50 | ~30x20x15mm |
| Misc | Wires | $0.20 | — |
| **Total** | | **$6.59** | |

**Temperature/Humidity Sensor Variant**

| Component | Part | Unit Cost (USD) | Notes |
|-----------|------|----------------|-------|
| MCU | ESP32-C3 Mini (Seeed XIAO) | $4.99 | — |
| Sensor | DHT22 / AM2302 | $2.50 | ±0.5°C, ±2% RH |
| Power | 2x AA battery holder | $0.30 | — |
| Enclosure | 3D printed, vented | $1.00 | Needs airflow for accurate readings |
| Misc | PCB, pullup resistor, wires | $0.50 | — |
| **Total** | | **$9.29** | |

**Alternative: Bulk ESP32-C3 modules** (not Seeed XIAO): ESP32-C3-MINI-1 modules are $1.50-2.50 on AliExpress in qty 5+. With a custom carrier PCB ($1.50 via JLCPCB for 5 boards), total MCU cost drops to ~$3.00, reducing all Tier 0 variants by ~$2.

---

### Tier 1 — Smart Leaf Node (Battery, Voice/Audio)

| Component | Part | Unit Cost (USD) | Notes |
|-----------|------|----------------|-------|
| MCU | ESP32-S3 (Seeed XIAO) | $7.49 | Needed for vector extensions (audio processing) |
| Microphone | INMP441 I2S MEMS mic | $1.50 | Digital I2S output, low power |
| Power | 500mAh LiPo + TP4056 charge board | $2.50 | USB-C charging |
| PIR | AM312 (for voice wake trigger) | $0.80 | Optional but recommended |
| Enclosure | 3D printed | $1.50 | Needs mic opening |
| Misc | PCB, wires, capacitors | $0.70 | — |
| **Total** | | **$14.49** | |

---

### Tier 2 — Edge Node (Mains, Camera)

| Component | Part | Unit Cost (USD) | Notes |
|-----------|------|----------------|-------|
| MCU + Camera | ESP32-S3-CAM (Freenove or AI-Thinker) | $8.99 | Integrated OV2640, PSRAM |
| Power | USB-C cable + 5V adapter | $2.00 | Standard phone charger |
| Enclosure | 3D printed, wall mount | $1.50 | Adjustable angle mount |
| Misc | MicroSD slot (onboard), wires | $0.50 | — |
| **Total** | | **$12.99** | |

**Note**: The ESP32-S3-CAM boards include PSRAM (2-8MB) which is required for camera frame buffer and TFLite Micro inference. No additional memory needed.

---

### Tier 3 — Hub/Gateway (Mains)

| Component | Part | Unit Cost (USD) | Notes |
|-----------|------|----------------|-------|
| MCU | ESP32-S3 DevKit (N16R8) | $9.99 | 16MB flash, 8MB PSRAM |
| Storage | MicroSD card (16GB) | $3.00 | For state persistence, logs |
| MicroSD adapter | SPI MicroSD breakout | $0.80 | — |
| Display (optional) | SSD1306 0.96" OLED | $2.00 | Status display |
| Button | Tactile button (node approval) | $0.10 | — |
| Buzzer (optional) | Passive piezo buzzer | $0.30 | Local alarm |
| Power | USB-C cable + 5V/2A adapter | $3.00 | — |
| Enclosure | 3D printed, desktop | $2.00 | — |
| Ethernet (optional) | W5500 SPI Ethernet module | $3.50 | For wired reliability |
| **Total (without Ethernet)** | | **$21.19** | |
| **Total (with Ethernet)** | | **$24.69** | |

---

## Deployment Cost Estimates

### Starter Deployment — 1 Room Security + Environment

| Item | Qty | Unit Cost | Subtotal |
|------|-----|-----------|----------|
| Hub (Tier 3) | 1 | $21.19 | $21.19 |
| Camera edge node (Tier 2) | 1 | $12.99 | $12.99 |
| PIR sensor (Tier 0) | 2 | $7.59 | $15.18 |
| Temp/humidity sensor (Tier 0) | 1 | $9.29 | $9.29 |
| **Total** | **5 nodes** | | **$58.65** |

This provides: motion detection in 2 zones, person vs cat detection via camera, temperature monitoring, automated HVAC control, and intruder alerting.

### Full Home — 3-Bedroom Deployment

| Item | Qty | Unit Cost | Subtotal |
|------|-----|-----------|----------|
| Hub (Tier 3) | 1 | $24.69 | $24.69 |
| Camera edge node (Tier 2) | 3 | $12.99 | $38.97 |
| PIR sensor (Tier 0) | 8 | $7.59 | $60.72 |
| Door/window sensor (Tier 0) | 5 | $6.59 | $32.95 |
| Temp/humidity sensor (Tier 0) | 4 | $9.29 | $37.16 |
| Smart relay actuator (Tier 0) | 3 | $8.50 | $25.50 |
| Voice node (Tier 1) | 2 | $14.49 | $28.98 |
| **Total** | **26 nodes** | | **$248.97** |

Coverage:
- 3 cameras (living room, front door, back door)
- 8 PIR sensors (all rooms + hallways)
- 5 door/window sensors (exterior doors + key windows)
- 4 temp/humidity sensors (living, master bedroom, nursery/office, exterior)
- 3 smart relays (living room lights, HVAC, porch light)
- 2 voice nodes (living room, master bedroom)

### Incremental Cost to Expand

| Addition | Cost |
|----------|------|
| Add 1 room (PIR + temp sensor) | $16.88 |
| Add 1 room (PIR + temp + camera) | $29.87 |
| Add 1 door sensor | $6.59 |
| Add 1 smart relay | $8.50 |
| Add voice to a room | $14.49 |

---

## Cost Comparison vs Commercial Systems

| System | 1-Room Starter | 3-Bedroom Full |
|--------|---------------|----------------|
| **MeshSwarm (this design)** | **~$59** | **~$249** |
| Ring Alarm (2nd gen) | $200 | $400-600 |
| SimpliSafe | $250 | $400-500 |
| Aqara (Zigbee) | $150 | $350-500 |
| Home Assistant + Zigbee | $100 (Pi + coordinator) | $300-500 |

**Advantages over commercial**:
- No monthly subscription (Ring: $10-20/mo, SimpliSafe: $18-28/mo)
- No cloud dependency
- Full local control and customization
- Intelligence (person detection) runs locally, not cloud-dependent

**Disadvantages**:
- Requires assembly (not plug-and-play consumer packaging)
- No professional monitoring option
- No polished mobile app (local web UI only)
- DIY enclosures (3D printed or project boxes)

---

## Cost Optimization Opportunities

1. **Bulk component ordering**: ESP32-C3 modules drop to $1.50-2.50 at qty 10+ from AliExpress. This reduces Tier 0 node cost to ~$4-5.
2. **Custom PCBs**: JLCPCB 5-board minimum run is $2-5 per design. A unified Tier 0 carrier board eliminates protoboard and simplifies assembly.
3. **Shared power infrastructure**: Multiple Tier 0 sensors in the same room can share a battery pack via a small wiring harness, reducing per-node battery cost.
4. **ESP32-C3 for Tier 3 hub**: If camera/voice features aren't needed at the hub (just aggregation and rules), a cheaper ESP32-C3 with external SPI flash could serve as hub for ~$8 less. However, the S3's PSRAM is valuable for larger state stores.

---

## Annual Operating Cost

| Item | Cost/Year |
|------|-----------|
| Electricity (mains nodes, ~4 total @ 0.5W) | $2-3 |
| Batteries (Tier 0 nodes, AA replacement every 2-3 years) | $5-10 |
| Batteries (Tier 1 LiPo recharge) | $0 (USB charging) |
| Cloud subscription | $0 (air-gapped default) |
| **Total annual** | **$7-13** |

Compare to Ring Protect Plus: $200/year.

---

## Summary

| Metric | Value |
|--------|-------|
| Cheapest node (Tier 0 door sensor) | $6.59 |
| Most expensive node (Tier 3 hub) | $24.69 |
| 1-room starter | $58.65 |
| Full 3-bedroom home | $248.97 |
| Annual operating cost | $7-13 |
| No subscription fees | Correct |
