import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main() {
  for (final t in createTracks()) {
    final e = RaceEngine(track: t, car: cars.first, laps: 1)..countdown = 0;
    for (var i = 0; i < 120 * 180 && !e.finished; i++) {
      final c = e.aiControls(e.player);
      e.steering = c.$1;
      e.accelerating = c.$2;
      e.brake = c.$3;
      e.update(1 / 120);
    }
    stdout.writeln(
      '${t.id}: human finished=${e.finished} place=${e.position} time=${e.time.toStringAsFixed(1)}',
    );
    for (final d in e.bots) {
      stdout.writeln(
        '${d.name} progress=${(d.distance / t.length * 100).toStringAsFixed(1)}% gate=${d.nextCheckpoint} speed=${d.speed.toStringAsFixed(1)}',
      );
    }
  }
}
