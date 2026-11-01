part of 'gpu_mesh.dart';

/// Authored toy-diorama geometry: no downloaded textures or external models.
void buildExpansionWorld(Mesh3 m, TrackSpec t) {
  m.box(
    const V3(0, -1, 0),
    const V3(1800, 2, 1800),
    t.floor,
    Material3.plastic,
  );
  // A low diorama rim is outside the playable 870-unit physical boundary.
  for (final side in [-1.0, 1.0]) {
    m.box(
      V3(side * 883, 10, 0),
      const V3(8, 20, 1774),
      t.wall,
      Material3.plastic,
    );
    m.box(
      V3(0, 10, side * 883),
      const V3(1774, 20, 8),
      t.wall,
      Material3.plastic,
    );
  }
  // Distant scenery is decorative, beyond the playable boundary.
  for (var i = 0; i < 20; i++) {
    final a = i * math.pi * 2 / 20,
        p = V3(math.cos(a) * 1070, 44, math.sin(a) * 1070);
    m.cylinder(
      p,
      const V3(0, 1, 0),
      88 + (i % 3) * 18.0,
      150,
      18,
      t.room == 'NEVE'
          ? 0xffe8f1f5
          : t.room == 'DESERTO'
          ? 0xffba8c5f
          : 0xff6d8b73,
      Material3.plastic,
      segments: 10,
    );
  }
  if (t.room == 'LITORAL') {
    // Sea remains outside the collision rim; no invisible drivable water.
    m.box(
      const V3(0, -2, 1100),
      const V3(2200, 2, 420),
      0xff4eacc4,
      Material3.plastic,
    );
    for (var j = 0; j < 7; j++) {
      m.box(
        V3(-800 + j * 250.0, -.85, 970 + (j % 3) * 20.0),
        const V3(130, .1, 3),
        0xffc3ebe9,
        Material3.paint,
      );
    }
  }
  for (final prop in t.details) buildExpansionPropMesh(m, prop);
}

void _worldEllipsoid(Mesh3 m, V3 p, V3 radius, int color, {int segments = 12}) {
  V3 point(double a, double b) =>
      p +
      V3(
        math.cos(a) * math.sin(b) * radius.x,
        math.cos(b) * radius.y,
        math.sin(a) * math.sin(b) * radius.z,
      );
  V3 normal(V3 q) => V3(
    (q.x - p.x) / (radius.x * radius.x),
    (q.y - p.y) / (radius.y * radius.y),
    (q.z - p.z) / (radius.z * radius.z),
  ).unit;
  for (var i = 0; i < segments; i++) {
    for (var j = 0; j < 8; j++) {
      final a = i / segments * math.pi * 2,
          b = (i + 1) / segments * math.pi * 2,
          c = j / 8 * math.pi,
          d = (j + 1) / 8 * math.pi;
      final p0 = point(a, c),
          p1 = point(b, c),
          p2 = point(b, d),
          p3 = point(a, d);
      m.quad(
        p0,
        p1,
        p2,
        p3,
        color,
        Material3.plastic,
        na: normal(p0),
        nb: normal(p1),
        nc: normal(p2),
        nd: normal(p3),
      );
    }
  }
}

void buildExpansionPropMesh(Mesh3 m, RoomProp prop) {
  final p = prop.center, s = prop.size, kind = prop.kind;
  V3 point(double x, double y, double z) => p + V3(x * s.x, y * s.y, z * s.z);
  void ball(
    double x,
    double y,
    double z,
    double rx,
    double ry,
    double rz,
    int c,
  ) => _worldEllipsoid(m, point(x, y, z), V3(rx * s.x, ry * s.y, rz * s.z), c);
  void beam(
    double x,
    double y,
    double z,
    double xx,
    double yy,
    double zz,
    double r0,
    double r1,
    int c,
  ) {
    final a = point(x, y, z), b = point(xx, yy, zz), v = b - a;
    m.cylinder(
      (a + b) * .5,
      v.unit,
      v.length,
      r0,
      r1,
      c,
      Material3.plastic,
      segments: 10,
    );
  }

  void cone(double y, double h, double r, int c) => m.cylinder(
    point(0, y, 0),
    const V3(0, 1, 0),
    s.y * h,
    s.x * r,
    0,
    c,
    Material3.plastic,
    segments: 12,
  );
  const bark = 0xff76533c,
      leaf = 0xff487a47,
      dark = 0xff24392c,
      ivory = 0xffe7d8ad;
  switch (kind) {
    case 'tree':
      beam(0, -.5, 0, 0, .18, 0, s.x * .10, s.x * .065, bark);
      for (final sign in [-1.0, 1.0]) {
        beam(0, -.02, 0, sign * .21, .26, .08, 3, 1.7, bark);
        ball(sign * .18, .22, .05, .29, .22, .31, leaf);
      }
      ball(0, .34, 0, .30, .15, .33, 0xff6e984e);
    case 'pine':
    case 'snowpine':
      beam(0, -.5, 0, 0, .28, 0, s.x * .08, s.x * .04, bark);
      for (var i = 0; i < 4; i++) {
        cone(-.10 + i * .14, .42 - i * .045, .46 - i * .085, leaf);
        if (kind == 'snowpine') {
          m.cylinder(
            point(0, -.05 + i * .14, 0),
            const V3(0, 1, 0),
            s.y * (.30 - i * .03),
            s.x * (.39 - i * .07),
            0,
            0xffe8f2f5,
            Material3.plastic,
            segments: 12,
          );
        }
      }
    case 'palm':
      beam(0, -.48, 0, .05, .30, 0, 4.4, 2.8, bark);
      for (var i = 0; i < 7; i++) {
        final a = i * math.pi * 2 / 7;
        final a0 = point(.05, .29, 0),
            tip = point(math.cos(a) * .46, .22, math.sin(a) * .46),
            side = V3(-math.sin(a) * s.x * .07, 0, math.cos(a) * s.z * .07);
        m.quad(
          a0,
          tip + side,
          tip + const V3(0, -4, 0),
          tip - side,
          i.isEven ? leaf : 0xff69924c,
          Material3.plastic,
        );
      }
      ball(.08, .26, .04, .06, .04, .06, 0xff8f7244);
    case 'fern':
      for (var i = 0; i < 9; i++) {
        final a = i * 2.399;
        beam(
          0,
          -.45,
          0,
          math.cos(a) * .40,
          .12,
          math.sin(a) * .40,
          .8,
          .35,
          leaf,
        );
        ball(math.cos(a) * .26, .0, math.sin(a) * .26, .16, .20, .14, leaf);
      }
    case 'log':
      m.cylinder(
        p,
        const V3(1, 0, 0),
        s.x * .96,
        s.y * .45,
        s.y * .45,
        bark,
        Material3.wood,
        segments: 12,
      );
      for (final side in [-1.0, 1.0]) {
        m.cylinder(
          point(side * .485, 0, 0),
          const V3(1, 0, 0),
          .25,
          s.y * .36,
          s.y * .36,
          ivory,
          Material3.wood,
          segments: 12,
        );
      }
    case 'rex':
    case 'triceratops':
    case 'sauropod':
      final tri = kind == 'triceratops', long = kind == 'sauropod';
      final c = tri
          ? 0xff9b925f
          : long
          ? 0xff68865f
          : 0xff698a50;
      ball(
        0,
        long
            ? -.25
            : tri
            ? -.04
            : -.08,
        -.04,
        .28,
        long ? .14 : .25,
        .27,
        c,
      );
      // Tail and rounded body never extend beyond the shared collision proxy.
      beam(0, -.08, -.16, 0, -.24, -.47, s.x * .13, .7, c);
      for (final side in [-1.0, 1.0]) {
        if (tri || long) {
          for (final z in [-.15, .12]) {
            beam(side * .18, -.20, z, side * .22, -.46, z, 4.5, 3.3, c);
            ball(side * .22, -.46, z, .07, .035, .075, dark);
          }
        } else {
          beam(side * .17, -.10, -.04, side * .25, -.40, .04, 5.8, 3.5, c);
          ball(side * .25, -.46, .09, .085, .04, .14, dark);
          beam(side * .19, .07, .13, side * .27, -.04, .24, 2.5, 1.3, c);
        }
      }
      if (long) {
        beam(0, -.18, .10, 0, .30, .27, 5.8, 3.9, c);
        ball(0, .37, .30, .11, .10, .13, c);
      } else if (tri) {
        ball(0, .06, .22, .41, .38, .065, c); // frill
        ball(0, -.01, .33, .22, .20, .16, c);
        for (final side in [-1.0, 1.0]) {
          beam(side * .12, .11, .35, side * .14, .26, .47, 2.4, 0, ivory);
        }
        beam(0, .03, .43, 0, .12, .49, 2.1, 0, ivory);
      } else {
        beam(0, .02, .11, 0, .20, .23, 6, 4.6, c);
        ball(0, .28, .28, .20, .16, .18, c);
        ball(0, .20, .31, .17, .045, .15, 0xffc0b785);
        for (final side in [-1.0, 1.0]) {
          for (var j = 0; j < 4; j++) {
            beam(
              side * .135,
              .21,
              .23 + j * .04,
              side * .135,
              .17,
              .23 + j * .04,
              1,
              0,
              ivory,
            );
          }
        }
      }
      for (final side in [-1.0, 1.0]) {
        ball(
          side *
              (long
                  ? .09
                  : tri
                  ? .17
                  : .16),
          long
              ? .39
              : tri
              ? .11
              : .32,
          long
              ? .34
              : tri
              ? .39
              : .35,
          .025,
          .022,
          .018,
          0xffffd57a,
        );
        ball(
          side *
              (long
                  ? .107
                  : tri
                  ? .192
                  : .182),
          long
              ? .39
              : tri
              ? .11
              : .32,
          long
              ? .35
              : tri
              ? .40
              : .36,
          .012,
          .013,
          .012,
          dark,
        );
      }
      if (!tri && !long) {
        for (var i = 0; i < 5; i++)
          ball(0, .11, -.23 + i * .07, .055, .08, .025, 0xff405d3b);
      }
    case 'eggs':
      ball(0, -.40, 0, .46, .09, .44, bark);
      for (var i = 0; i < 4; i++) {
        final a = i * 2.399;
        ball(math.cos(a) * .22, -.05, math.sin(a) * .20, .12, .40, .14, ivory);
      }
    case 'cactus':
      beam(0, -.47, 0, 0, .40, 0, 6, 5, 0xff53865c);
      ball(0, .40, 0, .12, .09, .16, 0xff53865c);
      for (final side in [-1.0, 1.0]) {
        beam(0, -.10, 0, side * .35, -.10, 0, 4, 4, leaf);
        beam(side * .35, -.10, 0, side * .35, .20, 0, 4, 3.5, leaf);
        ball(side * .35, .20, 0, .085, .05, .12, leaf);
      }
    case 'buoy':
      m.cylinder(
        point(0, -.28, 0),
        const V3(0, 1, 0),
        s.y * .42,
        s.x * .43,
        s.x * .26,
        0xffe8753f,
        Material3.plastic,
        segments: 14,
      );
      m.cylinder(
        point(0, .02, 0),
        const V3(0, 1, 0),
        s.y * .18,
        s.x * .26,
        s.x * .21,
        0xffebe4d0,
        Material3.plastic,
        segments: 14,
      );
      beam(0, .10, 0, 0, .45, 0, 1, 1, 0xff5c737d);
    case 'iceberg':
      m.cylinder(
        p,
        const V3(0, 1, 0),
        s.y * .96,
        s.x * .44,
        s.x * .12,
        0xffa9d5e7,
        Material3.plastic,
        segments: 7,
      );
    case 'shell':
      ball(0, -.12, 0, .46, .33, .44, 0xffe9d6b4);
      for (var i = 0; i < 5; i++) {
        beam(0, -.30, -.40, (i - 2) * .18, .12, .28, .7, .5, 0xffc1a886);
      }
    case 'snowrock':
      ball(0, -.10, 0, .47, .37, .46, 0xff8d9da6);
      ball(0, .09, 0, .44, .32, .42, 0xffeef7fa);
    default:
      final c = kind == 'sandrock' ? 0xffba8e5c : 0xff7b8071;
      ball(0, -.05, 0, .48, .44, .47, c);
      ball(-.17, .20, -.05, .27, .25, .28, c);
  }
}
