// ============================================================
// VBT Tracker — boîtier imprimable en 3D (unités : mm)
// Fixation double : sangle velcro (oreilles latérales) +
// aimants néodyme Ø10x3 dans le plancher.
//
// part = "case" | "lid" | "assembly"
// Impression : PETG ou PLA, couches 0.2 mm, sans support.
// "case" et "lid" sont déjà orientés pour l'impression.
// ============================================================

part = "assembly";

// ---------- cavité interne ----------
in   = [43, 40, 18];   // x, y, hauteur au-dessus du plancher
wall = 2;              // épaisseur des parois
flr  = 4;              // plancher épais : loge les aimants
rad  = 3;              // rayon des angles

// ---------- contenu (cotes de l'assemblage) ----------
bat_h = 10; foam = 1; pcb_t = 1.6;
pcb_w = 26; pcb_l = 37;
pcb_x = (in[0] - pcb_w) / 2;   // PCB centré en x
pcb_y = 1.2;                   // USB-C affleurant la paroi avant
pcb_z = bat_h + foam;          // dessous du PCB : 11 mm

// ---------- aimants (disques néodyme, collés à la cyano) ----------
mag_d = 10; mag_h = 3; mag_gap = 0.4;
mag_pos = [[10, 9], [33, 9], [10, 31], [33, 31]];

// ---------- sangle ----------
strap_w  = 22;    // largeur de la sangle velcro
strap_th = 3.5;   // épaisseur de passage
lug_th   = 6;     // épaisseur des oreilles

// ---------- fente USB-C (recharge sans ouvrir) ----------
usb_w = 11; usb_h = 4.4;
usb_z = pcb_z + pcb_t - 0.2;

// ---------- plots de vissage du PCB (M2 autotaraudeuses) ----------
post_d = 5; post_hole = 1.8;
posts = [[pcb_x + 2.5, pcb_y + pcb_l - 2.5],
         [pcb_x + pcb_w - 2.5, pcb_y + pcb_l - 2.5]];

$fn = 48;

// ============================================================
module rbox(s, r = rad) {
  linear_extrude(s[2]) offset(r) offset(-r) square([s[0], s[1]]);
}

// oreille latérale traversée par la sangle
module lug(side) {
  lug_l = strap_w + 8;
  lug_h = 10;
  x0 = (side < 0) ? -wall - lug_th : in[0] + wall;
  difference() {
    translate([x0, (in[1] - lug_l) / 2, -flr]) rbox([lug_th, lug_l, lug_h], r = 2);
    translate([x0 - 1, (in[1] - strap_w) / 2, -flr + 2])
      cube([lug_th + 2, strap_w, strap_th]);
  }
}

module case() {
  difference() {
    union() {
      translate([-wall, -wall, -flr]) rbox([in[0] + 2 * wall, in[1] + 2 * wall, in[2] + flr]);
      lug(-1);
      lug(1);
    }
    cube([in[0], in[1], in[2] + 1]);                  // cavité
    translate([(in[0] - usb_w) / 2, -wall - 1, usb_z]) // fente USB-C
      cube([usb_w, wall + 2, usb_h]);
    for (p = mag_pos)                                  // poches des aimants
      translate([p[0], p[1], -flr - 0.01])
        cylinder(d = mag_d + mag_gap, h = mag_h + 0.4);
  }
  for (p = posts) difference() {                       // plots de vissage
    translate([p[0], p[1], 0]) cylinder(d = post_d, h = pcb_z);
    translate([p[0], p[1], pcb_z - 8]) cylinder(d = post_hole, h = 9);
  }
}

// couvercle à lèvre, emboîtement en friction
module lid() {
  gap = 0.3;   // jeu d'emboîtement, à ajuster selon l'imprimante
  translate([-wall, -wall, 0]) rbox([in[0] + 2 * wall, in[1] + 2 * wall, 2.4]);
  translate([0, 0, -2]) linear_extrude(2) difference() {
    offset(-gap) square([in[0], in[1]]);
    offset(-gap - 1.5) square([in[0], in[1]]);
  }
}

// ============================================================
if (part == "case") {
  case();
} else if (part == "lid") {
  rotate([180, 0, 0]) lid();          // à plat pour l'impression
} else {
  case();
  translate([0, 0, in[2] + 8]) lid(); // couvercle au-dessus
  // composants en transparence
  %translate([(in[0] - 40) / 2, pcb_y, 0]) cube([40, 30, bat_h]);          // batterie
  %translate([pcb_x, pcb_y, pcb_z]) cube([pcb_w, pcb_l, pcb_t]);           // PCB
  %translate([pcb_x + 4.1, pcb_y + 1.2, pcb_z + pcb_t]) cube([17.8, 21, 4]);        // XIAO
  %translate([pcb_x + 2.15, pcb_y + 20.6, pcb_z + pcb_t + 2.5]) cube([21.7, 15.6, 2.1]); // GY-521
}

echo(str("Boitier exterieur : ", in[0] + 2 * wall, " x ", in[1] + 2 * wall,
         " x ", in[2] + flr + 2.4, " mm (hors oreilles, +",
         2 * (lug_th + 0), " mm en largeur avec les oreilles)"));
