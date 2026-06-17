# ⚡ PowerVBT

> Capteur de **Velocity Based Training** open source, pour le powerlifting.

Un XIAO ESP32-S3 et un MPU6050 mesurent la vitesse de la phase concentrique
de chaque répétition et l'affichent en temps réel sur le téléphone, en
Bluetooth Low Energy.

Pas d'application native à installer : l'interface est une page web qui se
connecte au capteur via Web Bluetooth.

```
┌──────────────┐   BLE    ┌─────────────────────┐
│  XIAO ESP32  │ ───────► │  Page web (Bluefy /  │
│   + MPU6050  │          │  Chrome Android)     │
└──────────────┘          └─────────────────────┘
   mesure la vitesse         affiche reps, perte
   à 200 Hz (Madgwick)       de vitesse, zones
```

## Structure du dépôt

| Dossier | Contenu |
|---------|---------|
| [`firmware/vbt-tracker/`](firmware/vbt-tracker/) | Le sketch Arduino (`.ino` + filtre de Madgwick) |
| [`hardware/3d/`](hardware/3d/) | Modèles OpenSCAD : assemblage et boîtier imprimable |
| [`docs/`](docs/) | La page web (servie par GitHub Pages) |

## Matériel

- Seeed Studio **XIAO ESP32-S3**
- Module **GY-521** (MPU6050, gyroscope + accéléromètre 3 axes)
- Batterie LiPo (1S, ex. 40 × 30 × 10 mm)
- PCB de support 26 × 37 mm

### Câblage

| GY-521 (MPU6050) | XIAO ESP32-S3 | Rôle |
|------------------|---------------|------|
| VCC              | 3V3           | Alimentation |
| GND              | GND           | Masse |
| SDA              | D4 (GPIO5)    | I2C — données |
| SCL              | D5 (GPIO6)    | I2C — horloge |
| INT              | D0 (GPIO1)    | Réveil sur mouvement |

La batterie LiPo se branche sur les pads BAT+ / BAT− au dos du XIAO
(chargeur intégré : elle se recharge dès que l'USB-C est branché).

> **Autonomie** — la LED d'alimentation du GY-521 consomme ~1-2 mA en
> permanence, soit plus que tout le reste du système en veille. Pour une
> autonomie de plusieurs semaines, dessoude cette LED sur le module.

## Firmware

### Installation (Arduino IDE)

1. Ajouter le support ESP32 : *Fichier → Préférences → URL de gestionnaire de
   cartes supplémentaires* :
   `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   puis *Outils → Gestionnaire de cartes* → installer **esp32 by Espressif**.
2. Carte : **XIAO_ESP32S3**. Activer *USB CDC On Boot* pour le moniteur série.
3. Ouvrir [`firmware/vbt-tracker/vbt-tracker.ino`](firmware/vbt-tracker/vbt-tracker.ino)
   et téléverser. **Aucune bibliothèque externe requise** (BLE inclus dans le
   cœur ESP32).

### Drapeaux de configuration (haut du `.ino`)

| Drapeau | Défaut | Effet |
|---------|--------|-------|
| `DEBUG_STREAM` | `1` | Flux de valeurs sur le moniteur série (mise au point) |
| `ENABLE_SLEEP` | `0` | `1` réactive le deep sleep automatique |

Au démarrage, un test **WHO_AM_I** confirme sur le moniteur série (115200
bauds) que le MPU6050 répond — premier réflexe de diagnostic.

### Comment ça marche

- **Orientation** : un filtre de Madgwick ([`madgwick.h`](firmware/vbt-tracker/madgwick.h))
  fusionne gyroscope et accéléromètre à 200 Hz. On en déduit l'accélération
  **verticale réelle** (signée : montée positive, descente négative), quelle
  que soit la fixation du capteur sur la barre. Pendant l'effort, le gain
  `beta` est réduit pour que les accélérations du mouvement ne faussent pas
  l'estimation.
- **Détection de rep** : déclenchement sur accélération verticale positive
  (phase concentrique), intégration de la vitesse jusqu'à son retour à zéro ;
  vitesse moyenne = déplacement / durée. Le biais gyro est calibré au
  démarrage, mémorisé en RTC pendant le deep sleep, et affiné pendant les
  phases de repos.
- **Transport** : service BLE type Nordic UART. Le capteur notifie chaque rep
  (`R,index,moyenne,pic`) ; le téléphone envoie des commandes (`R` reset,
  `D` dump, `S` sleep).
- **Veille** : deep sleep ESP32 + MPU6050 en « wake on motion » à 5 Hz ;
  réveil par la broche INT au moindre mouvement.

### Calibration

À ajuster en tête du `.ino` en observant le flux de debug :

| Constante | Défaut | Effet |
|-----------|--------|-------|
| `TH_START` | 1.2 m/s² | Plus bas = déclenche plus facilement (plus de faux positifs) |
| `DISP_MIN_M` | 0.12 m | Déplacement minimal pour valider une rep |
| `STILL_MS` | 350 ms | Pause minimale entre deux mouvements |

## Interface web (BLE)

La page [`docs/index.html`](docs/index.html) utilise l'API Web Bluetooth.

- **Android** : Chrome la prend en charge nativement.
- **iPhone** : Safari ne supporte pas Web Bluetooth → utiliser le navigateur
  **Bluefy**.

Hébergée gratuitement via **GitHub Pages** (voir ci-dessous), elle s'ouvre
depuis n'importe quel navigateur compatible : bouton « Connecter le capteur »
→ sélectionner `VBT-Tracker` → les répétitions s'affichent en direct, avec
zone de vitesse et alerte de perte ≥ 20 % (signal de fin de série).

### Activer GitHub Pages

1. Pousser ce dépôt sur GitHub (voir section suivante).
2. *Settings → Pages → Build and deployment*.
3. Source : **Deploy from a branch**, branche `main`, dossier **`/docs`**.
4. La page sera servie à `https://<utilisateur>.github.io/<dépôt>/`.

## Modèles 3D

Fichiers OpenSCAD ([openscad.org](https://openscad.org), gratuit) dans
[`hardware/3d/`](hardware/3d/). F5 = aperçu, F6 = rendu, F7 = export STL.

- `vbt-assembly.scad` — assemblage des composants (`explode = 15` pour la vue
  éclatée).
- `vbt-case.scad` — boîtier imprimable. Changer `part` en `"case"` puis
  `"lid"` pour exporter chaque pièce (PETG ou PLA, 0.2 mm, sans support).

Fixation double : **sangle** velcro 20 mm (oreilles latérales) + **aimants**
néodyme Ø10 × 3 mm (4 poches sous le plancher, même polarité), pour les barres
comme pour les machines guidées en acier. Fente USB-C en façade : recharge
sans ouvrir le boîtier.

## Limites connues et feuille de route

- L'intégration de l'accélération dérive un peu (MEMS grand public) : les
  valeurs absolues peuvent différer de quelques % d'un capteur commercial,
  mais la **perte de vitesse relative** (métrique clé du VBT) reste fiable.
- Après le réveil, le filtre a besoin de ~1,5 s de convergence : poser le
  capteur immobile une seconde avant la première rep.
- **v2 envisagée** : historique des séances en flash, profil charge-vitesse
  pour estimer le 1RM, export CSV.

## Licence

[MIT](LICENSE) © 2026 Pierre Cuvillier
