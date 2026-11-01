import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main() {
  final tracks = createTracks(), results = <Map<String, Object>>[];
  void lap(TrackSpec track, CarSpec car, String kind) {
    final e = RaceEngine(
      track: track,
      car: car,
      mode: RaceMode.timeTrial,
      laps: 1,
    )..countdown = 0;
    for (var i = 0; i < 240 * 120 && !e.finished; i++) {
      final controls = e.aiControls(e.player);
      e.steering = controls.$1;
      e.accelerating = controls.$2;
      e.brake = controls.$3;
      e.update(1 / 120);
      if (!e.player.position!.length.isFinite)
        throw StateError('Nonfinite motion');
    }
    final result = <String, Object>{
      'kind': kind,
      'track': track.id,
      'car': car.id,
      'finished': e.finished,
      'seconds': e.time,
      'distance': e.player.distance,
      'recoveries': e.player.aiRecoveries,
    };
    results.add(result);
    stdout.writeln(jsonEncode(result));
  }

  for (final track in tracks.skip(26)) lap(track, cars.first, 'track');
  for (final car in cars.skip(31)) lap(tracks.first, car, 'car');
  final output = File('build/worlds_drive_qa.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  if (results.any((r) => r['finished'] != true)) exitCode = 1;
}
