part of 'gpu_mesh.dart';

/// Decorative surfaces match the furniture proxies authored in TrackSpec.
void buildRoomDetails(Mesh3 m, TrackSpec track) {
  void box(
    V3 p,
    V3 size,
    int color, [
    int material = Material3.paint,
    double radius = 2,
  ]) => m.roundedBox(p, size, radius, color, material);
  void cyl(
    V3 p,
    double height,
    double r0,
    double r1,
    int color, [
    int material = Material3.metal,
  ]) => m.cylinder(
    p,
    const V3(0, 1, 0),
    height,
    r0,
    r1,
    color,
    material,
    segments: 32,
  );
  if (track.room == 'BANHEIRO') {
    // Tub rim, dark inner wall and a reflective shallow water surface.
    box(
      const V3(100, 32, 590),
      const V3(460, 64, 190),
      0xffeaf1e8,
      Material3.ceramic,
      24,
    );
    box(
      const V3(100, 64.6, 590),
      const V3(426, 2, 156),
      0xff688e9a,
      Material3.ceramic,
      22,
    );
    box(
      const V3(100, 65.9, 590),
      const V3(402, 1, 133),
      0xff54b6c7,
      Material3.glass,
      20,
    );
    for (final x in [-80.0, 280.0]) {
      box(V3(x, 11, 590), const V3(18, 22, 110), 0xffb9c4bf, Material3.metal);
    }
    cyl(const V3(270, 81, 660), 29, 3.5, 3.5, 0xffcad9df);
    m.cylinder(
      const V3(270, 95, 650),
      const V3(0, 0, 1),
      22,
      3.5,
      3.5,
      0xffcad9df,
      Material3.metal,
    );
    for (final x in [248.0, 290.0]) cyl(V3(x, 70, 660), 6, 5, 5, 0xffc3d3de);
    // Sink with porcelain bowl, chrome faucet and mirror attached to the wall.
    box(
      const V3(710, 48, 20),
      const V3(142, 96, 162),
      0xffe9f1e6,
      Material3.ceramic,
      14,
    );
    box(
      const V3(710, 97, 20),
      const V3(120, 2, 134),
      0xff779fac,
      Material3.ceramic,
      18,
    );
    box(
      const V3(710, 98.4, 20),
      const V3(98, 1, 110),
      0xffb8dce0,
      Material3.glass,
      16,
    );
    cyl(const V3(757, 111, 20), 30, 3.5, 3.5, 0xffd7e1df);
    m.cylinder(
      const V3(744, 125, 20),
      const V3(1, 0, 0),
      26,
      3.5,
      3.5,
      0xffd7e1df,
      Material3.metal,
    );
    box(
      const V3(873, 145, 20),
      const V3(2, 100, 176),
      0xffe1ebed,
      Material3.metal,
    );
    box(
      const V3(871, 145, 20),
      const V3(1, 88, 164),
      0xff7eacb8,
      Material3.glass,
    );
    // Toilet bowl and cistern; their union lies in the solid authored bounds.
    cyl(const V3(-710, 25, 212), 44, 25, 43, 0xffe6eee7, Material3.ceramic);
    cyl(const V3(-710, 48, 212), 4, 43, 43, 0xfff4f5e8, Material3.ceramic);
    cyl(const V3(-710, 50.4, 212), 1, 29, 29, 0xff628b96, Material3.glass);
    box(
      const V3(-710, 64, 251),
      const V3(80, 43, 25),
      0xffe2ede8,
      Material3.ceramic,
      6,
    );
    box(
      const V3(-710, 87, 251),
      const V3(81, 4, 27),
      0xffe9eee4,
      Material3.ceramic,
      3,
    );
    cyl(const V3(-688, 90, 251), 2, 3, 3, 0xffb9c9d0);
    // Soap bottles on the tub rim, towel bar and a drain flush with the floor.
    for (var i = 0; i < 4; i++) {
      cyl(
        V3(-50 + i * 32.0, 81, 662),
        28,
        7,
        6,
        [0xff47b8ad, 0xffecb96f, 0xff9b7ac7, 0xffee8d92][i],
        Material3.plastic,
      );
      cyl(V3(-50 + i * 32.0, 97, 662), 5, 4, 4, 0xffeee9da, Material3.plastic);
    }
    box(
      const V3(871, 105, -250),
      const V3(3, 60, 90),
      0xff70b9c3,
      Material3.fabric,
    );
    box(
      const V3(867, 138, -250),
      const V3(6, 3, 110),
      0xffb9d2d9,
      Material3.metal,
    );
    cyl(const V3(0, .04, -50), .07, 13, 13, 0xff697c89);
    for (var i = 0; i < 6; i++)
      box(
        V3(-9 + i * 3.6, .09, -50),
        const V3(1, .04, 18),
        0xff253e4c,
        Material3.rubber,
        .1,
      );
  } else if (track.room == 'COZINHA') {
    // Long counter with cupboards; the route passes in front of it.
    box(
      const V3(50, 58, 620),
      const V3(640, 116, 170),
      0xff4e8c8a,
      Material3.paint,
      3,
    );
    box(
      const V3(50, 119, 620),
      const V3(644, 4, 174),
      0xffe2dbbc,
      Material3.ceramic,
      2,
    );
    for (var i = 0; i < 6; i++) {
      box(
        V3(-211 + i * 104.0, 58, 533),
        const V3(96, 104, 2),
        0xff659b95,
        Material3.paint,
        1,
      );
      box(
        V3(-178 + i * 104.0, 64, 530),
        const V3(3, 18, 3),
        0xffc0d3d1,
        Material3.metal,
        .5,
      );
    }
    // Stove rings and a pot on top.
    box(
      const V3(-735, 55, 50),
      const V3(150, 110, 220),
      0xffd5dddc,
      Material3.metal,
      3,
    );
    box(
      const V3(-657, 52, 50),
      const V3(3, 62, 140),
      0xff1d3241,
      Material3.glass,
      3,
    );
    for (final z in [-10.0, 110.0])
      for (final x in [-768.0, -700.0]) {
        cyl(V3(x, 112, z), 2, 20, 20, 0xff29333c, Material3.rubber);
        cyl(V3(x, 113.4, z), 1, 14, 14, 0xff78818b);
      }
    cyl(const V3(-700, 129, -10), 29, 19, 19, 0xff9eabb8);
    cyl(const V3(-700, 145, -10), 3, 22, 22, 0xffe1e5d8);
    cyl(const V3(-700, 148, -10), 5, 4, 4, 0xff182937, Material3.plastic);
    // Fridge with two doors, seal, handles and geometric magnets.
    box(
      const V3(735, 135, 30),
      const V3(140, 270, 160),
      0xffc5d4d5,
      Material3.metal,
      5,
    );
    box(
      const V3(663, 190, 30),
      const V3(3, 143, 153),
      0xffdde5df,
      Material3.metal,
      3,
    );
    box(
      const V3(663, 60, 30),
      const V3(3, 112, 153),
      0xffd9e1db,
      Material3.metal,
      3,
    );
    box(
      const V3(659, 152, 90),
      const V3(7, 48, 4),
      0xff6a7c88,
      Material3.metal,
    );
    box(const V3(659, 80, 90), const V3(7, 40, 4), 0xff6a7c88, Material3.metal);
    for (var i = 0; i < 4; i++)
      box(
        V3(660, 210 - i * 22.0, 10 + i % 2 * 25.0),
        const V3(2, 12, 12),
        [0xfff1a44d, 0xff4baab2, 0xffcf5a56, 0xff566fbb][i],
        Material3.plastic,
      );
    // Cup, cutting board and kettle are fixed to the counter top.
    box(
      const V3(80, 123, 620),
      const V3(100, 4, 62),
      0xffb98c56,
      Material3.wood,
      4,
    );
    cyl(const V3(190, 138, 620), 32, 12, 12, 0xffecd7b1, Material3.ceramic);
    cyl(const V3(190, 155, 620), 1, 9, 9, 0xff694b37, Material3.rubber);
    cyl(const V3(-150, 143, 620), 42, 23, 15, 0xffa6bec5);
    cyl(const V3(-150, 165, 620), 3, 17, 17, 0xff315369, Material3.plastic);
  } else if (track.room == 'SALA') {
    // Upholstered sofa and cushions.
    box(
      const V3(60, 40, 630),
      const V3(500, 80, 160),
      0xff356d7b,
      Material3.fabric,
      15,
    );
    box(
      const V3(60, 88, 690),
      const V3(500, 24, 37),
      0xff2e6171,
      Material3.fabric,
      9,
    );
    for (final x in [-170.0, 290.0])
      box(
        V3(x, 76, 630),
        const V3(38, 48, 160),
        0xff2d5f70,
        Material3.fabric,
        10,
      );
    for (var i = 0; i < 3; i++)
      box(
        V3(-85 + i * 145.0, 82, 615),
        const V3(135, 10, 118),
        0xff4e8b93,
        Material3.fabric,
        9,
      );
    box(
      const V3(-106, 100, 665),
      const V3(65, 45, 24),
      0xffdeb46f,
      Material3.fabric,
      7,
    );
    // Coffee table: only legs obstruct floor travel, top can be driven under.
    box(
      const V3(-380, 65, 40),
      const V3(204, 6, 125),
      0xffb68654,
      Material3.wood,
      5,
    );
    for (final x in [-465.0, -295.0])
      for (final z in [-5.0, 85.0])
        box(V3(x, 32, z), const V3(7, 64, 7), 0xff795235, Material3.wood, 1);
    for (var i = 0; i < 3; i++)
      box(
        V3(-392, 71 + i * 4.0, 25),
        V3(65 - i * 3.0, 4, 40),
        [0xffc36d54, 0xffd6bf81, 0xff557e9c][i],
        Material3.paint,
        1,
      );
    // TV stand shares solid bounds with its proxy; screen faces the circuit.
    box(
      const V3(740, 37, 20),
      const V3(120, 74, 320),
      0xff805b40,
      Material3.wood,
      3,
    );
    box(
      const V3(740, 90, 20),
      const V3(115, 20, 310),
      0xff343e4a,
      Material3.paint,
      2,
    );
    box(
      const V3(741, 173, 20),
      const V3(5, 138, 250),
      0xff172c3c,
      Material3.metal,
      2,
    );
    box(
      const V3(737, 173, 20),
      const V3(1, 125, 237),
      0xff294b6e,
      Material3.glass,
      .5,
    );
    // Original abstract TV scene: sky, mountains and a sun made with geometry.
    box(
      const V3(736, 194, -15),
      const V3(.3, 65, 150),
      0xff367a97,
      Material3.glow,
      .1,
    );
  }
}
