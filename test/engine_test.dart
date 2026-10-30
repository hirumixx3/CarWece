import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/platform.dart';

void main() {
  final tracks = createTracks();
  RaceEngine engine({
    RaceMode mode = RaceMode.quick,
    String difficulty = 'normal',
  }) => RaceEngine(
    track: tracks.first,
    car: cars.first,
    mode: mode,
    difficulty: difficulty,
  )..autoAccelerate = true;
  void advance(RaceEngine e, double time, [int hz = 60]) {
    for (var i = 0; i < (time * hz).round(); i++) {
      e.update(1 / hz);
    }
  }

  test('All twelve circuits have finite, continuous, orthonormal frames', () {
    for (final track in tracks) {
      expect(track.length, greaterThan(500));
      for (final f in track.frames) {
        expect(f.p.x.isFinite && f.p.y.isFinite && f.p.z.isFinite, isTrue);
        expect(f.right.length, closeTo(1, 1e-6));
        expect(f.up.length, closeTo(1, 1e-6));
        expect(f.forward.dot(f.right), closeTo(0, 1e-6));
        expect(f.forward.dot(f.up), closeTo(0, 1e-6));
      }
      expect((track.at(-.01).p - track.at(.01).p).length, lessThan(.05));
      expect(track.at(-.01).right.dot(track.at(.01).right), greaterThan(.98));
    }
    expect(
      tracks.first.frames.any((f) => f.up.y < -.9),
      isTrue,
      reason: 'A vertical loop must invert the driving frame.',
    );
  });
  test(
    'Countdown holds cars, then automatic acceleration moves the player',
    () {
      final e = engine();
      advance(e, 3);
      expect(e.player.distance, -62);
      for (var i = 0; i < 180; i++) {
        e.steering = e.aiControls(e.player).$1;
        e.update(1 / 60);
      }
      expect(e.player.distance, greaterThan(0));
      expect(e.player.speed, greaterThan(30));
    },
  );
  test('Physics gives the same result at 30, 60 and 120 FPS', () {
    final a = engine(), b = engine(), c = engine();
    advance(a, 18, 30);
    advance(b, 18, 60);
    advance(c, 18, 120);
    expect(a.player.distance, closeTo(b.player.distance, .01));
    expect(a.player.distance, closeTo(c.player.distance, .01));
    expect(a.nitro, closeTo(c.nitro, .01));
  });
  test('Pausing freezes the clock and clears held controls', () {
    final e = engine(mode: RaceMode.timeTrial);
    advance(e, 6);
    e.boosting = true;
    e.steering = 1;
    e.setPaused(true);
    final s = e.player.distance, time = e.time;
    advance(e, 4);
    expect(e.player.distance, s);
    expect(e.time, time);
    expect(e.boosting, isFalse);
    expect(e.steering, 0);
    e.setPaused(false);
    advance(e, 1);
    expect(e.player.distance, greaterThan(s));
  });
  test(
    'Manual acceleration, braking, walls, nitro and drift affect driving',
    () {
      final e = engine(mode: RaceMode.timeTrial)..autoAccelerate = false;
      advance(e, 5);
      expect(e.player.speed, 0);
      e.accelerating = true;
      advance(e, 4);
      final speed = e.player.speed;
      e.boosting = true;
      advance(e, 1);
      expect(e.nitro, lessThan(100));
      expect(e.player.speed, greaterThan(speed));
      e.boosting = false;
      e.driftPressed = true;
      e.steering = .6;
      advance(e, .2);
      expect(e.drifting, isTrue);
      e.driftPressed = false;
      e.steering = 1;
      advance(e, 3);
      expect(e.player.lane.abs(), lessThanOrEqualTo(.97));
    },
  );
  test('Items are collected once per pickup per lap', () {
    final e = engine();
    e.countdown = 0;
    e.player.distance = e.track.length * .09;
    e.player.lane = -.6;
    e.update(.02);
    expect(e.item, isNotNull);
    expect(e.collected, contains('0:0'));
    e.useItem();
    e.item = null;
    e.update(.02);
    expect(e.item, isNull);
  });
  test('All four items have functional effects and consume inventory', () {
    final e = engine();
    e.placeDriver(e.player, 0, 0);
    e.countdown = 0;
    e.item = ItemType.shield;
    e.useItem();
    expect(e.player.shield, 6);
    expect(e.item, isNull);
    e.item = ItemType.oil;
    e.useItem();
    expect(e.oil.length, 1);
    e.nitro = 5;
    e.item = ItemType.nitro;
    e.useItem();
    expect(e.nitro, 65);
    final target = e.bots.first;
    e.bots.removeRange(1, e.bots.length);
    target.distance = 45;
    target.lane = 0;
    target.speed = 0;
    e.item = ItemType.missile;
    e.nitro = 100;
    e.superchargeItem();
    e.useItem();
    expect(e.projectiles.length, 1);
    advance(e, .5);
    expect(e.hitCount, greaterThan(0));
  });
  test('Time trial excludes bots and weapons', () {
    final e = engine(mode: RaceMode.timeTrial);
    expect(e.bots, isEmpty);
    e.countdown = 0;
    e.player.distance = e.track.length * .09;
    e.player.lane = -.6;
    e.update(.02);
    expect(e.item, isNull);
  });
  test('Finishing records exactly three laps and a finite reward', () {
    final e = engine(mode: RaceMode.timeTrial);
    e.countdown = 0;
    for (var i = 0; i < 260 * 120 && !e.finished; i++) {
      final c = e.aiControls(e.player);
      e.steering = c.$1;
      e.accelerating = c.$2;
      e.brake = c.$3;
      e.update(1 / 120);
    }
    expect(e.finished, isTrue);
    expect(e.lapTimes.length, 3);
    expect(e.result, isNotNull);
    expect(e.result!.time.isFinite, isTrue);
    expect(e.result!.bestLap, greaterThan(0));
    expect(e.result!.coins, greaterThan(0));
    final time = e.time;
    advance(e, 1);
    expect(e.time, time);
  });
  test('A bot that finished earlier still ranks ahead at the finish line', () {
    final e = engine();
    e.countdown = 0;
    e.bots.first.distance = e.track.length * 3;
    e.bots.first.finishTime = 1;
    e.player.distance = e.track.length * 3 - .1;
    e.player.speed = 80;
    e.time = 50;
    e.lapTimes.addAll([15, 16]);
    e.lastLapTime = 31;
    e.update(.02);
    expect(e.finished, isTrue);
    expect(e.result!.position, 2);
    expect(e.standings.first, e.bots.first);
  });
  test('Visible boost pads provide an actual velocity impulse', () {
    final e = engine(mode: RaceMode.timeTrial)..countdown = 0;
    e.player.distance = e.track.length * .145;
    e.player.lane = 0;
    e.player.speed = 40;
    e.update(.02);
    expect(e.boostCount, 1);
    expect(e.player.speed, greaterThan(95));
  });
  test(
    'Settings restore clamps invalid input; records and car purchases persist in the store model',
    () async {
      final s = GameSettings()
        ..restore({
          'music': 99,
          'effects': -2,
          'difficulty': 'invalid',
          'camera': -10,
        });
      expect(s.music, 1);
      expect(s.effects, 0);
      expect(s.difficulty, 'normal');
      expect(s.cameraDistance, .8);
      final store = GameStore();
      expect(store.buyCar(cars[7]), isFalse);
      store.coins = 600;
      expect(store.buyCar(cars[7]), isTrue);
      expect(store.coins, 100);
      expect(store.ownedCars, contains('ek9'));
      store.record(
        tracks.first,
        const RaceResult(1, 60, 19, 150, 0, 0),
        RaceMode.quick,
      );
      store.record(
        tracks.first,
        const RaceResult(2, 70, 20, 100, 0, 0),
        RaceMode.quick,
      );
      expect(store.records[store.recordKey(tracks.first, RaceMode.quick)], 60);
      expect(store.coins, 350);
      expect(store.wins, 1);
      await store.save();
      store.dispose();
    },
  );
  test('Hitch cap prevents a paused app from fast-forwarding physics', () {
    final e = engine();
    advance(e, 8);
    final d = e.player.distance;
    e.update(5);
    expect(e.player.distance - d, lessThan(12));
  });
  test('Time formatting and vector rotation preserve useful invariants', () {
    expect(formatTime(65.123), '1:05.12');
    final v = const V3(0, 1, 0).rotate(const V3(1, 0, 0), math.pi);
    expect(v.y, closeTo(-1, 1e-8));
  });
}
