import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/math3d.dart';
import 'surface_contacts_test.dart' show surfaceTrack, straight, carAt, step;

TrackSpec descendingRoad() => TrackSpec(
  'descending_solid',
  'DESCIDA',
  '',
  'TESTE',
  0xffee8844,
  0xff777777,
  0xff333333,
  [
    const V3(-200, 35, -600),
    const V3(-200, 20, -300),
    const V3(-200, .16, 50),
    const V3(-200, .16, 500),
    const V3(500, .16, 500),
    const V3(500, 35, -600),
  ],
  openArena: true,
  width: 52,
);

void main() {
  test('An airborne car hits the vertical loop ribbon from its upper face', () {
    final t = createTracks().first;
    final loop = t.loops.first;
    final f = t.frames.firstWhere(
      (f) => f.s > loop.start && f.s < loop.end && f.up.y.abs() < .04,
    );
    final e = carAt(t, f.point(0, 8), f.right, 0);
    e.player.airborne = true;
    e.player.velocity = f.up * -300;
    for (var i = 0; i < 12; i++) {
      e.update(1 / 120);
      expect((e.player.position! - f.p).dot(f.up), greaterThan(.8));
    }
    expect(e.player.airborne, isTrue);
  });
  test(
    'A fast fall lands on the upper deck instead of tunnelling through it',
    () {
      final t = surfaceTrack(20), f = straight(t);
      final e = carAt(t, f.point(0, 3), f.forward, 0);
      e.player.airborne = true;
      e.player.velocity = const V3(0, -700, 0);
      e.update(1 / 120);
      expect(e.player.position!.y, greaterThanOrEqualTo(19.95));
      expect(e.player.airborne, isFalse);
    },
  );
  test('A falling upside-down body cannot pass through a lower deck', () {
    final t = surfaceTrack(20), f = straight(t);
    final e = carAt(t, f.point(0, 4), f.forward, 0);
    e.player.normal = const V3(0, -1, 0);
    e.player.airborne = true;
    e.player.velocity = const V3(0, -90, 0);
    for (var i = 0; i < 35; i++) {
      e.update(1 / 120);
      final d = e.player,
          low =
              d.position!.y +
              1.4 * d.normal!.y -
              (1.4 * d.normal!.y.abs() +
                  3.65 * d.forward!.y.abs() +
                  1.95 * d.normal!.cross(d.forward!).unit.y.abs());
      expect(low, greaterThanOrEqualTo(19.9));
    }
  });
  test(
    'A descending deck blocks a ground car roof, without snapping it onto the road',
    () {
      final t = descendingRoad()..obstacles.clear();
      final f = t.frames.firstWhere(
        (f) => f.p.x < -199 && f.p.y > 4 && f.p.y < 5 && f.forward.y < -.01,
      );
      final heading = V3(f.forward.x, 0, f.forward.z).unit;
      final e = carAt(t, V3(f.p.x, .16, f.p.z), heading, 65)
        ..accelerating = true;
      final initial = e.player.position!;
      step(e, 2);
      expect(e.player.position!.y, closeTo(.16, .03));
      expect((e.player.position! - initial).dot(heading), lessThan(50));
      final p = t.project(e.player.position!);
      expect(p.height, lessThan(-2.8));
    },
  );
}
