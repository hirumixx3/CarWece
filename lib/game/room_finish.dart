part of 'gpu_mesh.dart';

/// Small architectural details sit against existing walls and furniture; they
/// add scale without introducing obstacles into playable floor space.
void buildRoomFinish(Mesh3 m, TrackSpec track) {
  final tiled = track.tiled, night = track.night;
  final trim = tiled ? 0xffc6d2d0 : 0xffddcfb8;
  for (final side in [-1.0, 1.0]) {
    for (final y in [8.5, 213.0]) {
      m.box(
        V3(0, y, side * 876.5),
        const V3(1754, 1.1, 2.2),
        trim,
        Material3.paint,
      );
      m.box(
        V3(side * 876.5, y, 0),
        const V3(2.2, 1.1, 1754),
        trim,
        Material3.paint,
      );
    }
    // Recessed wall outlet and its mounting screws.
    for (final z in [-410.0, 430.0]) {
      m.roundedBox(
        V3(side * 875.7, 24, z),
        const V3(1.4, 9, 7),
        .6,
        0xffe1e3db,
        Material3.ceramic,
      );
      for (final dz in [-1.4, 1.4])
        m.box(
          V3(side * 874.8, 24, z + dz),
          const V3(.05, 2, .55),
          0xff26323b,
          Material3.rubber,
        );
      for (final y in [20.7, 27.3])
        m.cylinder(
          V3(side * 874.8, y, z),
          const V3(1, 0, 0),
          .08,
          .26,
          .26,
          0xff879292,
          Material3.metal,
          segments: 8,
        );
    }
  }
  // Panelled door, inset panels, brass hinges and a real handle.
  m.roundedBox(
    const V3(610, 88, -876),
    const V3(115, 176, 3),
    1.2,
    tiled ? 0xffd4ddda : 0xff836347,
    Material3.wood,
  );
  for (final x in [550.0, 670.0])
    m.box(V3(x, 89, -872), const V3(5, 181, 5), trim, Material3.paint);
  m.box(const V3(610, 180, -872), const V3(125, 6, 5), trim, Material3.paint);
  for (final y in [49.0, 128.0])
    m.roundedBox(
      V3(610, y, -873.7),
      const V3(85, 61, 1.2),
      1.5,
      tiled ? 0xffc6d0cc : 0xff72523d,
      Material3.wood,
    );
  m.cylinder(
    const V3(649, 84, -870),
    const V3(0, 0, 1),
    3,
    1.9,
    1.9,
    0xffb2a67e,
    Material3.metal,
    segments: 12,
  );
  m.box(
    const V3(642, 84, -867),
    const V3(16, 1.6, 2.3),
    0xffc6c4a5,
    Material3.metal,
  );
  for (final y in [28.0, 146.0])
    m.box(V3(553, y, -870), const V3(2, 7, 1.5), 0xffa69a76, Material3.metal);
  // Framed room-specific print: geometric art is authored here, not a texture.
  const palette = [
    0xffcd865a,
    0xff7ea2ad,
    0xffafb775,
    0xffb39a7d,
    0xff817eae,
    0xffab7399,
  ];
  final index = [
    'QUARTO',
    'GARAGEM',
    'BANHEIRO',
    'COZINHA',
    'SALA',
    'ARCADE',
  ].indexOf(track.room);
  final art = palette[math.max(0, index)];
  m.box(
    const V3(120, 135, -875.1),
    const V3(112, 70, 2),
    0xff463b36,
    Material3.wood,
  );
  m.box(
    const V3(120, 135, -873.9),
    const V3(102, 60, .3),
    0xffede2c9,
    Material3.fabric,
  );
  for (var i = 0; i < 7; i++)
    m.box(
      V3(84 + i * 12, 128 + math.sin(i * 1.4 + index) * 13, -873.6),
      V3(9, 18 + (i % 3) * 8, .1),
      i.isEven ? art : 0xff526b77,
      Material3.paint,
    );
  // Warm/cool wall fixtures add visible housing and diffusers, with no fog.
  for (final x in [-450.0, 380.0]) {
    m.box(V3(x, 184, -874), const V3(57, 12, 5), 0xff35424c, Material3.metal);
    m.roundedBox(
      V3(x, 183, -870.8),
      const V3(50, 6, 1.5),
      1.2,
      night ? 0xff68cbd4 : 0xffffe9bd,
      Material3.glow,
    );
  }
  // Window gaskets and curtain rods, avoiding the glass itself.
  for (final z in [-114.0, 44.0])
    m.box(V3(-870.5, 113, z), const V3(1, 97, 1), 0xff3f4a4c, Material3.rubber);
  if (!tiled && track.room != 'GARAGEM') {
    m.cylinder(
      const V3(-866, 173, -35),
      const V3(0, 0, 1),
      196,
      1,
      1,
      0xffa2a69c,
      Material3.metal,
      segments: 10,
    );
    for (final z in [-127.0, 57.0])
      for (var j = 0; j < 6; j++)
        m.cylinder(
          V3(-866 + j % 2 * 1.8, 116, z + (j - 2.5) * 3.0),
          const V3(0, 1, 0),
          108,
          2.6,
          2.6,
          j.isEven ? 0xffb4aca0 : 0xffc7beb1,
          Material3.fabric,
          segments: 8,
        );
  }
}
