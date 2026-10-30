part of 'gpu_mesh.dart';

void buildRoomProps(Mesh3 m, TrackSpec track) {
  void ellipsoid(
    V3 p,
    V3 radius,
    int color,
    int material, {
    int segments = 16,
  }) {
    V3 point(double a, double b) =>
        V3(
          math.cos(a) * math.sin(b) * radius.x,
          math.cos(b) * radius.y,
          math.sin(a) * math.sin(b) * radius.z,
        ) +
        p;
    V3 normal(V3 q) => V3(
      (q.x - p.x) / (radius.x * radius.x),
      (q.y - p.y) / (radius.y * radius.y),
      (q.z - p.z) / (radius.z * radius.z),
    ).unit;
    for (var i = 0; i < segments; i++)
      for (var j = 0; j < 10; j++) {
        final a = i / segments * math.pi * 2,
            b = (i + 1) / segments * math.pi * 2,
            c = j / 10 * math.pi,
            d = (j + 1) / 10 * math.pi;
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
          material,
          na: normal(p0),
          nb: normal(p1),
          nc: normal(p2),
          nd: normal(p3),
        );
      }
  }

  for (final prop in track.details) {
    final p = prop.center, s = prop.size, c = prop.color;
    V3 point(double x, double y, double z) => p + V3(x * s.x, y * s.y, z * s.z);
    void box(
      V3 at,
      V3 size,
      int color, [
      int material = Material3.wood,
      double radius = 1,
    ]) => m.roundedBox(at, size, radius, color, material);
    void cylinder(
      V3 at,
      V3 axis,
      double length,
      double r0,
      double r1,
      int color, [
      int material = Material3.metal,
    ]) => m.cylinder(at, axis, length, r0, r1, color, material, segments: 24);
    switch (prop.kind) {
      case 'plant':
        cylinder(
          point(0, -.33, 0),
          const V3(0, 1, 0),
          s.y * .34,
          s.x * .25,
          s.x * .34,
          0xffa37757,
          Material3.ceramic,
        );
        cylinder(
          point(0, -.15, 0),
          const V3(0, 1, 0),
          1,
          s.x * .30,
          s.x * .30,
          0xff433d2d,
          Material3.concrete,
        );
        for (var i = 0; i < 9; i++) {
          final a = i * 2.4, r = s.x * (.18 + (i % 3) * .055);
          final leaf = point(
            math.cos(a) * r / s.x,
            .03 + (i % 3) * .11,
            math.sin(a) * r / s.z,
          );
          final stem = leaf - point(0, -.12, 0);
          cylinder(
            (leaf + point(0, -.12, 0)) * .5,
            stem.unit,
            stem.length,
            .45,
            .25,
            0xff5f7046,
            Material3.wood,
          );
          ellipsoid(
            leaf,
            V3(s.x * .16, s.y * .20, s.z * .15),
            i.isEven ? c : 0xff698c55,
            Material3.fabric,
          );
        }
      case 'wardrobe':
      case 'dresser':
        box(p, s, c, Material3.wood, 2);
        final count = prop.kind == 'wardrobe' ? 3 : 4;
        for (var i = 0; i < count; i++) {
          if (prop.kind == 'wardrobe') {
            box(
              point(-.5 + (i + .5) / count, 0, -.508),
              V3(s.x / count - 3, s.y * .95, 2),
              c,
              Material3.wood,
              .5,
            );
            box(
              point(-.5 + (i + .75) / count, -.03, -.528),
              const V3(2, 15, 3),
              0xffaeb8b3,
              Material3.metal,
              .4,
            );
          } else {
            box(
              point(0, -.5 + (i + .5) / count, -.51),
              V3(s.x * .94, s.y / count - 3, 2),
              c,
              Material3.wood,
              .4,
            );
            box(
              point(0, -.5 + (i + .5) / count, -.53),
              V3(s.x * .22, 1.8, 3),
              0xffb9b9a6,
              Material3.metal,
              .4,
            );
          }
        }
      case 'basket':
        cylinder(
          point(0, -.05, 0),
          const V3(0, 1, 0),
          s.y * .9,
          s.x * .37,
          s.x * .46,
          c,
          Material3.fabric,
        );
        cylinder(
          point(0, .42, 0),
          const V3(0, 1, 0),
          2,
          s.x * .44,
          s.x * .44,
          0xff444c49,
          Material3.fabric,
        );
        for (var i = 0; i < 7; i++)
          cylinder(
            point(0, -.4 + i * .13, 0),
            const V3(0, 1, 0),
            1,
            s.x * (.38 + i * .012),
            s.x * (.38 + i * .012),
            0xffc5b698,
            Material3.fabric,
          );
        box(
          point(.05, .44, .07),
          V3(s.x * .5, s.y * .14, s.z * .45),
          0xff94adb0,
          Material3.fabric,
          3,
        );
      case 'ball':
        ellipsoid(p, s * .5, c, Material3.rubber, segments: 24);
        for (var i = 0; i < 4; i++) {
          final a = i / 4 * math.pi;
          for (var j = 0; j < 32; j++) {
            final b = j / 32 * math.pi * 2, d = (j + 1) / 32 * math.pi * 2;
            V3 q(double t) =>
                p +
                V3(
                  math.cos(t) * s.x * .502,
                  math.sin(t) * math.cos(a) * s.y * .502,
                  math.sin(t) * math.sin(a) * s.z * .502,
                );
            final v = q(d) - q(b);
            cylinder(
              (q(d) + q(b)) * .5,
              v.unit,
              v.length,
              .20,
              .20,
              0xff323d3b,
              Material3.rubber,
            );
          }
        }
      case 'shoe':
        box(
          point(0, -.35, 0),
          V3(s.x, s.y * .25, s.z),
          0xffe4dfce,
          Material3.rubber,
          3,
        );
        box(
          point(0, -.04, -.05),
          V3(s.x * .92, s.y * .55, s.z * .94),
          c,
          Material3.fabric,
          4,
        );
        for (var i = 0; i < 5; i++)
          box(
            point(0, .27, -.17 + i * .07),
            V3(s.x * .6, .7, 1.1),
            0xffefeee0,
            Material3.fabric,
            .2,
          );
      case 'shower':
        box(
          point(0, -.46, 0),
          V3(s.x, s.y * .08, s.z),
          0xffe0e9e3,
          Material3.ceramic,
          6,
        );
        for (final x in [-.48, .48])
          for (final z in [-.48, .48])
            cylinder(
              point(x, 0, z),
              const V3(0, 1, 0),
              s.y,
              1.8,
              1.8,
              0xffbecfd1,
            );
        box(
          point(0, 0, -.48),
          V3(s.x * .96, s.y * .94, 1.2),
          c,
          Material3.glass,
          .2,
        );
        box(
          point(.48, 0, 0),
          V3(1.2, s.y * .94, s.z * .96),
          c,
          Material3.glass,
          .2,
        );
        cylinder(point(0, .37, .43), const V3(0, 1, 0), 25, 7, 7, 0xffcbd7d7);
        cylinder(point(0, .32, .35), const V3(0, 0, 1), 25, 2, 2, 0xffbeced0);
      case 'shelf':
        if (s.y < 20) {
          box(p, s, c);
          break;
        }
        for (final x in [-.48, .48])
          box(point(x, 0, 0), V3(s.x * .04, s.y, s.z), c, Material3.metal);
        for (var i = 0; i < 4; i++) {
          box(
            point(0, -.45 + i * .30, 0),
            V3(s.x, s.y * .03, s.z),
            c,
            Material3.metal,
          );
          for (var j = 0; j < 3; j++)
            box(
              point(-.28 + j * .28, -.36 + i * .30, 0),
              V3(s.x * .22, s.y * .15, s.z * .55),
              [0xffa29b83, 0xff637e85, 0xff9e6855][j],
              Material3.plastic,
            );
        }
      case 'workbench':
        box(p, s, c, Material3.wood, 2);
        box(
          point(0, .48, 0),
          V3(s.x * 1.04, s.y * .06, s.z * 1.05),
          0xffc5b18a,
          Material3.wood,
        );
        for (var i = 0; i < 5; i++)
          box(
            point(-.32 + i * .16, 0, -.515),
            V3(s.x * .14, s.y * .83, 2),
            0xff667b7b,
            Material3.metal,
          );
      case 'billiards':
        box(
          point(0, .22, 0),
          V3(s.x, s.y * .22, s.z),
          0xff87634a,
          Material3.wood,
          5,
        );
        box(
          point(0, .34, 0),
          V3(s.x * .89, 2, s.z * .82),
          c,
          Material3.fabric,
          3,
        );
        for (final x in [-.36, .36])
          for (final z in [-.33, .33])
            box(point(x, -.14, z), V3(15, s.y * .72, 15), 0xff67513f);
        for (var i = 0; i < 7; i++)
          ellipsoid(
            point(-.23 + i * .07, .37, math.sin(i) * .2),
            const V3(2.6, 2.6, 2.6),
            [0xffdfc787, 0xffd6d6cf, 0xff9d4f46, 0xff4e7494][i % 4],
            Material3.paint,
          );
      case 'stool':
        cylinder(
          point(0, .39, 0),
          const V3(0, 1, 0),
          s.y * .2,
          s.x * .48,
          s.x * .48,
          c,
          Material3.fabric,
        );
        cylinder(
          point(0, -.05, 0),
          const V3(0, 1, 0),
          s.y * .75,
          3,
          3,
          0xffaab7b6,
        );
        cylinder(
          point(0, -.46, 0),
          const V3(0, 1, 0),
          s.y * .06,
          s.x * .43,
          s.x * .43,
          0xff8b999d,
        );
      case 'tire':
        cylinder(
          p,
          const V3(0, 1, 0),
          s.y,
          s.x * .49,
          s.x * .49,
          c,
          Material3.rubber,
        );
        cylinder(
          point(0, .505, 0),
          const V3(0, 1, 0),
          1,
          s.x * .31,
          s.x * .31,
          0xff67767e,
        );
        cylinder(
          point(0, .52, 0),
          const V3(0, 1, 0),
          1,
          s.x * .21,
          s.x * .21,
          0xff1d2932,
          Material3.rubber,
        );
      case 'speaker':
        box(p, s, c, Material3.plastic, 2);
        for (final y in [-.22, .22]) {
          cylinder(
            point(0, y, -.506),
            const V3(0, 0, 1),
            1,
            s.x * .34,
            s.x * .34,
            0xff17212a,
            Material3.rubber,
          );
          cylinder(
            point(0, y, -.521),
            const V3(0, 0, 1),
            1,
            s.x * .13,
            s.x * .13,
            0xff5c6f79,
          );
        }
      case 'bottle':
      case 'can':
        cylinder(
          p,
          const V3(0, 1, 0),
          s.y * .78,
          s.x * .46,
          s.x * .46,
          c,
          Material3.plastic,
        );
        cylinder(
          point(0, .43, 0),
          const V3(0, 1, 0),
          s.y * .15,
          s.x * .24,
          s.x * .24,
          0xffe3e1d2,
          Material3.plastic,
        );
        box(
          point(0, 0, -.46),
          V3(s.x * .6, s.y * .35, .4),
          0xffd8d5bd,
          Material3.decal,
          .1,
        );
      case 'curtain':
        for (var i = 0; i < 24; i++) {
          final z = -s.z * .5 + i * s.z / 24, z1 = z + s.z / 24;
          double wave(double z) => math.sin(z / s.z * math.pi * 12) * 2.3;
          m.quad(
            p + V3(wave(z), -s.y / 2, z),
            p + V3(wave(z1), -s.y / 2, z1),
            p + V3(wave(z1), s.y / 2, z1),
            p + V3(wave(z), s.y / 2, z),
            c,
            Material3.fabric,
          );
        }
      case 'door':
        box(p, s, c, Material3.wood, .3);
        for (final x in [-.52, .52])
          box(point(x, 0, .6), V3(3, s.y + 6, 4), 0xffcbb69a, Material3.wood);
        box(point(0, .52, .6), V3(s.x + 6, 3, 4), 0xffcbb69a);
        for (final y in [-.24, .24])
          box(point(0, y, .65), V3(s.x * .72, s.y * .36, 1), 0xff927252);
        ellipsoid(
          point(.34, -.03, 1.1),
          const V3(2, 2, 2),
          0xffbcbda5,
          Material3.metal,
        );
      case 'socket':
        box(p, s, c, Material3.plastic, .5);
        for (final x in [-.2, .2])
          box(
            point(x, 0, 1),
            const V3(.8, 3, .3),
            0xff46535a,
            Material3.rubber,
            .1,
          );
      case 'walllight':
        box(p, s, c, Material3.glow, 1);
        box(
          point(0, 0, .6),
          V3(s.x + 4, s.y + 3, 2),
          0xff7b8c8c,
          Material3.metal,
          .5,
        );
      case 'towel':
        box(p, s, c, Material3.fabric, 1);
        for (var i = 0; i < 8; i++)
          box(
            point(.7, -.44 + i * .01, 0),
            V3(.6, 1, s.z * .9),
            0xffb5a98b,
            Material3.fabric,
            .1,
          );
      case 'poster':
        box(p, s, c, Material3.paint, .1);
        final sign = p.z > 0 ? -1.0 : 1.0;
        box(
          point(0, .1, sign),
          V3(s.x * .88, s.y * .7, .3),
          0xff345466,
          Material3.decal,
          .1,
        );
        m.triangle(
          point(-.44, -.35, sign * 1.2),
          point(.10, .20, sign * 1.2),
          point(.42, -.35, sign * 1.2),
          0xff6c9e9e,
          Material3.decal,
        );
        for (final x in [-.5, .5])
          box(point(x, 0, 0), V3(3, s.y + 3, 3), 0xffc9b293);
      case 'clock':
        cylinder(p, const V3(0, 0, 1), 3, s.x * .5, s.x * .5, 0xff687875);
        cylinder(
          point(0, 0, 1),
          const V3(0, 0, 1),
          .5,
          s.x * .45,
          s.x * .45,
          c,
          Material3.decal,
        );
        box(
          point(.06, .08, 1.3),
          V3(2, s.y * .28, .4),
          0xff26363d,
          Material3.decal,
          .1,
        );
        box(
          point(-.08, 0, 1.4),
          V3(s.x * .34, 2, .4),
          0xff26363d,
          Material3.decal,
          .1,
        );
      case 'toolboard':
        box(p, s, c, Material3.wood, .1);
        for (var i = 0; i < 10; i++) {
          final x = -.43 + i * .095;
          box(
            point(x, -.05, -1),
            V3(2, s.y * .46, 2),
            0xffa8b4b9,
            Material3.metal,
            .3,
          );
          cylinder(
            point(x, -.32, -1.2),
            const V3(0, 0, 1),
            2,
            4,
            4,
            0xff899ca3,
          );
        }
      case 'shutter':
        box(p, s, c, Material3.metal, .1);
        for (var i = 0; i < 18; i++)
          box(
            point(0, -.47 + i * .055, 1),
            V3(s.x * .99, 1.3, 1),
            0xff4e5d66,
            Material3.metal,
            .2,
          );
    }
  }
}
