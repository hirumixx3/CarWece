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
      laps: 1,
    )..countdown = 0;
    var gate = e.player.nextCheckpoint, unchanged = 0.0;
    for (var i = 0; i < 120 * 240 && !e.finished; i++) {
      final input = e.aiControls(e.player);
      e.steering = input.$1;
      e.accelerating = input.$2;
      e.brake = input.$3;
      e.update(1 / 120);
      if (e.player.nextCheckpoint != gate) {
        gate = e.player.nextCheckpoint;
        unchanged = 0;
      } else {
        unchanged += 1 / 120;
      }
      if (unchanged > 12) {
        stdout.writeln(
          '${track.id} STALLED t=${e.time.toStringAsFixed(1)} gate=$gate s=${e.player.routeS} speed=${e.player.speed} pos=${e.player.position!.x},${e.player.position!.y},${e.player.position!.z}',
        );
        break;
      }
    }
    stdout.writeln(
      '${track.id}: length=${track.length.toStringAsFixed(0)} finished=${e.finished} t=${e.time.toStringAsFixed(1)} gate=$gate floor=${track.frames.where((f) => track.isFloor(f.s)).length}/${track.frames.length} upMin=${track.frames.map((f) => f.up.y).reduce((a, b) => a < b ? a : b)}',
    );
    var minEdge = double.infinity, postLoopMinUp = 1.0;
    for (final f in track.frames) {
      final y1 = f.point(-track.width / 2).y, y2 = f.point(track.width / 2).y;
      if (y1 < minEdge) minEdge = y1;
      if (y2 < minEdge) minEdge = y2;
      if (track.loopEnd != null &&
          f.s > track.loopEnd! + 10 &&
          f.up.y < postLoopMinUp)
        postLoopMinUp = f.up.y;
    }
    stdout.writeln('minEdgeY=$minEdge postLoopMinUp=$postLoopMinUp');
  }
}
