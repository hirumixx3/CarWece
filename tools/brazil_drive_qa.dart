import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main(List<String> args) {
  final tracks = createTracks(), newTracks = tracks.skip(51).toList();
  final results = <Map<String, Object>>[];
  void lap(TrackSpec t, CarSpec c, String kind) {
    final e = RaceEngine(track: t, car: c, mode: RaceMode.timeTrial, laps: 1)
      ..countdown = 0;
    for (var i = 0; i < 180 * 120 && !e.finished; i++) {
      final control = e.aiControls(e.player);
      e.steering = control.$1;
      e.accelerating = control.$2;
      e.brake = control.$3;
      e.update(1 / 120);
      if (!e.player.position!.length.isFinite)
        throw StateError('Nonfinite state');
    }
    final record = <String, Object>{
      'kind': kind,
      'track': t.id,
      'car': c.id,
      'finished': e.finished,
      'seconds': e.time,
      'distance': e.player.distance,
      'routeS': e.player.routeS,
      'checkpoint': e.player.nextCheckpoint,
      'recoveries': e.player.aiRecoveries,
    };
    results.add(record);
    stdout.writeln(jsonEncode(record));
  }

  for (final t in newTracks) {
    if (args.isNotEmpty && !args.contains(t.id)) continue;
    lap(t, cars.first, 'new_track');
    lap(t, brazilCars[newTracks.indexOf(t)], 'national_on_new_loop');
  }
  if (args.isEmpty) {
    for (final c in brazilCars) lap(tracks.first, c, 'national_on_legacy_loop');
  }
  final out = File('verification/brasil_loops/voltas_simuladas.json')
    ..parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  if (results.any((r) => r['finished'] != true)) exitCode = 1;
}
