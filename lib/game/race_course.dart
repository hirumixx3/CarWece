part of 'content.dart';

class CourseBarrier {
  final TrackFrame frame;
  final String kind;
  final double length, height;
  const CourseBarrier(
    this.frame,
    this.kind, {
    this.length = 9.7,
    this.height = 12,
  });
  WorldObstacle get collider => WorldObstacle(
    frame.p + const V3(0, 6, 0),
    V3(5, 12, length),
    visible: false,
    right: frame.right,
    forward: frame.forward,
  );
}

class ShortcutSpec {
  final String id;
  final int entryCheckpoint, exitCheckpoint;
  final double entryS, exitS, width;
  final List<TrackFrame> frames;
  final double length;
  const ShortcutSpec(
    this.id,
    this.entryCheckpoint,
    this.exitCheckpoint,
    this.entryS,
    this.exitS,
    this.frames,
    this.length, {
    this.width = 20,
  });
  TrackFrame at(double s) {
    s = s.clamp(0, length);
    var lo = 0, hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (frames[mid].s <= s) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    if (lo == frames.length - 1) return frames.last;
    final a = frames[lo],
        b = frames[lo + 1],
        t = (s - a.s) / (b.s - a.s),
        f = a.forward.lerp(b.forward, t).unit;
    final r = const V3(0, 1, 0).cross(f).unit;
    return TrackFrame(a.p.lerp(b.p, t), r, const V3(0, 1, 0), f, s);
  }

  TrackProjection project(V3 p) {
    var best = double.infinity, s = 0.0;
    for (var i = 0; i < frames.length - 1; i++) {
      final a = frames[i], b = frames[i + 1], v = b.p - a.p;
      final t = ((p - a.p).dot(v) / v.dot(v)).clamp(0.0, 1.0),
          ds = (p - a.p - v * t).length;
      if (ds < best) {
        best = ds;
        s = a.s + (b.s - a.s) * t;
      }
    }
    final f = at(s), d = p - f.p;
    return TrackProjection(f, d.dot(f.right), d.y, best * best);
  }

  TrackFrame get gate => at(length * .50);
  TrackFrame get entrance => at(length * .22);
  TrackFrame portal(int index) =>
      at(length * ([.22, .47, .74, 1.0][index.clamp(0, 3)]));
  WorldObstacle get gateCollider => WorldObstacle(
    gate.p + const V3(0, 5, 0),
    V3(width, 10, 2),
    visible: false,
    right: gate.right,
    forward: gate.forward,
  );
}

/// Choose a genuine shorter, clear alternate route, with a protected merge at
/// both ends. Entry/exit always correspond to ordered main-track checkpoints.
void buildRaceCourse(TrackSpec t) {
  ShortcutSpec? selected;
  var bestScore = 0.0;
  for (var k = 2; k < 26; k++)
    for (var span = 3; span <= 6 && k + span < 30; span++) {
      final a = t.checkpoint(k), b = t.checkpoint(k + span), arc = b.s - a.s;
      if (!t.isFloor(a.s) || !t.isFloor(b.s)) continue;
      var allFloor = true;
      for (var j = 0; j <= 12; j++)
        if (!t.isFloor(a.s + arc * j / 12)) {
          allFloor = false;
          break;
        }
      if (!allFloor) continue;
      final direct = (b.p - a.p).length;
      if (direct < 85 || direct > arc * .89 || direct < arc * .38) continue;
      final bend = math.min(70.0, direct * .20),
          p0 = a.p,
          p1 = a.p + a.forward * bend,
          p2 = b.p - b.forward * bend,
          p3 = b.p;
      V3 point(double u) {
        final v = 1 - u;
        return p0 * (v * v * v) +
            p1 * (3 * v * v * u) +
            p2 * (3 * v * u * u) +
            p3 * (u * u * u);
      }

      final frames = <TrackFrame>[];
      var len = 0.0, clear = true;
      for (var j = 0; j <= 64; j++) {
        final u = j / 64,
            p = point(u),
            f =
                (point(math.min(1.0, u + .001)) -
                        point(math.max(0.0, u - .001)))
                    .unit;
        if (j > 0) len += (p - frames.last.p).length;
        frames.add(
          TrackFrame(
            p,
            const V3(0, 1, 0).cross(f).unit,
            const V3(0, 1, 0),
            f,
            len,
          ),
        );
        if (j < 4 || j > 60) continue;
        for (final o in t.obstacles) {
          if (o.center.y - o.size.y / 2 > 5) continue;
          if ((p.x - o.center.x).abs() < o.size.x / 2 + 15 &&
              (p.z - o.center.z).abs() < o.size.z / 2 + 15) {
            clear = false;
            break;
          }
        }
        if (p.x.abs() > 800 || p.z.abs() > 800) clear = false;
        if (!clear) break;
      }
      if (!clear || len > arc * .91) continue;
      final candidate = ShortcutSpec(
        '${t.id}-shortcut',
        k,
        k + span,
        a.s,
        b.s,
        frames,
        len,
      );
      final middle = t.project(candidate.gate.p);
      if (middle.squaredDistance <
          math.pow(t.widthAt(middle.frame.s) / 2 + 14, 2))
        continue;
      // A branch must not cut across a second part of the circuit on the floor.
      for (var j = 20; j <= 44; j += 3) {
        final p = t.project(frames[j].p);
        if ((p.frame.p - frames[j].p).length < 25) {
          clear = false;
          break;
        }
      }
      if (!clear) continue;
      final score = arc - len;
      if (score > bestScore) {
        selected = candidate;
        bestScore = score;
      }
    }
  if (selected != null) t.shortcuts.add(selected);
  bool insideBranch(V3 p) => t.shortcuts.any(
    (s) => s.project(p).squaredDistance < math.pow(s.width / 2 + 3.4, 2),
  );
  bool insideMain(V3 p) {
    final q = t.project(p);
    return q.height.abs() < 3 &&
        q.squaredDistance < math.pow(t.widthAt(q.frame.s) / 2 + 2.0, 2);
  }

  final kind = switch (t.room) {
    'QUARTO' => 'books',
    'GARAGEM' => 'crates',
    'BANHEIRO' => 'towels',
    'COZINHA' => 'cartons',
    'SALA' => 'cases',
    _ => 'dominoes',
  };
  void add(TrackFrame f, double lateral) {
    final p = f.point(lateral), r = const V3(0, 1, 0).cross(f.forward).unit;
    final barrier = CourseBarrier(
      TrackFrame(p, r, const V3(0, 1, 0), f.forward, f.s),
      kind,
    );
    t.barriers.add(barrier);
    t.barrierGrid
        .putIfAbsent(((p.x / 64).floor(), (p.z / 64).floor()), () => [])
        .add(barrier.collider);
  }

  // Tightly packed solid household objects define the complete floor corridor.
  for (var s = 0.0; s < t.length; s += 9.0) {
    if (!t.isFloor(s)) continue;
    final f = t.at(s);
    for (final side in [-1.0, 1.0]) {
      final lateral = side * (t.widthAt(s) / 2 + 2.5);
      if (!insideBranch(f.point(lateral))) add(f, lateral);
    }
  }
  for (final path in t.shortcuts)
    for (var s = 0.0; s <= path.length; s += 9.0) {
      final f = path.at(s);
      for (final side in [-1.0, 1.0]) {
        final lateral = side * (path.width / 2 + 2.5);
        if (!insideMain(f.point(lateral))) add(f, lateral);
      }
    }
}
