# GitHub Issues Plan — PowerVBT

Copy-paste each block to create issues on GitHub.
Labels to create first: `firmware`, `app`, `hardware`, `docs`, `enhancement`, `bug`

---

## 🔧 FIRMWARE

### [firmware] IMU Driver — MPU-6050 via I2C
**Label:** firmware
**Description:**
Implement the MPU-6050 I2C driver for the XIAO ESP32-S3.
- Configure accelerometer range to ±8g
- Configure gyroscope range to ±1000 dps
- Set ODR to 200Hz
- Implement DATA_READY interrupt on INT1
- Read raw 6-axis data (ax, ay, az, gx, gy, gz)
- Validate readings on Serial monitor

**Acceptance criteria:**
- [ ] Device detected on I2C bus (address 0x68)
- [ ] Raw data printed at 200Hz on serial
- [ ] No I2C errors under sustained operation

---

### [firmware] Static Calibration Routine
**Label:** firmware
**Description:**
On startup, compute and store zero-g and zero-rate offsets.
- Average 200 samples with device stationary
- Store offsets in flash (NVS) for persistence across reboots
- Subtract offsets from all subsequent readings
- Add serial command to trigger re-calibration

**Acceptance criteria:**
- [ ] Offsets computed and stored on first boot
- [ ] Calibration reloaded on subsequent boots
- [ ] Residual offset < 5mg after calibration

---

### [firmware] Madgwick Filter — Orientation Estimation
**Label:** firmware
**Description:**
Implement Madgwick AHRS filter using accel + gyro data.
- Input: calibrated 6-axis IMU @ 200Hz
- Output: quaternion representing sensor orientation
- Beta parameter: start at 0.1, tune empirically
- Use MadgwickAHRS Arduino library

**Acceptance criteria:**
- [ ] Quaternion output stable when device is stationary
- [ ] Orientation tracks correctly during slow rotation
- [ ] No gimbal lock issues

---

### [firmware] Gravity Subtraction & Linear Acceleration
**Label:** firmware
**Description:**
Using the orientation quaternion, remove gravity from accelerometer data.
- Rotate gravity vector [0, 0, 9.81] into sensor frame
- Subtract from calibrated accelerometer reading
- Output: linear acceleration in world frame (vertical axis = Z)

**Acceptance criteria:**
- [ ] Linear acceleration ≈ 0 when device is stationary
- [ ] Vertical acceleration positive during upward movement

---

### [firmware] Low-Pass Filter (Butterworth 2nd order)
**Label:** firmware
**Description:**
Apply a low-pass filter to remove vibration noise from linear acceleration.
- Type: Butterworth 2nd order
- Cutoff frequency: 15Hz
- Sample rate: 200Hz
- Pre-compute coefficients at compile time
- Apply to vertical axis only (primary) and optionally all 3 axes

**Acceptance criteria:**
- [ ] High-frequency vibration (plate rattle, bar bounce) removed
- [ ] Step response < 100ms

---

### [firmware] ZUPT — Zero Velocity Update
**Label:** firmware
**Description:**
Detect when the bar is stationary and reset velocity integrator to prevent drift.
- Compute variance of acceleration magnitude over 20-sample sliding window
- Threshold: variance < 0.01 m²/s⁴ AND magnitude ≈ 9.81 m/s²
- When stationary detected: set velocity = 0
- Log ZUPT events on serial for debugging

**Acceptance criteria:**
- [ ] Velocity resets to 0 between reps
- [ ] No false ZUPT triggers during slow movement
- [ ] Drift < 0.05 m/s over 3-second rep

---

### [firmware] Velocity Integration
**Label:** firmware
**Description:**
Integrate vertical linear acceleration to compute bar velocity.
- Trapezoidal numerical integration
- dt = 5ms (200Hz)
- ZUPT correction applied
- Output: velocity in m/s (positive = upward)

**Acceptance criteria:**
- [ ] Velocity ≈ 0 at start and end of rep
- [ ] Peak velocity plausible (0.2–1.5 m/s for powerlifting)
- [ ] Sign correct (positive during concentric)

---

### [firmware] Rep Detection State Machine
**Label:** firmware
**Description:**
Detect start and end of each repetition using velocity thresholds.

State machine:
- IDLE → CONCENTRIC: velocity > 0.08 m/s for > 50ms
- CONCENTRIC → IDLE: velocity < 0.05 m/s for > 100ms
- Minimum rep duration: 200ms
- Maximum rep duration: 8000ms

**Acceptance criteria:**
- [ ] Each rep correctly detected on bench/squat/deadlift
- [ ] No phantom reps detected at rest
- [ ] Rep boundaries within ±50ms of actual movement

---

### [firmware] Metrics Computation
**Label:** firmware
**Description:**
Compute VBT metrics for each detected rep.
- Peak concentric velocity (m/s)
- Mean concentric velocity (m/s)
- Time under tension (ms)
- Tempo concentric (ms)
- Rep index in set

**Acceptance criteria:**
- [ ] All metrics computed within 5ms of rep end
- [ ] Values plausible across 3 real training sets

---

### [firmware] BLE GATT Server
**Label:** firmware
**Description:**
Implement BLE 5.0 GATT server to stream data to mobile app.

Services:
- **VBT Service** (custom UUID)
  - Characteristic: Live velocity (notify, 20Hz) — int16 × 1000
  - Characteristic: Rep completed (notify) — 12-byte packet
  - Characteristic: Device status (read) — battery %, calibration state
  - Characteristic: Command (write) — start/stop session, trigger calibration

**Acceptance criteria:**
- [ ] Device visible in nRF Connect app
- [ ] Live velocity streamed at 20Hz with < 20ms latency
- [ ] Rep data received correctly after each rep
- [ ] Reconnection works after BLE drop

---

### [firmware] Power Management & Battery Optimization
**Label:** firmware
**Description:**
Implement sleep modes to extend battery life between sets.
- Light sleep when no movement detected for > 30s
- Wake on IMU interrupt (motion detection)
- Reduce BLE advertising interval when not connected
- Battery voltage reading via ADC

**Acceptance criteria:**
- [ ] Current draw < 5mA during inter-set rest
- [ ] Wake-up latency < 500ms
- [ ] Battery % reported accurately (±10%)

---

## 📱 APP

### [app] Project Setup — Flutter + Dependencies
**Label:** app
**Description:**
Initialize Flutter project with all required dependencies.

pubspec.yaml dependencies:
- flutter_blue_plus (BLE)
- sqflite (local DB)
- riverpod / flutter_riverpod (state management)
- fl_chart (graphs)
- shared_preferences (settings)
- path_provider
- uuid

**Acceptance criteria:**
- [ ] flutter pub get runs without errors
- [ ] App builds on Android
- [ ] App builds on iOS (via Mac)

---

### [app] BLE Connection Manager
**Label:** app
**Description:**
Implement BLE scanning, connection, and data parsing.
- Scan for PowerVBT device by service UUID
- Auto-reconnect on disconnect
- Subscribe to live velocity notifications
- Subscribe to rep completed notifications
- Parse binary packets to Dart models
- Connection state indicator in UI

**Acceptance criteria:**
- [ ] App connects to device in < 3s
- [ ] Live velocity received and parsed correctly
- [ ] Reconnection automatic after BLE drop
- [ ] Works on both iOS and Android

---

### [app] Live Training Screen
**Label:** app
**Description:**
Main screen displayed during a set.
- Large velocity display (current m/s, color-coded by zone)
- Rep counter
- Velocity bar / gauge (animated)
- Last rep peak velocity
- Set timer
- Stop set button

**Acceptance criteria:**
- [ ] Velocity updates with < 50ms visual latency
- [ ] Color zones correct (green > 0.75, yellow 0.5–0.75, red < 0.35)
- [ ] Rep counter increments correctly

---

### [app] Set Summary Screen
**Label:** app
**Description:**
Screen shown after completing a set.
- Rep-by-rep table (rep #, peak vel, mean vel, TUT)
- Average velocity of set
- Velocity drop % (rep 1 vs last rep = fatigue index)
- Estimated 1RM
- RPE / RIR input
- Save or discard set

**Acceptance criteria:**
- [ ] All reps from the set displayed correctly
- [ ] 1RM estimate calculated from mean velocity + load
- [ ] Set saved to local DB on confirm

---

### [app] Exercise & Load Selection
**Label:** app
**Description:**
Before starting a set, select exercise and input load.
- Exercise picker: Squat / Bench / Deadlift / Other
- Load input (kg)
- Mode: Powerlifting SBD or General Strength
- Quick access to recent loads

**Acceptance criteria:**
- [ ] Exercise and load saved with each set
- [ ] SBD mode applies correct MVT thresholds per lift
- [ ] Recent loads shown as shortcuts

---

### [app] RPE / RIR Input
**Label:** app
**Description:**
Post-set manual input for perceived exertion.
- RPE slider (1–10, 0.5 increments)
- RIR input (0–5+)
- Auto-convert RPE ↔ RIR
- Saved with set data

**Acceptance criteria:**
- [ ] RPE and RIR saved with every set
- [ ] Conversion formula correct (RIR = 10 - RPE)

---

### [app] 1RM Estimation
**Label:** app
**Description:**
Calculate estimated 1RM from velocity and load data.

Formulas to implement:
- Epley: `1RM = load × (1 + reps / 30)`
- Velocity-based: extrapolate load-velocity profile to MVT
  - Requires minimum 2 sets at different loads
  - Linear regression: `%1RM = a × velocity + b`

Display:
- Estimated 1RM after each set
- Confidence indicator (1 set = low, 3+ sets = high)

**Acceptance criteria:**
- [ ] Epley estimate shown after every set
- [ ] Velocity-based estimate shown when enough data
- [ ] Values within 5% of known 1RM in testing

---

### [app] Athlete Profile
**Label:** app
**Description:**
Athlete profile screen.
- Nickname
- Bodyweight (kg)
- Profile photo (camera or gallery)
- Competition category (optional)
- Account creation date

**Acceptance criteria:**
- [ ] Profile data saved locally
- [ ] Profile photo displayed throughout app
- [ ] Multi-profile support (for friends using same device)

---

### [app] Statistics Screen — Personal Records
**Label:** app
**Description:**
Display athlete performance records.
- All-time max velocity per lift
- Best set (1RM, 2RM, 3RM… estimated)
- Velocity trend over time (line chart)
- Best SBD total in a single session
- Movement performance ranking / grading

**Acceptance criteria:**
- [ ] Records update automatically after each session
- [ ] Charts render correctly with 0 and many data points
- [ ] SBD total calculated correctly

---

### [app] Session History
**Label:** app
**Description:**
Browse past training sessions.
- List of sessions (date, lifts, total sets)
- Drill into session → sets → reps
- Delete session
- Filter by exercise or date range

**Acceptance criteria:**
- [ ] All past sessions accessible
- [ ] Rep-level data viewable
- [ ] Delete works without crashing

---

### [app] Manual Data Entry
**Label:** app
**Description:**
Allow logging sets without the PowerVBT device connected.
- Same exercise/load/RPE/RIR input
- Manual rep count
- No velocity data (marked as "manual")
- Stored in same DB, excluded from velocity stats

**Acceptance criteria:**
- [ ] Manual sets saved and displayed in history
- [ ] Manual sets clearly distinguished from device sets
- [ ] 1RM estimation still works (Epley from reps)

---

### [app] Local Database Schema (sqflite)
**Label:** app
**Description:**
Design and implement SQLite database schema.

Tables:
- `athletes` (id, nickname, bodyweight, photo_path, created_at)
- `sessions` (id, athlete_id, date, notes)
- `sets` (id, session_id, exercise, load_kg, mode, rpe, rir, is_manual)
- `reps` (id, set_id, rep_index, peak_velocity, mean_velocity, tut_ms, tempo_ms)

**Acceptance criteria:**
- [ ] All CRUD operations working
- [ ] DB migration system in place for future schema changes
- [ ] No data loss on app update

---

### [app] Tempo Tracking & Display
**Label:** app
**Description:**
Track and display rep tempo (concentric / eccentric duration).
- Receive tempo data from BLE packet
- Display tempo per rep in set summary
- Compare to target tempo if set by user
- Tempo notation: e.g. "2-0-1" (eccentric-pause-concentric)

**Acceptance criteria:**
- [ ] Tempo displayed per rep
- [ ] Target tempo input available pre-set
- [ ] Visual indicator if tempo out of range

---

## 🔩 HARDWARE

### [hardware] Wiring Diagram v1
**Label:** hardware, docs
**Description:**
Create a clean wiring diagram for the full hardware assembly.
- XIAO ESP32-S3 + GY-521 MPU-6050 + LiPo + Switch
- Tools: Fritzing or KiCad or draw.io
- Export as PNG + PDF
- Save to /hardware/schematics/

**Acceptance criteria:**
- [ ] All connections labeled (pin names + colors)
- [ ] Diagram matches actual build
- [ ] Readable at A4 size

---

### [hardware] 3D Enclosure Design v1
**Label:** hardware
**Description:**
Design a compact enclosure for the PowerVBT device.
- Must fit: XIAO ESP32-S3 + GY-521 + LiPo 102530 + switch
- 4× N52 magnet slots on back face
- USB-C access for charging
- Switch cutout
- Design tool: Fusion 360 or FreeCAD
- Export STL to /hardware/3d-models/

**Acceptance criteria:**
- [ ] All components fit with < 1mm clearance
- [ ] Magnets flush with back face
- [ ] Printable on FDM printer (0.2mm layer, no supports preferred)
- [ ] USB-C port accessible without disassembly
