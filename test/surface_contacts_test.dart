import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/math3d.dart';

TrackSpec surfaceTrack(double height) {
  final t = TrackSpec(
    'contact_$height',
    'CONTATO',
    '',
    'TESTE',
    0xffee8844,
    0xff777777,
    0xff333333,
    [
      V3(-600, height, -600),
      V3(600, height, -600),
      V3(600, height, 600),
      V3(-600, height, 600),
    ],
    openArena: true,
    width: 52,
  );
  t.obstacles.clear();
  t.ramps.clear();
  return t;
}

void step(RaceEngine e, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) e.update(1 / 120);
}

RaceEngine carAt(TrackSpec t, V3 p, V3 heading, double speed) {
  final e = RaceEngine(track: t, car: cars.first, mode: RaceMode.timeTrial)
    ..countdown = 0;
  e.placeDriver(e.player, 0, 0);
  e.player.position = p;
  e.player.forward = heading;
  e.player.normal = const V3(0, 1, 0);
  e.player.speed = speed;
  e.player.velocity = heading * speed;
  return e;
}

TrackFrame straight(TrackSpec t) =>
    t.frames.reduce((a, b) => a.forward.x.abs() < b.forward.x.abs() ? a : b);

void main() {
  for (final side in [-1.0, 1.0])
    test(
      'Outside road rail blocks side $side without pulling car onto deck',
      () {
        final t = surfaceTrack(3), f = straight(t), w = t.width / 2;
        final p = f.point(side * (w + 16));
        final e = carAt(t, V3(p.x, .16, p.z), f.right * -side, 100);
        step(e, .4);
        expect(
          t.project(e.player.position!).lateral * side,
          greaterThan(w + 3.4),
        );
        expect(e.player.position!.y, closeTo(.16, .02));
        expect(e.driverFrame(e.player).p.y, closeTo(.16, .02));
        expect(e.effects, isNotEmpty);
      },
    );
  test(
    'Inside rail retains a car without letting it cross to the exterior',
    () {
      final t = surfaceTrack(3), f = straight(t), w = t.width / 2;
      final e = carAt(t, f.point(w - 9), f.right, 80);
      step(e, .35);
      expect(t.project(e.player.position!).lateral, lessThan(w - 3.5));
      expect(e.player.position!.y, closeTo(3, .03));
    },
  );
  test('Driving under an elevated bridge never snaps up to the deck', () {
    final t = surfaceTrack(20), f = straight(t), p = f.point(t.width / 2 + 15);
    final e = carAt(t, V3(p.x, .16, p.z), f.right * -1, 65);
    step(e, .7);
    expect(e.player.position!.y, closeTo(.16, .02));
    expect(e.player.airborne, isFalse);
    expect(t.project(e.player.position!).lateral.abs(), lessThan(t.width / 2));
  });
  test('A car can land from above and hits the underside from below', () {
    final t = surfaceTrack(20), f = straight(t);
    final landing = carAt(t, f.point(0, 8), f.forward, 0);
    landing.player.airborne = true;
    landing.player.velocity = const V3(0, -20, 0);
    step(landing, .5);
    expect(landing.player.airborne, isFalse);
    expect(landing.player.position!.y, closeTo(20, .05));
    final underneath = carAt(t, f.point(0, -4), f.forward, 0);
    underneath.player.airborne = true;
    underneath.player.velocity = const V3(0, 15, 0);
    step(underneath, .2);
    expect(underneath.player.position!.y, lessThan(17.1));
    expect(underneath.player.velocity.y, lessThan(0));
  });
  WorldRamp addRamp(TrackSpec t) {
    final r = WorldRamp(
      const TrackFrame(V3(0, .16, 0), V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1), 0),
      width: 20,
      length: 40,
      height: 8,
    );
    t.ramps.add(r);
    return r;
  }

  test(
    'Ramp sides and back are solid and never grant top contact from outside',
    () {
      final t = surfaceTrack(.16), r = addRamp(t);
      for (final side in [-1.0, 1.0]) {
        final e = carAt(t, V3(side * 22, .16, 10), V3(-side, 0, 0), 80);
        step(e, .4);
        expect(e.player.position!.x * side, greaterThan(r.width / 2 + 3.4));
        expect(e.player.activeRamp, isNull);
        expect(e.driverFrame(e.player).p.y, closeTo(.16, .02));
      }
      final back = carAt(t, const V3(0, .16, 32), const V3(0, 0, -1), 80);
      step(back, .4);
      expect(back.player.position!.z, greaterThan(r.length / 2 + 3.4));
      expect(back.player.activeRamp, isNull);
      expect(back.player.position!.y, closeTo(.16, .02));
    },
  );
  test(
    'Ramp entrance climbs continuously, launches at the lip and permits a top landing',
    () {
      final t = surfaceTrack(.16), r = addRamp(t);
      final e = carAt(t, const V3(0, .16, -28), const V3(0, 0, 1), 60)
        ..accelerating = true;
      var climbed = false, launched = false;
      var previous = e.player.position!;
      for (var i = 0; i < 120; i++) {
        e.update(1 / 120);
        climbed |= e.player.activeRamp == r && e.player.position!.y > 4;
        launched |= e.player.airborne;
        expect((e.player.position! - previous).length, lessThan(1.5));
        previous = e.player.position!;
      }
      expect(climbed, isTrue);
      expect(launched, isTrue);
      expect(e.events, contains('jump'));
      final landing = carAt(t, const V3(0, 15, 0), const V3(0, 0, 1), 0);
      landing.player.airborne = true;
      landing.player.velocity = const V3(0, -15, 0);
      step(landing, .65);
      expect(landing.player.activeRamp, r);
      expect(landing.player.position!.y, closeTo(4.16, .5));
    },
  );
}
