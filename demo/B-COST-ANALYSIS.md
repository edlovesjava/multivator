# COST-ANALYSIS.md -- Experimental Track (Implementor B)

## Bill of Materials by Tier

### Tier 0 -- Leaf Node (PIR Motion Sensor Variant)

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-C3-MINI-1 (4MB flash) | $1.50 |
| Sensor | HC-SR501 PIR module | $0.80 |
| Power | 2x AAA battery holder | $0.30 |
| Voltage regulator | HT7333 LDO (3.3V) | $0.10 |
| PCB | Custom 2-layer, 30x40mm | $0.50 |
| Enclosure | 3D printed or injection molded shell | $0.80 |
| Passive components | Caps, resistors, LED | $0.20 |
| **Total** | | **$4.20** |

### Tier 0 -- Leaf Node (Door/Window Sensor Variant)

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-C3-MINI-1 (4MB flash) | $1.50 |
| Sensor | Reed switch + magnet | $0.30 |
| Power | CR2032 holder | $0.15 |
| Voltage regulator | HT7333 LDO (3.3V) | $0.10 |
| PCB | Custom 2-layer, 20x30mm | $0.40 |
| Enclosure | Small shell + adhesive mount | $0.60 |
| Passive components | Caps, resistors | $0.15 |
| **Total** | | **$3.20** |

### Tier 0 -- Leaf Node (Temp/Humidity Variant)

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-C3-MINI-1 (4MB flash) | $1.50 |
| Sensor | DHT22 (AM2302) | $2.00 |
| Power | 2x AAA battery holder | $0.30 |
| Voltage regulator | HT7333 LDO (3.3V) | $0.10 |
| PCB | Custom 2-layer, 30x40mm | $0.50 |
| Enclosure | Vented shell | $0.80 |
| Passive components | Caps, resistors, pull-up | $0.20 |
| **Total** | | **$5.40** |

### Tier 1 -- Smart Leaf (Voice/Keyword Spotting)

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-S3-MINI-1 (4MB flash, 2MB PSRAM) | $3.00 |
| Microphone | INMP441 I2S MEMS mic | $1.50 |
| Power | 500mAh LiPo cell | $2.00 |
| Charge IC | TP4056 USB-C charge board | $0.50 |
| USB-C connector | For charging | $0.20 |
| Voltage regulator | MCP1700 LDO (3.3V) | $0.15 |
| PCB | Custom 2-layer, 35x45mm | $0.60 |
| Enclosure | Compact shell with mic port | $1.00 |
| Passive components | Caps, resistors, LED | $0.25 |
| **Total** | | **$9.20** |

### Tier 2 -- Edge Node (Camera + Inference)

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-S3-WROOM-1 N8R8 (8MB flash, 8MB PSRAM) | $4.00 |
| Camera | OV2640 module (2MP, 15fps SVGA) | $3.00 |
| Power supply | 5V/2A USB-C adapter | $2.00 |
| USB-C connector + power path | | $0.40 |
| Voltage regulator | AMS1117-3.3 | $0.10 |
| PCB | Custom 4-layer, 40x50mm | $1.50 |
| Enclosure | Wall-mount shell with camera window | $1.50 |
| Status LED | WS2812B (RGB indicator) | $0.15 |
| Passive components | Caps, resistors, ESD protection | $0.35 |
| **Total** | | **$13.00** |

### Tier 3 -- Hub/Gateway

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-S3-WROOM-1 N16R8 (16MB flash, 8MB PSRAM) | $5.00 |
| Storage | MicroSD card slot + 8GB card | $3.00 |
| Ethernet (optional) | W5500 SPI Ethernet module | $2.50 |
| Power supply | 5V/3A USB-C adapter | $3.00 |
| USB-C connector + power path | | $0.40 |
| Voltage regulator | AMS1117-3.3 | $0.10 |
| Status display | 0.96" SSD1306 OLED (128x64) | $1.50 |
| Buttons | Reset + provisioning buttons | $0.20 |
| PCB | Custom 4-layer, 50x60mm | $2.00 |
| Enclosure | Desktop shell with ventilation | $2.00 |
| Passive components | Caps, resistors, ESD, antenna | $0.50 |
| **Total** | | **$20.20** |

### Actuator Node -- Relay Variant

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-C3-MINI-1 (4MB flash) | $1.50 |
| Relay | SRD-05VDC-SL-C (5V SPDT) | $0.60 |
| Relay driver | BC547 + flyback diode | $0.10 |
| Power supply | Hi-Link HLK-PM03 (AC-DC 3.3V) | $2.50 |
| Screw terminals | 3-position, 5mm pitch | $0.30 |
| PCB | Custom 2-layer, 35x50mm | $0.60 |
| Enclosure | DIN-rail or wall-mount box | $1.20 |
| Passive components | Caps, resistors, fuse | $0.30 |
| **Total** | | **$7.10** |

### Actuator Node -- IR Blaster Variant

| Component | Part | Unit Cost |
|-----------|------|-----------|
| MCU | ESP32-C3-MINI-1 (4MB flash) | $1.50 |
| IR LED | TSAL6200 (940nm, high power) x2 | $0.40 |
| IR receiver | VS1838B (for learning codes) | $0.30 |
| IR driver | MOSFET driver circuit | $0.20 |
| Power supply | 5V/1A USB-C adapter | $1.50 |
| PCB | Custom 2-layer, 25x35mm | $0.40 |
| Enclosure | Small shell with IR window | $0.80 |
| Passive components | Caps, resistors | $0.20 |
| **Total** | | **$5.30** |

---

## Deployment Cost Scenarios

### Starter Deployment (1 Room)

Minimum viable security + environment for a single room (e.g., apartment front entrance + living area).

| Item | Qty | Unit Cost | Subtotal |
|------|-----|-----------|----------|
| Hub (Tier 3) | 1 | $20.20 | $20.20 |
| Camera edge node (Tier 2) | 1 | $13.00 | $13.00 |
| PIR sensor (Tier 0) | 2 | $4.20 | $8.40 |
| Door sensor (Tier 0) | 1 | $3.20 | $3.20 |
| Relay actuator (lights) | 1 | $7.10 | $7.10 |
| **Total BOM** | | | **$51.90** |
| Batteries (initial) | -- | -- | $3.00 |
| **Total deployed** | | | **$54.90** |

**What this gets you:**
- Motion detection in 2 zones
- Camera-based person/pet classification at entrance
- Door open/close monitoring
- Automated light control
- Local security reasoning (intruder vs cat, settling-in detection)
- Local web dashboard on hub

### Medium Deployment (2-Bedroom Apartment)

| Item | Qty | Unit Cost | Subtotal |
|------|-----|-----------|----------|
| Hub (Tier 3) | 1 | $20.20 | $20.20 |
| Camera edge node (Tier 2) | 2 | $13.00 | $26.00 |
| PIR sensor (Tier 0) | 4 | $4.20 | $16.80 |
| Door sensor (Tier 0) | 3 | $3.20 | $9.60 |
| Temp/humidity (Tier 0) | 2 | $5.40 | $10.80 |
| Smart leaf w/mic (Tier 1) | 1 | $9.20 | $9.20 |
| Relay actuator | 2 | $7.10 | $14.20 |
| IR blaster (HVAC/TV) | 1 | $5.30 | $5.30 |
| **Total BOM** | | | **$112.10** |
| Batteries + misc | -- | -- | $8.00 |
| **Total deployed** | | | **$120.10** |

### Full Home Deployment (3-Bedroom House)

| Item | Qty | Unit Cost | Subtotal |
|------|-----|-----------|----------|
| Hub (Tier 3) | 1 | $20.20 | $20.20 |
| Camera edge node (Tier 2) | 4 | $13.00 | $52.00 |
| PIR sensor (Tier 0) | 6 | $4.20 | $25.20 |
| Door/window sensor (Tier 0) | 8 | $3.20 | $25.60 |
| Temp/humidity (Tier 0) | 4 | $5.40 | $21.60 |
| Smart leaf w/mic (Tier 1) | 2 | $9.20 | $18.40 |
| Relay actuator | 4 | $7.10 | $28.40 |
| IR blaster | 2 | $5.30 | $10.60 |
| **Total BOM** | | | **$202.00** |
| Batteries + misc | -- | -- | $15.00 |
| **Total deployed** | | | **$217.00** |

---

## Incremental Cost Analysis

| Addition | Cost | What It Adds |
|----------|------|-------------|
| One more room (basic) | $4.20 + $3.20 = **$7.40** | PIR + door sensor |
| One more room (full) | $13.00 + $4.20 + $3.20 + $5.40 + $7.10 = **$32.90** | Camera + PIR + door + temp + relay |
| Voice control to a room | **$9.20** | Smart leaf with keyword spotting |
| IR control for legacy devices | **$5.30** | IR blaster node |
| Outdoor camera | **$15.00** | Edge node + weatherproof enclosure (+$2) |
| Second hub (large home) | **$20.20** | Redundancy or multi-floor |

---

## Cost Comparison with Commercial Solutions

| System | Starter (1 room) | Full home (3-bed) | Monthly fee |
|--------|-----------------|-------------------|-------------|
| **MeshSwarm (our design)** | **$55** | **$217** | **$0** |
| Ring Alarm (basic) | $200 | $500+ | $10-20/mo |
| SimpliSafe | $250 | $500+ | $15-25/mo |
| Wyze Home Monitoring | $100 | $300+ | $4-8/mo |
| HomeAssistant + Zigbee | $150 | $400+ | $0 |

**Key advantages:**
- No monthly subscription (all intelligence runs locally)
- Lower hardware cost due to commodity ESP32 modules
- No cloud lock-in or vendor dependency
- Fully air-gapped operation by default

**Key disadvantages vs commercial:**
- DIY assembly required (no pre-built retail units)
- No professional monitoring service
- No polished mobile app (local web dashboard only)
- Camera quality limited by OV2640 (2MP) vs commercial 1080p/4K cameras

---

## Cost Optimization Through Architecture

### 1. ESP32-C3 for Leaf Nodes
The ESP32-C3 at ~$1.50 is 57% cheaper than a full ESP32 ($3.50) and 50% cheaper than an ESP32-S3 ($3.00). Since leaf nodes only need to sense and transmit via ESP-NOW, the single-core RISC-V C3 is sufficient. This saves $2-3 per leaf node, which compounds across a full deployment (14 leaf nodes x $2 = $28 saved).

### 2. No External Radio Hardware
By choosing ESP-NOW + Wi-Fi instead of Zigbee or Thread, we avoid the cost of 802.15.4 radio modules ($3-5 each) on every node. For 20+ nodes, this saves $60-100.

### 3. Single Hub Architecture
One hub serves the entire home. No per-room hubs or bridges needed. Commercial Zigbee systems often require a coordinator ($30-50) plus range extenders.

### 4. On-Device Inference Eliminates Cloud Costs
Camera frames processed locally means no cloud compute costs, no video storage fees, no bandwidth charges. A cloud-based camera system at 3 cameras would cost ~$10-15/month for video storage alone.

### 5. SD Card for Extended Storage
Hub uses a $3 microSD card instead of expensive high-density flash modules. 8GB is sufficient for months of event logs and pattern data.

---

## Volume Pricing Estimates

At moderate volume (100 units per node type), component costs decrease:

| Component | Unit (qty 1) | Unit (qty 100) | Savings |
|-----------|-------------|----------------|---------|
| ESP32-C3-MINI-1 | $1.50 | $1.10 | 27% |
| ESP32-S3-WROOM-1 N8R8 | $4.00 | $3.20 | 20% |
| OV2640 module | $3.00 | $2.20 | 27% |
| Custom PCB (2-layer) | $0.50 | $0.15 | 70% |
| Custom PCB (4-layer) | $1.50 | $0.50 | 67% |

At volume, a full home deployment BOM drops from ~$202 to ~$155, a **23% reduction**.

---

## Annual Operating Cost

| Item | Cost |
|------|------|
| Electricity (hub + edge nodes, ~10W total) | $11.40/year |
| Battery replacements (AAA + CR2032) | $8-12/year |
| USB-C charging for Tier 1 nodes | ~$1/year |
| Cloud services | $0 (optional, self-hosted) |
| **Total annual** | **~$21-25/year** |

Compare to Ring Alarm at $120-240/year in subscription fees alone.
