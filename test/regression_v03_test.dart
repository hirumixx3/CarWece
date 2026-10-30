import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/platform.dart';

void main() {
  final tracks = createTracks();
  RaceEngine isolated({bool bots = false}) {
    final e = RaceEngine(track: tracks.first, car: cars.first)..countdown = 0;
    if (!bots) e.bots.clear();
    e.player.distance = 0;
    e.player.lane = 0;
    return e;
  }

  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) {
      e.update(1 / 120);
    }
  }

  List<int> meshes(RaceEngine e) {
    final packet = raceGpuFrame(e);
    return [
      for (var i = 0; i < packet[14].toInt(); i++) packet[15 + i * 17].toInt(),
    ];
  }

  double penetration(RaceEngine e, Driver a, Driver b) => math.min(
    a.colliderLength +
        b.colliderLength +
        .12 -
        e.separation(a.distance, b.distance).abs(),
    a.colliderWidth +
        b.colliderWidth +
        .12 -
        (a.lane - b.lane).abs() * e.track.width / 2,
  );

  test(
    'Manual is the default, including migration of old automatic settings',
    () {
      final e = isolated();
      final before = e.player.distance;
      e.steering = 1;
      e.boosting = true;
      advance(e, 3);
      expect(e.autoAccelerate, isFalse);
      expect(e.player.distance, before);
      expect(e.player.lane, 0);
      expect(e.nitro, 100);
      final settings = GameSettings()..restore({'auto': true});
      expect(settings.autoAccelerate, isFalse);
      settings.restore({'auto': true, 'controlsVersion': 3});
      expect(settings.autoAccelerate, isTrue);
    },
  );
  test(
    'Throttle, coasting and brakes change momentum; steering has inertia',
    () {
      final e = isolated()..accelerating = true;
      advance(e, 2);
      expect(e.player.speed, greaterThan(30));
      final speed = e.player.speed;
      e.accelerating = false;
      advance(e, .25);
      expect(e.player.speed, lessThan(speed));
      expect(e.player.speed, greaterThan(speed - 5));
      e.brake = true;
      advance(e, .5);
      expect(e.player.speed, lessThan(speed - 20));
      e.brake = false;
      e.accelerating = true;
      e.player.speed = 65;
      e.placeDriver(
        e.player,
        e.player.distance,
        e.player.lane,
        setProgress: false,
      );
      e.steering = .8;
      advance(e, .2);
      expect(e.player.angularSpeed, greaterThan(.5));
      final turn = e.player.angularSpeed;
      e.steering = 0;
      e.update(1 / 120);
      expect(e.player.angularSpeed, greaterThan(0));
      // Steering rack returns smoothly; chassis yaw may peak one step later.
      advance(e, .15);
      expect(e.player.angularSpeed, lessThan(turn));
    },
  );
  test(
    'Rear collision exchanges momentum and never allows an overtake through a car',
    () {
      final e = isolated();
      e.player.distance = 25;
      e.player.speed = 100;
      e.accelerating = true;
      final b = Driver('TESTE', cars.first, .3, 40, 0);
      e.bots.add(b);
      var contact = false;
      for (var i = 0; i < 100; i++) {
        e.update(1 / 120);
        expect(e.player.distance, lessThan(b.distance));
        expect(penetration(e, e.player, b), lessThan(.025));
        contact = contact || e.effects.isNotEmpty;
      }
      expect(contact, isTrue);
      expect(b.speed, greaterThan(20));
      expect(e.player.speed, lessThan(100));
    },
  );
  test('Side contact next to a barrier separates the whole pack', () {
    final e = isolated();
    e.player.distance = 30;
    e.player.lane = .77;
    final b = Driver('LADO', cars.first, .5, 30, .55)..speed = 30;
    e.player.speed = 30;
    e.bots.add(b);
    advance(e, .25);
    expect(penetration(e, e.player, b), lessThan(.025));
    for (final d in e.drivers) {
      expect(
        d.lane.abs() * e.track.width / 2 + d.colliderWidth,
        lessThanOrEqualTo(e.track.width / 2 - .4),
      );
    }
  });
  test('Collisions also detect a lapped car across the course seam', () {
    final e = isolated();
    e.player.distance = 1;
    final b = Driver('RETARDATÁRIO', cars.first, .5, e.track.length - 2, 0);
    e.bots.add(b);
    e.update(1 / 120);
    expect(penetration(e, e.player, b), lessThan(.025));
  });
  test('Cars can jump over a rival without an invisible collision', () {
    final e = isolated();
    e.player.distance = 30;
    e.player.speed = 80;
    e.player.jump = 7;
    final b = Driver('EMBAIXO', cars.first, .5, 30, 0);
    e.bots.add(b);
    e.update(1 / 120);
    expect(e.player.hitFlash, 0);
    expect(e.player.speed, greaterThan(75));
    expect(e.player.jump, greaterThan(6));
  });
  test(
    'All road ribbons are wider than six car bodies and do not fold inside corners',
    () {
      for (final track in tracks) {
        expect(track.width, greaterThan(Driver.halfWidth * 2 * 6));
        for (var s = 0.0; s < track.length; s += 2) {
          final a = track.at(s), b = track.at(s + 1);
          final curvature = (b.forward - a.forward).length;
          if (curvature > 1e-6)
            expect(
              1 / curvature,
              greaterThan(
                track.isFloor(s) ? Driver.halfLength + 2 : track.width / 2 + 2,
              ),
              reason: '${track.id}: $s',
            );
          expect(a.forward.dot(a.right).abs(), lessThan(1e-6));
        }
      }
    },
  );
  test(
    'Loop entry and exit have separate lanes and clear vertical and lateral space',
    () {
      final t = tracks.first;
      final entry = t.at(t.loopStart!), exit = t.at(t.loopEnd!);
      expect((entry.p - exit.p).length, greaterThan(t.width + 10));
      expect(entry.forward.dot(exit.forward), greaterThan(.99));
      expect(t.frames.any((f) => f.up.y < -.9), isTrue);
      for (var s = 0.0; s < t.length; s += 4) {
        for (var q = s + t.width * 2; q < t.length; q += 4) {
          if (t.length - q + s < t.width * 2) continue;
          expect(
            (t.at(s).p - t.at(q).p).length,
            greaterThan(t.width + 5),
            reason: 'Road overlap: $s / $q',
          );
        }
      }
    },
  );
  test(
    'Photo finish in the same physics step uses crossing times, not update order',
    () {
      final e = isolated();
      final finish = e.track.length * 3;
      e.time = 100;
      e.lapTimes.addAll([33, 34]);
      e.lastLapTime = 67;
      e.player.distance = finish - .5;
      e.player.speed = 80;
      e.accelerating = true;
      e.bots.addAll([
        Driver('ANTES', cars.first, 1, finish - .3, -.6)..speed = 80,
        Driver('DEPOIS', cars.first, 1, finish - .7, .6)..speed = 95,
      ]);
      final gate = e.track.at(0);
      for (final d in e.drivers) {
        e.placeDriver(d, d.distance, d.lane);
        final remaining = finish - d.distance;
        d.position =
            gate.point(d.lane * e.track.width / 2) - gate.forward * remaining;
        d.forward = gate.forward;
        d.normal = gate.up;
        d.velocity = gate.forward * d.speed;
      }
      e.update(1 / 120);
      expect(e.finished, isTrue);
      expect(e.position, 2);
      expect(e.result!.position, 2);
      expect(e.result!.standings.map((d) => d.name), [
        'ANTES',
        'VOCÊ',
        'DEPOIS',
      ]);
      expect(e.bots.first.finishTime!, lessThan(e.player.finishTime!));
      expect(e.bots.last.finishTime!, greaterThan(e.player.finishTime!));
      expect(e.time, e.player.finishTime);
      expect(e.lapTimes.length, 3);
      final frozen = e.result!.standings.map((d) => d.name).toList();
      e.update(1);
      expect(e.result!.standings.map((d) => d.name), frozen);
    },
  );
  test(
    'Every finishing place agrees with the immutable results and rewards',
    () {
      for (var rank = 1; rank <= 6; rank++) {
        final e = isolated(bots: true);
        final finish = e.track.length * 3;
        e.time = 90;
        e.lapTimes.addAll([28, 29]);
        e.lastLapTime = 57;
        e.player.distance = finish - .1;
        e.player.speed = 80;
        for (var i = 0; i < e.bots.length; i++) {
          if (i < rank - 1) {
            e.bots[i].distance = finish;
            e.bots[i].finishTime = 80 + i.toDouble();
          } else {
            e.bots[i].distance = finish - 100 - i * 12;
          }
        }
        e.update(1 / 120);
        expect(e.result!.position, rank);
        expect(e.result!.standings[rank - 1].name, 'VOCÊ');
        expect(e.standings[rank - 1], e.player);
        expect(e.result!.coins, [1000, 500, 250, 0, 0, 0][rank - 1]);
      }
    },
  );
  test('Being pushed backwards over a lap gate cannot record a second lap', () {
    final e = isolated();
    e.player.distance = e.track.length - .1;
    e.player.speed = 80;
    e.update(1 / 120);
    expect(e.lapTimes.length, 1);
    e.player.speed = 80;
    e.placeDriver(e.player, e.track.length - .1, 0, setProgress: false);
    e.update(1 / 120);
    expect(e.lapTimes.length, 1);
  });
  test(
    'Missile is visible in flight, then triggers damage, spin, sparks and smoke',
    () {
      final e = isolated();
      e.player.distance = 30;
      final target = Driver('ALVO', cars.first, .5, 85, 0)..speed = 35;
      e.bots.add(target);
      e.item = ItemType.missile;
      e.superchargeItem();
      e.useItem();
      advance(e, .12);
      expect(e.projectiles, isNotEmpty);
      expect(e.hitCount, 0);
      expect(meshes(e), containsAll([GpuMeshId.rocket, GpuMeshId.trail]));
      advance(e, .75);
      expect(e.hitCount, 1);
      expect(target.damage, greaterThan(0));
      expect(target.spinTime, greaterThan(0));
      expect(e.effects.any((x) => x.kind == ImpactKind.explosion), isTrue);
      expect(
        meshes(e),
        containsAll([GpuMeshId.explosion, GpuMeshId.smoke, GpuMeshId.sparks]),
      );
      expect(raceGpuFrame(e).every((v) => v.isFinite), isTrue);
    },
  );
  test('A missile in another lane cannot hit by distance alone', () {
    final e = isolated();
    e.player.distance = 30;
    e.bots.add(Driver('OUTRA FAIXA', cars.first, .4, 60, .75));
    e.projectiles.add(Projectile(36, -.75, owner: e.player));
    advance(e, .7);
    expect(e.hitCount, 0);
    expect(e.bots.first.damage, 0);
  });
  test(
    'Oil causes a visible spin and a shield blocks physical weapon damage',
    () {
      final e = isolated();
      e.player.distance = 30;
      final b = Driver('ALVO', cars.first, .5, 18, 0)..speed = 60;
      e.bots.add(b);
      e.item = ItemType.oil;
      e.useItem();
      advance(e, .1);
      expect(e.hitCount, 1);
      expect(b.spinTime, greaterThan(0));
      final protected = isolated();
      protected.player.distance = 30;
      protected.player.shield = 6;
      protected.projectiles.add(
        Projectile(24, 0, owner: b, target: protected.player),
      );
      advance(protected, .04);
      expect(protected.player.spinTime, 0);
      expect(protected.player.damage, 0);
      expect(
        protected.effects.any((x) => x.kind == ImpactKind.blocked),
        isTrue,
      );
    },
  );
  test('All circuits are finishable using steering, throttle and brakes', () {
    for (final track in tracks) {
      final e = RaceEngine(
        track: track,
        car: cars.first,
        mode: RaceMode.timeTrial,
      )..accelerating = true;
      for (
        var i = 0;
        i < math.max(260, track.length * .045) * 120 && !e.finished;
        i++
      ) {
        final c = e.aiControls(e.player);
        e.steering = c.$1;
        e.accelerating = c.$2;
        e.brake = c.$3;
        e.update(1 / 120);
      }
      expect(e.finished, isTrue, reason: track.id);
      expect(e.lapTimes.length, 3, reason: track.id);
      expect(e.result!.bestLap, greaterThan(0));
    }
  });
  test(
    'Failing a loop releases the car into a visible fall without teleporting',
    () {
      final e = isolated();
      final top = e.track.frames.firstWhere((f) => f.up.y < -.99);
      e.placeDriver(e.player, top.s, 0);
      final before = e.player.position!;
      advance(e, .8);
      expect(e.player.airborne, isTrue);
      expect(e.player.position!.y, lessThan(before.y - 6));
      expect((e.player.position! - before).length, lessThan(20));
      expect(e.player.velocity.y, lessThan(-15));
      expect(e.player.completedLaps, 0);
    },
  );
}
