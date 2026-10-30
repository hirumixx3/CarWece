import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/math3d.dart';

void main() {
  final tracks = createTracks();
  final track = tracks.firstWhere((t) => t.shortcuts.isNotEmpty);

  RaceEngine race(TrackSpec t) =>
      RaceEngine(track: t, car: cars.first, mode: RaceMode.timeTrial)
        ..countdown = 0;

  bool driveShortcut(RaceEngine e, ShortcutSpec path, {bool jump = false}) {
    var lifted = false;
    for (var i = 0; i < 120 * 35; i++) {
      final c = e.aiControls(e.player);
      e.steering = c.$1;
      e.accelerating = c.$2;
      e.brake = c.$3;
      final s = path.project(e.player.position!).frame.s;
      if (jump &&
          !lifted &&
          e.shortcut &&
          s >= path.portal(1).s - 3 &&
          s < path.portal(1).s) {
        e.player.position = e.player.position! + const V3(0, 12, 0);
        e.player.airborne = true;
        lifted = true;
      }
      e.update(1 / 120);
      if (e.player.nextCheckpoint == path.exitCheckpoint + 1 && !e.shortcut)
        return !jump || lifted;
    }
    return false;
  }

  test(
    'A car starting on a checkpoint plane advances when it drives forward',
    () {
      final e = race(track), gate = track.checkpoint(1);
      e.player.speed = 40;
      e.placeDriver(e.player, gate.s, 0);
      e.player.nextCheckpoint = 1;
      e.accelerating = true;
      e.update(1 / 120);
      expect(e.player.nextCheckpoint, 2);
    },
  );

  test(
    'A shortcut accepts an already credited overlapping main checkpoint',
    () {
      final e = race(track), path = track.shortcuts.single;
      e.breakGate(path.id);
      e.player.speed = 40;
      e.placeDriver(e.player, path.entryS + 1, 0);
      e.player.nextCheckpoint = path.entryCheckpoint + 2;
      e.player.plannedShortcut = path;
      expect(driveShortcut(e, path), isTrue);
      expect(e.player.completedLaps, 0);
    },
  );

  test(
    'A legal jump inside the shortcut does not lose its checkpoint sequence',
    () {
      final e = race(track), path = track.shortcuts.single;
      e.breakGate(path.id);
      e.player.speed = 40;
      e.placeDriver(e.player, path.entryS - 15, 0);
      e.player.plannedShortcut = path;
      expect(driveShortcut(e, path, jump: true), isTrue);
      expect(e.player.completedLaps, 0);
    },
  );

  test(
    'A missed entry plane does not invalidate a correctly driven shortcut',
    () {
      final e = race(track), path = track.shortcuts.single;
      e.breakGate(path.id);
      e.player.speed = 40;
      e.placeDriver(e.player, path.entryS + 1, 0);
      e.player.nextCheckpoint = path.entryCheckpoint;
      e.player.plannedShortcut = path;
      expect(driveShortcut(e, path), isTrue);
    },
  );

  test('Crossing a checkpoint backwards does not grant progress', () {
    final e = race(track), gate = track.checkpoint(1);
    e.player.speed = -35;
    e.placeDriver(e.player, gate.s + .05, 0);
    e.player.nextCheckpoint = 1;
    for (var i = 0; i < 12; i++) {
      e.update(1 / 120);
    }
    expect(e.player.nextCheckpoint, 1);
    expect(e.player.completedLaps, 0);
  });

  test(
    'Every shortcut rejoins and completes the current lap without an extra lap',
    () {
      for (final t in tracks) {
        for (final path in t.shortcuts) {
          final e = race(t);
          e.breakGate(path.id);
          e.player.speed = 40;
          e.placeDriver(e.player, path.entryS - 15, 0);
          e.player.plannedShortcut = path;
          expect(driveShortcut(e, path), isTrue, reason: t.id);
          var traveled = 0.0;
          for (var i = 0; i < 120 * 180 && e.player.completedLaps == 0; i++) {
            final c = e.aiControls(e.player), before = e.player.position!;
            e.steering = c.$1;
            e.accelerating = c.$2;
            e.brake = c.$3;
            e.update(1 / 120);
            traveled += (e.player.position! - before).length;
          }
          expect(e.player.completedLaps, 1, reason: t.id);
          expect(
            traveled,
            lessThan(t.length - path.exitS + t.length * .20),
            reason: '${t.id} required an extra circuit after the shortcut',
          );
          expect(e.player.aiRecoveries, 0, reason: t.id);
        }
      }
    },
  );
}
