import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';

void main() {
  final tracks = createTracks(), first = tracks.first;
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

  void arm(RaceEngine e, {Driver? driver}) {
    final d = driver ?? e.player, path = e.track.shortcuts.single;
    e.placeDriver(d, path.entryS + 1, 0);
    pose(d, path.gate);
    e.update(1 / 120);
    expect(d.activeShortcut, same(path), reason: e.track.id);
    expect(d.shortcutStage, 2, reason: e.track.id);
  }

  test(
    'Every existing shortcut arms at the physical gate without the old entrance portal',
    () {
      expect(tracks.length, 76);
      for (final t in shortcutTracks) {
        final e = race(t), path = t.shortcuts.single;
        arm(e);
        expect(e.navigationFrame(e.player).p, same(path.exit.p));
        expect(e.player.distance, greaterThan(path.entryS), reason: t.id);
        expect(e.events.where((x) => x == 'shortcut'), isEmpty);
      }
    },
  );
  test(
    'Every existing shortcut finishes exactly when the end is crossed, without intermediate portals',
    () {
      for (final t in shortcutTracks) {
        final e = race(t), path = t.shortcuts.single;
        arm(e);
        pose(e.player, path.exit);
        e.update(1 / 120);
        expect(e.shortcut, isFalse, reason: t.id);
        expect(e.player.shortcutStage, 4, reason: t.id);
        expect(e.player.nextCheckpoint, path.exitCheckpoint + 1, reason: t.id);
        expect(
          e.player.distance,
          greaterThanOrEqualTo(path.exitS),
          reason: t.id,
        );
        expect(e.player.completedLaps, 0);
        expect(e.events.where((x) => x == 'shortcut').length, 1, reason: t.id);
        expect(
          e.navigationFrame(e.player).s,
          t.checkpoint(path.exitCheckpoint + 1).s,
        );
      }
    },
  );
  test(
    'Passing only the last few metres before the exit does not complete early',
    () {
      final e = race(first), path = first.shortcuts.single;
      arm(e);
      pose(e.player, path.exit, along: -6, speed: 10);
      e.update(1 / 120);
      expect(e.player.activeShortcut, same(path));
      expect(e.player.shortcutStage, 2);
      expect(e.player.nextCheckpoint, lessThanOrEqualTo(path.exitCheckpoint));
      expect(e.events.where((x) => x == 'shortcut'), isEmpty);
    },
  );
  test(
    'The merge accepts a wide legitimate line beyond the narrow branch width',
    () {
      for (final t in tracks.where((t) => t.outdoor).take(5)) {
        final e = race(t), path = t.shortcuts.single;
        arm(e);
        final side = t.widthAt(path.exitS) / 2 - 4;
        expect(side, greaterThan(path.width / 2 + Driver.halfWidth + 3));
        pose(e.player, path.exit, side: side);
        e.update(1 / 120);
        expect(e.player.nextCheckpoint, path.exitCheckpoint + 1, reason: t.id);
        expect(e.shortcut, isFalse);
      }
    },
  );
  test(
    'A jump over an old intermediate portal cannot leave the branch unfinished',
    () {
      final e = race(first), path = first.shortcuts.single;
      arm(e);
      pose(e.player, path.portal(2), along: 12, height: 12);
      e.update(1 / 120);
      expect(e.player.activeShortcut, same(path));
      expect(e.player.shortcutStage, 2);
      pose(e.player, path.exit, height: 12);
      e.update(1 / 120);
      expect(e.player.nextCheckpoint, path.exitCheckpoint + 1);
    },
  );
  test(
    'Crossing the exit without a proven gate cannot credit skipped checkpoints',
    () {
      final e = race(first), path = first.shortcuts.single;
      e.placeDriver(e.player, path.entryS + 1, 0);
      final expected = e.player.nextCheckpoint;
      pose(e.player, path.exit);
      e.update(1 / 120);
      expect(e.player.nextCheckpoint, expected);
      expect(e.shortcut, isFalse);
      expect(e.events.where((x) => x == 'shortcut'), isEmpty);
    },
  );
  test('Crossing the gate backwards does not arm the branch', () {
    final e = race(first), path = first.shortcuts.single;
    e.placeDriver(e.player, path.entryS + 1, 0);
    pose(e.player, path.gate, along: .05, speed: -50);
    e.update(1 / 120);
    expect(e.player.shortcutStage, 1);
    expect(e.shortcut, isFalse);
  });
  test('Returning backwards through the gate revokes the attempt', () {
    final e = race(first), path = first.shortcuts.single;
    arm(e);
    pose(e.player, path.gate, along: .05, speed: -50);
    e.update(1 / 120);
    expect(e.shortcut, isFalse);
    pose(e.player, path.exit);
    e.update(1 / 120);
    expect(e.player.nextCheckpoint, lessThanOrEqualTo(path.exitCheckpoint));
    expect(e.events.where((x) => x == 'shortcut'), isEmpty);
  });
  test(
    'A gate in an unrelated sector cannot skip the earlier main checkpoints',
    () {
      final e = race(first), path = first.shortcuts.single;
      e.placeDriver(e.player, 0, 0);
      pose(e.player, path.gate);
      e.update(1 / 120);
      expect(e.player.nextCheckpoint, 1);
      expect(e.shortcut, isFalse);
    },
  );
  test(
    'Leaving the branch corridor invalidates gate proof before rejoining',
    () {
      final e = race(first), path = first.shortcuts.single;
      arm(e);
      pose(e.player, path.at(path.length * .65), side: 100);
      e.update(1 / 120);
      expect(e.shortcut, isFalse);
      pose(e.player, path.exit);
      e.update(1 / 120);
      expect(e.player.nextCheckpoint, lessThanOrEqualTo(path.exitCheckpoint));
    },
  );
  test('The physical closed gate still blocks an ordinary grounded car', () {
    final e = RaceEngine(
      track: first,
      car: cars.first,
      mode: RaceMode.timeTrial,
    )..countdown = 0;
    final path = first.shortcuts.single;
    e.placeDriver(e.player, path.entryS + 1, 0);
    pose(e.player, path.gate, along: -10, speed: 80);
    e.accelerating = true;
    for (var i = 0; i < 60; i++) e.update(1 / 120);
    expect(e.brokenGates, isEmpty);
    expect(e.player.shortcutStage, lessThan(2));
    expect(
      (e.player.position! - path.gate.p).dot(path.gate.forward),
      lessThan(0),
    );
  });
  test(
    'Completing a shortcut advances standings immediately, not only the marker',
    () {
      final e = race(first), path = first.shortcuts.single;
      final other = Driver('RIVAL', cars[1], 1, path.exitS - 30, 0);
      e.bots.add(other);
      e.placeDriver(other, path.exitS - 30, 0);
      arm(e);
      pose(e.player, path.exit);
      e.update(1 / 120);
      expect(e.player.distance, greaterThan(other.distance));
      expect(e.position, 1);
      final rewardCount = e.events.where((x) => x == 'shortcut').length;
      for (var i = 0; i < 10; i++) e.update(1 / 120);
      expect(e.events.where((x) => x == 'shortcut').length, rewardCount);
    },
  );
  test(
    'The host validates every online driver and snapshots retain gate proof and completion',
    () {
      final people = [for (var i = 0; i < 2; i++) NetworkParticipant('P$i', i)];
      final e = race(first)
        ..configureNetwork(people)
        ..countdown = 0;
      final view = race(first)
        ..configureNetwork(people, local: 1)
        ..countdown = 0;
      final d = e.networkDrivers[1], path = first.shortcuts.single;
      arm(e, driver: d);
      NetworkSnapshot.apply(
        view,
        jsonDecode(jsonEncode(NetworkSnapshot.capture(e))),
      );
      expect(view.player.activeShortcut?.id, path.id);
      expect(view.player.shortcutStage, 2);
      expect(view.navigationFrame(view.player).s, path.exit.s);
      pose(d, path.exit);
      e.update(1 / 120);
      NetworkSnapshot.apply(
        view,
        jsonDecode(jsonEncode(NetworkSnapshot.capture(e))),
      );
      expect(view.player.nextCheckpoint, path.exitCheckpoint + 1);
      expect(view.player.activeShortcut, isNull);
      expect(view.player.distance, greaterThanOrEqualTo(path.exitS));
      expect(view.player.completedLaps, 0);
    },
  );
}
