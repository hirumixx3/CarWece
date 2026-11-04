import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';

// Regression coverage for the "shortcut does not complete and the driver
// loses a lap" bug: attempts must arm and finish by physical presence in
// the branch corridor and at the merge, not only by crossing the exact
// entrance, gate and exit planes.
void main() {
  final tracks = createTracks();
  final shortcutTracks = tracks.where((t) => t.shortcuts.isNotEmpty).toList();

  RaceEngine race(TrackSpec t) {
    final e = RaceEngine(track: t, car: cars.first, mode: RaceMode.timeTrial)
      ..countdown = 0;
    e.breakGate(t.shortcuts.single.id);
    return e;
  }

  void pose(
    Driver d,
    TrackFrame f, {
    double along = -.05,
    double side = 0,
    double height = 0,
    double speed = 80,
  }) {
    d.position = f.point(side, height) + f.forward * along;
    d.forward = f.forward;
    d.normal = f.up;
    d.speed = speed;
    d.velocity = f.forward * speed;
    d.airborne = height > 3;
    d.activeRamp = null;
    d.jump = 0;
  }

  void armAtGate(RaceEngine e) {
    final d = e.player, path = e.track.shortcuts.single;
    e.placeDriver(d, path.entryS + 1, 0);
    pose(d, path.gate);
    e.update(1 / 120);
    expect(d.activeShortcut, same(path), reason: e.track.id);
    expect(d.shortcutStage, 2, reason: e.track.id);
  }

  bool driveToCompletion(RaceEngine e, ShortcutSpec path) {
    for (var i = 0; i < 120 * 30; i++) {
      final c = e.aiControls(e.player);
      e.steering = c.$1;
      e.accelerating = c.$2;
      e.brake = c.$3;
      e.update(1 / 120);
      if (e.player.nextCheckpoint ==
              (path.exitCheckpoint + 1) % TrackSpec.checkpointCount &&
          !e.shortcut) {
        return true;
      }
    }
    return false;
  }

  test('Entering the branch past the gate arms the attempt by presence', () {
    for (final t in shortcutTracks) {
      final e = race(t), path = t.shortcuts.single;
      e.placeDriver(e.player, path.entryS + 1, 0);
      pose(e.player, path.at(path.length * .7), speed: 60);
      e.update(1 / 120);
      expect(e.player.activeShortcut, same(path), reason: t.id);
      expect(e.player.shortcutStage, 2, reason: t.id);
    }
  });

  test('A shortcut entered in the middle still completes at the exit', () {
    for (final t in shortcutTracks) {
      final e = race(t), path = t.shortcuts.single;
      e.placeDriver(e.player, path.entryS + 1, 0);
      pose(e.player, path.at(path.length * .7), speed: 60);
      expect(driveToCompletion(e, path), isTrue, reason: t.id);
      expect(e.player.completedLaps, 0, reason: t.id);
      expect(e.events.where((x) => x == 'shortcut').length, 1, reason: t.id);
    }
  });

  test('Entering the branch corridor backwards does not arm it', () {
    final t = shortcutTracks.first, e = race(t), path = t.shortcuts.single;
    e.placeDriver(e.player, path.entryS + 1, 0);
    pose(e.player, path.at(path.length * .7), speed: -50);
    e.update(1 / 120);
    expect(e.player.activeShortcut, isNull);
    expect(e.player.shortcutStage, 1);
  });

  test('Rejoining the main road past the exit completes an armed shortcut', () {
    for (final t in shortcutTracks) {
      final e = race(t), path = t.shortcuts.single;
      armAtGate(e);
      pose(e.player, t.at(path.exitS + 8), speed: 60);
      e.update(1 / 120);
      expect(
        e.player.nextCheckpoint,
        (path.exitCheckpoint + 1) % TrackSpec.checkpointCount,
        reason: t.id,
      );
      expect(e.shortcut, isFalse, reason: t.id);
      expect(e.player.shortcutStage, 4, reason: t.id);
      expect(e.player.completedLaps, 0, reason: t.id);
    }
  });

  test(
    'Rejoining the main road before the exit abandons the attempt safely',
    () {
      final t = shortcutTracks.first, e = race(t), path = t.shortcuts.single;
      armAtGate(e);
      final before = e.player.nextCheckpoint;
      pose(e.player, t.at((path.entryS + path.exitS) / 2), speed: 60);
      e.update(1 / 120);
      e.update(1 / 120);
      expect(e.player.activeShortcut, isNull);
      expect(e.player.shortcutStage, 1);
      // The checkpoints of the skipped span are still ahead on the main road,
      // so progress can continue without losing a lap.
      expect(e.player.nextCheckpoint, before);
      expect(e.player.completedLaps, 0);
    },
  );
}
