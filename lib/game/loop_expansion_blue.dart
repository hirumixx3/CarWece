part of 'content.dart';

/// Fifty toy-blue playset circuits: bright blue plastic ribbon with orange
/// rails, every one with two or three full vertical loops. Appended after
/// the first 76 circuit indices, which are intentionally left untouched.
/// The star costs live in [brazilLoopStars] so the shared progression and
/// obstacle population treat these like the other Brazil loop circuits.
const _blueLoopSpecs = <(String, String, String, int)>[
  // id, name, room, loop count
  ('blue_canopy', 'DOSSEL AZUL', 'FLORESTA', 2),
  ('blue_river', 'CURVA DO RIO AZUL', 'FLORESTA', 3),
  ('blue_falls', 'VÉU DA QUEDA', 'FLORESTA', 2),
  ('blue_monkey', 'SALTO DO MACACO', 'FLORESTA', 3),
  ('blue_vines', 'TEIA DE CIPÓS', 'FLORESTA', 2),
  ('blue_jaguar', 'RONCO DA ONÇA', 'FLORESTA', 3),
  ('blue_bones', 'FÓSSIL AZUL', 'PRÉ-HISTÓRIA', 2),
  ('blue_lava', 'CALDEIRA AZUL', 'PRÉ-HISTÓRIA', 3),
  ('blue_rex', 'PEGADA DO REX', 'PRÉ-HISTÓRIA', 2),
  ('blue_fern', 'SAMAMBAIA GIGANTE', 'PRÉ-HISTÓRIA', 3),
  ('blue_meteor', 'CRATERA AZUL', 'PRÉ-HISTÓRIA', 2),
  ('blue_mirage', 'MIRAGEM AZUL', 'DESERTO', 3),
  ('blue_dune', 'DUNA ELÉTRICA', 'DESERTO', 2),
  ('blue_oasis', 'OÁSIS NEON', 'DESERTO', 3),
  ('blue_cactus', 'ESPINHO DO DESERTO', 'DESERTO', 2),
  ('blue_canyon', 'FENDA AZUL', 'DESERTO', 3),
  ('blue_aurora', 'AURORA BOREAL', 'NEVE', 2),
  ('blue_glacier', 'GELEIRA VIVA', 'NEVE', 3),
  ('blue_pine', 'PINHEIRO CONGELADO', 'NEVE', 2),
  ('blue_storm', 'TEMPESTADE DE GELO', 'NEVE', 3),
  ('blue_iceberg', 'ILHA DE GELO', 'NEVE', 2),
  ('blue_wave', 'ONDA GIGANTE', 'LITORAL', 3),
  ('blue_reef', 'RECIFE AZUL', 'LITORAL', 2),
  ('blue_lighthouse', 'FAROL DOURADO', 'LITORAL', 3),
  ('blue_tide', 'MARÉ ALTA', 'LITORAL', 2),
  ('blue_coral', 'JARDIM DE CORAL', 'LITORAL', 3),
  ('blue_harbor', 'PORTO AZUL', 'LITORAL', 2),
  ('blue_desk', 'MESA DE ESTUDOS', 'QUARTO', 3),
  ('blue_books', 'TORRE DE LIVROS', 'QUARTO', 2),
  ('blue_bed', 'BEIRA DA CAMA', 'QUARTO', 3),
  ('blue_toys', 'CAIXA DE BRINQUEDOS', 'QUARTO', 2),
  ('blue_window', 'JANELA ABERTA', 'QUARTO', 3),
  ('blue_bench', 'BANCADA AZUL', 'GARAGEM', 2),
  ('blue_tires', 'TORRE DE PNEUS', 'GARAGEM', 3),
  ('blue_tools', 'PAINEL DE FERRAMENTAS', 'GARAGEM', 2),
  ('blue_lift', 'ELEVADOR TRASEIRO', 'GARAGEM', 3),
  ('blue_shelf', 'PRATELEIRA ALTA', 'GARAGEM', 2),
  ('blue_neon', 'NEON TRIPLO', 'ARCADE', 3),
  ('blue_pixels', 'CHUVA DE PIXELS', 'ARCADE', 2),
  ('blue_joystick', 'ALAVANCA DOURADA', 'ARCADE', 3),
  ('blue_token', 'CHUVA DE FICHAS', 'ARCADE', 2),
  ('blue_screen', 'TELA FINAL', 'ARCADE', 3),
  ('blue_tiles', 'AZULEJO VIVO', 'BANHEIRO', 2),
  ('blue_bubbles', 'CHUVA DE BOLHAS', 'BANHEIRO', 3),
  ('blue_mirror', 'ESPELHO MOLHADO', 'BANHEIRO', 2),
  ('blue_faucet', 'TORNEIRA ABERTA', 'BANHEIRO', 3),
  ('blue_recipe', 'LIVRO DE RECEITAS', 'COZINHA', 2),
  ('blue_stove', 'BOCA DO FOGÃO', 'COZINHA', 3),
  ('blue_fridge', 'PORTA DA GELADEIRA', 'COZINHA', 2),
  ('blue_counter', 'BALCÃO AZUL', 'COZINHA', 3),
];

List<TrackSpec> createBlueLoopTracks() {
  final result = <TrackSpec>[];
  for (var i = 0; i < _blueLoopSpecs.length; i++) {
    final spec = _blueLoopSpecs[i];
    final room = spec.$3, loopCount = spec.$4;
    // Parametric rounded circuit: a superellipse with a gentle radial
    // wobble, so every layout is a simple, non-self-intersecting toy track.
    // Aspect, corner exponent and start phase step by mutually coprime
    // strides, so no two of the fifty silhouettes repeat or nearly repeat:
    // long ovals, round rings, tall ovals, boxy and pointed variants.
    const n = 16;
    final aspect = .88 + ((i * 37) % 29) / 100;
    final rx = 552.0 * aspect, rz = 500.0 / aspect;
    final exponent = 1.85 + ((i * 7) % 10) / 10;
    final phase0 = (i * 2.399963) % (math.pi * 2);
    // Two radial harmonics on top of the oval: any positive polar radius
    // stays a simple closed curve, and the lobes give every circuit an
    // authored, blobby silhouette (bays, bulges and straights) instead of
    // fifty copies of the same oval.
    final a1 = .10 + ((i * 13) % 11) / 100, f1 = 2 + i % 2;
    final a2 = .04 + ((i * 17) % 7) / 100, f2 = 3 + (i >> 1) % 3;
    final p1 = (i * 1.13) % (math.pi * 2), p2 = (i * 2.71) % (math.pi * 2);
    // The whole circuit also sits off-center by a per-track offset, like a
    // playset laid out wherever it fit on the floor.
    final cx = ((i * 29) % 7 - 3) * 10.0, cz = ((i * 43) % 7 - 3) * 10.0;
    double spow(double c) {
      final v = math.pow(c.abs(), 2 / exponent).toDouble();
      return c < 0 ? -v : v;
    }

    final verts = <V3>[];
    for (var k = 0; k < n; k++) {
      final a = phase0 + k / n * math.pi * 2;
      final r = 1 + a1 * math.sin(a * f1 + p1) + a2 * math.sin(a * f2 + p2);
      verts.add(
        V3(
          cx + spow(math.cos(a)) * rx * r,
          TrackSpec.floorHeight,
          cz + spow(math.sin(a)) * rz * r,
        ),
      );
    }
    final loopAt = loopCount == 3
        ? const {3, 8, 12}
        : (i.isEven ? const {4, 11} : const {5, 12});
    final route = _LoopCircuit();
    for (var k = 0; k < n; k++) {
      final p = verts[k];
      if (!loopAt.contains(k)) {
        route.p(p.x, p.z);
        continue;
      }
      final prev = verts[(k - 1 + n) % n], next = verts[(k + 1) % n];
      final raw = next - prev;
      final fwd = V3(raw.x, 0, raw.z).unit;
      final right = const V3(0, 1, 0).cross(fwd).unit;
      route.p(p.x - fwd.x * 70, p.z - fwd.z * 70, 6);
      route.loop(p.x, p.z, fwd, radius: 54 + (i % 3) * 5.0);
      // The loop exit is offset 84 units along `right`; bridge back onto
      // the circuit's flow with a raised exit and a descent point.
      final exitX = p.x + right.x * 84, exitZ = p.z + right.z * 84;
      route.p(exitX + fwd.x * 55, exitZ + fwd.z * 55, 6);
      route.p(exitX + fwd.x * 130, exitZ + fwd.z * 130);
    }
    final angle = (i % 4) * math.pi / 2 + [0.0, .18, -.18, .30][(i ~/ 8) % 4];
    final mirror = i % 8 >= 4 ? -1.0 : 1.0;
    V3 orient(V3 p) => V3(
      (p.x * mirror * math.cos(angle) - p.z * math.sin(angle)) * .94,
      p.y,
      (p.x * mirror * math.sin(angle) + p.z * math.cos(angle)) * .94,
    );
    final t = TrackSpec(
      spec.$1,
      spec.$2,
      loopCount == 3
          ? 'Pista azul de brinquedo com três loops verticais completos.'
          : 'Pista azul de brinquedo com dois loops verticais completos.',
      room,
      0xff35a7ff,
      0xff1449c8,
      0xff7fb2ff,
      route.points.map(orient).toList(),
      width: 46,
      loopSections: [
        for (final s in route.sections)
          LoopSection(s.first, s.last, orient(s.right).unit * mirror),
      ],
      blueTrack: true,
    );
    if (t.outdoor) {
      final baseObstacles = t.obstacles.length;
      populateExpansionObstacles(t, i);
      if (t.themedObstacles.length < 3) {
        // With three loops the ramp's launch corridor sterilizes too much
        // of a short lap; retry without it so the theme still shows.
        t.themedObstacles.clear();
        t.obstacles.removeRange(baseObstacles, t.obstacles.length);
        t.ramps.clear();
        populateExpansionObstacles(t, i);
      }
    } else {
      // Same reasoning as the Brazil loops: the loops are the stunt here;
      // the generic floor ramp can launch a car into a closed shortcut gate.
      t.ramps.clear();
    }
    result.add(t);
  }
  return result;
}
