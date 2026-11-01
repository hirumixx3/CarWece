import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/platform.dart';

void main() {
  final tracks = createTracks();
  RaceEngine floorCar([double speed = 45]) {
    final e = RaceEngine(
      track: tracks.first,
      car: cars.first,
      mode: RaceMode.timeTrial,
    )..countdown = 0;
    e.player.speed = speed;
    e.placeDriver(e.player, tracks.first.length * .5, 0);
    e.player.position = const V3(0, TrackSpec.floorHeight, 0);
    e.player.forward = const V3(0, 0, 1);
    e.player.normal = const V3(0, 1, 0);
    e.player.velocity = V3(0, 0, speed);
    return e;
  }

  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) {
      e.update(1 / 120);
    }
  }

  test(
    'Neutral steering preserves the world heading instead of following a curve',
    () {
      final e = floorCar()..accelerating = true;
      final heading = e.player.forward!;
      advance(e, 1.2);
      expect(e.player.forward!.dot(heading), greaterThan(.99999));
      expect(e.player.position!.x, closeTo(0, .0001));
      expect(e.player.position!.z, greaterThan(40));
    },
  );
  test(
    'Left and right turn the body and its actual world trajectory in opposite directions',
    () {
      final left = floorCar()
        ..accelerating = true
        ..steering = -.65;
      final right = floorCar()
        ..accelerating = true
        ..steering = .65;
      advance(left, .75);
      advance(right, .75);
      expect(left.player.position!.x, lessThan(-5));
      expect(right.player.position!.x, greaterThan(5));
      expect(left.player.forward!.x, lessThan(-.4));
      expect(right.player.forward!.x, greaterThan(.4));
      expect(raceGpuFrame(right).every((v) => v.isFinite), isTrue);
    },
  );
  test(
    'Floor driving stays free outside the circuit corridor and never recenters the car',
    () {
      final e = floorCar()..accelerating = true;
      expect(
        e.track.project(e.player.position!).lateral.abs(),
        greaterThan(e.track.width / 2),
      );
      advance(e, .5);
      expect(e.player.position!.x, closeTo(0, .001));
      expect(e.player.position!.y, closeTo(TrackSpec.floorHeight, .001));
      expect(e.player.position!.z, greaterThan(20));
    },
  );
  test('Holding the accelerator alone cannot complete a lap', () {
    final e =
        RaceEngine(
            track: tracks.first,
            car: cars.first,
            mode: RaceMode.timeTrial,
            laps: 1,
          )
          ..countdown = 0
          ..accelerating = true;
    advance(e, 90);
    expect(e.finished, isFalse);
    expect(e.player.completedLaps, 0);
  });
  test('Crossing the finish line after skipping gates never awards a lap', () {
    final e = floorCar(70);
    final gate = e.track.at(0);
    e.player.completedLaps = 0;
    e.player.nextCheckpoint = 1;
    e.player.started = true;
    e.player.position = gate.p - gate.forward * 3;
    e.player.forward = gate.forward;
    e.player.normal = gate.up;
    e.player.velocity = gate.forward * 70;
    advance(e, .12);
    expect(e.lapTimes, isEmpty);
    expect(e.player.completedLaps, 0);
    expect(e.finished, isFalse);
  });
  test('Solid room props stop the front bumper and produce an impact', () {
    final e = floorCar(60);
    final old = e.track.obstacles.toList();
    e.track.obstacles
      ..clear()
      ..add(const WorldObstacle(V3(0, 3, 16), V3(12, 6, 6)));
    advance(e, .4);
    expect(e.player.position!.z, lessThanOrEqualTo(9.21));
    expect(e.effects, isNotEmpty);
    expect(e.player.speed, lessThan(40));
    e.track.obstacles
      ..clear()
      ..addAll(old);
  });
  test(
    'All road edges stay above the floor and no roll leaks past the loop',
    () {
      for (final t in tracks) {
        expect(t.length, greaterThan(3500));
        expect(t.width, greaterThanOrEqualTo(42));
        var floorLength = 0.0;
        for (var s = 0.0; s < t.length; s += 5) {
          final f = t.at(s);
          expect(f.point(-t.width / 2).y, greaterThanOrEqualTo(.15));
          expect(f.point(t.width / 2).y, greaterThanOrEqualTo(.15));
          if (t.loopAt(s, after: 5) == null) expect(f.up.y, greaterThan(.98));
          if (t.isFloor(s)) floorLength += 5;
        }
        expect(floorLength / t.length, greaterThan(.3));
        expect(
          t.widthAt(t.frames.firstWhere((f) => t.isFloor(f.s)).s),
          t.outdoor ? greaterThan(t.width) : greaterThan(t.width * 2),
        );
        expect(
          t.obstacles.where((o) => o.visible).length,
          greaterThanOrEqualTo(3),
        );
      }
      final a = tracks.first.at(tracks.first.loopStart!),
          b = tracks.first.at(tracks.first.loopEnd!);
      expect((a.p - b.p).length, greaterThan(tracks.first.width + 20));
    },
  );
  test(
    'Braking at low speed engages reverse so the player can leave a wall',
    () {
      final e = floorCar(0)..brake = true;
      advance(e, 1.1);
      expect(e.player.speed, lessThan(-3));
      expect(e.player.position!.z, lessThan(-1));
    },
  );
  test(
    'Recovery returns to the last validated gate without completing skipped sectors',
    () {
      final e = floorCar();
      e.player.nextCheckpoint = 7;
      e.player.completedLaps = 1;
      e.resetPlayer();
      expect(e.player.nextCheckpoint, 7);
      expect(e.player.completedLaps, 1);
      expect(e.player.speed, 0);
      expect(
        (e.player.position! - e.track.checkpoint(6).p).length,
        lessThan(.01),
      );
    },
  );
  test(
    'A turn requires braking at speed: the bicycle model has a finite turning radius',
    () {
      final slow = floorCar(25)..steering = 1;
      final fast = floorCar(75)..steering = 1;
      advance(slow, .3);
      advance(fast, .3);
      final slowRadius =
          slow.player.speed.abs() /
          math.max(.001, slow.player.angularSpeed.abs());
      final fastRadius =
          fast.player.speed.abs() /
          math.max(.001, fast.player.angularSpeed.abs());
      expect(fastRadius, greaterThan(slowRadius * 1.3));
    },
  );
  test(
    'The ramp raises the body, launches it and lands it back on the real floor',
    () {
      final e =
          RaceEngine(
              track: tracks.first,
              car: cars.first,
              mode: RaceMode.timeTrial,
            )
            ..countdown = 0
            ..accelerating = true;
      final r = e.track.ramps.first, f = r.frame;
      e.player.speed = 60;
      e.placeDriver(e.player, f.s - 10, 0);
      e.player.position = f.p - f.forward * 10;
      e.player.forward = f.forward;
      e.player.normal = f.up;
      e.player.velocity = f.forward * 60;
      advance(e, .38);
      expect(e.events, contains('jump'));
      expect(e.player.airborne, isTrue);
      expect(e.driverFrame(e.player).p.y, greaterThan(3));
      advance(e, 1.6);
      expect(e.player.jump, 0);
      expect(e.player.position!.y, closeTo(TrackSpec.floorHeight, .03));
    },
  );
  test(
    'Cars waiting behind the start cannot appear one lap ahead when the race begins',
    () {
      final e = RaceEngine(track: tracks.first, car: cars.first)..countdown = 0;
      expect(e.position, 6);
      advance(e, .1);
      expect(e.position, 6);
      expect(e.bots.every((d) => d.distance < 0), isTrue);
    },
  );
  test('The chase camera follows the actual body heading on free floor', () {
    final e = floorCar();
    e.player.forward = const V3(1, 0, 0);
    e.player.velocity = const V3(45, 0, 0);
    final packet = raceGpuFrame(e);
    expect(packet[0], lessThan(e.player.position!.x - 10));
    expect(packet[3], greaterThan(e.player.position!.x + 10));
    expect(packet[2], closeTo(e.player.position!.z, .001));
  });
  test(
    'Longer layouts keep independent records while preserving old saved times',
    () async {
      final store = GameStore();
      store.records['bedroom:quick'] = 40;
      store.record(
        tracks.first,
        const RaceResult(1, 220, 70, 150, 0, 0),
        RaceMode.quick,
      );
      expect(store.records['bedroom:quick'], 40);
      expect(store.records[store.recordKey(tracks.first, RaceMode.quick)], 220);
      await store.save();
      store.dispose();
    },
  );
}
