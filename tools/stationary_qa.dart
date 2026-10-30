import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main() {
  final rows = <Map<String, dynamic>>[];
  for (final track in createTracks()) {
    for (final mode in [RaceMode.quick, RaceMode.timeTrial]) {
      final e = RaceEngine(track: track, car: cars.first, mode: mode)
        ..countdown = 0;
      e.bots.clear();
      e.driverFrame(e.player);
      final d = e.player, p = d.position!, startS = d.routeS;
      e.steering = 1;
      for (var i = 0; i < 360; i++) e.update(1 / 120);
      final idle = (d.position! - p).length;
      e.steering = 0;
      e.accelerating = true;
      for (var i = 0; i < 90; i++) e.update(1 / 120);
      rows.add({
        'track': track.id,
        'mode': mode.name,
        'idleMoved': idle,
        'launchSpeed': d.speed,
        'startS': startS,
        'finalS': d.routeS,
        'lane': d.lane,
        'position': [d.position!.x, d.position!.y, d.position!.z],
        'airborne': d.airborne,
        'normal': d.normal!.y,
      });
    }
    final samples = track.frames
        .where(
          (f) =>
              !track.isFloor(f.s) && f.up.y > .995 && f.forward.y.abs() < .025,
        )
        .toList();
    for (var j = 0; j < samples.length; j += 40) {
      final f = samples[j],
          e = RaceEngine(
            track: track,
            car: cars.first,
            mode: RaceMode.timeTrial,
          )..countdown = 0;
      e.placeDriver(e.player, f.s, .5);
      final p = e.player.position!;
      e.steering = 1;
      for (var i = 0; i < 240; i++) e.update(1 / 120);
      final idle = (e.player.position! - p).length;
      e.steering = 0;
      e.accelerating = true;
      for (var i = 0; i < 60; i++) e.update(1 / 120);
      rows.add({
        'track': track.id,
        'mode': 'stop',
        'idleMoved': idle,
        'launchSpeed': e.player.speed,
        'startS': f.s,
        'finalS': e.player.routeS,
        'lane': e.player.lane,
        'normal': e.player.normal!.y,
        'slope': f.forward.y,
      });
    }
  }
  File(
    'verification/stationary_v0121.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  for (final row in rows.where(
    (r) => (r['idleMoved'] as double) > .5 || (r['launchSpeed'] as double) < 5,
  ))
    stdout.writeln(jsonEncode(row));
  stdout.writeln('Checked ${rows.length} cases.');
}
