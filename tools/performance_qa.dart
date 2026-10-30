import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';

// Host CPU microbenchmark. These timings are NOT Android FPS measurements.
void main(List<String> args) {
  final tracks = createTracks(), arenas = createBattleArenas();
  final cases = <RaceEngine>[
    RaceEngine(track: tracks.first, car: cars.first, seed: 71),
    RaceEngine(track: tracks.last, car: cars[8], difficulty: 'hard', seed: 72),
    BattleEngine(arena: arenas[1], car: cars.first, seed: 73),
  ];
  final rows = <Map<String, Object>>[];
  for (final race in cases) {
    race.countdown = 0;
    final samples = <int>[], physics = <int>[];
    var checksum = 0.0;
    final watch = Stopwatch();
    for (var i = 0; i < 1800; i++) {
      watch.reset();
      watch.start();
      if (race is BattleEngine) {
        // Keep all six participants alive for the full measured workload.
        for (final f in race.fighters.values) f.health = 100000;
      }
      final input = race.aiControls(race.player);
      race.steering = input.$1;
      race.accelerating = input.$2;
      race.brake = input.$3;
      if (race is BattleEngine) race.triggerHeld = true;
      race.update(1 / 60);
      if (race.finished) throw StateError('Benchmark ended before all samples');
      final updateUs = watch.elapsedMicroseconds;
      final frame = raceGpuFrame(race);
      final totalUs = watch.elapsedMicroseconds;
      watch.stop();
      checksum += frame[0] + frame[2] + frame[14];
      if (i >= 300) {
        samples.add(totalUs);
        physics.add(updateUs);
      }
    }
    samples.sort();
    physics.sort();
    rows.add({
      'case': race.track.id,
      'battle': race is BattleEngine,
      'samples': samples.length,
      'median_us': samples[samples.length ~/ 2],
      'p95_us': samples[(samples.length * .95).floor()],
      'mean_us': samples.reduce((a, b) => a + b) / samples.length,
      'physics_median_us': physics[physics.length ~/ 2],
      'checksum': checksum,
    });
  }
  final result = {
    'scope':
        'Host Dart CPU, 60 simulation updates/sec plus frame serialization; not device FPS',
    'cases': rows,
  };
  final output = args.isEmpty
      ? 'verification/performance_v0122.json'
      : args.first;
  File(
    output,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(jsonEncode(result));
}
