part of 'content.dart';

class RoomProp {
  final String kind;
  final V3 center, size;
  final int color;
  final bool solid;
  const RoomProp(
    this.kind,
    this.center,
    this.size,
    this.color, {
    this.solid = true,
  });
}

/// The renderer and physical scene use these exact same authored bounds.
void populateRoom(TrackSpec t) {
  void add(String kind, V3 p, V3 size, int color, {bool solid = true}) {
    if (solid) {
      for (final f in t.frames) {
        if (f.p.y > p.y + size.y / 2 + 6) continue;
        final margin = t.widthAt(f.s) / 2 + 14;
        if ((f.p.x - p.x).abs() < size.x / 2 + margin &&
            (f.p.z - p.z).abs() < size.z / 2 + margin)
          return;
      }
      // Avoid burying props inside the larger existing furniture.
      for (final o in t.obstacles.where((o) => !o.visible)) {
        if ((p.x - o.center.x).abs() < (size.x + o.size.x) / 2 + 2 &&
            (p.z - o.center.z).abs() < (size.z + o.size.z) / 2 + 2)
          return;
      }
      t.obstacles.add(WorldObstacle(p, size, color: color, visible: false));
    }
    t.details.add(RoomProp(kind, p, size, color, solid: solid));
  }

  // Raised wall details, door, sockets and curtains cannot block the race floor.
  add(
    'door',
    const V3(830, 90, -875),
    const V3(78, 180, 3),
    0xffa07b57,
    solid: false,
  );
  add(
    'curtain',
    const V3(-870, 120, -150),
    const V3(8, 120, 62),
    0xffafc8cd,
    solid: false,
  );
  add(
    'curtain',
    const V3(-870, 120, 80),
    const V3(8, 120, 62),
    0xffafc8cd,
    solid: false,
  );
  for (final x in [-600.0, -120.0, 420.0]) {
    add(
      'socket',
      V3(x, 16, -875),
      const V3(10, 12, 2),
      0xffe4e4da,
      solid: false,
    );
    add(
      'walllight',
      V3(x, 184, 874),
      const V3(24, 9, 8),
      0xffffe8bb,
      solid: false,
    );
  }
  for (final x in [-800.0, 800.0]) {
    for (final z in [-760.0, 740.0]) {
      add('plant', V3(x, 34, z), const V3(46, 68, 46), 0xff527451);
    }
  }
  switch (t.room) {
    case 'QUARTO':
      add(
        'wardrobe',
        const V3(-550, 103, 760),
        const V3(280, 206, 115),
        0xffbb986d,
      );
      add('dresser', const V3(580, 43, 680), const V3(150, 86, 85), 0xffb58b5d);
      add('basket', const V3(600, 22, 510), const V3(46, 44, 46), 0xffa69275);
      add('ball', const V3(410, 13, 620), const V3(26, 26, 26), 0xffbe533e);
      add('ball', const V3(-710, 10, 380), const V3(20, 20, 20), 0xff337fa2);
      add('shoe', const V3(650, 8, -400), const V3(21, 16, 44), 0xffc6b7a6);
      add('shoe', const V3(690, 8, -410), const V3(21, 16, 44), 0xffc6b7a6);
      add(
        'poster',
        const V3(240, 155, -875),
        const V3(140, 86, 2),
        0xffc46f42,
        solid: false,
      );
    case 'BANHEIRO':
      add(
        'shower',
        const V3(-570, 98, 700),
        const V3(178, 196, 180),
        0xff9ec8cd,
      );
      add('basket', const V3(550, 30, 690), const V3(62, 60, 62), 0xffb6b0a0);
      add(
        'dresser',
        const V3(810, 75, -390),
        const V3(90, 150, 150),
        0xffcbd8d5,
      );
      add(
        'towel',
        const V3(-875, 108, -230),
        const V3(4, 72, 100),
        0xffded5bd,
        solid: false,
      );
      add(
        'shelf',
        const V3(870, 135, 330),
        const V3(16, 12, 160),
        0xffa48a6e,
        solid: false,
      );
      for (var i = 0; i < 5; i++)
        add(
          'bottle',
          V3(859, 158, 275 + i * 25.0),
          const V3(10, 33, 10),
          [0xffabcad0, 0xffe3c6b9, 0xff547da0][i % 3],
          solid: false,
        );
    case 'GARAGEM':
      add(
        'workbench',
        const V3(-430, 55, 720),
        const V3(300, 110, 100),
        0xff8d785e,
      );
      add('shelf', const V3(795, 75, 630), const V3(90, 150, 180), 0xff637b86);
      add('can', const V3(-810, 23, -280), const V3(35, 46, 25), 0xffa94335);
      add('can', const V3(-810, 19, -335), const V3(30, 38, 24), 0xffd7b25e);
      add('tire', const V3(660, 21, 700), const V3(70, 42, 70), 0xff252b2f);
      add(
        'toolboard',
        const V3(-430, 158, 874),
        const V3(280, 100, 3),
        0xff8a7052,
        solid: false,
      );
      add(
        'shutter',
        const V3(0, 106, -875),
        const V3(570, 204, 3),
        0xff8d969a,
        solid: false,
      );
    case 'COZINHA':
      add(
        'dresser',
        const V3(-500, 60, 715),
        const V3(220, 120, 110),
        0xff68988b,
      );
      add('stool', const V3(420, 35, 690), const V3(54, 70, 54), 0xffb9946e);
      add('stool', const V3(510, 35, 690), const V3(54, 70, 54), 0xffb9946e);
      add('basket', const V3(-810, 28, 390), const V3(52, 56, 52), 0xffb5ad94);
      add(
        'shelf',
        const V3(120, 170, 872),
        const V3(420, 12, 25),
        0xffbd9a70,
        solid: false,
      );
      for (var i = 0; i < 6; i++)
        add(
          'bottle',
          V3(-50 + i * 65.0, 194, 865),
          const V3(16, 36, 16),
          [0xffaab47b, 0xffc4b890, 0xffb7c9c7][i % 3],
          solid: false,
        );
      add(
        'clock',
        const V3(500, 162, -875),
        const V3(65, 65, 2),
        0xffe1d7c4,
        solid: false,
      );
    case 'SALA':
      add(
        'dresser',
        const V3(-600, 35, 710),
        const V3(220, 70, 90),
        0xff896443,
      );
      add('speaker', const V3(820, 55, 330), const V3(42, 110, 50), 0xff303b43);
      add(
        'speaker',
        const V3(820, 55, -300),
        const V3(42, 110, 50),
        0xff303b43,
      );
      add('basket', const V3(440, 25, 740), const V3(56, 50, 56), 0xffb3a58f);
      add(
        'poster',
        const V3(-250, 150, 874),
        const V3(200, 100, 2),
        0xff6d9699,
        solid: false,
      );
      add(
        'clock',
        const V3(-450, 166, -875),
        const V3(70, 70, 2),
        0xffd5c0a2,
        solid: false,
      );
    case 'ARCADE':
      add(
        'billiards',
        const V3(-570, 55, 720),
        const V3(250, 110, 150),
        0xff305f64,
      );
      add(
        'speaker',
        const V3(810, 65, -400),
        const V3(60, 130, 65),
        0xff293141,
      );
      add(
        'speaker',
        const V3(-810, 65, 300),
        const V3(60, 130, 65),
        0xff293141,
      );
      add('stool', const V3(470, 35, 730), const V3(54, 70, 54), 0xffa54479);
      add(
        'poster',
        const V3(100, 152, -875),
        const V3(190, 90, 2),
        0xff7b53a6,
        solid: false,
      );
  }
}

/// Close trackside vignettes fill the room around the race, while leaving both
/// the main corridor and every alternate route physically clear.
void populateTrackside(TrackSpec t) {
  final choices = switch (t.room) {
    'QUARTO' => ['basket', 'shoe', 'ball', 'plant'],
    'GARAGEM' => ['tire', 'can', 'workbench', 'speaker'],
    'BANHEIRO' => ['bottle', 'basket', 'plant'],
    'COZINHA' => ['stool', 'bottle', 'basket'],
    'SALA' => ['plant', 'speaker', 'basket', 'dresser'],
    _ => ['speaker', 'stool', 'ball'],
  };
  var index = 0;
  for (var s = 80.0; s < t.length; s += 120) {
    if (!t.isFloor(s)) continue;
    final f = t.at(s);
    for (final side in [-1.0, 1.0]) {
      final kind = choices[index++ % choices.length];
      final size = switch (kind) {
        'workbench' => const V3(46, 42, 28),
        'dresser' => const V3(42, 30, 26),
        'speaker' => const V3(18, 42, 20),
        'shoe' => const V3(14, 10, 27),
        'ball' => const V3(18, 18, 18),
        'tire' => const V3(28, 17, 28),
        _ => const V3(22, 28, 22),
      };
      final raw = f.point(side * (t.widthAt(s) / 2 + 28 + size.x / 2));
      final p = V3(raw.x, size.y / 2, raw.z),
          r = math.max(size.x, size.z) * .72;
      if (p.x.abs() + r > 830 || p.z.abs() + r > 830) continue;
      if (t.frames.any(
        (f) =>
            f.p.y < p.y + size.y / 2 + 6 &&
            (f.p.x - p.x).abs() < size.x / 2 + t.widthAt(f.s) / 2 + 14 &&
            (f.p.z - p.z).abs() < size.z / 2 + t.widthAt(f.s) / 2 + 14,
      ))
        continue;
      final near = t.project(p);
      if (near.squaredDistance <
          math.pow(t.widthAt(near.frame.s) / 2 + r + 8, 2))
        continue;
      if (t.shortcuts.any(
        (s) => s.project(p).squaredDistance < math.pow(s.width / 2 + r + 10, 2),
      ))
        continue;
      if (t.obstacles.any(
        (o) =>
            (p.x - o.center.x).abs() < (size.x + o.size.x) / 2 + 5 &&
            (p.z - o.center.z).abs() < (size.z + o.size.z) / 2 + 5,
      ))
        continue;
      final color = [0xff9c8666, 0xff648b91, 0xff85936b, 0xffb18b63][index % 4];
      t.details.add(RoomProp(kind, p, size, color));
      t.obstacles.add(WorldObstacle(p, size, color: color, visible: false));
    }
  }
}
