// ============================================================
// VBT Tracker — XIAO ESP32-S3 + MPU6050 (GY-521)  —  version BLE
// Fusion gyro + accéléromètre (Madgwick) -> vitesse verticale,
// envoyée en Bluetooth Low Energy (service type Nordic UART).
//
// Câblage GY-521 -> XIAO ESP32-S3 :
//   VCC->3V3 | GND->GND | SDA->D5(GPIO6) | SCL->D6(GPIO43) | INT->D0(GPIO1)
//
// Côté iPhone : navigateur Bluefy -> ouvrir la page vbt-ble.html
// ============================================================

#include <Wire.h>
#include "driver/gpio.h"
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
#define PIN_I2C_SDA     6        // broche serigraphiee D5
#define PIN_I2C_SCL     43       // broche serigraphiee D6 (= U0TXD, voir setup)
#define SAMPLE_HZ       200
// --- seuils de detection de rep (a calibrer avec le flux de debug) ---
#define V_MOVE          0.12f       // m/s : vitesse a partir de laquelle on considere un mouvement
#define A_QUIET         0.50f       // m/s2 : sous ce seuil (+ gyro) = quasi-immobile
#define G_QUIET         0.15f       // rad/s (~8.6 deg/s) : gyro sous ce seuil = quasi-immobile
#define QUIET_MS        250         // duree de calme avant remise a zero de la vitesse (ZVU)
#define ECC_MIN_DISP    0.05f       // m : descente minimale pour valider une vraie phase excentrique
#define DISP_MIN_M      0.10f       // m : deplacement concentrique minimal pour compter la rep
#define REP_MIN_MS      150         // duree concentrique minimale
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
volatile bool      reAdvertise = false;     // demande de re-publicité (depuis le callback)
volatile uint32_t  disconnectMs = 0;

// ---------- État détection ----------
// ST_WAIT : au repos / entre les reps  | ST_DESC : phase excentrique (descente)
// ST_ASC  : phase concentrique (montee, c'est elle qu'on mesure)
enum RepState { ST_WAIT, ST_DESC, ST_ASC };
RepState state = ST_WAIT;

float    vOff = 0;                 // offset residuel d'accel verticale au repos
float    vVert = 0;                // vitesse verticale integree (m/s, + = montee)
float    eccDisp = 0;              // deplacement de la descente (suivi, signe negatif)
float    concDisp = 0, concPeak = 0;   // deplacement et pic de vitesse de la montee
uint32_t concStartMs = 0, quietSinceMs = 0;
uint32_t lastMotionMs = 0, warmupUntil = 0, ledOffMs = 0;
float    repMean[MAX_REPS], repPk[MAX_REPS];
int      repCount = 0;
bool     mpuOk = false;
uint8_t  whoami = 0;

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

// Battement de coeur : etat courant + derniere vitesse, pour que la page
// sache que le lien est vivant meme entre deux repetitions.
void sendStatus() {
  const char* st = state == ST_ASC ? "1" : "0";   // 1 = phase concentrique en cours
  float lastMean = repCount ? repMean[repCount - 1] : 0;
  notify("S," + String(st) + "," + String(lastMean, 2) + "," + String(repCount) + "\n");
}

void goToSleep() {
  Serial.println("Passage en deep sleep");
  BLEDevice::deinit(true);
  mpuInitWakeOnMotion();
  esp_sleep_enable_ext0_wakeup(PIN_MPU_INT, 1);
  esp_deep_sleep_start();
}

class ServerCB : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    connected = true;
    Serial.println("BLE connecte");
  }
  void onDisconnect(BLEServer*) override {
    connected = false;
    disconnectMs = millis();
    reAdvertise = true;                  // la re-publicite se fait dans loop(), pas ici
    Serial.println("BLE deconnecte");
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
  adv->setMinPreferred(0x06);            // intervalles recommandes pour iOS
  adv->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("BLE pret : cherche \"VBT-Tracker\"");
}

// ============================================================
// Détection de rep — machine à états basée sur la VITESSE verticale.
// Mesure la phase concentrique (montée), quel que soit l'ordre des phases :
//   squat/bench : ATTENTE -> DESCENTE -> (bas) -> MONTEE -> rep
//   souleve     : ATTENTE -> MONTEE -> rep
// ============================================================
void finishRep(uint32_t now) {
  float durS = (now - concStartMs) / 1000.0f;
  float mean = (durS > 0) ? concDisp / durS : 0;
  if (concDisp >= DISP_MIN_M && (now - concStartMs) >= REP_MIN_MS && repCount < MAX_REPS) {
    repMean[repCount] = mean; repPk[repCount] = concPeak;
    notify("R," + String(repCount) + "," + String(mean, 2) + "," + String(concPeak, 2) + "\n");
    repCount++;
    digitalWrite(LED_BUILTIN, LOW); ledOffMs = now + 150;
    Serial.printf(">>> REP %d : moy %.2f m/s, pic %.2f m/s, depl %.2f m\n",
                  repCount, mean, concPeak, concDisp);
  }
  state = ST_WAIT;
}

// aVert : accel verticale lineaire (m/s2, + = haut) ; gMag : norme gyro (rad/s)
void processSample(float aVert, float gMag, float g[3], float dt, uint32_t now) {
  vVert += aVert * dt;                       // integration de la vitesse verticale

  // --- ZVU : quasi-immobile sur une fenetre -> on annule la derive ---
  bool quiet = (fabsf(aVert) < A_QUIET) && (gMag < G_QUIET);
  if (!quiet) { quietSinceMs = now; lastMotionMs = now; }
  if (now - quietSinceMs >= QUIET_MS) {
    if (state == ST_ASC) finishRep(now);     // pause en haut = fin de la montee
    vVert = 0;                               // remise a zero de la vitesse
    vOff += 0.02f * aVert;                    // recalage lent de l'offset accel
    for (int k = 0; k < 3; k++) gyroBias[k] += 0.01f * g[k];
    state = ST_WAIT;
    return;
  }

  switch (state) {
    case ST_WAIT:
      if (vVert < -V_MOVE) { state = ST_DESC; eccDisp = 0; }          // descente
      else if (vVert > V_MOVE) {                                       // montee directe (souleve)
        state = ST_ASC; concDisp = 0; concPeak = 0; concStartMs = now;
      }
      break;

    case ST_DESC:
      eccDisp += vVert * dt;                  // s'accumule en negatif
      if (vVert >= 0) {                        // <-- vitesse change de sens = BAS atteint
        if (fabsf(eccDisp) >= ECC_MIN_DISP) {  // vraie descente (pas un tremblement)
          vVert = 0;                           // ancrage : vitesse nulle au point bas
          concDisp = 0; concPeak = 0; concStartMs = now;
          state = ST_ASC;
        } else {
          state = ST_WAIT;
        }
      }
      break;

    case ST_ASC:
      concDisp += vVert * dt;
      if (vVert > concPeak) concPeak = vVert;
      if (vVert <= 0 && (now - concStartMs) >= REP_MIN_MS) finishRep(now);  // HAUT atteint
      break;
  }
}

// Debloque le bus I2C si le MPU est reste coince (SDA tenu bas), ce que
// peuvent provoquer les impulsions de boot sur GPIO43/U0TXD : on pulse SCL
// jusqu'a 16 fois puis on genere une condition STOP propre.
void i2cBusRecover() {
  pinMode(PIN_I2C_SDA, INPUT_PULLUP);
  pinMode(PIN_I2C_SCL, OUTPUT);
  for (int i = 0; i < 16 && digitalRead(PIN_I2C_SDA) == LOW; i++) {
    digitalWrite(PIN_I2C_SCL, HIGH); delayMicroseconds(6);
    digitalWrite(PIN_I2C_SCL, LOW);  delayMicroseconds(6);
  }
  pinMode(PIN_I2C_SDA, OUTPUT);
  digitalWrite(PIN_I2C_SDA, LOW);  delayMicroseconds(6);   // STOP : SDA monte
  digitalWrite(PIN_I2C_SCL, HIGH); delayMicroseconds(6);   //        pendant que
  digitalWrite(PIN_I2C_SDA, HIGH); delayMicroseconds(6);   //        SCL est haut
}

// ============================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH);

  // GPIO43 (= D6) est l'U0TXD : le bootloader y laisse la fonction UART et y
  // envoie ses logs de boot. On remet les broches en GPIO simple, puis on
  // debloque le bus, avant de demarrer l'I2C.
  gpio_reset_pin((gpio_num_t)PIN_I2C_SDA);   // GPIO6  (D5)
  gpio_reset_pin((gpio_num_t)PIN_I2C_SCL);   // GPIO43 (D6)
  i2cBusRecover();
  Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);   // SDA=GPIO6 (D5), SCL=GPIO43 (D6)
  Wire.setClock(400000);

  whoami = mpuRead8(0x75);   // WHO_AM_I : doit valoir 0x68
  Serial.printf("\n=== WHO_AM_I = 0x%02X ===\n", whoami);
  if (whoami == 0x68 || whoami == 0x70 || whoami == 0x72) {
    mpuOk = true; Serial.println("--> MPU6050 DETECTE, OK\n");
    mpuInitActive();
    calibrateGyro();
  } else {
    Serial.println("--> AUCUNE REPONSE du MPU ! (verifie SDA=D4, SCL=D5, 3V3, GND, soudures, AD0)\n");
  }

  warmupUntil = millis() + WARMUP_MS;
  setupBLE();
  lastMotionMs = millis();
  Serial.println("Pret.");
}

void loop() {
  static uint32_t lastUs = 0, lastDbg = 0, winReads = 0;
  static float dbgPeak = 0, dbgMag = 0, dbgAx = 0, dbgAy = 0, dbgAz = 0;
  uint32_t nowUs = micros();

  if (mpuOk && nowUs - lastUs >= 1000000UL / SAMPLE_HZ) {
    float dt = (lastUs == 0) ? 1.0f / SAMPLE_HZ : (nowUs - lastUs) / 1e6f;
    lastUs = nowUs;
    float a[3], g[3];
    if (mpuReadMotion(a, g)) {
      winReads++;
      uint32_t now = millis();
      float mag = sqrtf(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
      bool inMotion = fabsf(mag - 1.0f) > 0.15f;
      float beta = (now < warmupUntil) ? BETA_WARMUP : (inMotion ? BETA_MOTION : BETA_STILL);
      ahrs.update(g[0], g[1], g[2], a[0], a[1], a[2], beta, dt);

      float aVert = (ahrs.verticalOf(a[0], a[1], a[2]) - 1.0f) * 9.80665f - vOff;
      float gMag = sqrtf(g[0] * g[0] + g[1] * g[1] + g[2] * g[2]);
      dbgMag = mag; dbgAx = a[0]; dbgAy = a[1]; dbgAz = a[2];
      if (fabsf(aVert) > fabsf(dbgPeak)) dbgPeak = aVert;

      if (now >= warmupUntil) processSample(aVert, gMag, g, dt, now);
      else lastMotionMs = now;
    }
  }

  uint32_t now = millis();

  // re-publicite robuste : on attend ~500 ms apres la deconnexion avant de
  // relancer l'annonce (relancer dans le callback echoue souvent)
  if (reAdvertise && now - disconnectMs > 500) {
    BLEDevice::startAdvertising();
    reAdvertise = false;
    Serial.println("BLE : re-annonce active");
  }

  // heartbeat ~1.4 Hz tant qu'on est connecte
  static uint32_t lastHb = 0;
  if (connected && now - lastHb >= 700) { lastHb = now; sendStatus(); }

#if DEBUG_STREAM
  if (now - lastDbg >= 500) {                 // 2 Hz : lisible
    float dtWin = (now - lastDbg) / 1000.0f;
    lastDbg = now;
    if (!mpuOk) {
      whoami = mpuRead8(0x75);                 // re-tente la detection a chaud
      if (whoami == 0x68 || whoami == 0x70 || whoami == 0x72) {
        mpuOk = true; mpuInitActive(); calibrateGyro();
        Serial.println("--> MPU6050 detecte a chaud, OK");
      } else {
        Serial.printf("[!] MPU NON DETECTE  WHO_AM_I=0x%02X  ->  verifie 3V3 / GND / SDA=D4 / SCL=D5 / soudures / AD0\n",
                      whoami);
      }
    } else {
      const char* st = state == ST_WAIT ? "ATTENTE" : state == ST_DESC ? "DESCENTE" : "MONTEE ";
      Serial.printf("MPU 0x%02X | %3lu lect/s | aVert_max=%+.2f | vVert=%+.2f m/s | %s | reps=%d | %s\n",
                    whoami, (unsigned long)(winReads / (dtWin > 0 ? dtWin : 1)),
                    dbgPeak, vVert, st, repCount,
                    connected ? "BLE CONNECTE" : "BLE en attente (VBT-Tracker)");
    }
    dbgPeak = 0; winReads = 0;
  }
#endif

  if (ledOffMs && now > ledOffMs) { digitalWrite(LED_BUILTIN, HIGH); ledOffMs = 0; }
#if ENABLE_SLEEP
  if (now - lastMotionMs > SLEEP_AFTER_MS) goToSleep();
#endif
}
