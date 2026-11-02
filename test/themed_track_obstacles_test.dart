import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_mesh.dart';
import 'package:carwece/game/math3d.dart';

void main() {
  final tracks = createTracks();
  final added = tracks.skip(26).take(25).toList();
  test('Only the 25 new races use fixed legacy ribbon width', () {
    expect(added.length, 25);
    for (final t in added) {
      expect(t.width, tracks.first.width, reason: t.id);
      expect(t.width, 46);
      for (final f in t.frames) expect(t.widthAt(f.s), 46, reason: t.id);
    }
    expect(tracks.take(26).every((t) => t.themedObstacles.isEmpty), isTrue);
    expect(
      createBattleArenas().every((a) => a.track.themedObstacles.isEmpty),
      isTrue,
    );
    expect(
      tracks.first.frames.any((f) => tracks.first.widthAt(f.s) > 46),
      isTrue,
    );
  });
  test(
    'Each new circuit has 12 solid theme-specific toys instead of generic boxes',
    () {
      for (final t in added) {
        expect(t.themedObstacles.length, 12, reason: t.id);
        expect(t.obstacles.where((o) => o.visible), isEmpty, reason: t.id);
        final kinds = t.themedObstacles.map((o) => o.prop.kind).toSet();
        expect(
          kinds,
          containsAll(expansionObstacleKinds[t.room]!.toSet()),
          reason: t.id,
        );
        for (final o in t.themedObstacles) {
          expect(
            t.obstacles.where((c) => identical(c.center, o.prop.center)).length,
            1,
          );
          expect(t.isFloor(o.frame.s), isTrue);
          expect(o.frame.s, greaterThanOrEqualTo(220));
          expect(o.frame.s, lessThan(t.length - 160));
          expect(t.loopAt(o.frame.s, before: 100, after: 100), isNull);
        }
      }
    },
  );
  test(
    'Obstacle footprints stay in-lane and do not block shortcut corridors',
    () {
      for (final t in added) {
        expect(t.shortcuts.length, 1, reason: t.id);
        expect(t.ramps, isNotEmpty);
        for (final o in t.themedObstacles) {
          final p = o.prop;
          for (final x in [-1.0, 1.0]) {
            for (final z in [-1.0, 1.0]) {
              final q = t.project(
                V3(
                  p.center.x + x * p.size.x / 2,
                  TrackSpec.floorHeight,
                  p.center.z + z * p.size.z / 2,
                ),
              );
              expect(
                q.lateral.abs(),
                lessThanOrEqualTo(21.7),
                reason: '${t.id} ${p.kind}',
              );
            }
          }
          for (final path in t.shortcuts) {
            for (final f in path.frames) {
              final d = f.p - p.center;
              final overlaps =
                  d.x.abs() < p.size.x / 2 + path.width / 2 + 8 &&
                  d.z.abs() < p.size.z / 2 + path.width / 2 + 8;
              expect(
                overlaps,
                isFalse,
                reason: '${t.id} ${p.kind} blocks branch',
              );
            }
          }
          final f = o.frame;
          final extent =
              (f.right.x.abs() * p.size.x + f.right.z.abs() * p.size.z) / 2;
          final lateral = (p.center - f.p).dot(f.right).abs();
          expect(
            lateral - extent,
            greaterThanOrEqualTo(4.4 - .001),
            reason: t.id,
          );
        }
      }
    },
  );
  test('Every toy mesh is finite and fits its actual physical proxy', () {
    for (final t in added) {
      for (final o in t.themedObstacles) {
        final mesh = Mesh3();
        buildExpansionTrackObstacleMesh(mesh, o);
        final data = mesh.buffer, p = o.prop;
        expect(data, isNotEmpty);
        expect(data.length % 36, 0);
        expect(data.every((v) => v.isFinite), isTrue);
        for (var i = 0; i < data.length; i += 12) {
          expect(
            (data[i] - p.center.x).abs(),
            lessThanOrEqualTo(p.size.x / 2 + .001),
          );
          expect(
            (data[i + 1] - p.center.y).abs(),
            lessThanOrEqualTo(p.size.y / 2 + .001),
          );
          expect(
            (data[i + 2] - p.center.z).abs(),
            lessThanOrEqualTo(p.size.z / 2 + .001),
          );
          final n = math.sqrt(
            data[i + 3] * data[i + 3] +
                data[i + 4] * data[i + 4] +
                data[i + 5] * data[i + 5],
          );
          expect(n, closeTo(1, .001));
        }
      }
    }
  });
  test(
    'The existing race solver physically ejects a car from every new obstacle',
    () {
      for (final t in added) {
        final e = RaceEngine(
          track: t,
          car: cars.first,
          mode: RaceMode.timeTrial,
        )..countdown = 0;
        for (final o in t.themedObstacles) {
          final p = o.prop;
          e.placeDriver(e.player, o.frame.s, 0);
          final d = e.player;
          d.position = V3(p.center.x, TrackSpec.floorHeight, p.center.z);
          d.velocity = o.frame.forward * 30;
          d.speed = 30;
          e.update(1 / 120);
          final delta = d.position! - p.center;
          expect(
            delta.x.abs() >= p.size.x / 2 || delta.z.abs() >= p.size.z / 2,
            isTrue,
            reason: '${t.id} ${p.kind} has no collision',
          );
        }
      }
    },
  );
  test('Obstacle placement and theme order are deterministic', () {
    final again = createTracks().skip(26).take(25).toList();
    for (var i = 0; i < added.length; i++) {
      final a = added[i].themedObstacles, b = again[i].themedObstacles;
      expect(b.length, a.length);
      for (var j = 0; j < a.length; j++) {
        expect(b[j].prop.kind, a[j].prop.kind);
        expect((a[j].prop.center - b[j].prop.center).length, 0);
      }
    }
  });
}
