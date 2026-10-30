import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main() {
  final rows = <Map<String, dynamic>>[];
  for (final a in createBattleArenas())
    for (var i = 0; i < a.track.loops.length; i++) {
      final loop = a.track.loops[i];
      final e = RaceEngine(
        track: a.track,
        car: cars.first,
        mode: RaceMode.timeTrial,
      )..countdown = 0;
      e.placeDriver(e.player, loop.start - 105, 0);
      e.player.speed = 94;
      e.player.velocity = e.player.forward! * 94;
      var crossed = false, fell = false, entered = false;
      for (var frame = 0; frame < 120 * 25; frame++) {
        final c = e.aiControls(e.player);
        e.steering = c.$1;
        e.accelerating = c.$2;
        e.brake = c.$3;
        e.update(1 / 120);
        if (e.player.routeS >= loop.start && e.player.routeS <= loop.end)
          entered = true;
        if (entered && e.player.airborne) fell = true;
        if (entered && e.player.routeS > loop.end + 25 && !e.player.airborne) {
          crossed = true;
          break;
        }
      }
      final r = {
        'arena': a.track.id,
        'loop': i + 1,
        'crossed': crossed,
        'fell': fell,
        'time': e.time,
        'speed': e.player.speed,
        'finalS': e.player.routeS,
        'start': loop.start,
        'end': loop.end,
      };
      rows.add(r);
      stdout.writeln(jsonEncode(r));
    }
  File(
    'verification/battle_fast_loops_v0121.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  if (rows.any((r) => r['crossed'] != true || r['fell'] == true))
    throw StateError('An arena loop failed the driving check');
}
