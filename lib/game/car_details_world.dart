part of 'gpu_mesh.dart';

/// Model-specific sculpted details over the shared CarWece toy-body pipeline.
/// Names identify real cars; all meshes are original stylized interpretations.
void buildWorldCarDetails(Mesh3 m, CarSpec car) {
  final d = car.design,
      l = d.halfLength,
      c = car.color,
      a = car.accent,
      w = d.halfWidth;
  const dark = 0xff1b2833,
      white = 0xffeaf5ed,
      red = 0xffff3d34,
      amber = 0xffffb957;
  void box(V3 p, V3 size, int color, [int mat = Material3.paint]) =>
      m.roundedBox(p, size, .018, color, mat);
  void front(
    double x,
    double y,
    double width,
    double height, [
    int color = white,
  ]) => box(V3(x, y, l + .035), V3(width, height, .04), color, Material3.glow);
  void rear(
    double x,
    double y,
    double width,
    double height, [
    int color = red,
  ]) => box(V3(x, y, -l - .035), V3(width, height, .04), color, Material3.glow);
  void lamp(double x, double y, bool back, double radius, int color) =>
      m.cylinder(
        V3(x, y, back ? -l - .065 : l + .065),
        const V3(0, 0, 1),
        .045,
        radius,
        radius,
        color,
        Material3.glow,
        segments: 18,
      );
  void grille(
    double x,
    double y,
    double width,
    double height, {
    bool vertical = false,
  }) {
    box(V3(x, y, l + .02), V3(width, height, .035), dark, Material3.rubber);
    for (var j = 0; j < (vertical ? 7 : 3); j++) {
      box(
        V3(
          x + (vertical ? (-.42 + j * .14) * width : 0),
          y + (vertical ? 0 : (j - 1) * height * .28),
          l + .045,
        ),
        vertical ? V3(.025, height * .88, .015) : V3(width * .92, .012, .015),
        0xff68757c,
        Material3.metal,
      );
    }
  }

  void wing(double height, {double depth = .38, double? width}) {
    for (final side in [-1.0, 1.0]) {
      box(
        V3(side * w * .62, (height + d.belt) / 2, -l + .4),
        V3(.09, height - d.belt, .14),
        a,
      );
    }
    box(V3(0, height, -l + .4), V3(width ?? w * 1.88, .11, depth), c);
  }

  void vent(double x, double z, int count, {double width = .48}) {
    for (var i = 0; i < count; i++) {
      box(
        V3(x, d.belt + .03, z + i * .14),
        V3(width, .03, .055),
        dark,
        Material3.rubber,
      );
    }
  }

  void sideIntake(double z, double height, double length) {
    for (final side in [-1.0, 1.0]) {
      box(
        V3(side * (w + .025), d.belt - .20, z),
        V3(.04, height, length),
        dark,
        Material3.rubber,
      );
    }
  }

  void popups({bool round = false}) {
    for (final side in [-1.0, 1.0]) {
      box(
        V3(side * w * .65, d.belt + .17, l - .46),
        const V3(.60, .33, .46),
        c,
      );
      if (round) {
        m.cylinder(
          V3(side * w * .65, d.belt + .18, l - .205),
          const V3(0, 0, 1),
          .035,
          .18,
          .18,
          white,
          Material3.glow,
          segments: 18,
        );
      } else {
        box(
          V3(side * w * .65, d.belt + .18, l - .205),
          const V3(.47, .19, .04),
          white,
          Material3.glow,
        );
      }
    }
  }

  // Recognizable profiles are authored per model, not recolored copies.
  switch (car.id) {
    case 'r32':
      grille(0, .79, 1.40, .27);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.05, 1.14, .86, .17);
        for (var j = 0; j < 2; j++)
          lamp(s * (.78 + j * .40), 1.10, true, j == 0 ? .22 : .17, red);
        front(s * 1.24, .67, .28, .12, amber);
      }
      wing(1.85, width: 2.91);
    case 'r33':
      grille(0, .77, 1.67, .31);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.12, 1.18, .79, .21);
        for (var j = 0; j < 2; j++)
          lamp(s * (.78 + j * .43), 1.13, true, .22 - j * .045, red);
        grille(s * 1.26, .65, .43, .23);
      }
      wing(2.04, depth: .43);
    case 's13':
      grille(0, .81, 1.22, .22);
      for (final s in [-1.0, 1.0]) {
        front(s * .97, 1.14, .92, .20);
        front(s * 1.31, .96, .23, .12, amber);
        rear(s * .95, 1.09, .92, .25);
      }
      wing(1.57, depth: .25);
    case '180sx':
      popups();
      grille(0, .66, 1.63, .30);
      for (final s in [-1.0, 1.0]) {
        for (var j = 0; j < 2; j++)
          lamp(s * (.77 + j * .38), 1.06, true, .15, red);
        front(s * 1.12, .99, .47, .09, amber);
      }
      wing(1.78, depth: .36);
    case '300zx':
      grille(0, .59, 1.74, .21);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.17, 1.06, .88, .16);
        rear(s * .94, 1.06, 1.04, .22);
        box(V3(s * .18, d.roof + .055, -.07), const V3(.06, .04, 1.36), dark);
      }
      rear(0, 1.04, .47, .08);
      wing(1.44, depth: .28);
    case '240z':
      grille(0, .74, 1.79, .30);
      for (final s in [-1.0, 1.0]) {
        lamp(s * 1.02, 1.13, false, .245, white);
        rear(s * .94, 1.08, .79, .23);
        front(s * 1.11, .71, .26, .10, amber);
      }
      vent(.64, 1.56, 6);
      vent(-.64, 1.56, 6);
      box(
        V3(0, .57, l + .04),
        const V3(2.64, .09, .14),
        0xffb6c4cc,
        Material3.metal,
      );
    case 'celica_gt4':
      grille(0, .66, 1.78, .31);
      for (final s in [-1.0, 1.0]) {
        lamp(s * .83, 1.13, false, .22, white);
        lamp(s * 1.25, 1.12, false, .16, white);
        rear(s * 1.04, 1.08, .87, .21);
      }
      box(V3(0, d.belt + .10, 1.73), const V3(.72, .18, .60), a);
      vent(.77, 1.42, 5);
      vent(-.77, 1.42, 5);
      wing(2.15, depth: .46);
    case 'mr2_sw20':
      popups();
      grille(0, .62, 1.66, .26);
      for (final s in [-1.0, 1.0]) {
        lamp(s * .88, 1.08, true, .19, red);
        lamp(s * 1.20, 1.08, true, .15, red);
      }
      sideIntake(-.92, .39, .63);
      vent(0, -2.30, 5, width: 1.45);
      wing(1.81, depth: .42);
    case 'integra_dc2':
      grille(0, .72, 1.36, .24);
      for (final s in [-1.0, 1.0]) {
        lamp(s * .78, 1.12, false, .16, white);
        lamp(s * 1.14, 1.12, false, .17, white);
        rear(s * 1.02, 1.12, .81, .26);
      }
      wing(2.03, depth: .41);
    case 'civic_fl5':
      grille(0, .83, 1.95, .42);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.19, 1.28, .83, .12);
        rear(s * 1.13, 1.30, .91, .10);
        rear(s * 1.48, 1.16, .10, .30);
        grille(s * 1.30, .61, .48, .25);
      }
      for (var j = 0; j < 3; j++)
        lamp((j - 1) * .26, .47, true, j == 1 ? .13 : .10, 0xffa9b5bf);
      vent(0, 1.72, 5, width: 1.02);
      wing(2.28, depth: .50);
    case 'wrx_sti04':
      grille(0, .88, 1.32, .28);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.10, 1.25, .74, .24);
        rear(s * 1.14, 1.25, .52, .36);
        lamp(s * 1.18, .66, false, .15, white);
      }
      box(V3(0, d.belt + .13, 1.75), const V3(1.08, .25, .66), c);
      box(V3(0, d.belt + .13, 2.10), const V3(.86, .14, .035), dark);
      wing(2.45, depth: .50);
    case 'evo6':
      grille(0, .80, 1.54, .35);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.08, 1.27, .75, .19);
        rear(s * 1.02, 1.22, .81, .27);
        lamp(s * 1.20, .65, false, .19, white);
        vent(s * .61, 1.50, 5);
      }
      wing(2.39, depth: .52);
    case 'bmw_m1':
      popups();
      for (final s in [-1.0, 1.0]) {
        grille(s * .19, .75, .28, .22, vertical: true);
        rear(s * 1.09, 1.01, .85, .23);
        front(s * 1.24, .77, .33, .12, amber);
      }
      vent(0, -2.30, 6, width: 1.52);
      sideIntake(-.86, .25, .65);
    case 'm4_g82':
      for (final s in [-1.0, 1.0]) {
        grille(s * .37, .88, .62, .73, vertical: true);
        front(s * 1.26, 1.20, .76, .16);
        for (var j = 0; j < 2; j++) front(s * (1.05 + j * .36), 1.13, .07, .13);
        rear(s * 1.18, 1.18, .94, .09);
      }
      vent(.65, 1.71, 4);
      vent(-.65, 1.71, 4);
      wing(1.67, depth: .26);
    case 'quattro':
      grille(0, 1.03, 1.58, .33);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.10, 1.24, .79, .24);
        rear(s * 1.06, 1.23, .78, .29);
        vent(s * .61, 1.55, 5);
        grille(s * 1.21, .69, .42, .20);
      }
      wing(2.23, depth: .48);
    case 'golf_gti':
      grille(0, 1.20, 2.36, .31);
      for (final s in [-1.0, 1.0]) {
        lamp(s * .98, 1.21, false, .21, white);
        rear(s * 1.02, 1.27, .52, .30);
        front(s * .99, .79, .26, .10, amber);
      }
      box(V3(0, 1.37, l + .06), const V3(2.32, .035, .045), red);
      box(V3(0, .71, l + .05), const V3(2.63, .18, .13), dark);
      box(V3(0, d.roof + .02, -2.19), const V3(2.40, .10, .25), a);
    case 'mini_cooper':
      grille(0, 1.03, 1.36, .53);
      for (final s in [-1.0, 1.0]) {
        lamp(s * .98, 1.28, false, .235, white);
        rear(s * 1.02, 1.26, .16, .46);
        box(V3(s * .31, d.belt + .03, 1.74), const V3(.19, .03, 1.02), a);
      }
      box(
        V3(0, d.roof + .08, (d.roofFront + d.roofRear) / 2),
        V3(w * 1.34, .045, d.roofFront - d.roofRear),
        a,
      );
      box(
        V3(0, .66, l + .05),
        const V3(2.46, .10, .14),
        0xffb9c5c9,
        Material3.metal,
      );
    case '205_t16':
      grille(0, 1.06, 1.25, .25);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.03, 1.30, .63, .25);
        rear(s * 1.17, 1.28, .30, .39);
        vent(s * .66, 1.51, 4);
      }
      sideIntake(-1.13, .54, .88);
      wing(2.30, depth: .40);
    case 'r5_turbo':
      grille(0, .98, 1.13, .31);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.05, 1.26, .62, .27);
        rear(s * 1.22, 1.28, .22, .48);
        box(V3(s * (w + .02), 1.26, -1.10), const V3(.045, .63, .73), a);
      }
      sideIntake(-1.03, .44, .72);
      vent(0, -2.35, 4, width: 1.23);
    case 'delta':
      grille(0, 1.11, 1.32, .31);
      for (final s in [-1.0, 1.0]) {
        lamp(s * .79, 1.29, false, .18, white);
        lamp(s * 1.18, 1.29, false, .19, white);
        rear(s * 1.12, 1.28, .48, .34);
        vent(s * .65, 1.60, 5);
      }
      box(V3(0, d.roof + .04, -2.20), const V3(2.81, .13, .43), a);
    case 'stratos':
      popups(round: true);
      grille(0, .62, 1.56, .25);
      for (final s in [-1.0, 1.0]) {
        lamp(s * .96, 1.01, true, .18, red);
        lamp(s * 1.16, .64, false, .15, amber);
      }
      for (var j = 0; j < 4; j++) lamp(-.54 + j * .36, .84, false, .145, white);
      vent(0, -2.26, 5, width: 1.44);
      wing(1.53, depth: .37);
    case 'alpine_a110':
      grille(0, .64, 1.51, .26);
      for (final s in [-1.0, 1.0]) {
        lamp(s * 1.05, 1.13, false, .22, white);
        lamp(s * .59, 1.05, false, .18, white);
        rear(s * 1.10, 1.06, .65, .10);
        rear(s * 1.28, .99, .08, .17);
      }
      sideIntake(-.98, .20, .39);
    case 'countach':
      popups();
      grille(0, .54, 1.39, .22);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.26, .78, .52, .13, amber);
        rear(s * 1.14, .94, .94, .18);
        box(V3(s * (w + .02), 1.20, -.72), const V3(.07, .52, .77), a);
        vent(s * .63, -2.43, 7, width: .76);
      }
      wing(2.04, depth: .62, width: 3.67);
    case 'testarossa':
      popups();
      grille(0, .54, 2.22, .25);
      for (final s in [-1.0, 1.0]) {
        front(s * 1.32, .86, .63, .13, amber);
        rear(s * 1.02, .99, 1.33, .25);
        for (var j = 0; j < 6; j++) {
          box(
            V3(s * (w + .03), .78 + j * .085, -.73),
            const V3(.055, .035, 1.48),
            c,
          );
        }
      }
      for (var j = 0; j < 5; j++)
        box(V3(0, .87 + j * .065, -l - .07), const V3(3.28, .028, .045), dark);
      vent(0, -2.47, 7, width: 1.57);
    case 'chiron':
      grille(0, .79, .58, .66, vertical: true);
      for (final s in [-1.0, 1.0]) {
        for (var j = 0; j < 4; j++) front(s * (.96 + j * .19), 1.10, .13, .08);
        grille(s * 1.20, .65, .74, .34);
        // C-shaped side intake surround is sculpted in three segments.
        box(
          V3(s * (w + .035), 1.14, -.97),
          const V3(.055, .75, .12),
          0xffbac7cc,
          Material3.metal,
        );
        box(
          V3(s * (w + .035), 1.48, -.59),
          const V3(.055, .10, .81),
          0xffbac7cc,
          Material3.metal,
        );
        box(
          V3(s * (w + .035), .80, -.59),
          const V3(.055, .10, .81),
          0xffbac7cc,
          Material3.metal,
        );
        vent(s * .60, -2.60, 6, width: .70);
      }
      rear(0, 1.01, 3.25, .065);
      wing(1.52, depth: .32);
  }
}
