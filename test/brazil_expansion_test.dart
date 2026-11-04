import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_mesh.dart';
import 'package:carwece/game/gpu_frame.dart';

void main() {
  final tracks = createTracks(), added = tracks.skip(51).toList();
  test(
    'Append exactly 50 national cars and 25 loop circuits without replacing old IDs',
    () {
      expect(cars.length, 106);
      expect(tracks.length, 76);
      expect(brazilCars.length, 50);
      expect(brazilCarDesigns.length, 50);
      expect(cars.skip(56).map((c) => c.id), brazilCars.map((c) => c.id));
      expect(cars[56].id, 'br_fusca');
      expect(cars[55].id, 'chiron');
      expect(tracks[50].id, 'coast_tideloop');
      expect(cars.map((c) => c.id).toSet().length, 106);
      expect(cars.map((c) => c.body), List.generate(106, (i) => i));
      expect(tracks.map((t) => t.id).toSet().length, 76);
      expect(createBattleArenas().length, 11);
    },
  );
  test(
    'Every added circuit contains a true complete vertical loop and upright return',
    () {
      expect(added.length, 25);
      expect(added.where((t) => t.outdoor).length, 15);
      expect(added.where((t) => !t.outdoor).length, 10);
      expect(
        added.map((t) => t.room).toSet(),
        tracks.take(51).map((t) => t.room).toSet(),
      );
      for (final t in added) {
        expect(t.loops.length, 1, reason: t.id);
        expect(t.length, greaterThan(3500));
        expect(t.shortcuts.length, 1, reason: t.id);
        expect(t.width, 46);
        expect(t.requiredStars, brazilLoopStars[t.id]);
        final l = t.loops.single;
        var inverted = false;
        for (var s = l.start; s < l.end; s += 4) {
          if (t.at(s).up.y < -.95) inverted = true;
        }
        expect(inverted, isTrue, reason: t.id);
        expect((t.at(l.start).p - t.at(l.end).p).length, greaterThan(76));
        for (final f in t.frames) {
          expect(t.widthAt(f.s), 46);
          expect(f.p.x.abs() + 23, lessThan(850));
          expect(f.p.z.abs() + 23, lessThan(850));
          if (t.loopAt(f.s, before: 5, after: 5) == null)
            expect(f.up.y, greaterThan(.98));
        }
        if (t.outdoor) {
          expect(t.themedObstacles.length, 12, reason: t.id);
          expect(
            t.themedObstacles.map((o) => o.prop.kind).toSet(),
            containsAll(expansionObstacleKinds[t.room]!.toSet()),
          );
        }
      }
    },
  );
  test(
    'National cars have unique chassis, finite normals and separate wheel meshes',
    () {
      final hashes = <int>{};
      for (final c in brazilCars) {
        final data = buildCarMesh(c).buffer, wheels = buildWheelMesh(c).buffer;
        expect(data.length % 36, 0);
        expect(data.length, greaterThan(10000));
        expect(data.every((v) => v.isFinite), isTrue, reason: c.id);
        expect(wheels.every((v) => v.isFinite), isTrue);
        hashes.add(Object.hashAll(data));
        for (var i = 0; i < data.length; i += 12) {
          final n = math.sqrt(
            data[i + 3] * data[i + 3] +
                data[i + 4] * data[i + 4] +
                data[i + 5] * data[i + 5],
          );
          expect(n, closeTo(1, .002), reason: c.id);
        }
      }
      expect(hashes.length, 50);
    },
  );
  test(
    'Every car has one independent performance class and model category',
    () {
      final classes = <String>{}, categories = <String>{};
      for (final c in cars) {
        expect(carPerformanceClasses, contains(c.performanceClass));
        expect(carModelCategories, contains(c.modelCategory));
        classes.add(c.performanceClass);
        categories.add(c.modelCategory);
      }
      expect(classes, carPerformanceClasses.toSet());
      expect(categories, carModelCategories.toSet());
      expect(cars[56].modelCategory, 'CLÁSSICO');
      expect(
        cars.firstWhere((c) => c.id == 'br_saveiro').modelCategory,
        'PICAPE',
      );
      expect(
        cars.firstWhere((c) => c.id == 'br_parati').modelCategory,
        'PERUA',
      );
    },
  );
  test(
    'Combined filters never remap master indices or mutate the catalogue',
    () {
      final before = cars.map((c) => c.id).toList();
      expect(filterCarCollection().length, 106);
      expect(filterCarCollection(brazilOnly: true).length, 50);
      for (final cls in carPerformanceClasses) {
        for (final cat in carModelCategories) {
          final indices = filterCarCollection(
            performanceClass: cls,
            category: cat,
            brazilOnly: true,
          );
          for (final i in indices) {
            expect(cars[i].performanceClass, cls);
            expect(cars[i].modelCategory, cat);
            expect(i, greaterThanOrEqualTo(56));
          }
        }
      }
      expect(
        filterCarCollection(performanceClass: 'S', category: 'PICAPE'),
        isEmpty,
      );
      expect(cars.map((c) => c.id), before);
    },
  );
  test(
    'The national roster starts in both race and battle using valid dynamic mesh IDs',
    () {
      final arena = createBattleArenas().first;
      for (final c in brazilCars) {
        final race = RaceEngine(
          track: added.first,
          car: c,
          mode: RaceMode.timeTrial,
        )..countdown = 0;
        race.accelerating = true;
        for (var i = 0; i < 30; i++) race.update(1 / 120);
        expect(race.player.speed, greaterThan(0));
        expect(raceGpuFrame(race).every((x) => x.isFinite), isTrue);
        final battle = BattleEngine(arena: arena, car: c, freeRoam: true)
          ..countdown = 0;
        battle.accelerating = true;
        for (var i = 0; i < 15; i++) battle.update(1 / 120);
        expect(raceGpuFrame(battle).every((x) => x.isFinite), isTrue);
      }
      expect(GpuMeshId.pickup, cars.length);
      expect(GpuMeshId.wheel, greaterThan(cars.length));
      expect(BattleMesh.first, cars.length * 3 + 21);
    },
  );
  test(
    'Outdoor terrain is never painted with the removed orange floor ribbon',
    () {
      for (final room in expansionBiomes.keys) {
        final t = tracks.firstWhere((t) => t.room == room);
        final m = buildWorldMesh(t).buffer;
        // At the normal terrain height there must be no orange track triangles.
        for (var i = 0; i < m.length; i += 36) {
          if (m[i + 11] != Material3.track) continue;
          final flat =
              (m[i + 1] - .16).abs() < .002 &&
              (m[i + 13] - .16).abs() < .002 &&
              (m[i + 25] - .16).abs() < .002;
          expect(
            flat,
            isFalse,
            reason: '${t.id}: orange floor overlay returned',
          );
        }
      }
    },
  );
}
