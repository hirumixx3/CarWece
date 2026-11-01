part of 'content.dart';

enum BattlePower {
  machineGun,
  homingMissile,
  rocket,
  mortar,
  cannon,
  roadMine,
  ripperWheels,
  armorRepair,
  oilDrum,
  laserCannon,
  sonicBoom,
  atomBlaster,
  freonBomb,
  energyShield,
  jetBoosters,
  superZapper,
  magnetMine,
  doomDisks,
  quantumAnnihilator,
  gridlock,
  whiteLightning,
  tantrumGun,
  bassQuake,
  invasion,
  steelBelter,
  scatterMissiles,
  deathRay,
  discoInferno,
  gammaSwarm,
  smogCheck,
  breathOfFire,
  alienLaser,
  haloDecoy,
  afterburner,
  roadRunner,
  stampede,
  turtleTurnover,
  craterMaker,
  cowPuncher,
  buckshot,
  bearHug,
  cactusPatch,
  radarJammer,
  weaponUpgrade,
}

bool battleTracksTarget(BattlePower p) => !const {
  BattlePower.roadMine,
  BattlePower.ripperWheels,
  BattlePower.armorRepair,
  BattlePower.sonicBoom,
  BattlePower.energyShield,
  BattlePower.jetBoosters,
  BattlePower.bassQuake,
  BattlePower.invasion,
  BattlePower.discoInferno,
  BattlePower.gammaSwarm,
  BattlePower.smogCheck,
  BattlePower.haloDecoy,
  BattlePower.afterburner,
  BattlePower.bearHug,
  BattlePower.cactusPatch,
  BattlePower.radarJammer,
  BattlePower.weaponUpgrade,
}.contains(p);

class BattleWeapon {
  final BattlePower power;
  final String name, reference, description, family;
  final int ammo, color;
  final double damage, cooldown;
  const BattleWeapon(
    this.power,
    this.name,
    this.reference,
    this.description,
    this.family,
    this.ammo,
    this.damage,
    this.cooldown,
    this.color,
  );
  bool get support => family == 'DEFESA';
}

// Names identify the researched mechanic; meshes, effects and tuning are CarWece's.
const battleWeapons = <BattleWeapon>[
  BattleWeapon(
    BattlePower.machineGun,
    'METRALHADORA',
    'Mosquito Machine Gun',
    'Tiros frontais; 60 disparos por coleta, aquece ao manter o disparo.',
    'V8 • PADRÃO',
    60,
    3.2,
    .13,
    0xffffdc68,
  ),
  BattleWeapon(
    BattlePower.homingMissile,
    'MÍSSIL GUIADO',
    'Interceptor Missiles',
    'Persegue o alvo selecionado; obstáculos interceptam o míssil.',
    'V8 • PADRÃO',
    6,
    19,
    .8,
    0xff93e778,
  ),
  BattleWeapon(
    BattlePower.rocket,
    'FOGUETE',
    "Bull’s Eye Rockets",
    'Disparo reto, rápido e explosivo; exige apontar o carro.',
    'V8 • PADRÃO',
    8,
    25,
    .65,
    0xffff8747,
  ),
  BattleWeapon(
    BattlePower.mortar,
    'MORTEIRO',
    'Sky Hammer Mortar',
    'Projétil em arco com correção limitada e explosão em área.',
    'V8 • PADRÃO',
    5,
    25,
    1.1,
    0xffffc46b,
  ),
  BattleWeapon(
    BattlePower.cannon,
    'CANHÃO',
    'Bruiser Cannon',
    'Torre gira até o alvo; projétil pesado causa recuo.',
    'V8 • PADRÃO',
    10,
    16,
    .55,
    0xffffb477,
  ),
  BattleWeapon(
    BattlePower.roadMine,
    'MINA DE CONTATO',
    'Roadkill Mines',
    'Fica atrás do carro e arma antes de explodir por contato.',
    'V8 • PADRÃO',
    6,
    27,
    .7,
    0xffff6052,
  ),
  BattleWeapon(
    BattlePower.ripperWheels,
    'RODAS CORTANTES',
    'Ripper Wheels',
    'Lâminas nas rodas ferem carros próximos durante sete segundos.',
    'VELOCITY X',
    2,
    9,
    1,
    0xffd0e2f1,
  ),
  BattleWeapon(
    BattlePower.armorRepair,
    'REPARO COMPLETO',
    'Armor Repair',
    'Restaura a vida e limpa fogo, gelo, fumaça e pane.',
    'DEFESA',
    1,
    0,
    1,
    0xff89efaa,
  ),
  BattleWeapon(
    BattlePower.oilDrum,
    'TAMBOR DE ÓLEO',
    'Oil Drum',
    'Arremessa um barril; o impacto espalha óleo que faz derrapar.',
    'VELOCITY X',
    4,
    10,
    .8,
    0xffa088e3,
  ),
  BattleWeapon(
    BattlePower.laserCannon,
    'CANHÃO LASER',
    'Laser Cannon',
    'Raio azul frontal preciso; cobertura sólida bloqueia o tiro.',
    'VELOCITY X',
    5,
    27,
    .9,
    0xff5edbff,
  ),
  BattleWeapon(
    BattlePower.sonicBoom,
    'EXPLOSÃO SÔNICA',
    'Sonic Boom',
    'Pulso circular desestabiliza e empurra inimigos próximos.',
    'VELOCITY X',
    3,
    15,
    1.2,
    0xffffc56f,
  ),
  BattleWeapon(
    BattlePower.atomBlaster,
    'RAJADA ATÔMICA',
    'Atom Blaster',
    'Rajada dupla de partículas amarelas.',
    'VELOCITY X',
    16,
    5,
    .2,
    0xffffe56a,
  ),
  BattleWeapon(
    BattlePower.freonBomb,
    'BOMBA CRIOGÊNICA',
    'Freon Bomb',
    'Bomba com quique que congela no raio da explosão.',
    'VELOCITY X',
    4,
    16,
    1,
    0xff85e9ff,
  ),
  BattleWeapon(
    BattlePower.energyShield,
    'ESCUDO DE ENERGIA',
    'Energy Shield',
    'Bloqueia dano por cinco segundos; mantém o carro visível.',
    'DEFESA',
    2,
    0,
    1,
    0xff5bddff,
  ),
  BattleWeapon(
    BattlePower.jetBoosters,
    'PROPULSORES',
    'Jet Boosters',
    'Aceleração forçada por três segundos e dano ao abalroar.',
    'VELOCITY X',
    3,
    12,
    1,
    0xffff9d56,
  ),
  BattleWeapon(
    BattlePower.superZapper,
    'SUPER DESCARGA',
    'Super Zapper',
    'Arco elétrico trava o motor e descarrega pulsos de dano.',
    'VELOCITY X',
    4,
    13,
    .9,
    0xffb28aff,
  ),
  BattleWeapon(
    BattlePower.magnetMine,
    'MINA MAGNÉTICA',
    'Magnet Mine',
    'Mina lançada segue, gruda no alvo e explode após a contagem.',
    'VELOCITY X',
    4,
    27,
    1,
    0xffff6cc0,
  ),
  BattleWeapon(
    BattlePower.doomDisks,
    'DISCOS GUIADOS',
    'Doom Disks',
    'Três discos curvos convergem sobre o alvo.',
    'VELOCITY X',
    3,
    10,
    1,
    0xffb0c8ed,
  ),
  BattleWeapon(
    BattlePower.quantumAnnihilator,
    'ANIQUILADOR QUÂNTICO',
    'Quantum Annihilator',
    'Raio frontal raro de grande dano e recarga lenta.',
    'VELOCITY X • BÔNUS',
    1,
    65,
    2.3,
    0xffff5b54,
  ),
  BattleWeapon(
    BattlePower.gridlock,
    'GRADE DE FLARES',
    'Gridlock',
    'Malha expansiva de flares, dano e pane dentro da grade.',
    'V8 • ESPECIAL',
    3,
    19,
    1.2,
    0xffffa46d,
  ),
  BattleWeapon(
    BattlePower.whiteLightning,
    'RELÂMPAGO BRANCO',
    'White Lightning',
    'Descarga guiada com salto entre carros próximos.',
    'V8 • ESPECIAL',
    3,
    22,
    1.2,
    0xffe3f6ff,
  ),
  BattleWeapon(
    BattlePower.tantrumGun,
    'TORRE GIRATÓRIA',
    'Tantrum Gun',
    'Gatling automática em rajada; pode expulsar munição do inimigo.',
    'V8 • ESPECIAL',
    10,
    7,
    .24,
    0xffffd582,
  ),
  BattleWeapon(
    BattlePower.bassQuake,
    'TERREMOTO DE GRAVES',
    'Bass Quake',
    'Ondas pelo chão levantam carros sem atingir veículos muito altos.',
    'V8 • ESPECIAL',
    3,
    22,
    1.4,
    0xffdb8bff,
  ),
  BattleWeapon(
    BattlePower.invasion,
    'INVASÃO ORBITAL',
    'Invasion Attack',
    'Três sondas orbitam o alvo e lançam pulsos visíveis.',
    'V8 • ESPECIAL',
    2,
    8,
    1.7,
    0xff83f8c4,
  ),
  BattleWeapon(
    BattlePower.steelBelter,
    'PNEU EXPLOSIVO',
    'Steel Belter',
    'Pneu rola, procura um alvo e explode em área.',
    'V8 • ESPECIAL',
    4,
    33,
    1.2,
    0xffffac59,
  ),
  BattleWeapon(
    BattlePower.scatterMissiles,
    'SALVA DISPERSA',
    'Scatter Missiles',
    'Seis pequenos mísseis se abrem e convergem.',
    'V8 • ESPECIAL',
    3,
    8,
    1.4,
    0xffff8b8b,
  ),
  BattleWeapon(
    BattlePower.deathRay,
    'RAIO PERFURANTE',
    'Super Fantastic Death Ray 3-Ax',
    'Feixe atravessa cobertura e pode atingir vários carros.',
    'V8 • ESPECIAL',
    4,
    28,
    1.2,
    0xff7b9dff,
  ),
  BattleWeapon(
    BattlePower.discoInferno,
    'GLOBO DO CAOS',
    'Disco Inferno',
    'Globo sobre o carro solta flares em todas as direções.',
    'V8 • ESPECIAL',
    2,
    8,
    1.6,
    0xffff73d6,
  ),
  BattleWeapon(
    BattlePower.gammaSwarm,
    'ENXAME GAMA',
    'Gamma Swarm',
    'Enxame perseguidor ergue o alvo e provoca dano em pulsos.',
    'V8 • ESPECIAL',
    3,
    7,
    1.5,
    0xffb5ff58,
  ),
  BattleWeapon(
    BattlePower.smogCheck,
    'NUVEM TÓXICA',
    'Smog Check',
    'Gás atrás do carro; dano e visão reduzida apenas dentro da nuvem.',
    'V8 • ESPECIAL',
    3,
    7,
    1.2,
    0xffa4ba66,
  ),
  BattleWeapon(
    BattlePower.breathOfFire,
    'SOPRO DE FOGO',
    'Breath of Fire',
    'Bolas de fogo deixam o alvo em chamas por tempo limitado.',
    'V8 • ESPECIAL',
    6,
    14,
    .65,
    0xffff7444,
  ),
  BattleWeapon(
    BattlePower.alienLaser,
    'LASER ALIENÍGENA',
    'Blue Laser',
    'Laser penetrante de alto dano, com pontaria frontal estreita.',
    'V8 • ESPECIAL',
    3,
    42,
    1.5,
    0xff65b6ff,
  ),
  BattleWeapon(
    BattlePower.haloDecoy,
    'ISCA HOLOGRÁFICA',
    'Halo Decoy',
    'Anel-isca desvia projéteis guiados para longe do carro.',
    'DEFESA',
    3,
    0,
    .8,
    0xffe5e2a2,
  ),
  BattleWeapon(
    BattlePower.afterburner,
    'PÓS-COMBUSTÃO',
    'Afterburner',
    'Usa a carga para uma arrancada curta, inclusive antes de rampas.',
    'V8 • COMBO',
    4,
    0,
    .9,
    0xffffc67e,
  ),
  BattleWeapon(
    BattlePower.roadRunner,
    'FOGUETE REBELDE',
    'Road Runner',
    'Foguete adesivo empurra e faz o alvo rodar.',
    'V8 • COMBO',
    4,
    7,
    .9,
    0xffe8b17b,
  ),
  BattleWeapon(
    BattlePower.stampede,
    'DEBANDADA',
    'Stampede',
    'Cinco foguetes disparados em leque concentrado.',
    'V8 • COMBO',
    3,
    10,
    1.2,
    0xffff8f60,
  ),
  BattleWeapon(
    BattlePower.turtleTurnover,
    'VIRA-CARRO',
    'Turtle Turnover',
    'Morteiro lança o carro para cima e o faz tombar.',
    'V8 • COMBO',
    3,
    12,
    1.2,
    0xffafcfef,
  ),
  BattleWeapon(
    BattlePower.craterMaker,
    'MEGACRATERA',
    'Crater Maker',
    'Morteiro pesado com grande raio e marca de impacto temporária.',
    'V8 • COMBO',
    2,
    43,
    1.8,
    0xffffad5c,
  ),
  BattleWeapon(
    BattlePower.cowPuncher,
    'SOCO CINÉTICO',
    'Cow Puncher',
    'Bala de impacto lança o carro atingido para trás.',
    'V8 • COMBO',
    4,
    10,
    .8,
    0xff9cea91,
  ),
  BattleWeapon(
    BattlePower.buckshot,
    'CHUMBO ESPALHADO',
    'Buckshot',
    'Seis balas em leque; forte a curta distância.',
    'V8 • COMBO',
    4,
    7,
    .9,
    0xffffd699,
  ),
  BattleWeapon(
    BattlePower.bearHug,
    'ABRAÇO MAGNÉTICO',
    'Bear Hug',
    'Armadilha atrai e imobiliza; não confere invulnerabilidade.',
    'V8 • COMBO',
    3,
    8,
    1,
    0xffd192ff,
  ),
  BattleWeapon(
    BattlePower.cactusPatch,
    'CAMPO MINADO',
    'Cactus Patch',
    'Espalha seis minas de contato atrás do carro.',
    'V8 • COMBO',
    3,
    13,
    1.1,
    0xffff8a79,
  ),
  BattleWeapon(
    BattlePower.radarJammer,
    'BLOQUEADOR DE RADAR',
    'Radar Jammer',
    'Oculta do radar e interrompe a mira guiada por sete segundos.',
    'DEFESA',
    2,
    0,
    1,
    0xffffe17b,
  ),
  BattleWeapon(
    BattlePower.weaponUpgrade,
    'DANO DOBRADO',
    'Weapon Upgrade',
    'Dobra temporariamente o dano das seis armas padrão.',
    'DEFESA',
    2,
    0,
    1,
    0xff68b3ff,
  ),
];
BattleWeapon battleWeapon(BattlePower power) => battleWeapons[power.index];

/// First intersection of a swept segment and an oriented household collider.
double? arenaBoxHit(WorldObstacle box, V3 from, V3 to, {double padding = .3}) {
  final origin = from - box.center, delta = to - from;
  var enter = 0.0, exit = 1.0;
  final axes = [box.right, const V3(0, 1, 0), box.forward];
  final half = [
    box.size.x / 2 + padding,
    box.size.y / 2 + padding,
    box.size.z / 2 + padding,
  ];
  for (var i = 0; i < 3; i++) {
    final p = origin.dot(axes[i]), v = delta.dot(axes[i]);
    if (v.abs() < 1e-9) {
      if (p.abs() > half[i]) return null;
      continue;
    }
    var a = (-half[i] - p) / v, b = (half[i] - p) / v;
    if (a > b) {
      final swap = a;
      a = b;
      b = swap;
    }
    enter = math.max(enter, a);
    exit = math.min(exit, b);
    if (enter > exit) return null;
  }
  return enter >= 0 && enter <= 1 ? enter : null;
}

class ArenaSpec {
  final TrackSpec track;
  final String tagline;
  final int index;
  final List<V3> spawns = [], supplies = [], health = [], nav = [];
  ArenaSpec(this.track, this.tagline, this.index) {
    for (var z = -640.0; z <= 640; z += 80) {
      for (var x = -640.0; x <= 640; x += 80) {
        final p = V3(x, TrackSpec.floorHeight, z);
        if (clearFloor(p, 9)) nav.add(p);
      }
    }
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + index * .23;
      spawns.add(safeFloor(V3(math.cos(a) * 220, .16, math.sin(a) * 220)));
    }
    for (var i = 0; i < 18; i++) {
      final a = i * 2.399 + index * .4,
          radius = i < 6
              ? 115.0
              : i < 12
              ? 340.0
              : 560.0;
      final p = safeFloor(V3(math.cos(a) * radius, .16, math.sin(a) * radius));
      if (supplies.every((s) => (s - p).length > 35)) supplies.add(p);
    }
    for (final p in [
      const V3(-400, .16, 0),
      const V3(400, .16, 0),
      const V3(0, .16, -400),
      const V3(0, .16, 400),
    ])
      health.add(safeFloor(p));
  }
  bool clearFloor(V3 p, [double margin = 6]) {
    for (final o in track.obstacles) {
      if (o.center.y - o.size.y / 2 > 6) continue;
      final d = p - o.center;
      if (d.dot(o.right).abs() < o.size.x / 2 + margin &&
          d.dot(o.forward).abs() < o.size.z / 2 + margin)
        return false;
    }
    final s = track.project(p);
    return track.isFloor(s.frame.s) ||
        s.lateral.abs() > track.width / 2 + margin ||
        s.frame.p.y > 12;
  }

  bool lineClear(V3 a, V3 b, [double margin = 7]) => !track.obstacles.any(
    (o) =>
        o.center.y - o.size.y / 2 < 5 &&
        arenaBoxHit(
              o,
              a + const V3(0, 2, 0),
              b + const V3(0, 2, 0),
              padding: margin,
            ) !=
            null,
  );
  V3 safeFloor(V3 p) {
    if (clearFloor(p, 10)) return V3(p.x, .16, p.z);
    return nav.reduce((a, b) => (a - p).length < (b - p).length ? a : b);
  }

  List<V3> path(V3 from, V3 target) {
    final start = nav.indexOf(safeFloor(from)),
        end = nav.indexOf(safeFloor(target));
    int closest(V3 p) {
      var best = double.infinity, at = 0;
      for (var i = 0; i < nav.length; i++) {
        final d = (nav[i] - p).length;
        if (d < best) {
          best = d;
          at = i;
        }
      }
      return at;
    }

    final first = start < 0 ? closest(from) : start,
        goal = end < 0 ? closest(target) : end;
    final open = <int>{first},
        cost = <int, double>{first: 0},
        previous = <int, int>{};
    var limit = 0;
    while (open.isNotEmpty && limit++ < 400) {
      final current = open.reduce(
        (a, b) =>
            cost[a]! + (nav[a] - nav[goal]).length <
                cost[b]! + (nav[b] - nav[goal]).length
            ? a
            : b,
      );
      if (current == goal) {
        final route = <V3>[target];
        var at = current;
        while (at != first) {
          route.insert(0, nav[at]);
          at = previous[at]!;
        }
        return route;
      }
      open.remove(current);
      for (var n = 0; n < nav.length; n++) {
        final gap = (nav[n] - nav[current]).length;
        if (gap < 1 || gap > 114) continue;
        if (!lineClear(nav[current], nav[n], 9)) continue;
        final score = cost[current]! + gap;
        if (score >= (cost[n] ?? double.infinity)) continue;
        previous[n] = current;
        cost[n] = score;
        open.add(n);
      }
    }
    return [safeFloor(target)];
  }
}

List<ArenaSpec> createBattleArenas() {
  final arenas = <ArenaSpec>[];
  final rooms = ['QUARTO', 'GARAGEM', 'BANHEIRO', 'COZINHA', 'SALA', 'ARCADE'];
  final names = [
    'FORTALEZA DOS BRINQUEDOS',
    'FERRO-VELHO ELÉTRICO',
    'MARÉ DE AZULEJOS',
    'CAOS NA COZINHA',
    'CERCO DO SOFÁ',
    'DOMO NEON',
  ];
  final tags = [
    'Livros formam cobertura; uma ponte cruza o campo e um loop domina a lateral.',
    'Dois loops, corredor de ferramentas e pneus para quebrar a linha de tiro.',
    'Azulejo escorregadio, tampas como refúgios e loop transversal.',
    'Dois loops em lados opostos; potes e embalagens dividem a arena.',
    'Tapete de combate, rampa entre almofadas e uma volta vertical.',
    'Duas voltas verticais, flippers de cobertura e luzes no salão.',
  ];
  final floors = [
    0xff81634a,
    0xff586470,
    0xffc7d8d7,
    0xffc7b99f,
    0xff81705a,
    0xff292c49,
  ];
  final colors = [
    0xffff8a35,
    0xff45dbc6,
    0xff64d1e8,
    0xfff6c666,
    0xffd6ac72,
    0xffaa7fff,
  ];
  for (var i = 0; i < 6; i++) {
    final route = _LoopCircuit();
    if (i == 2 || i == 4) {
      route
        ..p(-600, -620)
        ..p(-480, -620, 3)
        ..p(-390, -620, 6)
        ..p(-310, -620, 6)
        ..loop(-160, -620, const V3(1, 0, 0), radius: i == 2 ? 59 : 65)
        ..p(20, -704, 6)
        ..p(170, -670, 3)
        ..p(420, -540)
        ..p(560, -300)
        ..p(i == 4 ? 470 : 460, i == 4 ? -100 : 30)
        ..p(300, i == 4 ? -20 : 170, 24)
        ..p(i == 4 ? 70 : 80, i == 4 ? 30 : 140, i == 4 ? 36 : 30)
        ..p(i == 4 ? -90 : -100, i == 4 ? 130 : 80, 24)
        ..p(-280, i == 4 ? 230 : 180)
        ..p(-500, 340)
        ..p(-620, 150)
        ..p(-700, -170);
    } else {
      route
        ..p(-640, -660)
        ..p(-640, -540, 3)
        ..p(-640, -450, 6)
        ..loop(-640, -270, const V3(0, 0, 1), radius: 58.0 + i)
        ..p(-556, -130, 6)
        ..p(-520, 30, 3)
        ..p(
          i == 1
              ? -430
              : i == 5
              ? -380
              : -460,
          i == 1
              ? 390
              : i == 5
              ? 420
              : 300,
        )
        ..p(
          i == 1
              ? -280
              : i == 3
              ? -210
              : i == 5
              ? -80
              : -230,
          i == 1
              ? 350
              : i == 3
              ? 360
              : i == 5
              ? 440
              : 410,
        )
        ..p(
          i == 1
              ? -230
              : i == 3
              ? -110
              : i == 5
              ? -240
              : -120,
          i == 1
              ? 170
              : i == 3
              ? 20
              : i == 5
              ? 210
              : 190,
          i == 0 ? 22 : 25,
        )
        ..p(
          i == 1
              ? 20
              : i == 3
              ? 50
              : i == 5
              ? -20
              : 80,
          i == 1
              ? -40
              : i == 3
              ? -170
              : i == 5
              ? -140
              : 120,
          i == 0 ? 32 : 36,
        )
        ..p(
          i == 3
              ? 280
              : i == 5
              ? 270
              : 260,
          i == 1
              ? 120
              : i == 3
              ? -30
              : i == 5
              ? 20
              : 190,
          i == 0 ? 22 : 25,
        )
        ..p(400, 390);
      if (i == 1 || i == 3 || i == 5) {
        route
          ..p(610, 400, 3)
          ..p(640, 260, 6)
          ..loop(640, 90, const V3(0, 0, -1), radius: 64.0 - i)
          ..p(556, -60, 6)
          ..p(520, -220, 3);
      } else {
        route
          ..p(610, 220)
          ..p(590, -80)
          ..p(410, -250);
      }
      route
        ..p(
          i == 1
              ? 250
              : i == 3
              ? 420
              : i == 5
              ? 370
              : 320,
          i == 1
              ? -470
              : i == 3
              ? -470
              : i == 5
              ? -520
              : -400,
        )
        ..p(
          i == 1
              ? -20
              : i == 3
              ? 150
              : i == 5
              ? 50
              : 90,
          i == 1
              ? -260
              : i == 3
              ? -540
              : i == 5
              ? -350
              : -300,
        )
        ..p(
          i == 5 ? -180 : -100,
          i == 3
              ? -260
              : i == 5
              ? -330
              : -460,
        )
        ..p(-310, -650)
        ..p(-520, -700);
    }
    final t = TrackSpec(
      'arena_${i + 1}',
      names[i],
      tags[i],
      rooms[i],
      colors[i],
      floors[i],
      i == 5 ? 0xff171831 : 0xff3d4c62,
      route.points,
      width: 52,
      loopSections: route.sections,
      openArena: true,
    );
    // Cover has gaps on every side; no lane walls or checkpoint corridor.
    for (var j = 0; j < 14; j++) {
      final angle = j * 2.399 + i * .31, radius = 160 + (j % 4) * 90.0;
      final p = V3(
        math.cos(angle) * radius,
        8 + (j % 3) * 4.0,
        math.sin(angle) * radius,
      );
      final projection = t.project(p);
      if (!t.isFloor(projection.frame.s) &&
          projection.lateral.abs() < t.width / 2 + 30)
        continue;
      final size = V3(24 + (j % 3) * 12.0, p.y * 2, 18 + (j % 2) * 22.0);
      t.obstacles.add(
        WorldObstacle(
          p,
          size,
          color: [0xffcd8056, 0xff4c929f, 0xffd8b954][j % 3],
        ),
      );
    }
    for (var j = 0; j < 3; j++) {
      final a = j * math.pi * 2 / 3 + i * .3;
      final p = V3(math.cos(a) * 300, .16, math.sin(a) * 300);
      final forward = V3(-math.sin(a), 0, math.cos(a));
      final f = TrackFrame(
        p,
        const V3(0, 1, 0).cross(forward),
        const V3(0, 1, 0),
        forward,
        0,
      );
      t.ramps.add(WorldRamp(f, width: 52, length: 42, height: 8));
    }
    arenas.add(ArenaSpec(t, tags[i], i));
  }
  arenas.addAll(createExpansionArenas());
  return arenas;
}
