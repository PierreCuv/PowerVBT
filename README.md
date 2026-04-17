# ⚡ PowerVBT

> Velocity Based Training device — open-source IoT system for powerlifting athletes.

A compact, magnet-mounted IoT device that measures barbell velocity in real time and streams training metrics to a smartphone app via Bluetooth.

Built by athletes, for athletes.

---

## 🎯 Concept

PowerVBT is a small electronic unit fixed magnetically to a barbell (squat / bench / deadlift). It captures bar acceleration using a 6-axis IMU, computes velocity metrics on-device, and streams them live to a companion mobile app (iOS & Android).

The goal: give any powerlifter access to **Velocity Based Training** without expensive commercial equipment.

---

## ✅ Target Features

### Device (Firmware)
- [x] Real-time bar velocity measurement (m/s)
- [x] Rep detection (start / end of concentric phase)
- [x] Peak concentric velocity
- [x] Mean concentric velocity
- [x] Time under tension
- [x] Rep tempo measurement
- [x] BLE 5.0 live data streaming
- [ ] Onboard rep history buffer (last session)

### Mobile App
- [x] Live velocity display (low latency)
- [x] Rep counter per set
- [x] Set summary (rep-by-rep breakdown)
- [x] RPE / RIR manual input
- [x] Tempo selection and tracking
- [x] Estimated 1RM (velocity-based, multiple formulas)
- [x] Athlete profile (nickname, bodyweight, profile photo)
- [x] Differentiate Powerlifting (SBD) vs General Strength training
- [x] Best SBD in a session
- [x] Movement statistics: all-time max, max per set (1RM, 2RM, 3RM…)
- [x] Movement leaderboard / performance ranking
- [x] Manual data entry (sets without the device)
- [x] Local database (SQLite, offline-first)
- [ ] Cloud sync (optional, Firebase or Supabase)
- [ ] Multi-athlete profiles

---

## 🔧 Hardware

### Component List (BOM)

| # | Component | Reference | Role |
|---|-----------|-----------|------|
| 1 | MCU + BLE + Charger | Seeed XIAO ESP32-S3 | Brain, BLE 5.0, LiPo charge |
| 2 | IMU 6-axis | ICM-42688-P breakout | Acceleration + Gyroscope |
| 3 | Battery | LiPo 102530 680mAh 3.7V | Power supply |
| 4 | Switch | Mini SPDT slide switch | ON/OFF |
| 5 | Magnets | N52 neodymium 20×3mm ×4 | Barbell attachment |

### Key Specs

- **MCU**: ESP32-S3 dual-core 240MHz, BLE 5.0, WiFi, USB-C charging
- **IMU**: ICM-42688-P — 6-axis (accel ±16g + gyro ±2000dps), noise ~70µg/√Hz
- **Battery**: 680mAh LiPo → ~6h autonomy (device active + BLE connected)
- **Sampling rate**: 200Hz IMU acquisition
- **BLE latency**: ~15ms (connection interval 15ms)
- **Connector**: JST-PH 2.0 → JST-SH 1.25 (adapter or re-soldered)

### Wiring Diagram

> 📌 *To be added — see `/hardware/schematics/`*

```
XIAO ESP32-S3         ICM-42688-P
─────────────         ───────────
3.3V         ──────── VCC
GND          ──────── GND
GPIO6 (SDA)  ──────── SDA
GPIO7 (SCL)  ──────── SCL

XIAO ESP32-S3         LiPo 680mAh
─────────────         ───────────
BAT+         ──────── RED (JST 1.25mm)
GND          ──────── BLACK (JST 1.25mm)

XIAO ESP32-S3         Switch
─────────────         ──────
3.3V OUT     ──[SW]── VIN (battery line)
```

---

## 🧠 Signal Processing Pipeline

```
IMU raw data @ 200Hz
        │
        ▼
Static calibration (zero-g offset removal)
        │
        ▼
Madgwick filter (real-time orientation from accel + gyro)
        │
        ▼
Gravity vector subtraction (world frame rotation)
        │
        ▼
Low-pass filter (Butterworth 2nd order, fc = 15Hz)
        │
        ▼
ZUPT — Zero Velocity Update (drift reset at rest periods)
        │
        ▼
Trapezoidal integration → velocity (m/s)
        │
        ▼
Rep detection (velocity threshold crossing)
        │
        ▼
Metrics computation (peak vel, mean vel, TUT, tempo)
        │
        ▼
BLE GATT stream → mobile app
```

---

## 📱 App Architecture

- **Framework**: Flutter (iOS + Android from single codebase)
- **BLE**: `flutter_blue_plus`
- **Local DB**: `sqflite` (SQLite, offline-first)
- **Cloud sync**: Firebase *(optional, future)*
- **State management**: Riverpod

---

## 📂 Project Structure

```
PowerVBT/
├── firmware/               # ESP32-S3 firmware (PlatformIO / Arduino)
│   ├── src/
│   │   ├── main.cpp
│   │   ├── imu/            # ICM-42688 driver + Madgwick filter
│   │   ├── vbt/            # Rep detection, velocity calc, ZUPT
│   │   └── ble/            # BLE GATT server
│   ├── include/
│   └── platformio.ini
├── app/                    # Flutter mobile app
│   ├── lib/
│   │   ├── ble/            # BLE connection + data parsing
│   │   ├── models/         # Athlete, Set, Rep, Exercise
│   │   ├── screens/        # UI screens
│   │   ├── db/             # SQLite repository
│   │   └── vbt/            # 1RM formulas, metrics, statistics
│   └── pubspec.yaml
├── hardware/
│   ├── schematics/         # KiCad or PDF wiring diagrams
│   ├── 3d-models/          # STL enclosure files
│   └── BOM.md              # Full Bill of Materials
├── docs/
│   ├── wiring/             # Wiring photos and annotations
│   ├── images/             # Device photos, renders
│   └── ALGORITHM.md        # Signal processing documentation
├── CONTRIBUTING.md
└── README.md
```

---

## 🌿 Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, tested releases only |
| `dev` | Integration branch — all features merged here first |
| `feature/xxx` | Individual feature development (branch off `dev`) |
| `firmware/xxx` | Firmware-specific feature branches |
| `app/xxx` | App-specific feature branches |
| `fix/xxx` | Bug fixes |

**Workflow:**
```
feature/xxx  ──▶  dev  ──▶ (tested + validated) ──▶  main
```

Never push directly to `main`. Always go through `dev` first.

---

## 🚀 Getting Started

### Firmware

Requirements: [PlatformIO](https://platformio.org/) (VSCode extension recommended)

```bash
cd firmware
pio run --target upload
pio device monitor --baud 115200
```

### App

Requirements: [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.x

```bash
cd app
flutter pub get
flutter run
```

---

## 📐 VBT Reference — Velocity Zones

| Velocity (m/s) | Training Zone |
|----------------|--------------|
| > 1.0 | Speed / Power |
| 0.75 – 1.0 | Speed-Strength |
| 0.50 – 0.75 | Strength-Speed |
| 0.35 – 0.50 | Strength |
| < 0.35 | Maximal Strength / Grind |

*Based on Bryan Mann's VBT velocity zones.*

---

## 📜 License

The **concepts, algorithms, component choices, and documentation** in this project are shared freely under [Creative Commons CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

The source code is currently **private** — maintained by a closed group of athletes/contributors.

---

## 👥 Contributors

| Athlete | Role |
|---------|------|
| @pierre-cuvillier | Founder, firmware & app |

---

*PowerVBT — because every rep tells a story.*
