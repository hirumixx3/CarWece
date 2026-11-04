part of 'gpu_mesh.dart';

/// Separate body profiles and model-specific lamps, vents and wings.
/// Wheels are independent objects, centered at their axle, never baked in.
Mesh3 buildCarMesh(CarSpec car) {
  final m = Mesh3(), d = car.design, color = car.color;
  final kind = car.body, length = d.halfLength;
  final roundedCabin = kind == 10 || car.id == 'br_fusca';
  final rings = <List<V3>>[];
  const slices = 64, segments = 40;
  double widthAt(double z) {
    final t = z / length, end = t.abs();
    final taper = kind == 10
        ? .24
        : (d.sedan || d.hatch || [2, 9, 14, 16, 23].contains(kind))
        ? .10
        : .16;
    final axleBulge =
        math.exp(-math.pow((z - d.frontAxle) / .7, 2)) +
        math.exp(-math.pow((z - d.rearAxle) / .8, 2));
    return d.halfWidth * (1 - taper * math.pow(end, 7)) +
        axleBulge * (kind == 0 ? .085 : .035);
  }

  for (var j = 0; j <= slices; j++) {
    final z = -length + j / slices * length * 2, w = widthAt(z);
    final ring = <V3>[];
    final tip = math.pow((z / length).abs(), 8).toDouble();
    for (var i = 0; i < segments; i++) {
      final a = i / segments * math.pi * 2, c = math.cos(a), sn = math.sin(a);
      double round(double v) =>
          v.sign *
          math
              .pow(
                v.abs(),
                kind == 10
                    ? .78
                    : [11, 15, 24, 26, 28, 29, 30].contains(kind)
                    ? .48
                    : .67,
              )
              .toDouble();
      final hood = ((z - d.glassFront) / (length - d.glassFront)).clamp(
        0.0,
        1.0,
      );
      final roofOfBody =
          d.belt -
          .15 * tip -
          ([11, 15, 24, 26, 28, 29, 30].contains(kind)
              ? .13 * hood
              : .035 * hood);
      final crease =
          .035 *
          math.exp(-math.pow((c.abs() - .55) / .17, 2)) *
          (sn > 0 ? 1.0 : 0.0);
      ring.add(
        V3(
          round(c) * w,
          .81 + round(sn) * (sn > 0 ? roofOfBody - .81 : .43) + crease,
          z,
        ),
      );
    }
    rings.add(ring);
  }
  V3 normal(int j, int i) {
    final a = rings[(j - 1).clamp(0, slices)][i],
        b = rings[(j + 1).clamp(0, slices)][i],
        c = rings[j][(i + 1) % segments],
        e = rings[j][(i - 1) % segments];
    return (c - e).cross(b - a).unit;
  }

  for (var j = 0; j < slices; j++) {
    for (var i = 0; i < segments; i++) {
      final k = (i + 1) % segments;
      final center =
          (rings[j][i] + rings[j + 1][i] + rings[j][k] + rings[j + 1][k]) * .25;
      final dz = math.min(
        (center.z - d.frontAxle).abs(),
        (center.z - d.rearAxle).abs(),
      );
      final arch = d.wheelRadius + .10;
      // Actual cut-outs reveal the rolling tires and steering clearance.
      if (center.x.abs() > d.halfWidth * .73 &&
          dz < arch &&
          center.y < d.wheelRadius + math.sqrt(arch * arch - dz * dz))
        continue;
      m.quad(
        rings[j][i],
        rings[j + 1][i],
        rings[j + 1][k],
        rings[j][k],
        color,
        Material3.paint,
        na: normal(j, i),
        nb: normal(j + 1, i),
        nc: normal(j + 1, k),
        nd: normal(j, k),
      );
    }
  }
  for (final j in [0, slices]) {
    for (var i = 0; i < segments; i++) {
      m.triangle(
        V3(0, .80, rings[j][i].z),
        rings[j][i],
        rings[j][(i + 1) % segments],
        color,
        Material3.paint,
        na: V3(0, 0, j == 0 ? -1 : 1),
        nb: V3(0, 0, j == 0 ? -1 : 1),
        nc: V3(0, 0, j == 0 ? -1 : 1),
      );
    }
  }
  m.box(
    const V3(0, .37, 0),
    V3(d.halfWidth * 1.78, .15, length * 1.9),
    0xff17232d,
    Material3.rubber,
  );
  // Bonnet shut lines follow its curved shoulder, rather than a flat sticker.
  for (final side in [-1.0, 1.0]) {
    for (var j = 0; j < 18; j++) {
      final z0 = d.glassFront + .08 + j * (length - d.glassFront - .35) / 18;
      final z1 =
          d.glassFront + .08 + (j + 1) * (length - d.glassFront - .35) / 18;
      V3 edge(double z) => V3(
        side * (.69 + .16 * (z - d.glassFront)),
        d.belt - .15 * math.pow((z / length).abs(), 8) + .014,
        z,
      );
      final a = edge(z0), b = edge(z1);
      m.cylinder(
        (a + b) * .5,
        (b - a).unit,
        (b - a).length,
        .009,
        .009,
        0xff35404a,
        Material3.rubber,
        segments: 4,
      );
    }
    m.box(
      V3(side * d.halfWidth, .64, -length + .3),
      const V3(.035, .07, .19),
      0xffc53a2e,
      Material3.glow,
    );
  }
  // Curved glass/roof volume, with different cabin placement per real model.
  final side = d.halfWidth * .82, roofSide = d.halfWidth * .67;
  final roofColor = [0, 5, 12, 18, 21, 22, 26, 30].contains(kind)
      ? 0xff151e29
      : color;
  if (roundedCabin) _buildRounded911Cabin(m, car);
  if (!roundedCabin)
    for (var i = 0; i < 16; i++) {
      final t0 = -1 + i / 8, t1 = -1 + (i + 1) / 8;
      double crown(double t) => (kind == 10 ? .17 : .11) * (1 - t * t);
      V3 p(double t, bool top, double z) => V3(
        t * (top ? roofSide : side),
        top ? d.roof + crown(t) : d.belt + .018,
        z,
      );
      m.quad(
        p(t0, false, d.glassFront),
        p(t1, false, d.glassFront),
        p(t1, true, d.roofFront),
        p(t0, true, d.roofFront),
        0xff183248,
        Material3.glass,
      );
      m.quad(
        p(t0, true, d.roofFront),
        p(t1, true, d.roofFront),
        p(t1, true, d.roofRear),
        p(t0, true, d.roofRear),
        roofColor,
        Material3.paint,
      );
      m.quad(
        p(t0, true, d.roofRear),
        p(t1, true, d.roofRear),
        p(t1, false, d.glassRear),
        p(t0, false, d.glassRear),
        0xff163349,
        Material3.glass,
      );
    }
  for (final sign in [-1.0, 1.0]) {
    final x = sign * side, rx = sign * roofSide;
    if (!roundedCabin)
      m.quad(
        V3(x, d.belt + .025, d.glassFront),
        V3(rx, d.roof, d.roofFront),
        V3(rx, d.roof, d.roofRear),
        V3(x, d.belt + .025, d.glassRear),
        0xff193448,
        Material3.glass,
      );
    // A/C pillars and a B pillar: closed, visibly different roof silhouettes.
    void pillar(double z0, double z1) {
      final from = V3(x, d.belt + .04, z0),
          to = V3(rx, d.roof + .025, z1),
          v = to - from;
      m.cylinder(
        (from + to) * .5,
        v.unit,
        v.length,
        .055,
        .055,
        roofColor,
        Material3.paint,
        segments: 8,
      );
    }

    if (!roundedCabin) {
      pillar(d.glassFront, d.roofFront);
      pillar(d.glassRear, d.roofRear);
      pillar(d.sedan ? -.28 : -.72, d.sedan ? -.28 : -.72);
    }
    m.box(
      V3(x, d.belt + .05, (d.glassFront + d.glassRear) / 2),
      V3(.06, .06, d.glassFront - d.glassRear),
      color,
      Material3.paint,
    );
    m.roundedBox(
      V3(sign * (d.halfWidth + .09), d.belt + .17, .91),
      const V3(.35, .18, .39),
      .06,
      color,
      Material3.paint,
    );
    m.box(
      V3(sign * (d.halfWidth - .01), .48, -.02),
      const V3(.14, .17, 2.50),
      kind == 0 ? car.accent : color,
      Material3.paint,
    );
    for (final z in d.sedan ? [-1.1, .30] : [-.72]) {
      m.box(
        V3(sign * (d.halfWidth + .012), d.belt - .13, z),
        const V3(.045, .045, .28),
        0xffb9c5cc,
        Material3.metal,
      );
    }
    // Panel seams and brake calipers stay with the chassis while rims rotate.
    for (final z in d.sedan ? [-1.55, -.20] : [-1.48]) {
      m.box(
        V3(sign * d.halfWidth, .90, z),
        const V3(.018, .66, .018),
        0xff26303a,
        Material3.rubber,
      );
    }
    for (final z in [d.frontAxle, d.rearAxle]) {
      m.box(
        V3(sign * (d.wheelTrack + .10), d.wheelRadius, z + .33),
        const V3(.08, .32, .14),
        0xffd62a29,
        Material3.paint,
      );
      // A painted arch bridges the body shoulder to the tire's outer edge.
      // This is a closed fender surface, not a floating trim ring.
      for (var k = 0; k < 24; k++) {
        final a = k / 24 * math.pi,
            b = (k + 1) / 24 * math.pi,
            r = d.wheelRadius + .12;
        V3 arch(double v, double x) => V3(
          sign * x,
          d.wheelRadius + math.sin(v) * r + .025,
          z + math.cos(v) * r,
        );
        m.quad(
          arch(a, d.halfWidth - .30),
          arch(a, d.wheelTrack + .265),
          arch(b, d.wheelTrack + .265),
          arch(b, d.halfWidth - .30),
          color,
          Material3.paint,
          na: V3(0, math.sin(a), math.cos(a)),
          nb: V3(0, math.sin(a), math.cos(a)),
          nc: V3(0, math.sin(b), math.cos(b)),
          nd: V3(0, math.sin(b), math.cos(b)),
        );
        final inner = d.halfWidth - .30;
        m.quad(
          V3(sign * (inner - .20), d.belt - .12, z + math.cos(a) * r),
          arch(a, inner),
          arch(b, inner),
          V3(sign * (inner - .20), d.belt - .12, z + math.cos(b) * r),
          color,
          Material3.paint,
        );
      }
      // Thin sculpted fender lip around the wheel arch.
      for (var k = 0; k < 20; k++) {
        final a = k / 20 * math.pi,
            b = (k + 1) / 20 * math.pi,
            r = d.wheelRadius + .12;
        final p = V3(
              sign * (d.halfWidth + .022),
              d.wheelRadius + math.sin(a) * r,
              z + math.cos(a) * r,
            ),
            q = V3(
              sign * (d.halfWidth + .022),
              d.wheelRadius + math.sin(b) * r,
              z + math.cos(b) * r,
            );
        m.cylinder(
          (p + q) * .5,
          (q - p).unit,
          (q - p).length,
          .025,
          .025,
          color,
          Material3.paint,
          segments: 5,
        );
      }
    }
    // Tailpipe, dark inside, with metallic rolled tip.
    if (sign < 0 || kind == 3 || kind == 5) {
      m.cylinder(
        V3(sign * .98, .52, -length - .07),
        const V3(0, 0, 1),
        .25,
        .14,
        .14,
        0xffabb8c3,
        Material3.metal,
        segments: 18,
      );
      m.cylinder(
        V3(sign * .98, .52, -length - .20),
        const V3(0, 0, 1),
        .012,
        .108,
        .108,
        0xff101825,
        Material3.rubber,
        segments: 18,
      );
    }
  }
  void box(V3 c, V3 size, int col, [int mat = Material3.paint]) =>
      m.roundedBox(c, size, .025, col, mat);
  void front(double x, double y, double w, double h, [int col = 0xffe1efff]) =>
      box(V3(x, y, length + .015), V3(w, h, .04), col, Material3.glow);
  void rear(double x, double y, double w, double h, [int col = 0xffff332c]) =>
      box(V3(x, y, -length - .015), V3(w, h, .035), col, Material3.glow);
  void lamp(double x, double y, double z, double r, int col) => m.cylinder(
    V3(x, y, z),
    const V3(0, 0, 1),
    .04,
    r,
    r,
    col,
    Material3.glow,
    segments: 22,
  );
  void grille(double x, double y, double w, double h) {
    box(V3(x, y, length + .024), V3(w, h, .045), 0xff111b24, Material3.rubber);
    for (var i = 0; i < 7; i++)
      m.box(
        V3(x - w * .43 + i * w * .86 / 6, y, length + .05),
        V3(.016, h * .85, .015),
        0xff495766,
        Material3.metal,
      );
  }

  void wing(double height, double width, double depth, {bool curved = false}) {
    for (final x in [-1.08, 1.08])
      box(
        V3(x, (height + d.belt) / 2, -length + .52),
        V3(.10, height - d.belt, .17),
        kind == 0 ? car.accent : color,
      );
    if (curved) {
      for (var i = 0; i < 18; i++) {
        final a = -width / 2 + i * width / 18, b = a + width / 18;
        final y0 = height - .18 * math.pow(a / (width / 2), 2),
            y1 = height - .18 * math.pow(b / (width / 2), 2);
        m.quad(
          V3(a, y0, -length + .14),
          V3(b, y1, -length + .14),
          V3(b, y1, -length + .14 + depth),
          V3(a, y0, -length + .14 + depth),
          color,
          Material3.paint,
        );
      }
    } else
      box(
        V3(0, height, -length + .44),
        V3(width, .10, depth),
        kind == 0 ? car.accent : color,
      );
  }

  // Small plate recesses and front splitter preserve toy-car detailing.
  box(V3(0, .82, -length - .02), const V3(.65, .20, .026), 0xff1a2638);
  m.text(
    'CW',
    V3(-.25, .76, -length - .04),
    const V3(1, 0, 0),
    const V3(0, 1, 0),
    .035,
    0xffe5edf0,
  );
  box(
    V3(0, .41, length - .06),
    V3(d.halfWidth * 1.85, .08, .43),
    0xff1c2635,
    Material3.rubber,
  );
  switch (kind) {
    case 0: // VeilSide Fortune: wide nose, black side scallops, black center.
      grille(0, .69, 1.55, .29);
      for (final sign in [-1.0, 1.0]) {
        m.quad(
          V3(sign * .76, 1.21, length - .08),
          V3(sign * 1.43, 1.15, length - .14),
          V3(sign * 1.34, 1.36, length - .77),
          V3(sign * 1.03, 1.38, length - .92),
          0xff182734,
          Material3.glass,
        );
        for (var j = 0; j < 2; j++) {
          final axis = const V3(0, .53, .85).unit;
          m.cylinder(
            V3(sign * (.99 + j * .23), 1.25, length - .29 - j * .02),
            axis,
            .04,
            .105,
            .105,
            0xffe4f4ff,
            Material3.glow,
            segments: 20,
          );
        }
        m.quad(
          V3(sign * 1.80, .56, -2.6),
          V3(sign * 1.80, 1.23, -1.3),
          V3(sign * 1.79, 1.12, 1.65),
          V3(sign * 1.80, .58, 1.4),
          car.accent,
          Material3.paint,
        );
        rear(sign * .99, 1.03, .70, .16);
        grille(sign * 1.12, .70, .41, .24);
      }
      box(V3(0, d.belt + .01, 2.02), const V3(1.37, .025, 1.29), car.accent);
      wing(2.15, 3.50, .63);
    case 1: // Evo IX: hood vents, large central opening, tall rectangular wing.
      grille(0, .71, 1.44, .42);
      for (final sign in [-1.0, 1.0]) {
        front(sign * 1.06, 1.22, .73, .22);
        rear(sign * 1.09, 1.16, .75, .25);
        lamp(sign * 1.20, .64, length + .04, .14, 0xfff3dfbd);
        for (var k = 0; k < 4; k++)
          box(
            V3(sign * .66, d.belt + .02, 1.90 + k * .14),
            const V3(.46, .025, .07),
            0xff16232d,
            Material3.rubber,
          );
      }
      wing(2.50, 3.34, .56);
    case 2: // R34: angular lamps, twin grille, four round rear lights.
      grille(0, .73, 1.47, .29);
      grille(0, 1.16, .77, .17);
      for (final sign in [-1.0, 1.0]) {
        front(sign * 1.09, 1.19, .71, .24);
        box(
          V3(sign * 1.16, 1.18, length + .04),
          const V3(.028, .24, .025),
          0xff344557,
        );
        lamp(sign * .78, .98, -length - .03, .20, 0xffff2824);
        lamp(sign * 1.24, .98, -length - .03, .16, 0xffff3129);
      }
      wing(2.34, 3.28, .55);
    case 3: // 350Z: long swept headlamp clusters and boomerang tail shape.
      grille(0, .67, 1.38, .30);
      for (final sign in [-1.0, 1.0]) {
        m.quad(
          V3(sign * .89, 1.04, length + .015),
          V3(sign * 1.43, 1.13, length - .03),
          V3(sign * 1.35, 1.47, length - .66),
          V3(sign * 1.16, 1.49, length - .76),
          0xffd7eaff,
          Material3.glow,
        );
        m.triangle(
          V3(sign * .81, .95, -length - .025),
          V3(sign * 1.31, 1.04, -length - .025),
          V3(sign * 1.33, 1.27, -length + .60),
          0xffff3b32,
          Material3.glow,
        );
        box(
          V3(sign * d.halfWidth, d.belt - .12, .63),
          const V3(.035, .14, .26),
          0xffa2b2c1,
          Material3.metal,
        );
      }
    case 4: // Supra A80: four circular tail lights and a hoop-like high wing.
      grille(0, .65, 1.55, .35);
      for (final sign in [-1.0, 1.0]) {
        front(sign * 1.04, 1.11, .75, .22);
        for (var j = 0; j < 3; j++)
          lamp(sign * (.77 + j * .19), 1.11, length + .045, .088, 0xffe9f6fc);
        lamp(sign * .83, .98, -length - .025, .17, 0xffff332b);
        lamp(sign * 1.24, .98, -length - .025, .15, 0xffff4537);
      }
      wing(2.37, 3.42, .62, curved: true);
    case 5: // NA1: raised pop-up headlights, long black greenhouse, rear light bar.
      grille(0, .57, 1.52, .17);
      for (final sign in [-1.0, 1.0]) {
        box(
          V3(sign * 1.03, 1.34, length - .60),
          const V3(.62, .26, .44),
          color,
        );
        box(
          V3(sign * 1.03, 1.34, length - .36),
          const V3(.53, .16, .025),
          0xffe9eff4,
          Material3.glow,
        );
        m.quad(
          V3(sign * 1.77, .65, -1.0),
          V3(sign * 1.78, 1.15, -.95),
          V3(sign * 1.78, 1.15, -1.67),
          V3(sign * 1.77, .61, -1.53),
          0xff122431,
          Material3.rubber,
        );
      }
      rear(0, .92, 2.83, .18);
      wing(1.53, 3.22, .37);
    case 6: // Impreza 22B: hood scoop, gold wheels, rally wing and wide arches.
      grille(0, .71, 1.19, .34);
      box(V3(0, 1.62, 1.94), const V3(1.10, .26, .75), color);
      box(
        V3(0, 1.62, 2.33),
        const V3(.88, .16, .024),
        0xff122331,
        Material3.rubber,
      );
      for (final sign in [-1.0, 1.0]) {
        front(sign * 1.04, 1.18, .70, .25);
        rear(sign * 1.11, 1.10, .65, .24);
        lamp(sign * 1.24, .67, length + .04, .20, 0xffffe4a3);
      }
      wing(2.43, 3.30, .54);
    case 7: // EK9: upright hatch, short nose, red accents and roof spoiler.
      grille(0, .82, .83, .17);
      grille(0, .58, 1.13, .21);
      for (final sign in [-1.0, 1.0]) {
        front(sign * .99, 1.15, .69, .20);
        rear(sign * 1.18, 1.01, .27, .36);
      }
      box(V3(0, 2.21, -2.51), const V3(2.69, .11, .37), color);
      box(V3(0, .89, length + .05), const V3(.085, .08, .025), 0xffd62d38);
    case 8: // Silvia S15: swept eye-shaped lamps, slim grille, low rear wing.
      grille(0, .67, 1.50, .29);
      grille(0, 1.14, .75, .10);
      for (final side in [-1.0, 1.0]) {
        m.quad(
          V3(side * .74, 1.15, length + .03),
          V3(side * 1.42, 1.18, length - .08),
          V3(side * 1.29, 1.36, length - .42),
          V3(side * .88, 1.27, length - .16),
          0xffcbdce3,
          Material3.glass,
        );
        lamp(side * .98, 1.21, length + .045, .10, 0xffe8f3f4);
        lamp(side * 1.23, 1.23, length - .04, .08, 0xffe8f3f4);
        rear(side * 1.06, 1.05, .76, .20);
        lamp(side * 1.12, .62, length + .05, .11, 0xffe9dbc1);
      }
      wing(1.80, 3.12, .43);
    case 9: // BMW E46: twin kidneys, four headlamps, side gills, four exhausts.
      for (final side in [-1.0, 1.0]) {
        grille(side * .25, 1.14, .40, .24);
        front(side * 1.09, 1.18, .77, .27, 0xff263746);
        lamp(side * .90, 1.18, length + .05, .125, 0xffeff5ff);
        lamp(side * 1.26, 1.18, length + .05, .125, 0xffeff5ff);
        rear(side * 1.12, 1.11, .73, .28);
        for (var j = 0; j < 3; j++)
          box(
            V3(side * (d.halfWidth + .018), 1.23, 1.33 + j * .09),
            const V3(.03, .13, .04),
            0xff273c48,
            Material3.metal,
          );
        for (var j = 0; j < 2; j++)
          m.cylinder(
            V3(side * (.82 + j * .24), .50, -length - .19),
            const V3(0, 0, 1),
            .30,
            .10,
            .10,
            0xffaeb9c1,
            Material3.metal,
            segments: 16,
          );
      }
      grille(0, .65, 1.64, .23);
      box(V3(0, d.belt + .04, -length + .35), const V3(2.93, .07, .24), color);
    case 10: // 992 GT3 RS: oval lamps, fender vents, swan-neck wing, light bar.
      grille(0, .62, 1.4, .22);
      for (final side in [-1.0, 1.0]) {
        final axis = const V3(0, .40, .92).unit;
        m.cylinder(
          V3(side * 1.16, 1.25, length - .29),
          axis,
          .07,
          .31,
          .31,
          0xff283c46,
          Material3.glass,
          segments: 32,
        );
        for (final x in [-.09, .09])
          for (final y in [-.07, .07])
            m.cylinder(
              V3(side * 1.16 + x, 1.25 + y, length - .22),
              axis,
              .025,
              .055,
              .055,
              0xfff3f6ff,
              Material3.glow,
              segments: 12,
            );
        grille(side * 1.19, .65, .56, .25);
        for (var j = 0; j < 5; j++)
          box(
            V3(side * 1.27, d.belt + .055, 1.77 + j * .12),
            const V3(.50, .035, .045),
            car.accent,
          );
        for (var j = 0; j < 3; j++)
          box(
            V3(side * .63, d.belt + .05, 1.70 + j * .16),
            const V3(.38, .03, .07),
            car.accent,
          );
        box(
          V3(side * 1.03, 2.28, -length + .55),
          const V3(.12, 1.3, .17),
          car.accent,
        );
        box(
          V3(side * 1.7, 2.83, -length + .35),
          const V3(.06, .30, .74),
          car.accent,
        );
      }
      box(V3(0, 2.73, -length + .35), const V3(3.65, .10, .81), car.accent);
      rear(0, 1.03, 3.10, .075);
      for (var i = 0; i < 8; i++)
        box(
          V3(-.67 + i * .19, d.belt + .06, -2.45),
          const V3(.055, .04, .54),
          car.accent,
        );
    case 11: // Huracan Tecnica: wedge nose, Y signature lights and side intakes.
      grille(0, .59, 1.16, .20);
      for (final side in [-1.0, 1.0]) {
        final p = V3(side * 1.16, 1.05, length - .10);
        m.quad(
          p + V3(-.35, 0, .02),
          p + V3(.35, 0, .02),
          p + V3(.28, .23, -.57),
          p + V3(-.25, .23, -.57),
          0xff14262d,
          Material3.glass,
        );
        for (final v in [
          V3(side * .25, .11, -.22),
          V3(-side * .17, .14, -.28),
        ]) {
          m.cylinder(
            p + v * .5,
            (v).unit,
            v.length,
            .022,
            .022,
            0xffecf7ef,
            Material3.glow,
            segments: 6,
          );
        }
        rear(side * 1.07, .99, .84, .08);
        grille(side * 1.13, .58, .73, .26);
        m.quad(
          V3(side * (d.halfWidth + .025), .58, -1.45),
          V3(side * (d.halfWidth + .025), 1.04, -1.74),
          V3(side * (d.halfWidth + .025), 1.09, -.8),
          V3(side * (d.halfWidth + .025), .66, -.48),
          car.accent,
          Material3.rubber,
        );
        box(
          V3(side * 1.12, .43, -length + .02),
          const V3(.08, .25, .65),
          car.accent,
        );
      }
      for (var i = 0; i < 7; i++)
        box(
          V3(0, 1.18 + i * .048, -2.52 + i * .12),
          const V3(1.40, .03, .07),
          car.accent,
        );
      wing(1.54, 3.38, .43);
    case 12: // MX-5 NA: small hardtop, raised round pop-ups, oval tail clusters.
      grille(0, .62, 1.48, .22);
      for (final side in [-1.0, 1.0]) {
        box(V3(side * .96, 1.35, length - .57), const V3(.53, .35, .44), color);
        lamp(side * .96, 1.36, length - .32, .17, 0xffeef5ef);
        front(side * 1.13, .95, .35, .10, 0xffffc875);
        rear(side * .98, .99, .63, .26);
        lamp(side * 1.13, .99, -length - .04, .095, 0xffffae41);
      }
      box(V3(0, 1.20, -length + .25), const V3(2.25, .07, .22), color);
    case 13: // Mustang fastback: long striped bonnet and six separate rear bars.
      grille(0, .96, 1.85, .36);
      grille(0, .60, 1.58, .20);
      for (final side in [-1.0, 1.0]) {
        front(side * 1.28, 1.19, .58, .17);
        for (var i = 0; i < 3; i++) {
          rear(side * (.82 + i * .23), 1.10, .12, .40);
          front(side * (.99 + i * .15), 1.30, .035, .13);
        }
        box(
          V3(side * .39, d.belt + .025, 2.05),
          const V3(.34, .035, 1.85),
          car.accent,
        );
        box(
          V3(side * .39, d.roof + .06, -.40),
          const V3(.34, .04, .80),
          car.accent,
        );
        box(
          V3(side * .39, d.belt + .025, -2.91),
          const V3(.34, .035, .60),
          car.accent,
        );
        box(
          V3(side * .92, d.belt + .045, 1.89),
          const V3(.26, .03, .48),
          0xff26343c,
        );
      }
      wing(1.59, 3.02, .38);
    case 14: // R35: muscular shoulders, swept headlights, round tails, quad tips.
      grille(0, .76, 1.72, .43);
      for (final side in [-1.0, 1.0]) {
        front(side * 1.19, 1.20, .58, .23);
        box(
          V3(side * 1.37, 1.29, length - .32),
          const V3(.17, .08, .58),
          0xffedf6ff,
          Material3.glow,
        );
        lamp(side * .81, 1.06, -length - .04, .22, 0xffff332b);
        lamp(side * 1.30, 1.06, -length - .04, .18, 0xffff332b);
        grille(side * 1.22, .65, .49, .24);
        for (var i = 0; i < 2; i++) {
          m.cylinder(
            V3(side * (.93 + i * .28), .49, -length - .16),
            const V3(0, 0, 1),
            .25,
            .12,
            .12,
            0xff9da9b3,
            Material3.metal,
            segments: 18,
          );
        }
        box(
          V3(side * (d.halfWidth + .015), 1.20, 1.26),
          const V3(.04, .16, .28),
          car.accent,
        );
      }
      wing(2.11, 3.35, .52);
    case 15: // F40: low wedge, rectangular lamps, side ducts and integrated wing.
      grille(0, .59, 1.52, .23);
      for (final side in [-1.0, 1.0]) {
        front(side * 1.18, .93, .65, .22);
        box(
          V3(side * 1.10, d.belt + .015, 2.43),
          const V3(.63, .025, .62),
          color,
        );
        lamp(side * .83, .98, -length - .035, .17, 0xffff332b);
        lamp(side * 1.25, .98, -length - .035, .14, 0xffff8d30);
        box(
          V3(side * (d.halfWidth + .018), .91, -1.26),
          const V3(.04, .45, .80),
          car.accent,
        );
        box(
          V3(side * 1.69, 1.56, -length + .45),
          const V3(.14, .77, .80),
          color,
        );
        for (var i = 0; i < 3; i++) {
          box(
            V3(side * .62, d.belt + .03, 2.12 + i * .14),
            const V3(.33, .03, .055),
            car.accent,
          );
        }
      }
      box(V3(0, 1.95, -length + .45), const V3(3.48, .13, .80), color);
      for (var i = 0; i < 8; i++) {
        box(
          V3(0, 1.28 + i * .055, -2.65 + i * .13),
          const V3(1.75, .035, .065),
          car.accent,
        );
      }
    case >= 16:
      if (car.body >= 56) {
        buildBrazilCarDetails(m, car);
      } else if (car.body >= 31) {
        buildWorldCarDetails(m, car);
      } else {
        _buildExpansionDetails(m, car);
      }
  }
  _buildUniversalCarDetails(m, car);
  if (car.body >= 31) {
    final rounded = m.buffer;
    V3 value(int at) => V3(rounded[at], rounded[at + 1], rounded[at + 2]);
    for (var i = 0; i < rounded.length; i += 36) {
      final geometric = (value(i + 12) - value(i)).cross(
        value(i + 24) - value(i),
      );
      final normals = value(i + 3) + value(i + 15) + value(i + 27);
      if (geometric.dot(normals) < 0) {
        for (var j = 0; j < 12; j++) {
          final old = m.data[i + 12 + j];
          m.data[i + 12 + j] = m.data[i + 24 + j];
          m.data[i + 24 + j] = old;
        }
      }
    }
  }
  // Realism stance pass: slightly wider and lower above the beltline, so
  // the catalogue reads as scale sports cars instead of tall toy blocks.
  // Physics uses fixed driver dimensions and never reads this mesh, so
  // handling is untouched; normals are re-normalized after the scale.
  for (var i = 0; i < m.data.length; i += 12) {
    final y = m.data[i + 1];
    m.data[i] *= 1.035;
    if (y > .55) m.data[i + 1] = y - (y - .55) * .09;
    var nx = m.data[i + 3] / 1.035, ny = m.data[i + 4], nz = m.data[i + 5];
    if (y > .55) ny /= .91;
    final il = 1 / math.sqrt(nx * nx + ny * ny + nz * nz);
    m.data[i + 3] = nx * il;
    m.data[i + 4] = ny * il;
    m.data[i + 5] = nz * il;
  }
  return m;
}

/// Detailing shared by every roster car, sized from its own design so the
/// whole catalogue gains mirrors, skirts, aero lips and exhausts without
/// touching each authored detail builder. All parts stay inside the design
/// silhouette (plus a few centimetres) so physics proxies remain honest.
void _buildUniversalCarDetails(Mesh3 m, CarSpec car) {
  final d = car.design, l = d.halfLength, w = d.halfWidth;
  const dark = 0xff141a20, chrome = 0xffc9d2d8;
  void part(V3 p, V3 size, int color, [int material = Material3.rubber]) =>
      m.roundedBox(p, size, .02, color, material);
  for (final side in [-1.0, 1.0]) {
    // Mirror on a short stalk at the base of the glasshouse.
    part(
      V3(side * (w + .07), d.belt + .34, d.glassFront - .28),
      const V3(.17, .11, .24),
      dark,
      Material3.plastic,
    );
    // Rocker skirt between the axles.
    part(
      V3(side * (w - .03), .36, (d.frontAxle + d.rearAxle) / 2),
      V3(.09, .17, (d.frontAxle - d.rearAxle) * .82),
      dark,
    );
    // Twin exhaust tips under the rear valance.
    m.cylinder(
      V3(side * w * .48, .4, -l - .05),
      const V3(0, 0, 1),
      .22,
      .085,
      .095,
      chrome,
      Material3.metal,
      segments: 12,
    );
    // Door handle hint.
    part(
      V3(side * (w + .012), d.belt + .02, -.35),
      const V3(.025, .045, .3),
      dark,
      Material3.plastic,
    );
  }
  // Front splitter and rear diffuser lips.
  part(V3(0, .27, l - .18), V3(w * 1.66, .08, .52), dark);
  part(V3(0, .3, -l + .14), V3(w * 1.58, .1, .42), dark);
}

/// Rear-engine 911 greenhouse: compound curved profile and wraparound glass.
void _buildRounded911Cabin(Mesh3 m, CarSpec car) {
  final d = car.design;
  double h(double z) {
    final t = ((z - d.glassRear) / (d.glassFront - d.glassRear)).clamp(
      0.0,
      1.0,
    );
    return math.pow(math.sin(t * math.pi), .65).toDouble() *
        (d.roof - d.belt + .12);
  }

  V3 p(double z, double theta) => V3(
    math.sin(theta) * d.halfWidth * .81,
    d.belt + h(z) * math.cos(theta),
    z,
  );
  V3 n(double z, double theta) => (p(z, theta + .001) - p(z, theta - .001))
      .cross(p(z + .001, theta) - p(z - .001, theta))
      .unit;
  for (var j = 0; j < 48; j++)
    for (var i = 0; i < 32; i++) {
      final z0 = d.glassRear + j / 48 * (d.glassFront - d.glassRear),
          z1 = d.glassRear + (j + 1) / 48 * (d.glassFront - d.glassRear);
      final a = -math.pi / 2 + i / 32 * math.pi,
          b = -math.pi / 2 + (i + 1) / 32 * math.pi;
      final z = (z0 + z1) / 2, t = (a + b) / 2;
      final pillar =
          (z - d.roofFront).abs() < .065 ||
          (z - d.roofRear).abs() < .065 ||
          (z + .5).abs() < .035;
      final glass =
          !pillar && (z > d.roofFront || z < d.roofRear || t.abs() > .83);
      m.quad(
        p(z0, a),
        p(z1, a),
        p(z1, b),
        p(z0, b),
        glass ? 0xff183545 : car.color,
        glass ? Material3.glass : Material3.paint,
        na: n(z0, a),
        nb: n(z1, a),
        nc: n(z1, b),
        nd: n(z0, b),
      );
    }
}

/// Center at origin; outward face is +X, rolling axle is X.
Mesh3 buildWheelMesh(CarSpec car) {
  final m = Mesh3(), d = car.design, r = d.wheelRadius;
  const axis = V3(1, 0, 0), width = .47;
  m.cylinder(
    V3.zero,
    axis,
    width,
    r * .93,
    r * .93,
    0xff151c24,
    Material3.rubber,
    segments: 40,
  );
  for (final side in [-1.0, 1.0]) {
    m.cylinder(
      V3(side * .225, 0, 0),
      axis,
      .04,
      r * .92,
      r * .92,
      0xff202832,
      Material3.rubber,
      segments: 40,
    );
    m.cylinder(
      V3(side * .251, 0, 0),
      axis,
      .035,
      r * .77,
      r * .77,
      d.rimColor,
      Material3.metal,
      segments: 40,
    );
    m.cylinder(
      V3(side * .274, 0, 0),
      axis,
      .015,
      r * .67,
      r * .67,
      0xff18202b,
      Material3.rubber,
      segments: 36,
    );
    m.cylinder(
      V3(side * .281, 0, 0),
      axis,
      .014,
      r * .57,
      r * .57,
      0xff566273,
      Material3.metal,
      segments: 32,
    );
    for (var k = 0; k < d.spokes; k++) {
      final a = k / d.spokes * math.pi * 2,
          radial = V3(0, math.cos(a), math.sin(a));
      m.box(
        V3(side * .302, 0, 0) + radial * (r * .38),
        V3(.045, r * .60, .075),
        d.rimColor,
        Material3.metal,
        r: axis,
        u: radial,
        f: axis.cross(radial),
      );
    }
    m.cylinder(
      V3(side * .329, 0, 0),
      axis,
      .036,
      r * .18,
      r * .18,
      0xff6e7b86,
      Material3.metal,
      segments: 16,
    );
    // Uneven valve and sidewall lettering marks make wheel rotation observable.
    m.box(
      V3(side * .249, r * .81, 0),
      const V3(.02, .04, .16),
      0xffc6c5b6,
      Material3.decal,
    );
  }
  // Individual tread ribs; transformed with rolling rotation, not time alone.
  for (var i = 0; i < 36; i++) {
    final a = i / 36 * math.pi * 2, b = (i + .36) / 36 * math.pi * 2;
    V3 p(double x, double v) => V3(x, math.cos(v) * r, math.sin(v) * r);
    m.quad(
      p(-.17, a),
      p(.17, a + .022),
      p(.17, b + .022),
      p(-.17, b),
      i % 3 == 0 ? 0xff35404a : 0xff252e38,
      Material3.rubber,
      na: V3(0, math.cos(a), math.sin(a)),
      nb: V3(0, math.cos(a + .022), math.sin(a + .022)),
      nc: V3(0, math.cos(b + .022), math.sin(b + .022)),
      nd: V3(0, math.cos(b), math.sin(b)),
    );
  }
  return m;
}
