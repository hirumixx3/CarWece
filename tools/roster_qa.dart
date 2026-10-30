import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main() {
  final track = createTracks().first;
  for (final car in cars) {
    final e = RaceEngine(
      track: track,
      car: car,
      mode: RaceMode.timeTrial,
      laps: 1,
    )..countdown = 0;
    for (var i = 0; i < 180 * 120 && !e.finished; i++) {
      final c = e.aiControls(e.player);
      e.steering = c.$1;
      e.accelerating = c.$2;
      e.brake = c.$3;
      e.update(1 / 120);
      if (!e.player.wheelAngles.every((v) => v.isFinite) ||
          !e.player.steeringAngle.isFinite)
        throw StateError('${car.id}: invalid wheel state');
    }
    stdout.writeln(
      '${car.id}: finished=${e.finished} t=${e.time.toStringAsFixed(1)} checkpoints=${e.player.completedLaps * TrackSpec.checkpointCount}',
    );
    if (!e.finished)
      throw StateError('${car.id}: did not finish reference lap');
  }
}
