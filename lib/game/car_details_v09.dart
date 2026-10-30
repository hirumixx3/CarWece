part of 'gpu_mesh.dart';

/// Original toy-scale silhouettes and recognizable details; no extracted assets.
void _buildExpansionDetails(Mesh3 m, CarSpec car) {
  final d = car.design, l = d.halfLength, c = car.color, a = car.accent;
  const dark = 0xff19252d, white = 0xffe3f2f7, red = 0xffff342c;
  void box(V3 p, V3 size, int color, [int mat = Material3.paint]) =>
      m.roundedBox(p, size, .022, color, mat);
  void front(double x, double y, double w, double h, [int color = white]) =>
      box(V3(x, y, l + .03), V3(w, h, .04), color, Material3.glow);
  void rear(double x, double y, double w, double h, [int color = red]) =>
      box(V3(x, y, -l - .03), V3(w, h, .04), color, Material3.glow);
  void lamp(double x, double y, double z, double radius, int color) =>
      m.cylinder(
        V3(x, y, z),
        const V3(0, 0, 1),
        .04,
        radius,
        radius,
        color,
        Material3.glow,
        segments: 20,
      );
  void grille(double x, double y, double w, double h, {bool vertical = false}) {
    box(V3(x, y, l + .025), V3(w, h, .045), dark, Material3.rubber);
    if (vertical) {
      for (var i = 0; i < 9; i++)
        box(
          V3(x - w * .43 + i * w * .86 / 8, y, l + .055),
          V3(.035, h * .86, .018),
          0xff82929b,
          Material3.metal,
        );
    } else {
      for (var i = 0; i < 3; i++)
        box(
          V3(x, y - h * .32 + i * h * .32, l + .055),
          V3(w * .94, .012, .018),
          0xff42545c,
          Material3.metal,
        );
    }
  }

  void wing(double y, double width, double depth) {
    for (final side in [-1.0, 1.0])
      box(
        V3(side * 1.05, (y + d.belt) / 2, -l + .43),
        V3(.10, y - d.belt, .18),
        a,
      );
    box(V3(0, y, -l + .43), V3(width, .11, depth), c);
  }

  void vents(double x, double z, int count, {double width = .42}) {
    for (var i = 0; i < count; i++)
      box(
        V3(x, d.belt + .025, z + i * .13),
        V3(width, .035, .055),
        dark,
        Material3.rubber,
      );
  }

  void stripes(double width, double spacing, int color) {
    for (final side in [-1.0, 1.0]) {
      box(
        V3(side * spacing, d.belt + .025, (l + d.glassFront) / 2),
        V3(width, .035, l - d.glassFront - .20),
        color,
      );
      box(
        V3(side * spacing, d.roof + .045, (d.roofFront + d.roofRear) / 2),
        V3(width, .04, d.roofFront - d.roofRear),
        color,
      );
      box(
        V3(side * spacing, d.belt + .025, (-l + d.glassRear) / 2),
        V3(width, .035, l + d.glassRear - .05),
        color,
      );
    }
  }

  switch (car.body) {
    case 16: // AE86 panda, rectangular pop-ups and black lower panels.
      grille(0, .83, 1.35, .18);
      for (final s in [-1.0, 1.0]) {
        box(V3(s * .96, 1.48, l - .52), const V3(.60, .38, .44), c);
        box(
          V3(s * .96, 1.48, l - .28),
          const V3(.48, .22, .035),
          white,
          Material3.glow,
        );
        front(s * 1.18, .97, .30, .11, 0xffffa93a);
        rear(s * .94, 1.14, .83, .23);
        box(V3(s * (d.halfWidth + .01), .78, 0), V3(.055, .43, l * 1.87), a);
      }
      box(V3(0, .66, l), const V3(2.81, .23, .16), a);
      box(V3(0, 1.48, -l + .20), const V3(2.77, .09, .32), a);
    case 17: // RX-8 rotary-themed fender outlets and paired rear circles.
      grille(0, .70, 1.72, .31);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.07, 1.16, .82, .18);
        rear(s * 1.04, 1.11, .73, .26, dark);
        lamp(s * 1.05, 1.11, -l - .055, .17, red);
        m.triangle(
          V3(s * (d.halfWidth + .025), 1.22, 1.50),
          V3(s * (d.halfWidth + .025), .89, 1.15),
          V3(s * (d.halfWidth + .025), 1.24, .97),
          a,
          Material3.rubber,
        );
      }
      wing(1.66, 2.9, .28);
    case 18:
      grille(0, .64, 1.68, .26);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.02, 1.10, .73, .16);
        rear(s * 1.04, 1.08, .69, .19);
        lamp(s * 1.16, 1.08, -l - .06, .105, red);
        box(
          V3(s * (d.halfWidth + .018), .98, 1.24),
          const V3(.025, .18, .28),
          a,
        );
      }
      wing(1.47, 2.73, .23);
    case 19: // Z34 boomerang lamps.
      grille(0, .64, 1.70, .31);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.15, 1.07, .52, .15);
        box(
          V3(s * 1.30, 1.23, l - .35),
          const V3(.12, .10, .72),
          white,
          Material3.glow,
        );
        rear(s * 1.15, 1.03, .52, .13);
        box(
          V3(s * 1.30, 1.17, -l + .32),
          const V3(.12, .12, .65),
          red,
          Material3.glow,
        );
      }
      wing(1.55, 2.93, .35);
    case 20:
      grille(0, .62, 1.75, .33);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.12, 1.09, .79, .16, dark);
        for (var i = 0; i < 3; i++) front(s * (.87 + i * .19), 1.11, .12, .075);
        rear(s * 1.13, 1.04, .83, .075);
        box(V3(s * .50, d.roof + .045, -.40), const V3(.52, .06, .74), c);
        vents(s * 1.14, 1.73, 4);
      }
      wing(1.54, 3.15, .31);
    case 21:
      grille(0, .81, 2.15, .55);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.03, 1.35, .70, .18);
        rear(s * 1.10, 1.30, .56, .24);
        rear(s * 1.33, 1.17, .10, .27);
      }
      box(V3(0, 2.43, -2.27), const V3(2.81, .13, .45), a);
      box(V3(0, d.roof + .02, -.32), const V3(1.98, .04, 1.45), a);
    case 22:
      grille(0, .65, 1.58, .26);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.12, 1.12, .77, .16);
        rear(s * 1.07, 1.08, .81, .19);
        vents(s * .77, 1.72, 4, width: .48);
      }
      rear(0, 1.08, .72, .13);
      wing(2.12, 3.06, .41);
    case 23:
      for (final s in [-1.0, 1.0]) {
        grille(s * .18, 1.19, .25, .23, vertical: true);
        for (var i = 0; i < 2; i++)
          lamp(s * (.80 + i * .38), 1.19, l + .045, .155, white);
        rear(s * .99, 1.15, .90, .25);
        box(V3(s * (d.halfWidth + .02), .86, 0), V3(.035, .11, l * 1.87), a);
      }
      grille(0, .65, 1.33, .20);
      wing(1.74, 3.05, .35);
    case 24:
      grille(0, .81, 1.83, .54);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.23, 1.11, .62, .11);
        front(s * 1.50, 1.04, .05, .17);
        rear(s * 1.19, .99, .78, .09);
        box(
          V3(s * (d.halfWidth + .025), .94, -1.08),
          const V3(.04, .64, .72),
          a,
        );
        grille(s * 1.24, .64, .52, .26);
      }
      vents(0, -2.56, 7, width: 1.45);
      wing(1.47, 3.17, .31);
    case 25:
      grille(0, .92, 1.82, .50, vertical: true);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.25, 1.15, .70, .14);
        rear(s * 1.21, 1.04, .90, .08);
        vents(s * .76, 1.46, 6);
        box(
          V3(s * (d.halfWidth + .018), 1.04, 1.14),
          const V3(.035, .24, .52),
          a,
        );
      }
      wing(2.03, 3.44, .52);
    case 26:
      grille(0, .61, 1.80, .28);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.22, 1.02, .68, .14);
        box(
          V3(s * 1.44, 1.14, l - .36),
          const V3(.10, .09, .65),
          white,
          Material3.glow,
        );
        for (var i = 0; i < 2; i++) rear(s * (.87 + i * .47), 1.02, .36, .20);
        vents(s * .48, 1.66, 5, width: .70);
      }
      for (var i = 0; i < 4; i++)
        lamp(-.43 + i * .29, .48, -l - .16, .105, 0xff9ca9b1);
      wing(1.56, 3.36, .39);
    case 27:
      grille(0, .65, 1.72, .34);
      stripes(.32, .37, a);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.19, 1.09, .72, .15);
        rear(s * 1.18, 1.03, .74, .13);
        for (var i = 0; i < 4; i++)
          box(
            V3(s * (d.halfWidth + .018), .97, .97 + i * .17),
            const V3(.04, .31, .055),
            dark,
          );
        m.cylinder(
          V3(s * (d.halfWidth + .10), .46, -.16),
          const V3(0, 0, 1),
          2.4,
          .13,
          .13,
          0xffa8b4bc,
          Material3.metal,
          segments: 16,
        );
      }
      wing(1.48, 3.12, .27);
    case 28:
      grille(0, .65, 1.90, .29);
      stripes(.29, .32, a);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.27, 1.02, .56, .18);
        lamp(s * 1.22, 1.00, -l - .05, .25, red);
        box(
          V3(s * (d.halfWidth + .024), .90, -.92),
          const V3(.04, .44, .69),
          dark,
        );
        vents(s * .54, -2.63, 7, width: .70);
      }
      wing(1.30, 3.33, .25);
    case 29:
      grille(0, .56, 1.58, .24);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.24, .95, .74, .33, dark);
        front(s * 1.20, 1.06, .51, .055);
        rear(s * 1.16, .98, .97, .065);
        box(
          V3(s * (d.halfWidth + .025), .81, -1.05),
          const V3(.035, .40, .83),
          dark,
        );
        vents(s * .60, -2.60, 6, width: .62);
      }
      wing(1.52, 3.40, .44);
    case 30:
      grille(0, .58, 1.52, .23);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.22, 1.00, .65, .29, dark);
        for (var i = 0; i < 2; i++) {
          lamp(s * (1.04 + i * .32), 1.02, l + .07, .11, white);
          lamp(s * (1.02 + i * .35), 1.01, -l - .05, .14, red);
        }
        box(
          V3(s * (d.halfWidth + .02), .78, -.95),
          const V3(.035, .44, .78),
          a,
        );
        vents(s * .55, -2.50, 6, width: .69);
      }
      for (final x in [-.15, .15])
        for (final y in [.75, 1.05]) lamp(x, y, -l - .13, .115, 0xff9faeb8);
      wing(2.06, 3.66, .63);
      box(V3(0, d.roof + .045, -.12), const V3(.53, .09, .90), a);
  }
}
