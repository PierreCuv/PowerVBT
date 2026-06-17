// ============================================================
// VBT Tracker — assemblage 3D (unités : mm)
// Ouvrir avec OpenSCAD (gratuit) : F5 aperçu, F6 rendu, F7 export STL
// Mettre explode = 15 pour une vue éclatée.
// ============================================================

explode = 0;        // écartement vertical entre les étages (mm)

// ---------- dimensions ----------
pcb  = [26, 37, 1.6];      // PCB principal (JLCPCB W1033614AS4FR7)
bat  = [40, 30, 10];       // batterie LiPo
xiao = [17.8, 21, 1.2];    // carte XIAO ESP32-S3 (PCB nu)
gy   = [21.7, 15.6, 1.2];  // module GY-521 (MPU6050)

foam     = 1;     // adhésif double face entre batterie et PCB
gy_stand = 2.5;   // surélévation du GY-521 (plastique du header)
hole_d   = 2.2;   // trous de fixation M2 du PCB principal
hole_off = 2.5;   // distance des trous aux bords

// ---------- étages ----------
pcb_z = bat[2] + foam + explode;        // dessous du PCB
top_z = pcb_z + pcb[2] + explode;       // dessus du PCB

// ============================================================
// Pièces
// ============================================================
module battery() {
  color("LightSlateGray") cube(bat);
  color("Red")   translate([bat[0]/2 - 2, bat[1] - 0.1, bat[2]/2])
    rotate([-90, 0, 0]) cylinder(d = 1.2, h = 6, $fn = 16);
  color("Black") translate([bat[0]/2 + 2, bat[1] - 0.1, bat[2]/2])
    rotate([-90, 0, 0]) cylinder(d = 1.2, h = 6, $fn = 16);
}

module main_pcb() {
  color("DarkGreen") difference() {
    cube(pcb);
    for (x = [hole_off, pcb[0] - hole_off], y = [hole_off, pcb[1] - hole_off])
      translate([x, y, -1]) cylinder(d = hole_d, h = pcb[2] + 2, $fn = 24);
  }
}

module xiao() {
  color([0.12, 0.12, 0.12]) cube(xiao);
  // blindage RF
  color("Silver") translate([(xiao[0] - 13) / 2, 5, xiao[2]])
    cube([13, 10.5, 2]);
  // connecteur USB-C, affleurant au bord avant
  color("Silver") translate([(xiao[0] - 8.9) / 2, -1.2, xiao[2]])
    cube([8.9, 7.4, 3.2]);
  // pastilles latérales
  color("Gold") for (s = [0, 1], i = [0 : 6])
    translate([s ? xiao[0] - 2 : 0.5, 3 + i * 2.54, xiao[2]])
      cube([1.5, 1.6, 0.1]);
}

module gy521() {
  // broches du header, traversent vers le PCB principal
  color("Gold") for (i = [0 : 7])
    translate([(gy[0] - 17.78) / 2 + i * 2.54 - 0.3, 1.27 - 0.3, -gy_stand - pcb[2]])
      cube([0.6, 0.6, gy_stand + pcb[2] + gy[2] + 2]);
  color("RoyalBlue") difference() {
    cube(gy);
    for (x = [1.5, gy[0] - 1.5])  // trous de fixation du module
      translate([x, gy[1] - 2.5, -1]) cylinder(d = 3, h = gy[2] + 2, $fn = 24);
  }
  // puce MPU6050
  color([0.12, 0.12, 0.12]) translate([(gy[0] - 4) / 2, (gy[1] - 4) / 2 + 1.5, gy[2]])
    cube([4, 4, 0.9]);
}

// ============================================================
// Assemblage (origine = coin du PCB principal)
// ============================================================
translate([(pcb[0] - bat[0]) / 2, (pcb[1] - bat[1]) / 2, 0]) battery();
translate([0, 0, pcb_z]) main_pcb();
// XIAO : USB-C vers le bord avant (y = 0) pour la recharge
translate([(pcb[0] - xiao[0]) / 2, 1.2, top_z]) xiao();
// GY-521 : surélevé sur son header, vers le bord arrière
translate([(pcb[0] - gy[0]) / 2, pcb[1] - gy[1] - 0.8, top_z + gy_stand]) gy521();

// ---------- encombrement ----------
total_h = bat[2] + foam + pcb[2] + gy_stand + gy[2] + 0.9;
echo(str("Encombrement total : ", bat[0], " x ", bat[1] + 6, " x ", total_h,
         " mm (L x l x H, fils de batterie inclus)"));
