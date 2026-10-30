import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';

void main() {
  final tracks = createTracks();
  final floor = TrackSpec(
    'qa',
    'QA',
    '',
    'GARAGEM',
    0xffff7700,
    0xff606870,
    0xff303840,
    const [
      V3(-400, .16, -400),
      V3(-400, .16, 400),
      V3(400, .16, 400),
      V3(400, .16, -400),
    ],
  );
  RaceEngine open() {
    final e = RaceEngine(
      track: floor,
      car: cars.first,
      mode: RaceMode.timeTrial,
    )..countdown = 0;
    e.placeDriver(e.player, 0, 0);
    e.player.position = const V3(0, .16, 0);
    e.player.forward = const V3(0, 0, 1);
    e.player.normal = const V3(0, 1, 0);
    e.player.velocity = V3.zero;
    return e;
  }

  Driver target(RaceEngine e, V3 p) {
    final d = Driver('ALVO', cars[1], .8, 20, 0);
    e.bots.add(d);
    e.placeDriver(d, 20, 0);
    d.position = p;
    d.forward = const V3(0, 0, 1);
    d.normal = const V3(0, 1, 0);
    d.velocity = V3.zero;
    return d;
  }

  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) e.update(1 / 120);
  }

  List<int> meshes(RaceEngine e) {
    final p = raceGpuFrame(e);
    return [for (var i = 0; i < p[14]; i++) p[15 + i * 17].toInt()];
  }

  test(
    'Eight new circuits have twelve independent full loops and no residual roll',
    () {
      final added = tracks.skip(18).toList();
      expect(added.length, 8);
      expect(added.map((t) => t.loops.length), [1, 2, 1, 2, 1, 2, 1, 2]);
      for (final t in added) {
        for (final loop in t.loops) {
          final a = t.at(loop.start), b = t.at(loop.end);
          expect((a.p - b.p).length, greaterThan(t.width + 30));
          expect(a.forward.dot(b.forward), greaterThan(.995));
          expect(a.up.y, greaterThan(.995));
          expect(b.up.y, greaterThan(.995));
          expect(t.isBoost(loop.start - 72, 0), isTrue);
          final top = t.frames.firstWhere(
            (f) => f.s > loop.start && f.s < loop.end && f.up.y < -.999,
          );
          final e = RaceEngine(
            track: t,
            car: cars.first,
            mode: RaceMode.timeTrial,
          )..countdown = 0;
          e.player.speed = 85;
          e.placeDriver(e.player, top.s, 0);
          expect(e.contactForce(e.player, top), greaterThan(40));
          e.player.speed = 0;
          e.player.velocity = V3.zero;
          final old = e.player.position!, cp = e.player.nextCheckpoint;
          advance(e, .12);
          expect(e.player.airborne, isTrue);
          expect(e.player.position!.y, lessThan(old.y));
          expect(e.player.nextCheckpoint, cp);
          expect(raceGpuFrame(e).every((v) => v.isFinite), isTrue);
        }
        for (var s = 0.0; s < t.length; s += 4) {
          final f = t.at(s);
          expect(f.point(t.width / 2).y, greaterThanOrEqualTo(.15));
          expect(f.point(-t.width / 2).y, greaterThanOrEqualTo(.15));
          if (t.loopAt(s, after: 5) == null) expect(f.up.y, greaterThan(.98));
          expect((t.project(f.p).frame.p - f.p).length, lessThan(.04));
        }
      }
    },
  );
  test(
    'Reset in a second loop returns before that loop without skipping gates',
    () {
      for (final t in tracks.where((t) => t.loops.length == 2)) {
        final loop = t.loops[1],
            cp = (loop.start / t.length * TrackSpec.checkpointCount).ceil();
        final e = RaceEngine(
          track: t,
          car: cars.first,
          mode: RaceMode.timeTrial,
        );
        e.placeDriver(e.player, t.checkpoint(cp).s, 0);
        e.player.nextCheckpoint = cp + 1;
        e.resetPlayer();
        expect(e.player.routeS, lessThanOrEqualTo(loop.start));
        expect(e.player.routeS, greaterThan(t.loops.first.end));
        expect(e.player.completedLaps, 0);
      }
    },
  );
  test(
    'Grenades are visible ballistic objects, bounce and explode on their fuse',
    () {
      final e = open();
      e.giveItem(ItemType.grenade);
      e.useItem();
      final p = e.projectiles.single, initial = p.position!;
      expect(e.itemCharges, 1);
      expect(meshes(e), contains(GpuMeshId.grenade));
      advance(e, .45);
      expect(p.position!.y, greaterThan(initial.y));
      expect(p.ballisticVelocity!.y, lessThan(20));
      advance(e, 1.4);
      expect(p.bounces, greaterThan(0));
      advance(e, .2);
      expect(e.projectiles, isEmpty);
      expect(meshes(e), contains(GpuMeshId.explosion));
    },
  );
  test(
    'Grenade splash hits nearby rivals and a shield absorbs the same hit',
    () {
      for (final shield in [false, true]) {
        final e = open();
        final d = target(e, const V3(0, .16, 20));
        d.shield = shield ? 6 : 0;
        e.projectiles.add(
          Projectile(0, 0, owner: e.player, kind: ItemType.grenade)
            ..position = const V3(7, 3, 20)
            ..direction = const V3(0, 0, 1)
            ..ballisticVelocity = V3.zero
            ..life = .01,
        );
        advance(e, .04);
        expect(e.events, contains('explosion'));
        expect(shield ? d.shield < 6 : d.damage > .8, isTrue);
        if (shield) expect(d.damage, 0);
      }
    },
  );
  test(
    'Shockwave pushes nearby rivals, respects shields and does not hit distant cars',
    () {
      final e = open();
      final near = target(e, const V3(8, .16, 8)),
          far = target(e, const V3(100, .16, 0)),
          protected = target(e, const V3(-8, .16, 8))..shield = 6;
      e.giveItem(ItemType.shockwave);
      e.useItem();
      expect(near.velocity.length, greaterThan(15));
      expect(near.velocity.x, greaterThan(5));
      expect(far.velocity.length, 0);
      expect(protected.velocity.length, 0);
      expect(protected.shield, 4);
      expect(e.player.damage, 0);
      expect(meshes(e), contains(GpuMeshId.shockwave));
    },
  );
  test(
    'Spikes puncture locally and repair removes damage and temporary faults',
    () {
      final e = open();
      e.giveItem(ItemType.spikes);
      e.useItem();
      final strip = e.spikeStrips.single;
      expect(meshes(e), contains(GpuMeshId.spikes));
      strip.arm = 0;
      strip.life = 10;
      e.player.position = strip.frame.p;
      advance(e, .02);
      expect(e.player.punctureTime, greaterThan(3.9));
      expect(e.spikeStrips, isEmpty);
      e.player.stun = 1;
      e.player.freezeTime = 2;
      e.player.electricTime = 3;
      e.player.damage = 1;
      e.giveItem(ItemType.repair, enhanced: true);
      e.useItem();
      expect(e.player.punctureTime, 0);
      expect(e.player.freezeTime, 0);
      expect(e.player.electricTime, 0);
      expect(e.player.damage, 0);
      expect(e.player.stun, 0);
      expect(e.player.shield, 4);
      expect(meshes(e), contains(GpuMeshId.repair));
      advance(e, 1.6);
      expect(e.player.repairGlow, 0);
    },
  );
  test(
    'Punctured tires lose grip while shields and height avoid spike damage',
    () {
      final healthy = open(), punctured = open();
      for (final e in [healthy, punctured]) {
        e.player.velocity = const V3(16, 0, 50);
        e.player.speed = 50;
      }
      punctured.player.punctureTime = 4;
      advance(healthy, .2);
      advance(punctured, .2);
      expect(
        punctured.player.lateralSpeed.abs(),
        greaterThan(healthy.player.lateralSpeed.abs() * 1.4),
      );
      final e = open();
      e.giveItem(ItemType.spikes);
      e.useItem();
      final strip = e.spikeStrips.single..arm = 0;
      final d = target(e, strip.frame.p)..jump = 4;
      advance(e, .02);
      expect(d.punctureTime, 0);
      d.jump = 0;
      d.position = strip.frame.p;
      d.shield = 6;
      advance(e, .02);
      expect(d.punctureTime, 0);
      expect(d.shield, lessThan(4));
      expect(e.spikeStrips, isEmpty);
    },
  );
  test(
    'Current race and garage upload only their models with stable mesh indices',
    () {
      final full = GpuResources.objects,
          one = GpuResources.objectsFor([cars.last.body]);
      expect(one.length, 114);
      expect(one[cars.last.body], orderedEquals(full[cars.last.body]));
      expect(
        one[GpuMeshId.wheel + cars.last.body],
        orderedEquals(full[GpuMeshId.wheel + cars.last.body]),
      );
      expect(one[0].length, 36);
      int bytes(List<dynamic> data) =>
          data.fold(0, (sum, d) => sum + (d.length as int) * 4);
      expect(bytes(one), lessThan(bytes(full) * .15));
      final e = RaceEngine(track: tracks.first, car: cars.last),
          scoped = GpuResources.objectsFor(
            RaceEngine(
              track: tracks.first,
              car: cars.last,
            ).drivers.map((d) => d.car.body),
          );
      expect(bytes(scoped), lessThan(bytes(full) * .35));
      for (final d in e.drivers)
        expect(scoped[d.car.body], orderedEquals(full[d.car.body]));
    },
  );
  test(
    'Quick race and first championship stage always start last; solo starts alone',
    () {
      for (final t in tracks)
        for (final difficulty in ['easy', 'normal', 'hard'])
          for (final mode in [RaceMode.quick, RaceMode.championship]) {
            final e = RaceEngine(
              track: t,
              car: cars.last,
              mode: mode,
              difficulty: difficulty,
            );
            expect(e.startingPosition, 6);
            expect(e.position, 6);
            e.update(.01);
            expect(e.position, 6);
            expect(e.player.completedLaps, 0);
            expect(e.player.started, isFalse);
            expect(e.player.nextCheckpoint, 0);
            for (final d in e.bots)
              expect(d.distance, greaterThan(e.player.distance));
          }
      final solo = RaceEngine(
        track: tracks.first,
        car: cars.first,
        mode: RaceMode.timeTrial,
      );
      expect(solo.position, 1);
      expect(solo.bots, isEmpty);
    },
  );
  test(
    'Championship stages use the complete previous finish order, not cup points',
    () {
      const bots = ['NOVA', 'BOLT', 'RAVEN', 'REX', 'PIXEL'];
      for (var place = 1; place <= 6; place++) {
        final previous = bots.reversed.toList()..insert(place - 1, 'VOCÊ');
        final e = RaceEngine(
          track: tracks[1],
          car: cars.first,
          mode: RaceMode.championship,
          previousChampionshipOrder: previous,
        );
        expect(e.startingPosition, place);
        expect(e.position, place);
        expect(e.gridOrder, previous);
        expect(e.standings.map((d) => d.name), previous);
        e.update(.02);
        expect(e.position, place);
        expect(e.player.completedLaps, 0);
        final quick = RaceEngine(
          track: tracks[1],
          car: cars.first,
          previousChampionshipOrder: previous,
        );
        expect(quick.startingPosition, 6);
      }
    },
  );
  test(
    'Expanded normal roster recovers from oscillation and completes chicanes',
    () {
      final t = tracks.firstWhere((t) => t.id == 'kitchen_chicane'),
          e = RaceEngine(
            track: tracks.firstWhere((t) => t.id == 'kitchen_chicane'),
            car: cars.first,
            laps: 1,
          )..countdown = 0;
      e.placeDriver(e.player, -100, 0);
      for (
        var i = 0;
        i < 150 * 120 && e.bots.any((d) => d.finishTime == null);
        i++
      )
        e.update(1 / 120);
      expect(e.bots.every((d) => d.finishTime != null), isTrue, reason: t.id);
      expect(e.bots.every((d) => d.completedLaps == 1), isTrue);
      expect(e.bots.every((d) => d.aiRecoveries <= 2), isTrue);
    },
  );
}
