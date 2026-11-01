import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/gpu_mesh.dart';

void main() {
  final tracks = createTracks();
  final arenas = createBattleArenas();
  final report = <String, Object>{
    'cars': cars.length,
    'tracks': tracks.length,
    'arenas': arenas.length,
    'circuits': <Object>[],
    'battle': <Object>[],
  };
  for (final t in tracks.skip(26)) {
    final data = {
      'id': t.id,
      'length': t.length,
      'shortcuts': t.shortcuts.length,
      'loops': t.loops.length,
      'props': t.details.length,
      'ramps': t.ramps.length,
      'species': t.details
          .where((p) => ['rex', 'triceratops', 'sauropod'].contains(p.kind))
          .map((p) => p.kind)
          .toSet()
          .toList(),
    };
    (report['circuits'] as List).add(data);
    stdout.writeln(jsonEncode(data));
  }
  for (final a in arenas.skip(6)) {
    final data = {
      'id': a.track.id,
      'nav': a.nav.length,
      'supplies': a.supplies.length,
      'spawns': a.spawns.length,
      'health': a.health.length,
      'props': a.track.details.length,
      'ramps': a.track.ramps.length,
    };
    (report['battle'] as List).add(data);
    stdout.writeln(jsonEncode(data));
  }
  final hashes = <int>{};
  for (final car in cars.skip(31)) {
    final mesh = buildCarMesh(car).buffer;
    if (!mesh.every((n) => n.isFinite)) throw StateError('Nonfinite ${car.id}');
    hashes.add(Object.hashAll(mesh));
  }
  report['distinctNewCarMeshes'] = hashes.length;
  final out = File('build/worlds_probe.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
}
