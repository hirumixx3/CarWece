part of 'gpu_mesh.dart';

void buildCourseObjects(Mesh3 m, TrackSpec track) {
  for (var i = 0; i < track.barriers.length; i++) {
    final b = track.barriers[i], f = b.frame;
    void box(double x, double y, double z, V3 size, int color, int material) =>
        m.box(
          f.point(x, y) + f.forward * z,
          size,
          color,
          material,
          r: f.right,
          u: f.up,
          f: f.forward,
        );
    final colors = switch (b.kind) {
      'books' => [0xff85493d, 0xff416c7f, 0xffb29458, 0xff51736a],
      'crates' => [0xff967450, 0xffa78358, 0xff826c53],
      'towels' => [0xffa1b9bb, 0xffd3c9b1, 0xff719ba2],
      'cartons' => [0xffc1ad80, 0xff94a79a, 0xffa89c7b],
      _ => [0xff61798c, 0xff7a7065, 0xffb28d61],
    };
    final c = colors[i % colors.length];
    if (b.kind == 'books') {
      box(0, 6, 0, V3(5, 12, b.length), c, Material3.fabric);
      box(0, 6, 0, V3(4.4, 10.9, b.length - .5), 0xffdcd3ba, Material3.fabric);
      for (final side in [-1.0, 1.0])
        box(side * 2.35, 6, 0, V3(.3, 12, b.length), c, Material3.paint);
      box(0, 6, -b.length / 2 + .2, const V3(5, 12, .4), c, Material3.paint);
      box(
        0,
        8,
        -b.length / 2 - .025,
        const V3(3, .5, .08),
        0xffc9b682,
        Material3.decal,
      );
    } else if (b.kind == 'towels') {
      for (var j = 0; j < 4; j++)
        box(
          0,
          1.5 + j * 3,
          0,
          V3(5, 2.9, b.length),
          j.isEven ? c : 0xffc7d4c9,
          Material3.fabric,
        );
      box(0, .35, 0, V3(5, .7, b.length), 0xffa69d87, Material3.wood);
    } else if (b.kind == 'crates') {
      box(0, 6, 0, V3(5, 12, b.length), c, Material3.wood);
      for (final side in [-1.0, 1.0]) {
        box(
          side * 2.51,
          6,
          -b.length * .36,
          const V3(.12, 11, 1),
          0xff524e42,
          Material3.metal,
        );
        box(
          side * 2.51,
          6,
          b.length * .36,
          const V3(.12, 11, 1),
          0xff524e42,
          Material3.metal,
        );
      }
      for (final y in [2.0, 6.0, 10.0])
        box(
          0,
          y,
          -b.length / 2 - .03,
          const V3(5, .1, .08),
          0xff544733,
          Material3.wood,
        );
    } else {
      box(
        0,
        6,
        0,
        V3(5, 12, b.length),
        c,
        b.kind == 'cartons' ? Material3.fabric : Material3.plastic,
      );
      box(
        0,
        9,
        -b.length / 2 - .03,
        const V3(3.6, 2, .08),
        0xffd5d0b5,
        Material3.decal,
      );
      if (b.kind == 'dominoes')
        for (final y in [3.0, 8.5])
          for (final x in [-1.0, 1.0])
            box(
              x,
              y,
              -b.length / 2 - .1,
              const V3(.6, .6, .10),
              0xff273440,
              Material3.decal,
            );
    }
  }
  for (final path in track.shortcuts) {
    final g = path.gate;
    for (final side in [-1.0, 1.0]) {
      m.box(
        g.point(side * (path.width / 2 + 1), 6),
        const V3(1.4, 12, 2.6),
        0xffcd843c,
        Material3.wood,
        r: g.right,
        u: g.up,
        f: g.forward,
      );
    }
  }
}
