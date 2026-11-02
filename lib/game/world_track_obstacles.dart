part of 'content.dart';

/// Solid, visible toy obstacles inside the new race corridors, not scenery.
/// Axis-aligned bounds are shared by the render mesh, AI and collision solver.
class ExpansionTrackObstacle {
  final RoomProp prop;
  final TrackFrame frame;
  const ExpansionTrackObstacle(this.prop, this.frame);
  WorldObstacle get collider =>
      WorldObstacle(prop.center, prop.size, color: prop.color, visible: false);
}

const expansionObstacleKinds = <String, List<String>>{
  'FLORESTA': ['log', 'stump', 'rock', 'tree'],
  'PRÉ-HISTÓRIA': ['eggs', 'fossil', 'rock', 'rex'],
  'DESERTO': ['cactus', 'sandrock', 'dune', 'sandrock'],
  'NEVE': ['snowrock', 'iceberg', 'snowball', 'snowpine'],
  'LITORAL': ['buoy', 'shell', 'coral', 'driftwood'],
};

V3 expansionObstaclePrototypeSize(String kind) => _worldPropSize(kind);

V3 expansionObstacleSize(String kind) {
  final size = switch (kind) {
    'log' || 'driftwood' => const V3(16, 7, 10),
    'stump' => const V3(12, 12, 12),
    'tree' => const V3(12, 26, 12),
    'eggs' => const V3(14, 10, 12),
    'fossil' => const V3(14, 8, 12),
    'rex' => const V3(13, 21, 16),
    'cactus' => const V3(12, 24, 10),
    'dune' => const V3(16, 8, 14),
    'iceberg' => const V3(13, 18, 13),
    'snowball' => const V3(12, 12, 12),
    'snowpine' => const V3(12, 26, 12),
    'buoy' => const V3(11, 20, 11),
    'shell' => const V3(14, 8, 12),
    'coral' => const V3(13, 15, 12),
    _ => const V3(14, 10, 13),
  };
  // Compact footprints leave steering room even on diagonal 46-unit sectors.
  return V3(size.x * .82, size.y, size.z * .82);
}

/// This runs AFTER shortcut selection and trackside placement. The decoration
/// safety rules intentionally exclude road props, so obstacles are a separate
/// collection. Nothing is added to old circuits or to the battle arenas.
void populateExpansionObstacles(TrackSpec t, int trackIndex) {
  if ((!expansionCircuitStars.containsKey(t.id) &&
          !brazilLoopStars.containsKey(t.id)) ||
      !t.outdoor ||
      t.openArena)
    return;
  t.obstacles.removeWhere((o) => o.visible); // replace generic storage boxes
  final kinds = expansionObstacleKinds[t.room]!;
  final variant = trackIndex % 5;
  final planned = <ExpansionTrackObstacle>[];

  bool tryAdd(double s) {
    // Clear start grid, finish approach, bridges and all loop transitions.
    if (s < 220 || s > t.length - 160) return false;
    if ([-65.0, -30.0, 0.0, 30.0, 65.0].any((d) => !t.isFloor(s + d))) {
      return false;
    }
    if (t.loops.any((l) => s > l.start - 100 && s < l.end + 100)) return false;
    final f = t.at(s);
    if (t.at(s - 25).forward.dot(t.at(s + 25).forward) < .94) return false;
    if (planned.any((o) => (o.frame.s - s).abs() < 100)) return false;
    final n = planned.length;
    final kind = kinds[(n + variant) % kinds.length];
    final size = expansionObstacleSize(kind);
    // Slalom changes phase on each track. An unobstructed center line and at
    // least a car + steering margin remain, even when the road is diagonal.
    final side = (n + variant).isEven ? 1.0 : -1.0;
    final extent = (f.right.x.abs() * size.x + f.right.z.abs() * size.z) / 2;
    final lateral = side * (t.widthAt(s) / 2 - extent - 2.5);
    if (lateral.abs() - extent < 4.4) return false;
    final p = f.point(lateral);
    final center = V3(p.x, TrackSpec.floorHeight + size.y / 2, p.z);
    // Keep the entire footprint inside the corridor, including curving edges.
    for (final x in [-1.0, 1.0]) {
      for (final z in [-1.0, 1.0]) {
        final q = t.project(
          V3(p.x + x * size.x / 2, TrackSpec.floorHeight, p.z + z * size.z / 2),
        );
        if (q.lateral.abs() > t.widthAt(q.frame.s) / 2 - 1.3) return false;
      }
    }
    if (t.shortcuts.any(
      (path) => path.frames.any(
        (q) =>
            (q.p.x - center.x).abs() < size.x / 2 + path.width / 2 + 8 &&
            (q.p.z - center.z).abs() < size.z / 2 + path.width / 2 + 8,
      ),
    ))
      return false;
    // Do not obstruct the launch, flight or landing area of the existing ramp.
    if (t.ramps.any((r) {
      // Follow route distance too: a jump can land past a bend, well beyond
      // the ramp's local forward axis (especially on the low-grip snow floor).
      final gap = wrap(s - r.frame.s, t.length);
      if (gap < 320 || gap > t.length - 80) return true;
      final d = center - r.frame.p;
      return d.dot(r.frame.forward).abs() < r.length / 2 + 75 &&
          d.dot(r.frame.right).abs() < r.width / 2 + 15;
    }))
      return false;
    if (t.obstacles.any(
      (o) =>
          (center.x - o.center.x).abs() < (size.x + o.size.x) / 2 + 3 &&
          (center.z - o.center.z).abs() < (size.z + o.size.z) / 2 + 3,
    ))
      return false;
    if (planned.any((o) => (o.prop.center - center).length < 90)) return false;
    planned.add(
      ExpansionTrackObstacle(
        RoomProp(kind, center, size, expansionBiomes[t.room]!.accent),
        f,
      ),
    );
    return true;
  }

  // Twelve distributed stations per map. Deterministic fallbacks handle local
  // turns/branches, without random placements or a runtime retry loop.
  for (var station = 0; station < 12; station++) {
    final target = t.length * (.07 + station * .073 + variant * .0015);
    for (final shift in [0.0, 24.0, -24.0, 48.0, -48.0, 72.0, -72.0]) {
      if (tryAdd(target + shift)) break;
    }
  }
  for (
    var s = 240.0 + variant * 9;
    s < t.length - 180 && planned.length < 12;
    s += 28
  ) {
    tryAdd(s);
  }
  // Add only validated stations; tests require exactly twelve on all 25 maps.
  planned.sort((a, b) => a.frame.s.compareTo(b.frame.s));
  t.themedObstacles.addAll(planned);
  t.obstacles.addAll(planned.map((o) => o.collider));
}
