// ============================================================
// VBT Tracker — XIAO ESP32-S3 + MPU6050 (GY-521)  —  version BLE
// Fusion gyro + accéléromètre (Madgwick) -> vitesse verticale,
// envoyée en Bluetooth Low Energy (service type Nordic UART).
//
// Câblage GY-521 -> XIAO ESP32-S3 :
//   VCC -> 3V3 | GND -> GND | SDA -> D4 | SCL -> D5 | INT -> D0
//
// Côté iPhone : navigateur Bluefy -> ouvrir la page vbt-ble.html
// ============================================================

#include <Wire.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "madgwick.h"

// ---------- Modes (tests) ----------
#define DEBUG_STREAM   1        // 1 = flux de valeurs sur le moniteur série
#define ENABLE_SLEEP   0        // 0 = pas de deep sleep pendant les tests

// ---------- BLE (UUID type Nordic UART) ----------
#define DEV_NAME   "VBT-Tracker"
#define SVC_UUID   "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define RX_UUID    "6e400002-b5a3-f393-e0a9-e50e24dcca9e"  // tel -> esp (commandes)
#define TX_UUID    "6e400003-b5a3-f393-e0a9-e50e24dcca9e"  // esp -> tel (données)

// ---------- Réglages capteur / algo (à calibrer) ----------
#define MPU_ADDR        0x68
#define PIN_MPU_INT     GPIO_NUM_1
#define SAMPLE_HZ       200
#define TH_START        1.2f
#define TH_STILL        0.45f
#define STILL_MS        350
#define REP_MIN_MS      180
#define REP_MAX_MS      3000
#define DISP_MIN_M      0.12f
#define SLEEP_AFTER_MS  600000UL    // 10 min (n'agit que si ENABLE_SLEEP=1)
#define MAX_REPS        40

// ---------- Madgwick ----------
#define BETA_WARMUP     2.0f
#define BETA_STILL      0.08f
#define BETA_MOTION     0.02f
#define WARMUP_MS       1500

Madgwick ahrs;
RTC_DATA_ATTR float gyroBias[3] = {0, 0, 0};

// ---------- BLE globals ----------
BLEServer*         bleServer = nullptr;
BLECharacteristic* txChar    = nullptr;
volatile bool      connected = false;

// ---------- État détection ----------
enum RepState { ST_IDLE, ST_CONC, ST_SUPPRESS };
RepState state = ST_IDLE;

float    vOff = 0, v = 0, disp = 0, repPeak = 0;
uint32_t repStartMs = 0, stillSinceMs = 0, lastMotionMs = 0, warmupUntil = 0, ledOffMs = 0;
float    repMean[MAX_REPS], repPk[MAX_REPS];
int      repCount = 0;
bool     mpuOk = false;

// ============================================================
// MPU6050
// ============================================================
void mpuWrite(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg); Wire.write(val);
  Wire.endTransmission();
}

uint8_t mpuRead8(uint8_t reg) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU_ADDR, 1);
  return Wire.available() ? Wire.read() : 0xFF;
}

bool mpuReadMotion(float a[3], float g[3]) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU_ADDR, 14) != 14) return false;
  uint8_t b[14];
  for (int i = 0; i < 14; i++) b[i] = Wire.read();
  int16_t raw[7];
  for (int i = 0; i < 7; i++) raw[i] = (int16_t)((b[2 * i] << 8) | b[2 * i + 1]);
  a[0] = raw[0] / 4096.0f; a[1] = raw[1] / 4096.0f; a[2] = raw[2] / 4096.0f;
  for (int k = 0; k < 3; k++)
    g[k] = (raw[4 + k] / 65.5f) * 0.0174533f - gyroBias[k];
  return true;
}

void mpuInitActive() {
  mpuWrite(0x6B, 0x80); delay(100);
  mpuWrite(0x6B, 0x01); delay(10);
  mpuWrite(0x1A, 0x03);
  mpuWrite(0x19, 0x04);
  mpuWrite(0x1B, 0x08);   // gyro ±500°/s
  mpuWrite(0x1C, 0x10);   // accel ±8g
  mpuWrite(0x38, 0x00);
}

void mpuInitWakeOnMotion() {
  mpuWrite(0x6B, 0x00); delay(100);
  mpuWrite(0x1C, 0x01);
  mpuWrite(0x1F, 2);
  mpuWrite(0x20, 40);
  mpuWrite(0x69, 0x15);
  mpuWrite(0x37, 0x20);
  mpuWrite(0x38, 0x40);
  delay(2);
  mpuWrite(0x6C, 0x47);
  mpuWrite(0x6B, 0x20);
}

void calibrateGyro() {
  const int N = 200;
  float sum[3] = {0, 0, 0}, mn[3] = {1e9, 1e9, 1e9}, mx[3] = {-1e9, -1e9, -1e9};
  int n = 0;
  for (int i = 0; i < N; i++) {
    float a[3], g[3];
    if (mpuReadMotion(a, g)) {
      for (int k = 0; k < 3; k++) {
        float r = g[k] + gyroBias[k];
        sum[k] += r;
        if (r < mn[k]) mn[k] = r;
        if (r > mx[k]) mx[k] = r;
      }
      n++;
    }
    delay(5);
  }
  if (n < N / 2) return;
  for (int k = 0; k < 3; k++)
    if (mx[k] - mn[k] > 0.07f) { Serial.println("Capteur bouge, biais gyro conserve"); return; }
  for (int k = 0; k < 3; k++) gyroBias[k] = sum[k] / n;
  Serial.println("Biais gyro calibre");
}

// ============================================================
// BLE
// ============================================================
void notify(const String& s) {
  if (connected && txChar) {
    txChar->setValue((uint8_t*)s.c_str(), s.length());
    txChar->notify();
    delay(4);   // laisse le temps à la pile BLE entre deux notifications
  }
}

void dumpReps() {
  notify("C\n");                       // signal "clear" pour la page
  for (int i = 0; i < repCount; i++)
    notify("R," + String(i) + "," + String(repMean[i], 2) + "," + String(repPk[i], 2) + "\n");
}

void goToSleep() {
  Serial.println("Passage en deep sleep");
  BLEDevice::deinit(true);
  mpuInitWakeOnMotion();
  esp_sleep_enable_ext0_wakeup(PIN_MPU_INT, 1);
  esp_deep_sleep_start();
}

class ServerCB : public BLEServerCallbacks {
  void onConnect(BLEServer*) override    { connected = true;  Serial.println("BLE connecte"); }
  void onDisconnect(BLEServer* s) override {
    connected = false; Serial.println("BLE deconnecte");
    s->getAdvertising()->start();        // re-annonce pour reconnexion
  }
};

class RxCB : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String cmd = String(c->getValue().c_str());
    cmd.trim();
    if      (cmd == "R") { repCount = 0; Serial.println("Reset series"); }
    else if (cmd == "D") { dumpReps(); }
    else if (cmd == "S") { if (ENABLE_SLEEP) goToSleep(); }
  }
};

void setupBLE() {
  BLEDevice::init(DEV_NAME);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCB());

  BLEService* svc = bleServer->createService(SVC_UUID);
  txChar = svc->createCharacteristic(TX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  txChar->addDescriptor(new BLE2902());
  BLECharacteristic* rxChar =
    svc->createCharacteristic(RX_UUID, BLECharacteristic::PROPERTY_WRITE);
  rxChar->setCallbacks(new RxCB());
  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SVC_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("BLE pret : cherche \"VBT-Tracker\"");
}

// ============================================================
// Détection de rep
// ============================================================
void endRep(uint32_t now) {
  float durS = (now - repStartMs) / 1000.0f;
  float mean = (durS > 0) ? disp / durS : 0;
  if (disp >= DISP_MIN_M && repCount < MAX_REPS) {
    repMean[repCount] = mean; repPk[repCount] = repPeak;
    notify("R," + String(repCount) + "," + String(mean, 2) + "," + String(repPeak, 2) + "\n");
    repCount++;
    digitalWrite(LED_BUILTIN, LOW); ledOffMs = now + 150;
    Serial.printf(">>> REP %d : moy %.2f m/s, pic %.2f m/s, depl %.2f m\n",
                  repCount, mean, repPeak, disp);
  }
  state = ST_SUPPRESS; stillSinceMs = now;
}

void processSample(float aVert, float dt, uint32_t now) {
  if (fabsf(aVert) > TH_STILL) lastMotionMs = now;
  switch (state) {
    case ST_IDLE:
      if (aVert > TH_START) { state = ST_CONC; v = 0; disp = 0; repPeak = 0; repStartMs = now; }
      else if (aVert < -TH_START) { state = ST_SUPPRESS; stillSinceMs = now; }
      break;
    case ST_CONC: {
      v += aVert * dt; disp += v * dt;
      if (v > repPeak) repPeak = v;
      uint32_t dur = now - repStartMs;
      if ((v <= 0 && dur >= REP_MIN_MS) || dur > REP_MAX_MS) endRep(now);
      break;
    }
    case ST_SUPPRESS:
      if (fabsf(aVert) > TH_STILL) stillSinceMs = now;
      if (now - stillSinceMs >= STILL_MS) state = ST_IDLE;
      break;
  }
}

// ============================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);

  Wire.begin();            // D4=SDA, D5=SCL
  Wire.setClock(400000);

  uint8_t who = mpuRead8(0x75);   // WHO_AM_I : doit valoir 0x68
  Serial.printf("WHO_AM_I = 0x%02X ", who);
  if (who == 0x68 || who == 0x70 || who == 0x72) {
    mpuOk = true; Serial.println("-> MPU detecte, OK");
    mpuInitActive();
    calibrateGyro();
  } else {
    Serial.println("-> AUCUNE reponse ! Verifie cablage SDA/SCL/3V3/GND (ou adresse AD0).");
  }

  warmupUntil = millis() + WARMUP_MS;
  setupBLE();
  lastMotionMs = millis();
  Serial.println("Pret.");
}

void loop() {
  static uint32_t lastUs = 0, lastDbg = 0;
  static float dbgPeak = 0, dbgMag = 1;
  uint32_t nowUs = micros();

  if (mpuOk && nowUs - lastUs >= 1000000UL / SAMPLE_HZ) {
    float dt = (lastUs == 0) ? 1.0f / SAMPLE_HZ : (nowUs - lastUs) / 1e6f;
    lastUs = nowUs;
    float a[3], g[3];
    if (mpuReadMotion(a, g)) {
      uint32_t now = millis();
      float mag = sqrtf(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
      bool inMotion = fabsf(mag - 1.0f) > 0.15f;
      float beta = (now < warmupUntil) ? BETA_WARMUP : (inMotion ? BETA_MOTION : BETA_STILL);
      ahrs.update(g[0], g[1], g[2], a[0], a[1], a[2], beta, dt);

      float aVert = (ahrs.verticalOf(a[0], a[1], a[2]) - 1.0f) * 9.80665f - vOff;
      dbgMag = mag;
      if (fabsf(aVert) > fabsf(dbgPeak)) dbgPeak = aVert;

      float gMag = sqrtf(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
      if (state == ST_IDLE && gMag < 0.05f && fabsf(aVert) < 0.6f) {
        vOff += 0.002f * aVert;
        for (int k = 0; k < 3; k++) gyroBias[k] += 0.002f * g[k];
      }

      if (now >= warmupUntil) processSample(aVert, dt, now);
      else lastMotionMs = now;
    }
  }

  uint32_t now = millis();
#if DEBUG_STREAM
  if (now - lastDbg >= 100) {          // 10 Hz : aVert max sur la fenêtre
    lastDbg = now;
    const char* st = state == ST_IDLE ? "IDLE" : state == ST_CONC ? "CONC" : "SUPP";
    Serial.printf("aVert_max=%+5.2f m/s2  |a|=%4.2fg  etat=%s  reps=%d  %s\n",
                  dbgPeak, dbgMag, st, repCount, connected ? "BLE+" : "BLE-");
    dbgPeak = 0;
  }
#endif

  if (ledOffMs && now > ledOffMs) { digitalWrite(LED_BUILTIN, HIGH); ledOffMs = 0; }
#if ENABLE_SLEEP
  if (now - lastMotionMs > SLEEP_AFTER_MS) goToSleep();
#endif
}
