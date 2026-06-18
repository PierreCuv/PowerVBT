# Alimentation, charge et marche/arrêt

Ce document consigne **l'analyse électrique** qui a mené au choix du circuit
d'allumage, pour que les décisions restent compréhensibles plus tard.

## TL;DR (le choix retenu)

- Batterie **LiPo 680 mAh, avec son propre circuit de protection (PCM)**.
- Allumage/extinction par **interrupteur sur la broche EN** du XIAO (pas sur
  la ligne batterie).
- Batterie reliée en permanence à BAT+ / BAT− → **recharge possible même
  appareil éteint**.

## 1. Le circuit d'alimentation du XIAO ESP32-S3

Relevé sur le **schéma officiel Seeed v1.5** (`202003753_XIAO ESP32S3 Sense`) :

| Repère | Composant | Rôle |
|--------|-----------|------|
| U4 | **SGM40567-4.2** | Chargeur LiPo linéaire (cellule 4,2 V) |
| U3 | SGM6029 | Régulateur 3,3 V (buck, Imax 600 mA) |
| Q1 | LP0404N3T5G | MOSFET de *power-path* (bascule USB ↔ batterie) |

**Courant de charge** fixé par une résistance de 220 K (R10) :
`ICharge = 24000 / 220K ≈ 110 mA`. Pour une batterie de 680 mAh, cela donne
une charge complète en **~7 à 8 h** (≈ 0,15C, très doux pour la cellule).

## 2. Recherche : le XIAO protège-t-il la batterie ?

Question de départ : peut-on laisser la batterie connectée en permanence sans
risque de **sur-décharge** (descente sous la tension de sécurité, qui abîme
voire rend dangereuse une LiPo) ?

Démarche et constats :

1. **Documentation Seeed ambiguë** : un membre du staff affirme sur le forum
   que « le XIAO inclut ces protections », mais le wiki officiel recommande à
   l'inverse « d'utiliser une batterie équipée d'un circuit de protection ».
   Contradiction → vérification sur le schéma.
2. **Lecture du schéma** : aucun circuit de protection dédié (pas de duo
   **DW01 + FS8205/8205** ni équivalent) sur la ligne BAT. Le seul MOSFET (Q1)
   sert au *power-path*, pas à protéger la cellule.
3. **Datasheet du SGM40567** : décrit comme un **chargeur linéaire** pur
   (pré-charge, charge rapide, maintien, compensation de tension). Un chargeur
   protège pendant la **charge** (surtension), mais **ne coupe pas** la
   batterie en décharge.

### Conclusion

> **Le XIAO ESP32-S3 n'assure PAS de protection contre la sur-décharge.**
> Cette protection doit venir de la batterie elle-même (PCM/BMS) ou être
> évitée (ne jamais vider la cellule à fond).

## 3. La batterie utilisée EST protégée

Inspection visuelle de la batterie (sous le ruban Kapton, côté pattes) :
petite carte verte portant un **CI 6 broches (type DW01)** + un **double
MOSFET 8 broches (type 8205)**. C'est le **module de protection LiPo (PCM)**
standard : protège contre sur-décharge, sur-charge, surintensité et
court-circuit.

→ La sur-décharge est donc **gérée par la batterie**, indépendamment du XIAO.

## 4. Choix du circuit marche/arrêt

Deux options étaient possibles :

| | **Interrupteur sur EN** (retenu) | Interrupteur sur BAT+ |
|---|---|---|
| Conso éteint | ~50–200 µA (faible courant de repos) | **0 µA** (coupure totale) |
| Charge appareil éteint | **Oui** | Non (ON requis pour charger) |
| Risque sur-décharge | Couvert par le PCM de la batterie | Très faible (batterie isolée) |
| Tenue au stockage long | Quelques mois (PCM coupe avant dégât) | Quasi illimitée |

**Décision : interrupteur sur EN.** Justification : puisque la batterie a son
propre PCM, la sur-décharge n'est plus un danger, ce qui débloque le confort
de **charger même éteint**. Le seul compromis (petit courant de repos) est
sans risque grâce au PCM — au pire la batterie est à plat après une très
longue pause, et il suffit de la recharger.

> Si un jour l'autonomie au repos devient gênante (appareil laissé des
> semaines sans charge), repasser à l'interrupteur sur **BAT+** redonne une
> coupure totale. Le code n'a pas à changer.

### Câblage retenu (EN)

| Connexion | |
|-----------|--|
| Batterie **+** (orange) | → pad **BAT+** (direct, sans interrupteur) |
| Batterie **−** (bleu) | → pad **BAT−** (direct) |
| Interrupteur, broche **milieu** | → pad **EN** |
| Interrupteur, **une** broche extérieure | → **GND** |
| Interrupteur, autre broche extérieure | libre |

Fonctionnement (EN possède une résistance de tirage interne au 3,3 V) :
- curseur côté **GND** → EN à la masse → ESP32 en reset = **OFF** ;
- curseur côté **libre** → EN tiré au niveau haut → ESP32 démarre = **ON**.

## Sources

- Schéma : `202003753_XIAO ESP32S3 Sense_v1.5_SCH`.
- [SGM40567 — SG Micro (datasheet)](https://www.sg-micro.com/product/SGM40567)
- [Forum Seeed — protection over/discharge](https://forum.seeedstudio.com/t/does-the-esp32c3-xiao-have-integrated-over-and-discharge-protection/275476)
- [Wiki XIAO ESP32-S3](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/)
