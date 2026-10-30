import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main(List<String> args) {
  for (final track in createTracks().where(
    (t) => args.isEmpty || args.contains(t.id),
  )) {
    final e = RaceEngine(
      track: track,
      car: cars.first,
      mode: RaceMode.timeTrial,
    );
    var gate = 1, quiet = 0.0;
    for (var i = 0; i < 360 * 120 && !e.finished; i++) {
      final c = e.aiControls(e.player);
      e.steering = c.$1;
      e.accelerating = c.$2;
      e.brake = c.$3;
      e.update(1 / 120);
      if (gate != e.player.nextCheckpoint) {
        gate = e.player.nextCheckpoint;
        quiet = 0;
      } else {
        quiet += 1 / 120;
      }
      if (quiet > 12) {
        final d = e.player, p = track.project(d.position!);
        stdout.writeln(
          '${track.id} lap=${e.lap} time=${e.time} gate=$gate s=${d.routeS} pos=${d.position!.x},${d.position!.y},${d.position!.z} speed=${d.speed} air=${d.airborne} up=${d.normal!.x},${d.normal!.y},${d.normal!.z} projectionH=${p.height} lat=${p.lateral}',
        );
        for (final tri in track.roadCollision.near(d.position!)) {
          final n = tri.normal, center = d.position! + d.normal! * 1.4;
          final right = d.normal!.cross(d.forward!).unit;
          final radius =
              d.forward!.dot(n).abs() * 3.65 +
              right.dot(n).abs() * 1.95 +
              d.normal!.dot(n).abs() * 1.4;
          final h = (center - tri.a).dot(n);
          if (h < -.4 &&
              h + radius > -.8 &&
              tri.containsBody(center, d.forward!, right, d.normal!))
            stdout.writeln(
              'ceiling s=${tri.s} n=${n.x},${n.y},${n.z} center=$h roof=${h + radius}',
            );
        }
        break;
      }
    }
    stdout.writeln(
      '${track.id}: finished=${e.finished} laps=${e.lapTimes.length}',
    );
  }
}
