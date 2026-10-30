import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/math3d.dart';

void advance(RaceEngine e, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) e.update(1 / 120);
}

void main() {
  final tracks = createTracks();
  test(
    'All 26 starting grids remain stationary when steering; throttle launches normally',
    () {
      for (final track in tracks)
        for (final mode in [RaceMode.quick, RaceMode.timeTrial]) {
          final e = RaceEngine(track: track, car: cars.first, mode: mode)
            ..countdown = 0;
          e.bots.clear();
          e.driverFrame(e.player);
          final p = e.player.position!, f = e.player.forward!;
          e.steering = 1;
          advance(e, 3);
          expect(
            (e.player.position! - p).length,
            lessThan(.025),
            reason: '${track.id} ${mode.name}',
          );
          expect(e.player.forward!.dot(f), greaterThan(.9999));
          expect(e.player.steeringAngle, greaterThan(.4));
          expect(e.player.speed.abs(), lessThan(.01));
          e.steering = 0;
          e.accelerating = true;
          advance(e, .75);
          expect(e.player.speed, greaterThan(10), reason: track.id);
          expect(e.player.airborne, isFalse, reason: track.id);
        }
    },
  );
  test(
    'Stopped cars on offset curved plastic surfaces do not creep to a rail',
    () {
      var count = 0;
      for (final track in tracks) {
        final samples = track.frames
            .where(
              (f) =>
                  !track.isFloor(f.s) &&
                  f.up.y > .995 &&
                  f.forward.y.abs() < .025,
            )
            .toList();
        for (var i = 0; i < samples.length; i += 40) {
          final e = RaceEngine(
            track: track,
            car: cars.first,
            mode: RaceMode.timeTrial,
          )..countdown = 0;
          e.placeDriver(e.player, samples[i].s, .5);
          final p = e.player.position!;
          e.steering = i.isEven ? -1 : 1;
          advance(e, 2);
          expect(
            (e.player.position! - p).length,
            lessThan(.025),
            reason: '${track.id} at ${samples[i].s}',
          );
          e.steering = 0;
          e.accelerating = true;
          advance(e, .5);
          expect(e.player.speed, greaterThan(10), reason: track.id);
          count++;
        }
      }
      expect(count, greaterThan(100));
    },
  );
  test(
    'Steering parked beside a rail moves only the front wheels, then can drive away',
    () {
      final track = TrackSpec(
        'parked',
        'PARKED',
        '',
        'TESTE',
        0xffee8844,
        0xff777777,
        0xff333333,
        const [
          V3(-600, 3, -600),
          V3(600, 3, -600),
          V3(600, 3, 600),
          V3(-600, 3, 600),
        ],
        openArena: true,
        width: 52,
      );
      track.obstacles.clear();
      track.ramps.clear();
      final f = track.frames.reduce(
        (a, b) => a.forward.x.abs() < b.forward.x.abs() ? a : b,
      );
      for (final side in [-1.0, 1.0]) {
        final e = RaceEngine(
          track: track,
          car: cars.first,
          mode: RaceMode.timeTrial,
        )..countdown = 0;
        e.placeDriver(e.player, f.s, side * (1 - 2.7 / 26));
        final p = e.player.position!, heading = e.player.forward!;
        e.steering = -side;
        advance(e, 3);
        expect((e.player.position! - p).length, lessThan(.015));
        expect(e.player.forward!.dot(heading), greaterThan(.99999));
        e.accelerating = true;
        advance(e, .8);
        expect(e.player.speed, greaterThan(15));
        expect((e.player.position! - p).dot(f.right) * side, lessThan(-.5));
      }
    },
  );
}
