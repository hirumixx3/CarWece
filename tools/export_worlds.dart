import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/math3d.dart';

/// Real production meshes, shader sources and camera packets, not concept art.
void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/worlds_visual_qa' : args.first)
    ..createSync(recursive: true);
  void binary(String name, Float32List data) =>
      File('${root.path}/$name.bin').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  final frames = <Map<String, Object>>[],
      tracks = createTracks().skip(26).toList();
  binary('showroom', GpuResources.showroom);
  final meshes = [...GpuResources.objects, ...BattleGpuMeshes.objects];
  for (var i = 0; i < meshes.length; i++) binary('object_$i', meshes[i]);
  for (final shader in [
    'scene.vert',
    'scene.frag',
    'depth.vert',
    'depth.frag',
  ]) {
    File('assets/shaders/$shader').copySync('${root.path}/$shader');
  }
  for (final car in cars.skip(31)) {
    for (final angle in [-.69, 2.45]) {
      frames.add({
        'name': '${car.id}_${angle < 0 ? 'front' : 'rear'}',
        'world': 'showroom',
        'showroom': true,
        'night': false,
        'frame': garageGpuFrame(car, angle).toList(),
      });
    }
  }
  void shot(String name, RaceEngine e, V3 eye, V3 focus) {
    final f = raceGpuFrame(e);
    f.setRange(0, 3, [eye.x, eye.y, eye.z]);
    f.setRange(3, 6, [focus.x, focus.y, focus.z]);
    f.setRange(6, 9, [0.0, 1.0, 0.0]);
    f.setRange(10, 13, [focus.x, focus.y, focus.z]);
    frames.add({
      'name': name,
      'world': e.track.id,
      'showroom': false,
      'night': e.track.night,
      'frame': f.toList(),
    });
  }

  for (final room in expansionBiomes.keys) {
    final t = tracks.firstWhere((t) => t.room == room);
    binary(t.id, GpuResources.world(t));
    final race = RaceEngine(track: t, car: cars[31], mode: RaceMode.timeTrial)
      ..countdown = 0;
    race.placeDriver(race.player, t.length * .18, 0);
    final f = t.at(t.length * .18);
    shot(
      '${t.id}_track',
      race,
      f.p - f.forward * 90 + const V3(0, 64, 0),
      f.p + f.forward * 60,
    );
    shot(
      '${t.id}_overview',
      race,
      const V3(-940, 1160, -1200),
      const V3(0, 5, 0),
    );
    if (room == 'PRÉ-HISTÓRIA') {
      for (final species in ['rex', 'triceratops', 'sauropod']) {
        final prop = t.details.firstWhere((p) => p.kind == species),
            p = prop.center;
        shot('dinosaur_$species', race, p + const V3(-150, 65, 170), p);
      }
    }
  }
  for (final arena in createBattleArenas().skip(6)) {
    binary(arena.track.id, GpuResources.world(arena.track));
    final battle = BattleEngine(arena: arena, car: cars[42], freeRoam: true)
      ..countdown = 0;
    shot(
      '${arena.track.id}_battle',
      battle,
      const V3(-660, 700, -850),
      const V3(0, 20, 0),
    );
  }
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(frames));
  stdout.writeln('Exported ${frames.length} real GLES views');
}
