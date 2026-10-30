import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

/// Same cars, seeds, tracks and finish conditions before/after the tuning.
void main(List<String> args) {
  final tracks = createTracks();
  final rows = <Map<String, Object>>[];
  stdout.writeln('Starting difficulty comparison');
  for (final track in tracks.where(
    (t) => ['garage', 'bathroom_hairpin'].contains(t.id),
  )) {
    for (final car in [cars.first, cars[10]]) {
      for (final difficulty in ['easy', 'normal', 'hard']) {
        for (final seed in [42, 84]) {
          final e = RaceEngine(
            track: track,
            car: car,
            difficulty: difficulty,
            laps: 1,
            seed: seed,
          )..countdown = 0;
          e.placeDriver(e.player, -100, 0);
          for (
            var i = 0;
            i < 120 * 210 && e.bots.any((d) => d.finishTime == null);
            i++
          )
            e.update(1 / 120);
          final times =
              e.bots
                  .where((d) => d.finishTime != null)
                  .map((d) => d.finishTime!)
                  .toList()
                ..sort();
          final row = <String, Object>{
            'track': track.id,
            'car': car.id,
            'difficulty': difficulty,
            'seed': seed,
            'finished': times.length,
            'median': times.length == 5 ? times[2] : 210.0,
            'last': times.isEmpty ? 210.0 : times.last,
            'recoveries': e.bots.fold<int>(0, (sum, d) => sum + d.aiRecoveries),
            'rivalCars': e.bots.map((d) => d.car.id).toList(),
          };
          rows.add(row);
          stdout.writeln(jsonEncode(row));
        }
      }
    }
  }
  if (args.isNotEmpty)
    File(args.first).writeAsStringSync('${jsonEncode(rows)}\n');
  if (rows.any((r) => r['finished'] != 5))
    throw StateError('Incomplete comparison race');
}
