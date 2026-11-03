import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_mesh.dart';
import '../lib/game/gpu_frame.dart';

// Real production geometry and gameplay. No mocks or Android performance claims.
Future<void> main(List<String> args) async {
  final root = Directory(args.isEmpty ? 'build/memory_tracks_qa' : args.first)
    ..createSync(recursive: true);
  final tracks = createTracks().skip(51).toList();
  final frames = <Map<String, Object>>[], rows = <Map<String, Object>>[];
  void binary(String name, Float32List data) =>
      File('${root.path}/$name.bin').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  final bodies = <int>{};
  for (final t in tracks) {
    final race = RaceEngine(track: t, car: cars.first);
    bodies.addAll(race.drivers.map((d) => d.car.body));
  }
  final objects = GpuResources.objectsFor(bodies);
  for (var i = 0; i < objects.length; i++) binary('object_$i', objects[i]);
  for (final s in ['scene.vert', 'scene.frag', 'depth.vert', 'depth.frag']) {
    File('assets/shaders/$s').copySync('${root.path}/$s');
  }
  for (var i = 0; i < tracks.length; i++) {
    final index = i + 51;
    // Each worker exits, so boxed mesh-builder temporaries cannot accumulate.
    final data = await Isolate.run(
      () => buildWorldMesh(createTracks()[index]).buffer,
    );
    if (data.isEmpty ||
        data.length % 36 != 0 ||
        !data.every((v) => v.isFinite)) {
      throw StateError('Invalid mesh: ${tracks[i].id}');
    }
    binary(tracks[i].id, data);
    final t = tracks[i], race = RaceEngine(track: tracks[i], car: cars.first);
    final active = GpuResources.objectsFor({
      for (final d in race.drivers) d.car.body,
    });
    final row = <String, Object>{
      'id': t.id,
      'name': t.name,
      'room': t.room,
      'triangles': data.length ~/ 36,
      'worldBytes': data.lengthInBytes,
      'activeObjectsBytes': active.fold<int>(0, (n, v) => n + v.lengthInBytes),
      'loops': t.loops.length,
      'checkpoints': TrackSpec.checkpointCount,
    };
    rows.add(row);
    for (final point in <String, double>{
      'start': 0,
      'loop': t.loops.single.start - 35,
    }.entries) {
      race.placeDriver(race.player, point.value, 0);
      frames.add({
        'name': '${t.id}_${point.key}',
        'world': t.id,
        'showroom': false,
        'night': t.night,
        'frame': raceGpuFrame(race).toList(),
      });
    }
    stdout.writeln(jsonEncode(row));
  }
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(frames));
  File(
    '${root.path}/tracks.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
}
