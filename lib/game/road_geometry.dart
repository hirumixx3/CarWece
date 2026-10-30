part of 'content.dart';

/// The two actual triangles of every visible ribbon segment. Separate from
/// route projection: stacked/looping ribbons can all be solid at the same XZ.
class RoadTriangle {
  final V3 a, b, c;
  final double s;
  late final V3 normal;
  late final List<V3> edges;
  late final double minX, maxX, minY, maxY, minZ, maxZ;
  RoadTriangle(this.a, this.b, this.c, V3 up, this.s) {
    var n = (b - a).cross(c - a).unit;
    if (n.dot(up) < 0) n = n * -1;
    normal = n;
    edges = [
      (b - a).cross(n).unit,
      (c - b).cross(n).unit,
      (a - c).cross(n).unit,
    ];
    final center = (a + b + c) * (1 / 3);
    final origins = [a, b, c];
    for (var i = 0; i < 3; i++)
      if ((center - origins[i]).dot(edges[i]) < 0) edges[i] = edges[i] * -1;
    minX = math.min(a.x, math.min(b.x, c.x));
    maxX = math.max(a.x, math.max(b.x, c.x));
    minY = math.min(a.y, math.min(b.y, c.y)) - .5;
    maxY = math.max(a.y, math.max(b.y, c.y));
    minZ = math.min(a.z, math.min(b.z, c.z));
    maxZ = math.max(a.z, math.max(b.z, c.z));
  }
  bool overlaps(V3 center, V3 half) =>
      center.x + half.x >= minX - .5 &&
      center.x - half.x <= maxX + .5 &&
      center.y + half.y >= minY &&
      center.y - half.y <= maxY + .5 &&
      center.z + half.z >= minZ - .5 &&
      center.z - half.z <= maxZ + .5;
  bool containsBody(V3 center, V3 forward, V3 right, V3 up) {
    final origins = [a, b, c];
    for (var i = 0; i < 3; i++) {
      final e = edges[i];
      final extent =
          forward.dot(e).abs() * DriverDimensions.length +
          right.dot(e).abs() * DriverDimensions.width +
          up.dot(e).abs() * 1.4;
      if ((center - origins[i]).dot(e) < -extent - .03) return false;
    }
    return true;
  }

  bool containsPoint(V3 point) =>
      (point - a).dot(edges[0]) >= -.03 &&
      (point - b).dot(edges[1]) >= -.03 &&
      (point - c).dot(edges[2]) >= -.03;
}

// Shared dimensions without a dependency from content back to the engine.
class DriverDimensions {
  static const width = 1.95, length = 3.65;
}

class RoadCollisionMesh {
  final Map<(int, int), List<RoadTriangle>> _grid = {};
  final Map<(int, int), List<RoadTriangle>> _cache = {};
  RoadCollisionMesh(TrackSpec track) {
    final fs = track.frames, w = track.width / 2;
    for (var i = 0; i < fs.length; i++) {
      final a = fs[i], b = fs[(i + 1) % fs.length];
      if (track.isFloor((a.s + (i + 1 == fs.length ? track.length : b.s)) * .5))
        continue;
      final up = (a.up + b.up).unit;
      for (final tri in [
        RoadTriangle(a.point(-w), b.point(-w), b.point(w), up, a.s),
        RoadTriangle(a.point(-w), b.point(w), a.point(w), up, a.s),
      ]) {
        for (var x = (tri.minX / 64).floor(); x <= (tri.maxX / 64).floor(); x++)
          for (
            var z = (tri.minZ / 64).floor();
            z <= (tri.maxZ / 64).floor();
            z++
          )
            (_grid[(x, z)] ??= []).add(tri);
      }
    }
  }
  List<RoadTriangle> near(V3 point) {
    final key = ((point.x / 64).floor(), (point.z / 64).floor());
    final old = _cache[key];
    if (old != null) return old;
    final faces = <RoadTriangle>{};
    for (var x = key.$1 - 1; x <= key.$1 + 1; x++)
      for (var z = key.$2 - 1; z <= key.$2 + 1; z++)
        faces.addAll(_grid[(x, z)] ?? const []);
    if (_cache.length >= 128) _cache.remove(_cache.keys.first);
    return _cache[key] = faces.toList();
  }
}
