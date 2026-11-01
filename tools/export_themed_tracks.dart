import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/math3d.dart';

/// Actual game meshes and shaders for reviewing the new obstacle placements.
void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/themed_visual_qa' : args.first)
    ..createSync(recursive: true);
  void binary(String name, Float32List data) =>
      File('${root.path}/$name.bin').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  final frames = <Map<String, Object>>[];
  final tracks = createTracks().skip(26).toList();
  final meshes = [...GpuResources.objects, ...BattleGpuMeshes.objects];
  for (var i = 0; i < meshes.length; i++) binary('object_$i', meshes[i]);
  for (final name in ['scene.vert', 'scene.frag', 'depth.vert', 'depth.frag'])
    File('assets/shaders/$name').copySync('${root.path}/$name');
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
      'night': false,
      'frame': frame.toList(),
    });
  }

  for (final room in expansionBiomes.keys) {
    final t = tracks.firstWhere((t) => t.room == room);
    binary(t.id, GpuResources.world(t));
    final race = RaceEngine(track: t, car: cars.first, mode: RaceMode.timeTrial)
      ..countdown = 0;
    final obstacle = t.themedObstacles[1];
    final f = obstacle.frame;
    race.placeDriver(race.player, f.s - 24, 0);
    shot(
      '${t.id}_obstaculos',
      race,
      f.p - f.forward * 72 + const V3(0, 48, 0),
      f.p + f.forward * 25,
    );
    shot(
      '${t.id}_visao_geral',
      race,
      const V3(-940, 1160, -1200),
      const V3(0, 5, 0),
    );
    final close = t.themedObstacles.firstWhere(
      (o) => !['rock', 'sandrock'].contains(o.prop.kind),
    );
    final p = close.prop.center;
    race.placeDriver(race.player, close.frame.s - 17, 0);
    shot(
      '${t.id}_miniatura',
      race,
      p -
          close.frame.forward * 44 +
          close.frame.right * 26 +
          const V3(0, 27, 0),
      p,
    );
  }
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(frames));
  final catalog = [
    for (final t in tracks)
      {
        'id': t.id,
        'nome': t.name,
        'ambiente': t.room,
        'largura': t.width,
        'obstaculos': [
          for (final o in t.themedObstacles)
            {
              'tipo': o.prop.kind,
              'distancia': o.frame.s,
              'posicao': [o.prop.center.x, o.prop.center.y, o.prop.center.z],
            },
        ],
        'atalhos': t.shortcuts.length,
        'rampas': t.ramps.length,
        'loops': t.loops.length,
      },
  ];
  File('verification/pistas_tematicas/catalogo.json')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(catalog));
  stdout.writeln(
    'Exported ${frames.length} real GLES views and ${catalog.length} track records.',
  );
}
