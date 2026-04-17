# Bill of Materials — PowerVBT v1

> Last updated: 2026-04

## Component List

| # | Component | Reference | Qty | Price (est.) | Source | Notes |
|---|-----------|-----------|-----|-------------|--------|-------|
| 1 | MCU / BLE / Charger | Seeed XIAO ESP32-S3 | 1 | ~9€ | Seeed Studio / AliExpress | Standard (not Plus, not Sense) |
| 2 | IMU 6-axis | ICM-42688-P breakout | 1 | ~5€ | AliExpress | 6-axis accel+gyro, I2C |
| 3 | Battery | LiPo 102530 680mAh 3.7V | 1 | ~15€ | Amazon (Sunkoo) | JST-PH2.0 → resolder to JST-SH 1.25mm |
| 4 | Switch | Mini SPDT slide switch | 1 | <1€ | AliExpress | ON/OFF power |
| 5 | Magnets | Neodymium N52 disc 20×3mm | 4 | ~3€ | AliExpress | Bar attachment |

**Total estimated: ~33€**

---

## Connector Notes

- XIAO ESP32-S3 battery port: **JST-SH 1.25mm 2-pin**
- Battery stock connector: **JST-PH 2.0mm 2-pin** (incompatible)
- Solution: desolder battery wires, re-crimp to JST-SH 1.25mm, or use adapter cable
- ⚠️ Always verify polarity before connecting (RED = +, BLACK = -)

---

## IMU Wiring (I2C)

| XIAO ESP32-S3 | ICM-42688-P |
|---------------|-------------|
| 3.3V | VCC |
| GND | GND |
| GPIO6 (SDA) | SDA |
| GPIO7 (SCL) | SCL |
| GPIO9 (optional) | INT1 (data ready interrupt) |

I2C address: `0x68` (SA0 to GND) or `0x69` (SA0 to VCC)

---

## Future / Optional Components (v2)

| Component | Purpose | Priority |
|-----------|---------|---------|
| RGB LED (WS2812B) | Visual feedback (rep count, battery) | Low |
| Buzzer passive | Audio rep feedback | Low |
| Larger LiPo (500mAh slim) | Better form factor | Medium |
| Custom PCB | Replace breakout boards, reduce size | High (v2) |
