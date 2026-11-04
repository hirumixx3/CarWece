import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_mesh.dart';
import 'package:carwece/game/gpu_frame.dart';

void main() {
  final tracks = createTracks(), added = tracks.skip(26).take(25).toList();
  final arenas = createBattleArenas().skip(6).toList();
  test(
    'Append-only catalogues add exactly 25 cars, 25 circuits and 5 arenas',
    () {
      expect(cars.length, 106);
      expect(tracks.length, 76);
      expect(arenas.length, 5);
      expect(cars.map((c) => c.id).toSet().length, cars.length);
      expect(cars.map((c) => c.body), List.generate(cars.length, (i) => i));
      expect(tracks.map((t) => t.id).toSet().length, tracks.length);
      for (final room in expansionBiomes.keys) {
        expect(added.where((t) => t.room == room).length, 5);
        expect(arenas.where((a) => a.track.room == room).length, 1);
      }
      expect(cars.first.id, 'rx7');
      expect(cars[30].id, 'zonda');
    },
  );
  test(
    '25 new sculpted cars have distinct finite chassis and independent wheels',
    () {
      final hashes = <int>{};
      for (final c in cars.skip(31).take(25)) {
        final body = buildCarMesh(c).buffer, wheel = buildWheelMesh(c).buffer;
        expect(body.length % 36, 0, reason: c.id);
        expect(body.every((n) => n.isFinite), isTrue, reason: c.id);
        expect(wheel.every((n) => n.isFinite), isTrue, reason: c.id);
        expect(body.length, greaterThan(10000), reason: c.id);
        hashes.add(Object.hashAll(body));
        expect(c.design.frontAxle, lessThan(c.design.halfLength));
        expect(c.design.rearAxle, greaterThan(-c.design.halfLength));
        expect(c.design.glassRear, lessThan(c.design.roofRear));
      }
      expect(hashes.length, 25);
      expect(BattleMesh.first, GpuResources.objects.length);
      expect(
        BattleMesh.count,
        GpuResources.objects.length + BattleGpuMeshes.objects.length,
      );
    },
  );
  test(
    'All new tracks have genuine clear shorter branches with ordered checkpoints',
    () {
      final hashes = <int>{};
      for (final t in added) {
        hashes.add(Object.hashAll(t.controls.expand((p) => [p.x, p.y, p.z])));
        expect(t.length, greaterThan(3500), reason: t.id);
        expect(t.requiredStars, greaterThanOrEqualTo(0));
        expect(t.shortcuts.length, 1, reason: t.id);
        expect(t.ramps, isNotEmpty, reason: t.id);
        expect(t.barriers, isNotEmpty, reason: t.id);
        final s = t.shortcuts.single;
        expect(s.entryCheckpoint, lessThan(s.exitCheckpoint));
        expect(s.length, lessThan((s.exitS - s.entryS) * .91), reason: t.id);
        for (final f in s.frames) {
          expect(f.p.y, closeTo(TrackSpec.floorHeight, .001));
          for (final prop in t.details) {
            final d = f.p - prop.center;
            final overlaps =
                d.x.abs() < prop.size.x / 2 + s.width / 2 + 3 &&
                d.z.abs() < prop.size.z / 2 + s.width / 2 + 3;
            expect(
              overlaps,
              isFalse,
              reason: '${t.id}: ${prop.kind} blocks branch',
            );
          }
        }
        for (final loop in t.loops) {
          var up = 1.0;
          for (var s = loop.start; s < loop.end; s += 4)
            up = math.min(up, t.at(s).up.y);
          expect(up, lessThan(-.90), reason: t.id);
        }
      }
      expect(hashes.length, 25);
      expect(added.fold<int>(0, (n, t) => n + t.loops.length), 5);
    },
  );
  test(
    'Prehistoric racing and battle contain all three physical toy species',
    () {
      for (final t in [
        ...added.where((t) => t.room == 'PRÉ-HISTÓRIA'),
        ...arenas
            .where((a) => a.track.room == 'PRÉ-HISTÓRIA')
            .map((a) => a.track),
      ]) {
        final species = t.details.map((p) => p.kind).toSet();
        expect(
          species,
          containsAll(['rex', 'triceratops', 'sauropod']),
          reason: t.id,
        );
        for (final prop in t.details) {
          final mesh = Mesh3();
          buildExpansionPropMesh(mesh, prop);
          expect(mesh.data, isNotEmpty, reason: prop.kind);
          for (var i = 0; i < mesh.data.length; i += 12) {
            expect(
              (mesh.data[i] - prop.center.x).abs(),
              lessThanOrEqualTo(prop.size.x / 2 + .1),
              reason: prop.kind,
            );
            expect(
              (mesh.data[i + 1] - prop.center.y).abs(),
              lessThanOrEqualTo(prop.size.y / 2 + .1),
              reason: prop.kind,
            );
            expect(
              (mesh.data[i + 2] - prop.center.z).abs(),
              lessThanOrEqualTo(prop.size.z / 2 + .1),
              reason: prop.kind,
            );
          }
          expect(
            t.obstacles.any((o) => identical(o.center, prop.center)),
            isTrue,
          );
        }
      }
    },
  );
  test(
    'New battle floors have clear safe spawns, pickups, routes and independent loops',
    () {
      for (final a in arenas) {
        expect(a.track.openArena, isTrue);
        expect(a.track.barriers, isEmpty);
        expect(a.track.shortcuts, isEmpty);
        expect(a.track.loops.length, 1);
        expect(a.nav.length, greaterThan(200));
        expect(a.spawns.length, 6);
        expect(a.supplies.length, 18);
        expect(a.health.length, 4);
        for (final p in [...a.spawns, ...a.supplies, ...a.health]) {
          expect(a.clearFloor(p, 9), isTrue, reason: a.track.id);
        }
        for (final start in a.spawns) {
          final route = a.path(start, a.supplies.first);
          expect(route, isNotEmpty, reason: a.track.id);
          // The existing pathfinder exposes a target even when unreachable;
          // verify actual segment visibility rather than just list non-emptiness.
          var previous = start;
          for (final p in route) {
            expect(a.lineClear(previous, p, 6), isTrue, reason: a.track.id);
            previous = p;
          }
        }
      }
    },
  );
  test(
    'Every new biome produces finite world data within the existing vertex layout',
    () {
      for (final room in expansionBiomes.keys) {
        final t = added.firstWhere((t) => t.room == room);
        final mesh = buildWorldMesh(t).buffer;
        expect(mesh.length % 36, 0);
        expect(mesh.every((n) => n.isFinite), isTrue, reason: room);
        expect(mesh.length * 4, lessThan(32 * 1024 * 1024), reason: room);
      }
    },
  );
  test(
    'Every new car starts in racing and combat with finite physical and GPU state',
    () {
      for (final c in cars.skip(31).take(25)) {
        final race = RaceEngine(
          track: added.first,
          car: c,
          mode: RaceMode.timeTrial,
        )..countdown = 0;
        race.accelerating = true;
        for (var j = 0; j < 60; j++) race.update(1 / 120);
        expect(race.player.speed, greaterThan(0), reason: c.id);
        expect(race.player.position!.length.isFinite, isTrue);
        expect(raceGpuFrame(race).every((n) => n.isFinite), isTrue);
        final battle = BattleEngine(arena: arenas.first, car: c, freeRoam: true)
          ..countdown = 0;
        battle.accelerating = true;
        for (var j = 0; j < 20; j++) battle.update(1 / 120);
        expect(
          raceGpuFrame(battle).every((n) => n.isFinite),
          isTrue,
          reason: c.id,
        );
      }
    },
  );
  test('Grip is biome-specific without changing existing room surfaces', () {
    expect(added.firstWhere((t) => t.room == 'NEVE').floorGrip, .84);
    expect(added.firstWhere((t) => t.room == 'DESERTO').floorGrip, .92);
    expect(tracks.first.floorGrip, 1);
    expect(added.every((t) => t.outdoor), isTrue);
    expect(tracks.take(26).any((t) => t.outdoor), isFalse);
  });
}
