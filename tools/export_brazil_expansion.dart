import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/math3d.dart';

/// Export actual production meshes, not generated concept illustrations.
void main() {
  final root = Directory('build/brasil_visual_qa')..createSync(recursive: true);
  final proof = Directory('verification/brasil_loops')
    ..createSync(recursive: true);
  final frames = <Map<String, Object>>[];
  void binary(String name, Float32List data) =>
      File('${root.path}/$name.bin').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  binary('showroom', GpuResources.showroom);
  final meshes = GpuResources.objectsFor({0, ...brazilCars.map((c) => c.body)});
  for (var i = 0; i < meshes.length; i++) binary('object_$i', meshes[i]);
  for (final name in ['scene.vert', 'scene.frag', 'depth.vert', 'depth.frag'])
    File('assets/shaders/$name').copySync('${root.path}/$name');
  for (final car in brazilCars) {
    frames.add({
      'name': car.id,
      'world': 'showroom',
      'showroom': true,
      'night': false,
      'frame': garageGpuFrame(car, -.69).toList(),
    });
    if (['br_fusca', 'br_saveiro', 'br_gurgel'].contains(car.id))
      frames.add({
        'name': '${car.id}_traseira',
        'world': 'showroom',
        'showroom': true,
        'night': false,
        'frame': garageGpuFrame(car, 2.45).toList(),
      });
  }
  final tracks = createTracks(), added = tracks.skip(51).toList();
  void shot(String name, RaceEngine e, V3 eye, V3 focus) {
    final frame = raceGpuFrame(e);
    frame.setRange(0, 3, [eye.x, eye.y, eye.z]);
    frame.setRange(3, 6, [focus.x, focus.y, focus.z]);
    frame.setRange(6, 9, [0.0, 1.0, 0.0]);
    frame.setRange(10, 13, [focus.x, focus.y, focus.z]);
    frames.add({
      'name': name,
      'world': e.track.id,
      'showroom': false,
      'night': e.track.night,
      'frame': frame.toList(),
    });
  }

  for (final room in tracks.map((t) => t.room).toSet()) {
    final t = added.firstWhere((t) => t.room == room);
    binary(t.id, GpuResources.world(t));
    final loop = t.loops.single, f = t.at(loop.start), end = t.at(loop.end);
    final center = (f.p + end.p) * .5 + const V3(0, 58, 0);
    final race = RaceEngine(
      track: t,
      car: brazilCars.first,
      mode: RaceMode.timeTrial,
    )..countdown = 0;
    race.placeDriver(race.player, loop.start - 35, 0);
    shot(
      'loop_${t.id}',
      race,
      center + f.right * 170 - f.forward * 140 + const V3(0, 45, 0),
      center,
    );
  }
  for (final room in expansionBiomes.keys) {
    final t = tracks.skip(26).take(25).firstWhere((t) => t.room == room);
    binary(t.id, GpuResources.world(t));
    final race = RaceEngine(
      track: t,
      car: brazilCars.first,
      mode: RaceMode.timeTrial,
    )..countdown = 0;
    final f = t.themedObstacles.first.frame;
    race.placeDriver(race.player, f.s - 25, 0);
    shot(
      'piso_${t.id}',
      race,
      f.p - f.forward * 70 + const V3(0, 48, 0),
      f.p + f.forward * 25,
    );
  }
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(frames));
  File('${proof.path}/catalogo.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'carros': [
        for (final c in brazilCars)
          {
            'id': c.id,
            'nome': c.name,
            'indice': c.body,
            'classe': c.performanceClass,
            'categoria': c.modelCategory,
            'moedas': c.cost,
            'estrelas': c.requiredStars,
          },
      ],
      'pistas': [
        for (final t in added)
          {
            'id': t.id,
            'nome': t.name,
            'ambiente': t.room,
            'loops': t.loops.length,
            'largura': t.width,
            'comprimento': t.length,
            'estrelas': t.requiredStars,
            'atalhos': t.shortcuts.length,
            'obstaculos_tematicos': t.themedObstacles.length,
          },
      ],
    }),
  );
  stdout.writeln(
    'Exported ${frames.length} production views: 28 cars, 11 loops and 5 natural floors.',
  );
}
