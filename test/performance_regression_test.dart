import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/platform.dart';

// Independent pre-optimization projection, preserving segment visitation order.
TrackProjection originalProjection(TrackSpec track, V3 p) {
  final grid = <(int, int), Set<int>>{};
  final fs = track.frames;
  for (var i = 0; i < fs.length; i++) {
    final q = fs[i].p;
    (grid[((q.x / 64).floor(), (q.z / 64).floor())] ??= {}).add(i);
  }
  final candidates = <int>{};
  final cx = (p.x / 64).floor(), cz = (p.z / 64).floor();
  for (var x = cx - 1; x <= cx + 1; x++)
    for (var z = cz - 1; z <= cz + 1; z++) {
      for (final i in grid[(x, z)] ?? const <int>{}) {
        candidates.add(i);
        candidates.add((i - 1) % fs.length);
      }
    }
  if (candidates.isEmpty)
    for (var i = 0; i < fs.length; i += 4) candidates.add(i);
  var best = double.infinity, s = 0.0;
  for (final i in candidates) {
    final a = fs[i], b = fs[(i + 1) % fs.length], v = b.p - a.p;
    final t = ((p - a.p).dot(v) / math.max(.000001, v.dot(v)))
        .clamp(0, 1)
        .toDouble();
    final delta = p - (a.p + v * t), ds = delta.dot(delta);
    if (ds < best) {
      best = ds;
      s = a.s + t * ((i + 1 == fs.length ? track.length : b.s) - a.s);
    }
  }
  final f = track.at(s), delta = p - f.p;
  return TrackProjection(f, delta.dot(f.right), delta.dot(f.up), best);
}

void main() {
  test(
    'Cached projection matches the original in all circuits, loops and arena heights',
    () {
      for (final t in [
        ...createTracks(),
        ...createBattleArenas().map((a) => a.track),
      ]) {
        for (var i = 0; i < 35; i++) {
          final f = t.at(t.length * i / 35);
          for (final offset in [-31.0, 0.0, 31.0]) {
            final p = f.p + f.right * offset + f.up * (i % 3 == 0 ? -8 : 5);
            final old = originalProjection(t, p), now = t.project(p);
            expect(now.frame.s, closeTo(old.frame.s, 1e-8), reason: t.id);
            expect(now.lateral, closeTo(old.lateral, 1e-8));
            expect(now.height, closeTo(old.height, 1e-8));
            expect(now.squaredDistance, closeTo(old.squaredDistance, 1e-7));
          }
        }
        final p = const V3(-2800, 510, 4200), old = originalProjection(t, p);
        // Evict both bounded caches and repeat a far-away fallback query.
        for (var i = 0; i < 300; i++) t.project(V3(i * 64.0, 0, -8000));
        expect(t.project(p).frame.s, closeTo(old.frame.s, 1e-8));
      }
    },
  );
  test(
    'Worker preparation returns identical world and car bytes without remapping slots',
    () async {
      final t = createTracks().first;
      final result = await GpuResources.prepare(
        track: t,
        bodies: {cars.last.body},
      );
      expect(listEquals(result.$1, GpuResources.world(t)), isTrue);
      final expected = GpuResources.objectsFor({cars.last.body});
      expect(result.$2.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(
          listEquals(result.$2[i], expected[i]),
          isTrue,
          reason: 'mesh $i',
        );
      }
    },
  );
  test(
    'Automatic quality migrates old graphics settings and preserves explicit new choices',
    () {
      final old = GameSettings()
        ..restore({'quality': 'high', 'difficulty': 'hard', 'music': .8});
      expect(old.quality, 'auto');
      expect(old.difficulty, 'hard');
      expect(old.music, .8);
      final current = GameSettings()..quality = 'low';
      final restored = GameSettings()..restore(current.toJson());
      expect(restored.quality, 'low');
    },
  );
}
