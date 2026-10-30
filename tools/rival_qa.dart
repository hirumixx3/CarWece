import 'dart:math' as math;
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main(List<String> args) {
  final difficulty = args.contains('--hard')
      ? 'hard'
      : args.contains('--easy')
      ? 'easy'
      : 'normal';
  final selected = args.where((a) => !a.startsWith('--')).toList();
  for (final t in createTracks().where(
    (t) => selected.isEmpty || selected.contains(t.id),
  )) {
    final e = RaceEngine(
      track: t,
      car: cars.first,
      difficulty: difficulty,
      laps: 1,
    )..countdown = 0;
    e.placeDriver(e.player, -100, 0);
    var spread = 0.0, samples = 0, changes = 0;
    List<String>? last;
    for (
      var i = 0;
      i < 120 * 210 && e.bots.any((d) => d.finishTime == null);
      i++
    ) {
      e.update(1 / 120);
      if (i % 120 != 0) continue;
      final active = e.bots.where((d) => d.finishTime == null).toList();
      if (active.length > 2 && e.time > 4) {
        final x = active.map((d) => d.lane * t.width / 2).toList(),
            mean = x.reduce((a, b) => a + b) / x.length;
        spread += math.sqrt(
          x.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
              x.length,
        );
        samples++;
      }
      final order = e.standings
          .where((d) => d != e.player)
          .map((d) => d.name)
          .toList();
      if (last != null && order.join(',') != last.join(',')) changes++;
      last = order;
    }
    final complete = e.bots.where((d) => d.finishTime != null).length;
    final times =
        e.bots
            .where((d) => d.finishTime != null)
            .map((d) => d.finishTime!)
            .toList()
          ..sort();
    stdout.writeln(
      '$difficulty ${t.id}: finished=$complete/5 time=${e.time.toStringAsFixed(1)} median=${(times.length == 5 ? times[2] : 210).toStringAsFixed(1)} boost=${e.bots.fold<double>(0, (s, d) => s + d.boostSeconds).toStringAsFixed(1)} lateralStd=${(spread / math.max(1, samples)).toStringAsFixed(2)} orderChanges=$changes recoveries=${e.bots.map((d) => d.aiRecoveries).reduce((a, b) => a + b)} ${e.bots.map((d) => '${d.name}:${(d.distance / t.length * 100).toStringAsFixed(0)}').join(' ')}',
    );
    if (complete != 5) throw StateError('${t.id}: unfinished rivals');
    if (spread / math.max(1, samples) < 3)
      throw StateError('${t.id}: train-like lateral spread');
  }
}
