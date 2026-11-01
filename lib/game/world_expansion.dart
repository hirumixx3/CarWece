part of 'content.dart';

/// Append-only expansion. Geometry, surfaces and collision proxies share bounds.
class ExpansionBiome {
  final int accent, floor, horizon;
  final String arena, tagline;
  final List<String> props;
  const ExpansionBiome(
    this.accent,
    this.floor,
    this.horizon,
    this.arena,
    this.tagline,
    this.props,
  );
}

const expansionBiomes = <String, ExpansionBiome>{
  'FLORESTA': ExpansionBiome(
    0xffa7da62,
    0xff5c7650,
    0xff8bb4ba,
    'CLAREIRA DO CONFRONTO',
    'Troncos, pinheiros e cobertura na clareira.',
    ['tree', 'pine', 'rock', 'log'],
  ),
  'PRÉ-HISTÓRIA': ExpansionBiome(
    0xffffb354,
    0xff8d8153,
    0xffb5c9ad,
    'VALE DOS TITÃS',
    'Miniaturas de dinossauros, ovos e rochas vulcânicas.',
    ['palm', 'fern', 'rock', 'rex', 'triceratops', 'sauropod', 'eggs'],
  ),
  'DESERTO': ExpansionBiome(
    0xfff1c679,
    0xffc6a36c,
    0xffc3d6db,
    'FORTALEZA DE AREIA',
    'Cactos e paredões em torno de um oásis de batalha.',
    ['cactus', 'sandrock', 'rock'],
  ),
  'NEVE': ExpansionBiome(
    0xff8edff1,
    0xffcbdfeb,
    0xffb8cedf,
    'BASTIÃO GLACIAL',
    'Pinheiros nevados, blocos de gelo e piso de baixa aderência.',
    ['snowpine', 'iceberg', 'snowrock'],
  ),
  'LITORAL': ExpansionBiome(
    0xff69e1df,
    0xffc9bc8d,
    0xffaad4e1,
    'BAÍA DOS TURBOS',
    'Palmeiras, boias e rochedos junto ao mar de brinquedo.',
    ['palm', 'rock', 'buoy', 'shell'],
  ),
};

const expansionCircuitStars = <String, int>{
  'forest_canopy': 0,
  'forest_roots': 4,
  'forest_river': 9,
  'forest_sawmill': 15,
  'forest_spiral': 24,
  'prehistoric_valley': 0,
  'prehistoric_eggs': 6,
  'prehistoric_fossils': 12,
  'prehistoric_volcano': 20,
  'prehistoric_loop': 29,
  'desert_oasis': 2,
  'desert_dunes': 8,
  'desert_canyon': 16,
  'desert_mirage': 24,
  'desert_sunloop': 34,
  'snow_pines': 3,
  'snow_glacier': 10,
  'snow_fjord': 18,
  'snow_avalanche': 27,
  'snow_polarloop': 39,
  'coast_bay': 1,
  'coast_lighthouse': 7,
  'coast_reef': 14,
  'coast_harbor': 22,
  'coast_tideloop': 32,
};

/// Each list is a separately authored X/Z polygon, not a scaled/rotated clone.
/// A subset adds elevated return bridges; the final route per biome adds a loop.
const _worldRoutes = <List<(double, double)>>[
  [
    (-650, -700),
    (-650, -460),
    (-620, -180),
    (-540, 110),
    (-590, 400),
    (-350, 590),
    (-120, 520),
    (-100, 290),
    (-300, 210),
    (-250, 20),
    (0, -40),
    (190, 150),
    (200, 450),
    (460, 560),
    (650, 300),
    (600, 10),
    (350, -120),
    (350, -360),
    (550, -530),
    (420, -680),
    (120, -640),
    (-100, -480),
    (-340, -500),
    (-480, -700),
  ],
  [
    (-650, -700),
    (-640, -420),
    (-600, -130),
    (-390, 60),
    (-530, 280),
    (-430, 540),
    (-180, 570),
    (20, 410),
    (-130, 240),
    (-80, 60),
    (160, 20),
    (370, 180),
    (300, 420),
    (470, 560),
    (650, 350),
    (660, 80),
    (520, -120),
    (310, -210),
    (160, -390),
    (370, -510),
    (300, -690),
    (20, -700),
    (-230, -620),
    (-450, -700),
  ],
  [
    (-640, -690),
    (-660, -400),
    (-540, -140),
    (-360, 100),
    (-490, 350),
    (-350, 590),
    (-90, 550),
    (80, 300),
    (-40, 100),
    (130, -80),
    (340, -30),
    (450, 200),
    (350, 450),
    (570, 560),
    (670, 270),
    (630, -80),
    (490, -330),
    (290, -400),
    (120, -600),
    (-130, -690),
    (-350, -570),
    (-490, -700),
  ],
  [
    (-650, -700),
    (-650, -380),
    (-530, -140),
    (-560, 140),
    (-400, 430),
    (-130, 570),
    (120, 530),
    (150, 300),
    (-70, 210),
    (-180, 30),
    (30, -120),
    (280, -40),
    (480, 180),
    (430, 410),
    (590, 480),
    (680, 190),
    (640, -140),
    (450, -280),
    (240, -300),
    (80, -490),
    (270, -630),
    (80, -710),
    (-170, -580),
    (-430, -690),
  ],
  [
    (-650, -700),
    (-650, -460),
    (-630, -180),
    (-490, 250),
    (-260, 530),
    (-40, 470),
    (-180, 190),
    (-80, 40),
    (180, 90),
    (310, 300),
    (250, 510),
    (490, 550),
    (660, 290),
    (570, 40),
    (350, -150),
    (390, -360),
    (590, -480),
    (420, -650),
    (180, -700),
    (-50, -550),
    (-300, -580),
    (-460, -710),
  ],
  [
    (-660, -700),
    (-640, -420),
    (-480, -210),
    (-520, 80),
    (-620, 330),
    (-410, 570),
    (-140, 590),
    (-20, 370),
    (-210, 240),
    (-180, 40),
    (50, -40),
    (280, 150),
    (240, 410),
    (430, 540),
    (620, 420),
    (660, 130),
    (480, -80),
    (280, -170),
    (200, -360),
    (430, -450),
    (530, -640),
    (250, -710),
    (-50, -620),
    (-330, -690),
  ],
  [
    (-650, -710),
    (-670, -400),
    (-540, -190),
    (-330, -110),
    (-340, 110),
    (-560, 260),
    (-460, 510),
    (-200, 590),
    (0, 420),
    (-90, 230),
    (130, 180),
    (320, 390),
    (550, 540),
    (670, 280),
    (560, 40),
    (330, -50),
    (100, -220),
    (160, -420),
    (410, -500),
    (400, -690),
    (130, -720),
    (-120, -540),
    (-370, -600),
  ],
  [
    (-650, -690),
    (-640, -410),
    (-470, -150),
    (-590, 90),
    (-520, 370),
    (-300, 560),
    (-60, 450),
    (-130, 190),
    (20, 30),
    (260, 30),
    (440, 230),
    (320, 470),
    (550, 590),
    (670, 320),
    (630, 40),
    (500, -230),
    (250, -310),
    (80, -460),
    (260, -620),
    (30, -710),
    (-210, -590),
    (-420, -690),
  ],
  [
    (-660, -710),
    (-650, -430),
    (-580, -160),
    (-350, 60),
    (-430, 300),
    (-270, 550),
    (-20, 570),
    (190, 370),
    (40, 220),
    (-170, 220),
    (-210, 30),
    (30, -140),
    (280, -90),
    (490, 70),
    (470, 330),
    (650, 430),
    (700, 150),
    (610, -160),
    (410, -330),
    (380, -530),
    (170, -700),
    (-80, -620),
    (-360, -690),
  ],
  [
    (-650, -700),
    (-650, -460),
    (-630, -180),
    (-520, 220),
    (-350, 480),
    (-80, 590),
    (100, 400),
    (-50, 230),
    (-220, 170),
    (-180, -30),
    (80, -90),
    (290, 90),
    (310, 370),
    (530, 540),
    (670, 260),
    (580, -10),
    (370, -170),
    (460, -400),
    (410, -620),
    (140, -700),
    (-110, -570),
    (-390, -690),
  ],
  [
    (-650, -700),
    (-660, -420),
    (-540, -130),
    (-560, 180),
    (-410, 480),
    (-140, 580),
    (100, 490),
    (50, 270),
    (-170, 180),
    (-100, -30),
    (120, -80),
    (360, 80),
    (370, 340),
    (570, 530),
    (680, 230),
    (570, -70),
    (320, -210),
    (220, -440),
    (420, -590),
    (200, -720),
    (-60, -600),
    (-360, -680),
  ],
  [
    (-650, -700),
    (-640, -420),
    (-430, -210),
    (-470, 40),
    (-600, 250),
    (-450, 510),
    (-170, 580),
    (30, 370),
    (-60, 150),
    (140, 100),
    (350, 250),
    (290, 480),
    (540, 570),
    (680, 290),
    (610, 30),
    (400, -100),
    (160, -170),
    (80, -360),
    (310, -460),
    (480, -630),
    (240, -720),
    (-50, -590),
    (-340, -660),
  ],
  [
    (-650, -700),
    (-670, -410),
    (-610, -140),
    (-400, 20),
    (-350, 270),
    (-520, 420),
    (-280, 580),
    (-40, 540),
    (100, 330),
    (-70, 220),
    (-130, 40),
    (70, -100),
    (280, -50),
    (460, 130),
    (420, 400),
    (600, 490),
    (690, 180),
    (590, -110),
    (400, -280),
    (380, -510),
    (140, -680),
    (-110, -620),
    (-360, -700),
  ],
  [
    (-650, -710),
    (-650, -400),
    (-530, -160),
    (-600, 110),
    (-460, 370),
    (-230, 540),
    (20, 570),
    (220, 400),
    (110, 200),
    (-100, 160),
    (-200, -40),
    (20, -200),
    (220, -160),
    (440, 40),
    (430, 280),
    (620, 410),
    (700, 130),
    (570, -160),
    (350, -330),
    (210, -520),
    (0, -700),
    (-260, -550),
    (-450, -690),
  ],
  [
    (-650, -700),
    (-650, -460),
    (-630, -180),
    (-460, 280),
    (-240, 550),
    (0, 480),
    (-150, 250),
    (-80, 70),
    (160, -20),
    (350, 160),
    (300, 420),
    (510, 570),
    (680, 320),
    (620, 40),
    (420, -140),
    (280, -350),
    (480, -490),
    (330, -680),
    (60, -690),
    (-160, -540),
    (-380, -630),
  ],
  [
    (-650, -710),
    (-640, -440),
    (-570, -160),
    (-600, 100),
    (-460, 390),
    (-210, 570),
    (40, 530),
    (140, 310),
    (-80, 200),
    (-170, 10),
    (50, -120),
    (300, -40),
    (440, 160),
    (390, 430),
    (580, 540),
    (680, 230),
    (550, -60),
    (310, -230),
    (340, -470),
    (110, -690),
    (-170, -570),
    (-410, -710),
  ],
  [
    (-650, -700),
    (-660, -420),
    (-490, -170),
    (-390, 80),
    (-540, 280),
    (-420, 550),
    (-170, 590),
    (10, 410),
    (-100, 190),
    (100, 80),
    (330, 200),
    (290, 450),
    (510, 590),
    (670, 340),
    (640, 80),
    (410, -70),
    (200, -210),
    (70, -430),
    (310, -490),
    (430, -690),
    (170, -730),
    (-80, -570),
    (-360, -660),
  ],
  [
    (-650, -710),
    (-670, -400),
    (-580, -130),
    (-370, 40),
    (-390, 260),
    (-560, 400),
    (-320, 580),
    (-50, 560),
    (140, 350),
    (-20, 190),
    (-90, 0),
    (140, -130),
    (340, -30),
    (490, 180),
    (400, 410),
    (590, 520),
    (690, 230),
    (580, -40),
    (460, -270),
    (230, -390),
    (100, -620),
    (-160, -700),
    (-390, -610),
  ],
  [
    (-650, -710),
    (-640, -420),
    (-550, -140),
    (-580, 160),
    (-380, 440),
    (-100, 600),
    (170, 470),
    (180, 220),
    (-40, 240),
    (-220, 80),
    (-140, -160),
    (100, -230),
    (290, -70),
    (400, 130),
    (540, 420),
    (680, 210),
    (620, -80),
    (460, -280),
    (370, -510),
    (140, -700),
    (-80, -600),
    (-350, -690),
  ],
  [
    (-650, -700),
    (-650, -460),
    (-630, -180),
    (-510, 220),
    (-310, 520),
    (-40, 560),
    (140, 370),
    (-20, 200),
    (-210, 130),
    (-140, -90),
    (100, -140),
    (310, 40),
    (360, 300),
    (560, 520),
    (690, 240),
    (580, -40),
    (370, -230),
    (440, -430),
    (260, -670),
    (0, -700),
    (-230, -550),
    (-450, -680),
  ],
  [
    (-650, -700),
    (-660, -420),
    (-530, -140),
    (-580, 140),
    (-430, 430),
    (-170, 590),
    (100, 540),
    (200, 340),
    (30, 190),
    (-180, 140),
    (-120, -90),
    (120, -160),
    (350, 10),
    (430, 250),
    (370, 460),
    (590, 510),
    (680, 180),
    (540, -110),
    (290, -280),
    (230, -500),
    (10, -710),
    (-240, -580),
    (-450, -690),
  ],
  [
    (-650, -710),
    (-650, -420),
    (-450, -200),
    (-400, 40),
    (-560, 230),
    (-480, 480),
    (-210, 590),
    (0, 430),
    (-50, 220),
    (160, 130),
    (360, 310),
    (350, 510),
    (580, 560),
    (690, 300),
    (600, 60),
    (370, -70),
    (140, -200),
    (80, -420),
    (320, -510),
    (300, -710),
    (30, -700),
    (-230, -590),
    (-450, -710),
  ],
  [
    (-650, -710),
    (-670, -430),
    (-570, -180),
    (-350, 0),
    (-370, 230),
    (-520, 420),
    (-260, 590),
    (10, 520),
    (170, 300),
    (20, 130),
    (-150, -10),
    (0, -190),
    (250, -120),
    (440, 80),
    (410, 340),
    (610, 490),
    (700, 200),
    (580, -80),
    (430, -300),
    (220, -400),
    (60, -640),
    (-190, -710),
    (-420, -610),
  ],
  [
    (-650, -700),
    (-640, -400),
    (-540, -100),
    (-580, 180),
    (-370, 420),
    (-110, 590),
    (160, 500),
    (230, 290),
    (10, 200),
    (-170, 30),
    (-90, -190),
    (160, -230),
    (330, -40),
    (420, 190),
    (580, 380),
    (700, 120),
    (580, -160),
    (360, -300),
    (300, -540),
    (80, -710),
    (-170, -590),
    (-420, -680),
  ],
  [
    (-650, -700),
    (-650, -460),
    (-630, -180),
    (-480, 270),
    (-250, 550),
    (20, 510),
    (180, 310),
    (-30, 230),
    (-190, 90),
    (-90, -120),
    (160, -160),
    (340, 80),
    (370, 350),
    (580, 520),
    (690, 230),
    (560, -30),
    (350, -240),
    (430, -440),
    (230, -680),
    (-40, -690),
    (-260, -530),
    (-440, -680),
  ],
];

const _worldIds = [
  'forest_canopy',
  'forest_roots',
  'forest_river',
  'forest_sawmill',
  'forest_spiral',
  'prehistoric_valley',
  'prehistoric_eggs',
  'prehistoric_fossils',
  'prehistoric_volcano',
  'prehistoric_loop',
  'desert_oasis',
  'desert_dunes',
  'desert_canyon',
  'desert_mirage',
  'desert_sunloop',
  'snow_pines',
  'snow_glacier',
  'snow_fjord',
  'snow_avalanche',
  'snow_polarloop',
  'coast_bay',
  'coast_lighthouse',
  'coast_reef',
  'coast_harbor',
  'coast_tideloop',
];
const _worldNames = [
  'COPAS VELOZES',
  'RAÍZES DO RALI',
  'CURVAS DO RIACHO',
  'SERRARIA TURBO',
  'ESPIRAL DA FLORESTA',
  'VALE DOS DINOSSAUROS',
  'NINHO DOS GIGANTES',
  'CÂNION DOS FÓSSEIS',
  'ROTA DO VULCÃO',
  'LOOP DO TIRANOSSAURO',
  'VOLTA DO OÁSIS',
  'DUNAS DOURADAS',
  'SERPENTE DO CÂNION',
  'MIRAGEM TURBO',
  'LOOP DO SOL',
  'RALI DOS PINHEIROS',
  'PONTE GLACIAL',
  'CURVAS DO FIORD',
  'ROTA DA AVALANCHE',
  'ESPIRAL POLAR',
  'CURVAS DA BAÍA',
  'RETA DO FAROL',
  'LABIRINTO DOS RECIFES',
  'PORTO A TODO VAPOR',
  'LOOP DA MARÉ',
];

List<TrackSpec> createExpansionTracks() {
  final result = <TrackSpec>[];
  for (var i = 0; i < _worldRoutes.length; i++) {
    final room = expansionBiomes.keys.elementAt(i ~/ 5),
        biome = expansionBiomes[room]!;
    final points = _worldRoutes[i];
    final route = _LoopCircuit();
    final hasLoop = i % 5 == 4;
    if (hasLoop) {
      route.p(-650, -710, 6);
      route.p(-650, -500, 6);
      route.loop(-650, -280, const V3(0, 0, 1), radius: 58 + i ~/ 5 * 2.0);
      route.p(-566, -140, 6);
      route.p(-550, -10, 3);
    }
    for (var j = hasLoop ? 3 : 0; j < points.length; j++) {
      var height = TrackSpec.floorHeight;
      if (!hasLoop && i % 5 == 1 && j >= points.length - 5) {
        height = [3.0, 16.0, 28.0, 16.0, 3.0][j - points.length + 5];
      }
      route.p(points[j].$1, points[j].$2, height);
    }
    const quarterTurns = [
      1,
      1,
      2,
      0,
      0,
      0,
      2,
      3,
      0,
      1,
      2,
      3,
      1,
      2,
      2,
      3,
      0,
      0,
      3,
      3,
      1,
      1,
      3,
      4,
      0,
    ];
    final angle = (quarterTurns[i] % 4) * math.pi / 2;
    final mirror = quarterTurns[i] >= 4 ? -1.0 : 1.0;
    final scale = 1.0;
    V3 orient(V3 p) => V3(
      (p.x * mirror * math.cos(angle) - p.z * math.sin(angle)) * scale,
      p.y,
      (p.x * mirror * math.sin(angle) + p.z * math.cos(angle)) * scale,
    );
    final positioned = route.points.map(orient).toList();
    final sections = [
      for (final section in route.sections)
        LoopSection(
          section.first,
          section.last,
          orient(section.right).unit * mirror,
        ),
    ];
    result.add(
      TrackSpec(
        _worldIds[i],
        _worldNames[i],
        hasLoop
            ? 'Loop vertical, curvas de piso e um atalho com portão destrutível.'
            : i % 5 == 1
            ? 'Ponte de retorno, rampas e um atalho protegido por portão.'
            : 'Traçado próprio, curvas técnicas, rampas e um atalho destrutível.',
        room,
        biome.accent,
        biome.floor,
        biome.horizon,
        positioned,
        width: 46,
        loopSections: sections,
      ),
    );
    populateExpansionObstacles(result.last, i);
  }
  return result;
}

bool _expansionProp(TrackSpec t, String kind, V3 p, V3 size, int color) {
  // Every prop fits in its collider. Preserve both the race and shortcut corridors.
  for (final f in t.frames) {
    if (f.p.y > p.y + size.y / 2 + 6) continue;
    if ((f.p.x - p.x).abs() < size.x / 2 + t.widthAt(f.s) / 2 + 18 &&
        (f.p.z - p.z).abs() < size.z / 2 + t.widthAt(f.s) / 2 + 18)
      return false;
  }
  if (t.shortcuts.any(
    (s) => s.frames.any(
      (f) =>
          (f.p.x - p.x).abs() < size.x / 2 + s.width / 2 + 18 &&
          (f.p.z - p.z).abs() < size.z / 2 + s.width / 2 + 18,
    ),
  ))
    return false;
  if (t.obstacles.any(
    (o) =>
        (p.x - o.center.x).abs() < (size.x + o.size.x) / 2 + 8 &&
        (p.z - o.center.z).abs() < (size.z + o.size.z) / 2 + 8,
  ))
    return false;
  t.details.add(RoomProp(kind, p, size, color));
  t.obstacles.add(WorldObstacle(p, size, color: color, visible: false));
  return true;
}

void populateExpansionScenery(TrackSpec t) {
  final biome = expansionBiomes[t.room]!;
  for (var i = 0; i < 32; i++) {
    final side = i ~/ 8, offset = -700 + (i % 8) * 200.0;
    final x = side == 0
        ? -790.0
        : side == 1
        ? 790.0
        : offset;
    final z = side == 2
        ? -790.0
        : side == 3
        ? 790.0
        : offset;
    final kind = biome.props[i % biome.props.length];
    final size = _worldPropSize(kind);
    _expansionProp(
      t,
      kind,
      V3(x, size.y / 2, z),
      size,
      [0xff56834b, 0xff719452, 0xff77905b][i % 3],
    );
  }
  if (t.room == 'PRÉ-HISTÓRIA') {
    // Distinct sculpted species, not live enemies. All maps use the same toy style.
    for (final item in [
      ('rex', -740.0, 490.0),
      ('triceratops', 740.0, -470.0),
      ('sauropod', 0.0, 760.0),
    ]) {
      final size = _worldPropSize(item.$1);
      _expansionProp(
        t,
        item.$1,
        V3(item.$2, size.y / 2, item.$3),
        size,
        0xff728752,
      );
    }
  }
}

V3 _worldPropSize(String kind) => switch (kind) {
  'tree' => const V3(64, 110, 64),
  'pine' || 'snowpine' => const V3(58, 124, 58),
  'palm' => const V3(78, 118, 78),
  'rex' => const V3(66, 76, 106),
  'triceratops' => const V3(76, 50, 104),
  'sauropod' => const V3(68, 132, 116),
  'fern' => const V3(42, 24, 42),
  'log' => const V3(68, 22, 28),
  'cactus' => const V3(42, 78, 30),
  'iceberg' => const V3(68, 66, 54),
  'buoy' => const V3(22, 40, 22),
  'eggs' => const V3(46, 22, 36),
  'shell' => const V3(30, 18, 28),
  _ => const V3(52, 36, 44),
};

void populateExpansionTrackside(TrackSpec t) {
  final biome = expansionBiomes[t.room]!;
  var index = 0;
  for (var s = 100.0; s < t.length; s += 165) {
    if (!t.isFloor(s)) continue;
    final f = t.at(s);
    final kind = biome.props[index++ % biome.props.length],
        size = _worldPropSize(kind);
    final side = index.isEven ? 1.0 : -1.0;
    final raw = f.point(side * (t.widthAt(s) / 2 + 40 + size.x / 2));
    if (raw.x.abs() + size.x / 2 > 820 || raw.z.abs() + size.z / 2 > 820)
      continue;
    _expansionProp(t, kind, V3(raw.x, size.y / 2, raw.z), size, 0xff638a51);
  }
}

List<ArenaSpec> createExpansionArenas() {
  final result = <ArenaSpec>[];
  var index = 6;
  for (final entry in expansionBiomes.entries) {
    final biome = entry.value;
    // An open combat floor with a freestanding loop, not a race converted to arena.
    final route = _LoopCircuit()
      ..p(-620, -690, 6)
      ..p(-620, -500, 6)
      ..loop(-620, -270, const V3(0, 0, 1), radius: 62)
      ..p(-536, -100, 6)
      ..p(-510, 70, 3)
      ..p(-410, 350)
      ..p(-200, 530)
      ..p(160, 520)
      ..p(470, 420)
      ..p(610, 120)
      ..p(560, -190)
      ..p(310, -440)
      ..p(20, -590)
      ..p(-310, -690, 3);
    final t = TrackSpec(
      'arena_world_${index - 6}',
      biome.arena,
      biome.tagline,
      entry.key,
      biome.accent,
      biome.floor,
      biome.horizon,
      route.points,
      width: 52,
      loopSections: route.sections,
      openArena: true,
    );
    // Hand-placed cover leaves gaps and a clear central fighting area.
    final kinds = entry.key == 'PRÉ-HISTÓRIA'
        ? ['rex', 'triceratops', 'rock', 'sauropod', 'eggs', 'rock']
        : biome.props;
    for (var j = 0; j < 12; j++) {
      final a = j * 2.399 + index * .19, r = 210 + j % 3 * 110.0;
      final kind = kinds[j % kinds.length], size = _worldPropSize(kind);
      _expansionProp(
        t,
        kind,
        V3(math.cos(a) * r, size.y / 2, math.sin(a) * r),
        size,
        0xff6d8d55,
      );
    }
    for (var j = 0; j < 3; j++) {
      final a = j * math.pi * 2 / 3;
      final p = V3(math.cos(a) * 150, .16, math.sin(a) * 150),
          forward = V3(-math.sin(a), 0, math.cos(a));
      final frame = TrackFrame(
        p,
        const V3(0, 1, 0).cross(forward),
        const V3(0, 1, 0),
        forward,
        0,
      );
      // Validate ramp floor footprint before adding cover-independent jump ramps.
      if (t.obstacles.any((o) => (o.center - p).length < 100)) continue;
      t.ramps.add(WorldRamp(frame, width: 48, length: 42, height: 8));
    }
    result.add(ArenaSpec(t, biome.tagline, index++));
  }
  return result;
}
