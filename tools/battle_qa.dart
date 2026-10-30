import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';

void main(List<String> args) {
  final duration = args.isEmpty ? 300 : double.parse(args.first);
  final report = <Map<String, dynamic>>[];
  final arenas = createBattleArenas();
  for (final level in ['easy', 'normal', 'hard'])
    for (final a in arenas) {
      final e = BattleEngine(
        arena: a,
        car: cars.first,
        difficulty: level,
        seed: 91 + a.index,
      )..countdown = 0;
      final states = <String, Set<String>>{
        for (final d in e.drivers) d.name: {},
      };
      // Reference human follows the same physical steering controller as opponents.
      for (var i = 0; i < duration * 120 + 240 && !e.finished; i++) {
        final controls = e.aiControls(e.player);
        e.steering = controls.$1;
        e.accelerating = controls.$2;
        e.brake = controls.$3;
        e.update(1 / 120);
        for (final d in e.drivers) {
          final p = d.position!;
          if (!p.x.isFinite || !p.y.isFinite || !p.z.isFinite)
            throw StateError('Non-finite driver');
          if (p.x.abs() > 871 || p.z.abs() > 871)
            throw StateError('Escaped arena');
          states[d.name]!.add('${(p.x / 100).floor()}:${(p.z / 100).floor()}');
        }
      }
      final row = {
        'arena': a.track.id,
        'difficulty': level,
        'time': e.time,
        'finished': e.finished,
        'kills': e.drivers.fold<int>(0, (sum, d) => sum + e.fighters[d]!.kills),
        'survivors': e.living.length,
        'escapeAttempts': {
          for (final d in e.drivers) d.name: e.fighters[d]!.escapeAttempts,
        },
        'health': [for (final d in e.drivers) e.fighters[d]!.health],
        'traversedCells': {
          for (final d in e.drivers) d.name: states[d.name]!.length,
        },
        'shots': e.drivers.fold<int>(0, (sum, d) => sum + e.fighters[d]!.shots),
        'damage': e.drivers.fold<double>(
          0,
          (sum, d) => sum + e.fighters[d]!.damageDealt,
        ),
        'finalPositions': [
          for (final d in e.drivers)
            [d.position!.x, d.position!.y, d.position!.z],
        ],
      };
      report.add(row);
      stdout.writeln(jsonEncode(row));
    }
  final out = File('verification/battle_simulation_v012.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  if (report.any((r) => (r['shots'] as int) < 5))
    throw StateError('A battle produced too few attacks');
  if (duration >= 300 && report.any((r) => r['finished'] != true))
    throw StateError('Battle did not terminate');
}
