import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/content.dart';
import '../game/math3d.dart';

/// Static map paths are cached independently of moving car/pickup markers.
/// Expando keys let discarded tracks and their paths be reclaimed together.
class RouteMapGeometry {
  static final _cache = Expando<Map<Size, RouteMapGeometry>>();
  static RouteMapGeometry forTrack(TrackSpec track, Size size) {
    final sizes = _cache[track] ??= {};
    if (sizes.containsKey(size)) return sizes[size]!;
    if (sizes.length >= 4) sizes.remove(sizes.keys.first);
    return sizes[size] = RouteMapGeometry._(track, size);
  }

  final Size size;
  late final double scale, centerX, centerZ;
  late final Path route;
  late final List<Path> branches;
  late final List<Offset> gates;
  RouteMapGeometry._(TrackSpec track, this.size) {
    var minX = double.infinity,
        maxX = -double.infinity,
        minZ = double.infinity,
        maxZ = -double.infinity;
    for (final f in track.frames) {
      minX = math.min(minX, f.p.x);
      maxX = math.max(maxX, f.p.x);
      minZ = math.min(minZ, f.p.z);
      maxZ = math.max(maxZ, f.p.z);
    }
    centerX = (minX + maxX) / 2;
    centerZ = (minZ + maxZ) / 2;
    scale = math.min(
      (size.width - 16) / (maxX - minX),
      (size.height - 16) / (maxZ - minZ),
    );
    route = Path()
      ..addPolygon([
        for (var i = 0; i < track.frames.length; i += 3)
          point(track.frames[i].p),
      ], true);
    branches = [
      for (final shortcut in track.shortcuts)
        Path()
          ..addPolygon([for (final f in shortcut.frames) point(f.p)], false),
    ];
    gates = [for (final shortcut in track.shortcuts) point(shortcut.gate.p)];
  }
  Offset point(V3 p) => Offset(
    size.width / 2 + (p.x - centerX) * scale,
    size.height / 2 - (p.z - centerZ) * scale,
  );
}

class ArenaMapGeometry {
  static final _cache = Expando<ArenaMapGeometry>();
  static ArenaMapGeometry forTrack(TrackSpec track) =>
      _cache[track] ??= ArenaMapGeometry._(track);
  final obstacles = Path(), floor = Path(), raised = Path();
  ArenaMapGeometry._(TrackSpec track) {
    Offset point(V3 p) => Offset(p.x, -p.z);
    for (final o in track.obstacles) {
      obstacles.addPolygon([
        point(o.center - o.right * (o.size.x / 2) - o.forward * (o.size.z / 2)),
        point(o.center + o.right * (o.size.x / 2) - o.forward * (o.size.z / 2)),
        point(o.center + o.right * (o.size.x / 2) + o.forward * (o.size.z / 2)),
        point(o.center - o.right * (o.size.x / 2) + o.forward * (o.size.z / 2)),
      ], true);
    }
    final fs = track.frames;
    for (var i = 0; i < fs.length; i += 3) {
      final a = point(fs[i].p), b = point(fs[(i + 3) % fs.length].p);
      final path = fs[i].p.y >= .38 ? raised : floor;
      path.moveTo(a.dx, a.dy);
      path.lineTo(b.dx, b.dy);
    }
  }
}
