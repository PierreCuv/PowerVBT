# Signal Processing Algorithm — PowerVBT

## Overview

The firmware acquires raw IMU data and transforms it into meaningful VBT metrics through a multi-stage pipeline running on the ESP32-S3.

---

## Pipeline

### Stage 1 — IMU Acquisition @ 200Hz

- ICM-42688-P configured via I2C
- Accelerometer range: ±8g (best resolution/noise tradeoff for powerlifting)
- Gyroscope range: ±1000 dps
- ODR: 200Hz
- Trigger: DATA_READY interrupt on INT1 pin (or polling fallback)

### Stage 2 — Static Calibration

Performed once at startup (bar motionless, flat on the rack):
- Average 200 samples per axis
- Store zero-g offset for each accelerometer axis
- Store zero-rate offset for each gyroscope axis
- Subtract offsets from all subsequent readings

### Stage 3 — Madgwick Filter (Orientation)

- Input: calibrated accel (ax, ay, az) + gyro (gx, gy, gz)
- Output: quaternion q representing sensor orientation in world frame
- Beta parameter: 0.1 (tune for accel/gyro trust balance)
- Update rate: 200Hz (same as acquisition)
- Purpose: track real orientation of device as it moves with the bar

### Stage 4 — Gravity Subtraction

- Rotate gravity vector g = [0, 0, 9.81] into sensor frame using quaternion
- Subtract from raw accelerometer reading
- Result: linear acceleration (motion only, gravity removed)

### Stage 5 — Low-Pass Filter

- Butterworth 2nd order, cutoff fc = 15Hz
- Applied to each axis of linear acceleration
- Purpose: remove high-frequency vibration (bar bounce, plate rattle)
- Coefficients pre-computed at compile time for 200Hz sample rate

### Stage 6 — ZUPT (Zero Velocity Update)

- Compute variance of acceleration magnitude over sliding window (N=20 samples = 100ms)
- If variance < threshold AND magnitude ≈ 9.81 → bar is stationary
- When stationary: reset velocity integrator to zero
- Purpose: prevent drift accumulation between reps and sets

### Stage 7 — Velocity Integration

- Trapezoidal numerical integration of vertical linear acceleration
- v(t) = v(t-1) + (a(t-1) + a(t)) / 2 × dt, where dt = 5ms (200Hz)
- Only vertical axis (world Z) used for primary velocity metric
- ZUPT correction applied at each detected rest period

### Stage 8 — Rep Detection

- State machine: IDLE → CONCENTRIC → ECCENTRIC (optional) → IDLE
- CONCENTRIC start: velocity crosses upward threshold (e.g. > 0.08 m/s)
- CONCENTRIC end: velocity drops below threshold OR direction reverses
- Minimum rep duration: 200ms (filter out noise spikes)
- Maximum rep duration: 8s (filter out very slow movements or errors)

### Stage 9 — Metrics Computation

Per rep:
- `peak_velocity`: maximum velocity during concentric phase
- `mean_velocity`: average velocity during concentric phase
- `time_under_tension`: duration of concentric phase (ms)
- `tempo_concentric`: duration of upward movement (ms)
- `tempo_eccentric`: duration of downward movement (ms, if tracked)
- `rep_index`: position in current set

---

## BLE Data Packet Format

Sent via BLE GATT Notify characteristic after each rep:

```
Byte layout (12 bytes total):
[0-1]   uint16  rep_index
[2-3]   uint16  peak_velocity  (× 1000, i.e. 0.850 m/s → 850)
[4-5]   uint16  mean_velocity  (× 1000)
[6-7]   uint16  time_under_tension  (ms)
[8-9]   uint16  tempo_concentric    (ms)
[10-11] uint16  tempo_eccentric     (ms)
```

Real-time stream (every 50ms during a rep):
```
[0-1]   int16   current_velocity (× 1000, signed)
[2]     uint8   state (0=idle, 1=concentric, 2=eccentric)
```

---

## 1RM Estimation Formulas

Based on mean concentric velocity (MCV) and load:

**Epley (velocity-adjusted):**
```
1RM = load × (1 + 0.0333 × reps_in_reserve)
```

**Load-velocity profile method (most accurate):**
- Requires minimum 2 data points at different loads
- Linear regression: v = a × (%1RM) + b
- Extrapolate to minimum velocity threshold (MVT, typically 0.17 m/s for squat)

---

## Velocity Zones Reference

| Zone | Velocity (m/s) | Training Quality |
|------|---------------|-----------------|
| Speed | > 1.00 | Ballistic / Power |
| Speed-Strength | 0.75 – 1.00 | Explosive |
| Strength-Speed | 0.50 – 0.75 | Power-Strength |
| Strength | 0.35 – 0.50 | Heavy Strength |
| Maximal / Grind | < 0.35 | Near 1RM |

*MVT (Minimum Velocity Threshold) per lift:*
- Squat: ~0.17 m/s
- Bench: ~0.17 m/s
- Deadlift: ~0.12 m/s

---

## Known Limitations

- Single accelerometer axis integration → velocity accuracy ±0.05 m/s
- Drift increases with rep duration (ZUPT mitigates between reps)
- No absolute position tracking (displacement is relative, not absolute)
- Calibration must be redone if device is repositioned on bar
- Not validated for Olympic lifts (too fast, different movement pattern)
