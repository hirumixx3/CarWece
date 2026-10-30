part of 'content.dart';

class LoopSection {
  final int first, last;
  final V3 right;
  const LoopSection(this.first, this.last, this.right);
}

class TrackLoop {
  final double start, end;
  const TrackLoop(this.start, this.end);
}

class _LoopCircuit {
  final List<V3> points = [];
  final List<LoopSection> sections = [];
  void p(double x, double z, [double y = TrackSpec.floorHeight]) =>
      points.add(V3(x, y, z));
  void loop(double x, double z, V3 forward, {double radius = 62}) {
    final right = const V3(0, 1, 0).cross(forward).unit;
    final origin = V3(x, 6, z), start = points.length;
    points.add(origin);
    // Offset the exit by 84 units: the 46-unit ribbons never coincide.
    for (var i = 1; i <= 24; i++) {
      final t = i / 24, a = t * math.pi * 2;
      points.add(
        origin +
            right * (84 * t * t * (3 - 2 * t)) +
            const V3(0, 1, 0) * (radius * (1 - math.cos(a))) +
            forward * (radius * math.sin(a)),
      );
    }
    sections.add(LoopSection(start, points.length - 1, right));
  }
}

List<TrackSpec> createLoopTracks() {
  final tracks = <TrackSpec>[];
  void add(
    String id,
    String name,
    String subtitle,
    String room,
    int accent,
    int floor,
    int wall,
    _LoopCircuit route,
  ) => tracks.add(
    TrackSpec(
      id,
      name,
      subtitle,
      room,
      accent,
      floor,
      wall,
      route.points,
      loopSections: route.sections,
    ),
  );
  final toys = _LoopCircuit()
    ..p(-650, -690, 6)
    ..p(-650, -540, 6)
    ..p(-650, -440, 6)
    ..loop(-650, -280, const V3(0, 0, 1))
    ..p(-566, -160, 6)
    ..p(-550, -30, 3)
    ..p(-490, 170)
    ..p(-390, 390)
    ..p(-170, 410)
    ..p(-250, 180)
    ..p(-170, 50)
    ..p(90, 30)
    ..p(280, 140)
    ..p(270, 370)
    ..p(520, 410)
    ..p(630, 180)
    ..p(570, -60)
    ..p(350, -130)
    ..p(330, -350)
    ..p(150, -570)
    ..p(-70, -670)
    ..p(-330, -700, 3)
    ..p(-530, -710, 6);
  add(
    'bedroom_spiral',
    'ESPIRAL DOS BRINQUEDOS',
    '1 loop vertical e um S entre livros, mesa e baú.',
    'QUARTO',
    0xffff8a35,
    0xff81634a,
    0xff465574,
    toys,
  );
  final twins = _LoopCircuit()
    ..p(-650, -700, 6)
    ..p(-650, -530, 6)
    ..p(-650, -420, 6)
    ..loop(-650, -260, const V3(0, 0, 1), radius: 58)
    ..p(-566, -130, 6)
    ..p(-560, 20, 3)
    ..p(-460, 270)
    ..p(-270, 400)
    ..p(-70, 400)
    ..p(-170, 110)
    ..p(30, 30)
    ..p(300, 80)
    ..p(350, 310)
    ..p(460, 420, 3)
    ..p(620, 400, 6)
    ..p(620, 280, 6)
    ..loop(620, 110, const V3(0, 0, -1), radius: 64)
    ..p(536, -30, 6)
    ..p(510, -190, 3)
    ..p(390, -350)
    ..p(150, -330)
    ..p(-10, -480)
    ..p(-200, -650)
    ..p(-450, -720, 6);
  add(
    'bedroom_dual',
    'DOBRO DE ADRENALINA',
    '2 loops separados por curvas no chão e uma reta elevada.',
    'QUARTO',
    0xffff6845,
    0xff8b674d,
    0xff455574,
    twins,
  );
  final piston = _LoopCircuit()
    ..p(-690, -610, 6)
    ..p(-540, -610, 6)
    ..p(-420, -610, 6)
    ..loop(-250, -610, const V3(1, 0, 0), radius: 60)
    ..p(-100, -694, 6)
    ..p(110, -650, 3)
    ..p(350, -490)
    ..p(590, -550)
    ..p(640, -340)
    ..p(450, -190)
    ..p(260, -90)
    ..p(360, 130)
    ..p(580, 240)
    ..p(540, 430)
    ..p(300, 410)
    ..p(100, 230)
    ..p(-100, 230)
    ..p(-260, 410)
    ..p(-490, 420)
    ..p(-580, 200)
    ..p(-410, 30)
    ..p(-300, -140)
    ..p(-460, -280)
    ..p(-670, -400, 6);
  add(
    'garage_piston',
    'PISTÃO INVERTIDO',
    '1 loop transversal, retorno da bancada e slalom entre caixas.',
    'GARAGEM',
    0xff45dbc6,
    0xff586470,
    0xff2b394e,
    piston,
  );
  final ignition = _LoopCircuit()
    ..p(-640, -710, 6)
    ..p(-640, -530, 6)
    ..p(-640, -420, 6)
    ..loop(-640, -260, const V3(0, 0, 1), radius: 64)
    ..p(-556, -100, 6)
    ..p(-540, 80)
    ..p(-430, 360)
    ..p(-190, 420)
    ..p(10, 250)
    ..p(230, 390)
    ..p(440, 430, 3)
    ..p(620, 400, 6)
    ..p(620, 270, 6)
    ..loop(620, 100, const V3(0, 0, -1), radius: 58)
    ..p(536, -40, 6)
    ..p(510, -240, 3)
    ..p(330, -400)
    ..p(110, -200)
    ..p(-80, -250)
    ..p(-140, -500)
    ..p(-340, -680)
    ..p(-510, -720);
  add(
    'garage_dual',
    'DUPLA COMBUSTÃO',
    '2 loops opostos e curvas de frenagem forte.',
    'GARAGEM',
    0xff63e0ba,
    0xff5e6872,
    0xff303d50,
    ignition,
  );
  final vortex = _LoopCircuit()
    ..p(-650, -690, 6)
    ..p(-650, -520, 6)
    ..p(-650, -410, 6)
    ..loop(-650, -250, const V3(0, 0, 1), radius: 56)
    ..p(-566, -100, 6)
    ..p(-500, 50, 3)
    ..p(-340, 170)
    ..p(-390, 400)
    ..p(-140, 430)
    ..p(30, 250)
    ..p(230, 140)
    ..p(310, 380)
    ..p(530, 400)
    ..p(590, 160)
    ..p(460, -60)
    ..p(530, -320)
    ..p(580, -570)
    ..p(350, -690, 6)
    ..p(120, -620, 6)
    ..p(90, -380, 6)
    ..p(-120, -320, 6)
    ..p(-250, -540, 6)
    ..p(-460, -700, 6);
  add(
    'bathroom_vortex',
    'VÓRTICE DO AZULEJO',
    '1 loop, piso escorregadio e retornos junto à banheira.',
    'BANHEIRO',
    0xff8de8f0,
    0xffc0dddc,
    0xff91b7c9,
    vortex,
  );
  final recipe = _LoopCircuit()
    ..p(-680, -600, 6)
    ..p(-530, -600, 6)
    ..p(-420, -600, 6)
    ..loop(-260, -600, const V3(1, 0, 0), radius: 58)
    ..p(-100, -684, 6)
    ..p(100, -650, 3)
    ..p(330, -500)
    ..p(500, -310)
    ..p(360, -80)
    ..p(130, -80)
    ..p(-80, -220)
    ..p(-300, -120)
    ..p(-530, 50)
    ..p(-520, 310)
    ..p(-320, 420)
    ..p(-80, 390)
    ..p(110, 240)
    ..p(290, 400)
    ..p(460, 420, 3)
    ..p(620, 400, 6)
    ..p(620, 260, 6)
    ..loop(620, 90, const V3(0, 0, -1), radius: 62)
    ..p(536, -70, 6)
    ..p(610, -290, 6)
    ..p(620, -570, 6)
    ..p(420, -770, 6)
    ..p(100, -790, 6)
    ..p(-220, -790, 6)
    ..p(-520, -770, 6)
    ..p(-700, -720, 6);
  add(
    'kitchen_dual',
    'RECEITA EM DOSE DUPLA',
    '2 loops em eixos diferentes, miolo técnico e reta da despensa.',
    'COZINHA',
    0xffffc768,
    0xffd7c6a2,
    0xffa0b8c1,
    recipe,
  );
  final orbit = _LoopCircuit()
    ..p(-660, -710, 6)
    ..p(-660, -540, 6)
    ..p(-660, -430, 6)
    ..loop(-660, -270, const V3(0, 0, 1), radius: 66)
    ..p(-576, -110, 6)
    ..p(-570, 80, 3)
    ..p(-520, 340)
    ..p(-300, 420)
    ..p(-100, 260)
    ..p(140, 260)
    ..p(380, 430)
    ..p(600, 360)
    ..p(610, 120)
    ..p(460, -40)
    ..p(280, 30)
    ..p(180, -160)
    ..p(310, -350)
    ..p(530, -490)
    ..p(470, -690, 6)
    ..p(220, -710, 6)
    ..p(10, -560, 3)
    ..p(-230, -600)
    ..p(-450, -710, 6);
  add(
    'living_orbit',
    'ÓRBITA DO SOFÁ',
    '1 loop alto e uma órbita longa pelo chão da sala.',
    'SALA',
    0xffe9b877,
    0xff927052,
    0xff7d90a3,
    orbit,
  );
  final neon = _LoopCircuit()
    ..p(-690, -630, 6)
    ..p(-540, -630, 6)
    ..p(-420, -630, 6)
    ..loop(-250, -630, const V3(1, 0, 0), radius: 64)
    ..p(-90, -714, 6)
    ..p(150, -680, 3)
    ..p(380, -510)
    ..p(620, -400)
    ..p(620, -130)
    ..p(440, 60)
    ..p(580, 300)
    ..p(530, 430, 6)
    ..p(420, 430, 6)
    ..loop(260, 430, const V3(-1, 0, 0), radius: 58)
    ..p(100, 514, 6)
    ..p(-100, 450, 3)
    ..p(-160, 260)
    ..p(-20, 40)
    ..p(-180, -130)
    ..p(-370, -40)
    ..p(-470, 190)
    ..p(-650, 290)
    ..p(-700, 30)
    ..p(-570, -230)
    ..p(-690, -440, 6);
  add(
    'arcade_dual',
    'NEON 360 ×2',
    '2 loops opostos, esses e combate no salão neon.',
    'ARCADE',
    0xffcf84f0,
    0xff202640,
    0xff19213b,
    neon,
  );
  return tracks;
}
