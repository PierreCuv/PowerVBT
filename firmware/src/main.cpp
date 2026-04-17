/**
 * PowerVBT — Firmware v0.1
 * Seeed XIAO ESP32-S3 + ICM-42688-P
 *
 * Status: skeleton / placeholder
 * TODO: implement each module
 */

#include <Arduino.h>
#include "imu/imu_driver.h"
#include "vbt/rep_detector.h"
#include "vbt/velocity_calc.h"
#include "ble/ble_server.h"

// ─── Pin definitions ──────────────────────────────────────
#define IMU_SDA   6
#define IMU_SCL   7
#define IMU_INT1  9

// ─── Sampling ─────────────────────────────────────────────
#define SAMPLE_RATE_HZ  200
#define SAMPLE_PERIOD_MS (1000 / SAMPLE_RATE_HZ)

// ─── FreeRTOS task handles ─────────────────────────────────
TaskHandle_t sensorTaskHandle = NULL;
TaskHandle_t bleTaskHandle    = NULL;

// ─── Shared data (protected by mutex) ─────────────────────
SemaphoreHandle_t dataMutex;
float currentVelocity = 0.0f;
RepData lastRep = {0};

// ─────────────────────────────────────────────────────────
// Sensor task — Core 0, high priority
// ─────────────────────────────────────────────────────────
void sensorTask(void* param) {
  IMUDriver imu(IMU_SDA, IMU_SCL, IMU_INT1);
  VelocityCalc velCalc(SAMPLE_RATE_HZ);
  RepDetector repDetector;

  if (!imu.begin()) {
    Serial.println("[IMU] Init failed!");
    vTaskDelete(NULL);
    return;
  }

  imu.calibrate();  // Zero-g + zero-rate offset
  Serial.println("[IMU] Calibrated. Starting acquisition.");

  TickType_t lastWakeTime = xTaskGetTickCount();

  while (true) {
    IMUData raw = imu.read();
    float velocity = velCalc.update(raw);

    RepEvent event = repDetector.update(velocity);

    if (event.type == RepEvent::REP_COMPLETED) {
      xSemaphoreTake(dataMutex, portMAX_DELAY);
      lastRep = event.data;
      xSemaphoreGive(dataMutex);
    }

    xSemaphoreTake(dataMutex, portMAX_DELAY);
    currentVelocity = velocity;
    xSemaphoreGive(dataMutex);

    vTaskDelayUntil(&lastWakeTime, pdMS_TO_TICKS(SAMPLE_PERIOD_MS));
  }
}

// ─────────────────────────────────────────────────────────
// BLE task — Core 1
// ─────────────────────────────────────────────────────────
void bleTask(void* param) {
  BLEServer bleServer;
  bleServer.begin();
  Serial.println("[BLE] Server started.");

  while (true) {
    if (bleServer.isConnected()) {
      float vel;
      xSemaphoreTake(dataMutex, portMAX_DELAY);
      vel = currentVelocity;
      xSemaphoreGive(dataMutex);

      bleServer.streamVelocity(vel);
    }
    vTaskDelay(pdMS_TO_TICKS(50));  // 20Hz BLE stream
  }
}

// ─────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("[PowerVBT] Booting...");

  dataMutex = xSemaphoreCreateMutex();

  // Core 0 → sensor acquisition (time-critical)
  xTaskCreatePinnedToCore(sensorTask, "SensorTask", 8192, NULL, 2, &sensorTaskHandle, 0);

  // Core 1 → BLE communication
  xTaskCreatePinnedToCore(bleTask, "BLETask", 8192, NULL, 1, &bleTaskHandle, 1);
}

void loop() {
  // All work done in FreeRTOS tasks
  vTaskDelay(pdMS_TO_TICKS(1000));
}
