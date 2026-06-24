// ============================================================
// Depth Tracker — Test potentiomètre à fil + buzzer
// XIAO ESP32-S3 :  potentiomètre → D1/GPIO2  |  buzzer → D3/GPIO4
// Wokwi (simulation) : potentiomètre → GPIO2  |  buzzer → GPIO4
// ============================================================

#define PIN_POT   2    // D1 sur XIAO / GPIO2
#define PIN_BUZZ  4    // D3 sur XIAO / GPIO4

#define FREQ_BIP    2700   // Hz — fréquence de résonance typique piézo
#define DUREE_BIP    200   // ms
#define SEUIL_PCT     90   // % de l'amplitude de calibration → profondeur atteinte

int valHaut    = 4095;   // valeur ADC debout (barre en haut)
int valBas     = 0;      // valeur ADC au fond du squat (calibration)
bool bipEnCours = false;

void setup() {
  Serial.begin(115200);
  analogReadResolution(12);   // 0-4095

  Serial.println("=== CALIBRATION ===");
  Serial.println("1) Mets la barre en position HAUTE (debout)");
  Serial.println("   Envoie 'H' dans le moniteur série quand prêt");
  while (Serial.read() != 'H') delay(10);
  valHaut = analogRead(PIN_POT);
  Serial.printf("   → valeur HAUT : %d\n", valHaut);

  Serial.println("2) Descends à la PROFONDEUR voulue");
  Serial.println("   Envoie 'B' dans le moniteur série quand prêt");
  while (Serial.read() != 'B') delay(10);
  valBas = analogRead(PIN_POT);
  Serial.printf("   → valeur BAS  : %d\n", valBas);

  Serial.println("Calibration OK — début de la détection !\n");
}

void loop() {
  int val = analogRead(PIN_POT);

  int amplitude = abs(valHaut - valBas);
  int profondeur = 0;
  if (amplitude > 0) {
    profondeur = abs(val - valHaut) * 100 / amplitude;
    profondeur = constrain(profondeur, 0, 100);
  }

  // Affichage barre de progression dans le moniteur série
  Serial.printf("ADC: %4d | Profondeur: %3d%% [", val, profondeur);
  int barres = profondeur / 5;
  for (int i = 0; i < 20; i++) Serial.print(i < barres ? "#" : "-");
  Serial.print("]");

  if (profondeur >= SEUIL_PCT) {
    Serial.print(" ← PROFONDEUR OK !");
    if (!bipEnCours) {
      tone(PIN_BUZZ, FREQ_BIP, DUREE_BIP);
      bipEnCours = true;
    }
  } else {
    bipEnCours = false;
  }

  Serial.println();
  delay(20);   // 50 Hz
}
