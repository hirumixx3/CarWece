import 'dart:math' as math;
import 'dart:typed_data';
import 'content.dart';
import 'math3d.dart';

part 'car_mesh.dart';
part 'car_details_v09.dart';
part 'room_mesh.dart';
part 'room_finish.dart';
part 'detailed_props.dart';
part 'course_mesh.dart';
part 'world_expansion_mesh.dart';
part 'world_track_obstacle_mesh.dart';
part 'car_details_world.dart';
part 'car_details_brazil.dart';
part 'brazil_indoor_mesh.dart';

/// Vertex layout shared with the Android GLES renderer and the offscreen QA tool:
/// position.xyz, normal.xyz, linear-input color.rgb, texture.uv, material.
class Material3 {
  static const paint = 0, rubber = 1, glass = 2, metal = 3, wood = 4;
  static const fabric = 5,
      wall = 6,
      track = 7,
      decal = 8,
      glow = 9,
      plastic = 10,
      tile = 13,
      ceramic = 14,
      concrete = 15;
}

class Mesh3 {
  final List<double> data = [];
  Float32List get buffer => Float32List.fromList(data);
  int get triangles => data.length ~/ 36;
  void vertex(V3 p, V3 n, int color, double u, double v, int material) {
    data.addAll([
      p.x,
      p.y,
      p.z,
      n.x,
      n.y,
      n.z,
      ((color >> 16) & 255) / 255,
      ((color >> 8) & 255) / 255,
      (color & 255) / 255,
      u,
      v,
      material.toDouble(),
    ]);
  }

  void triangle(
    V3 a,
    V3 b,
    V3 c,
    int color,
    int material, {
    V3? na,
    V3? nb,
    V3? nc,
    double u0 = 0,
    double v0 = 0,
    double u1 = 1,
    double v1 = 0,
    double u2 = 1,
    double v2 = 1,
  }) {
    final n = (b - a).cross(c - a).unit;
    vertex(a, na ?? n, color, u0, v0, material);
    if (na != null && nb != null && nc != null && n.dot(na + nb + nc) < 0) {
      vertex(c, nc, color, u2, v2, material);
      vertex(b, nb, color, u1, v1, material);
      return;
    }
    vertex(b, nb ?? n, color, u1, v1, material);
    vertex(c, nc ?? n, color, u2, v2, material);
  }

  void quad(
    V3 a,
    V3 b,
    V3 c,
    V3 d,
    int color,
    int material, {
    V3? na,
    V3? nb,
    V3? nc,
    V3? nd,
    double repeatU = 1,
    double repeatV = 1,
  }) {
    triangle(
      a,
      b,
      c,
      color,
      material,
      na: na,
      nb: nb,
      nc: nc,
      u1: repeatU,
      u2: repeatU,
      v2: repeatV,
    );
    triangle(
      a,
      c,
      d,
      color,
      material,
      na: na,
      nb: nc,
      nc: nd,
      u1: repeatU,
      v1: repeatV,
      u2: 0,
      v2: repeatV,
    );
  }

  void box(
    V3 center,
    V3 size,
    int color,
    int material, {
    V3 r = const V3(1, 0, 0),
    V3 u = const V3(0, 1, 0),
    V3 f = const V3(0, 0, 1),
  }) {
    V3 p(double x, double y, double z) =>
        center +
        r * (x * size.x * .5) +
        u * (y * size.y * .5) +
        f * (z * size.z * .5);
    quad(
      p(-1, -1, -1),
      p(-1, 1, -1),
      p(1, 1, -1),
      p(1, -1, -1),
      color,
      material,
    );
    quad(p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1), p(-1, -1, 1), color, material);
    quad(
      p(-1, -1, 1),
      p(-1, 1, 1),
      p(-1, 1, -1),
      p(-1, -1, -1),
      color,
      material,
    );
    quad(p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), p(1, -1, 1), color, material);
    quad(p(-1, 1, -1), p(-1, 1, 1), p(1, 1, 1), p(1, 1, -1), color, material);
    quad(
      p(-1, -1, 1),
      p(-1, -1, -1),
      p(1, -1, -1),
      p(1, -1, 1),
      color,
      material,
    );
  }

  void roundedBox(V3 center, V3 size, double radius, int color, int material) {
    final rings = <List<V3>>[];
    for (final t in [0.0, .07, .93, 1.0]) {
      final inset = (t == 0 || t == 1) ? radius * .18 : 0.0;
      final ring = <V3>[];
      for (var corner = 0; corner < 4; corner++) {
        final sx = corner == 0 || corner == 3 ? 1.0 : -1.0,
            sz = corner < 2 ? 1.0 : -1.0;
        for (var j = 0; j <= 4; j++) {
          final a = corner * math.pi * .5 + j / 4 * math.pi * .5;
          ring.add(
            center +
                V3(
                  sx * (size.x / 2 - radius - inset) + math.cos(a) * radius,
                  (t - .5) * size.y,
                  sz * (size.z / 2 - radius - inset) + math.sin(a) * radius,
                ),
          );
        }
      }
      rings.add(ring);
    }
    for (var r = 0; r < rings.length - 1; r++) {
      for (var j = 0; j < rings[r].length; j++) {
        final k = (j + 1) % rings[r].length;
        quad(
          rings[r][j],
          rings[r + 1][j],
          rings[r + 1][k],
          rings[r][k],
          color,
          material,
        );
      }
    }
    for (var j = 0; j < rings.last.length; j++) {
      triangle(
        center + V3(0, size.y * .5, 0),
        rings.last[j],
        rings.last[(j + 1) % rings.last.length],
        color,
        material,
        na: const V3(0, 1, 0),
        nb: const V3(0, 1, 0),
        nc: const V3(0, 1, 0),
      );
    }
  }

  void cylinder(
    V3 center,
    V3 axis,
    double length,
    double r0,
    double r1,
    int color,
    int material, {
    int segments = 32,
  }) {
    axis = axis.unit;
    final right =
        (axis.y.abs() < .9
                ? axis.cross(const V3(0, 1, 0))
                : axis.cross(const V3(1, 0, 0)))
            .unit;
    final up = axis.cross(right).unit;
    V3 radial(double a) => right * math.cos(a) + up * math.sin(a);
    for (var i = 0; i < segments; i++) {
      final a = i / segments * math.pi * 2,
          b = (i + 1) / segments * math.pi * 2;
      final n1 = (radial(a) + axis * ((r0 - r1) / length)).unit,
          n2 = (radial(b) + axis * ((r0 - r1) / length)).unit;
      final p1 = center - axis * (length / 2) + radial(a) * r0,
          p2 = center + axis * (length / 2) + radial(a) * r1;
      final p3 = center + axis * (length / 2) + radial(b) * r1,
          p4 = center - axis * (length / 2) + radial(b) * r0;
      quad(p1, p2, p3, p4, color, material, na: n1, nb: n1, nc: n2, nd: n2);
      triangle(
        center - axis * (length / 2),
        p1,
        p4,
        color,
        material,
        na: axis * -1,
        nb: axis * -1,
        nc: axis * -1,
      );
      triangle(
        center + axis * (length / 2),
        p3,
        p2,
        color,
        material,
        na: axis,
        nb: axis,
        nc: axis,
      );
    }
  }

  void text(String text, V3 origin, V3 right, V3 up, double size, int color) {
    const glyphs = {
      'P': ['111', '101', '111', '100', '100'],
      'O': ['111', '101', '101', '101', '111'],
      'C': ['111', '100', '100', '100', '111'],
      'K': ['101', '110', '100', '110', '101'],
      'E': ['111', '100', '110', '100', '111'],
      'T': ['111', '010', '010', '010', '010'],
      'R': ['110', '101', '110', '101', '101'],
      'U': ['101', '101', '101', '101', '111'],
      'S': ['111', '100', '111', '001', '111'],
      'H': ['101', '101', '111', '101', '101'],
      '0': ['111', '101', '101', '101', '111'],
      '1': ['010', '110', '010', '010', '111'],
      '2': ['111', '001', '111', '100', '111'],
      '3': ['111', '001', '111', '001', '111'],
      '4': ['101', '101', '111', '001', '001'],
      '5': ['111', '100', '111', '001', '111'],
      '6': ['111', '100', '111', '101', '111'],
      '7': ['111', '001', '010', '010', '010'],
      '8': ['111', '101', '111', '101', '111'],
      '9': ['111', '101', '111', '001', '111'],
      'A': ['010', '101', '111', '101', '101'],
      'D': ['110', '101', '101', '101', '110'],
      'V': ['101', '101', '101', '101', '010'],
      'F': ['111', '100', '110', '100', '100'],
      'L': ['100', '100', '100', '100', '111'],
      'N': ['101', '111', '111', '111', '101'],
      'I': ['111', '010', '010', '010', '111'],
      'X': ['101', '101', '010', '101', '101'],
      'B': ['110', '101', '110', '101', '110'],
      'G': ['111', '100', '101', '101', '111'],
      'M': ['101', '111', '111', '101', '101'],
      'W': ['101', '101', '111', '111', '101'],
      'Y': ['101', '101', '010', '010', '010'],
      ' ': ['000', '000', '000', '000', '000'],
    };
    for (var i = 0; i < text.length; i++) {
      final rows = glyphs[text[i]] ?? glyphs[' ']!;
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 3; x++) {
          if (rows[y][x] != '1') continue;
          final p =
              origin + right * ((i * 4 + x) * size) + up * ((4 - y) * size);
          quad(
            p,
            p + right * size * .86,
            p + right * size * .86 + up * size * .86,
            p + up * size * .86,
            color,
            Material3.decal,
          );
        }
      }
    }
  }
}

Mesh3 buildWorldMesh(TrackSpec track) {
  final m = Mesh3(), w = track.width / 2;
  final fs = track.frames;
  for (var i = 0; i < fs.length; i++) {
    final a = fs[i], b = fs[(i + 1) % fs.length];
    if (track.isFloor((a.s + (i + 1 == fs.length ? track.length : b.s)) * .5)) {
      if (track.outdoor && !track.openArena) {
        buildExpansionFloorRibbon(m, track, a, b, i);
      }
      if (!track.openArena && i % 24 == 0) {
        final p = a.point(0, .025);
        m.triangle(
          p + a.forward * 4,
          p - a.forward * 2 - a.right * 1.8,
          p - a.forward * 2 + a.right * 1.8,
          0xff5ee2d0,
          Material3.decal,
        );
      }
      if (track.isBoost(a.s, 0)) {
        m.quad(
          a.point(-w * .7, .035),
          b.point(-w * .7, .035),
          b.point(w * .7, .035),
          a.point(w * .7, .035),
          i.isEven ? 0xff1de8ff : 0xff1e539e,
          Material3.glow,
        );
      }
      continue;
    }
    m.quad(
      a.point(-w),
      b.point(-w),
      b.point(w),
      a.point(w),
      0xffef5813,
      Material3.track,
      na: a.up,
      nb: b.up,
      nc: b.up,
      nd: a.up,
      repeatU: (b.p - a.p).length,
      repeatV: 1,
    );
    m.quad(
      a.point(w, -.45),
      b.point(w, -.45),
      b.point(-w, -.45),
      a.point(-w, -.45),
      0xffb84912,
      Material3.plastic,
    );
    for (final side in [-1.0, 1.0]) {
      final profile = [
        (w * side, 0.0),
        ((w + .13) * side, .4),
        ((w + .09) * side, .9),
        ((w - .22) * side, 1.03),
        ((w - .35) * side, .85),
        ((w - .33) * side, .15),
      ];
      for (var j = 0; j < profile.length - 1; j++) {
        final p = profile[j], q = profile[j + 1];
        m.quad(
          a.point(p.$1, p.$2),
          b.point(p.$1, p.$2),
          b.point(q.$1, q.$2),
          a.point(q.$1, q.$2),
          j == 2 ? 0xffffc05d : 0xffff912d,
          Material3.track,
        );
      }
      if (i % 18 < 4)
        m.quad(
          a.point(side * w * .97, .025),
          b.point(side * w * .97, .025),
          b.point(side * w * .86, .025),
          a.point(side * w * .86, .025),
          0xffffdfa1,
          Material3.decal,
        );
    }
    if (i % 14 < 6) {
      for (final lane in [-.5, 0.0, .5]) {
        m.quad(
          a.point(w * lane - .055, .03),
          b.point(w * lane - .055, .03),
          b.point(w * lane + .055, .03),
          a.point(w * lane + .055, .03),
          0xffffbb64,
          Material3.decal,
        );
      }
    }
    if (track.isShortcut(a.s, .8))
      m.quad(
        a.point(w * .55, .035),
        b.point(w * .55, .035),
        b.point(w * .95, .035),
        a.point(w * .95, .035),
        0xff9bd837,
        Material3.decal,
      );
    if (track.isBoost(a.s, 0)) {
      final color = i % 4 < 2 ? 0xff1de8ff : 0xff1e539e;
      m.quad(
        a.point(-w * .51, .045),
        b.point(-w * .51, .045),
        b.point(w * .51, .045),
        a.point(w * .51, .045),
        color,
        Material3.glow,
      );
    }
    if (!track.openArena && a.s < 7) {
      for (var j = 0; j < 10; j++) {
        final x = -w + j * w / 5;
        m.quad(
          a.point(x, .06),
          b.point(x, .06),
          b.point(x + w / 5, .06),
          a.point(x + w / 5, .06),
          (j + i) % 2 == 0 ? 0xfffaf2dd : 0xff182738,
          Material3.decal,
        );
      }
    }
    if (i % 40 == 0 && a.p.y > 7 && a.up.y > .4) {
      for (final side in [-1.0, 1.0]) {
        final top = a.point(side * (w - .5), -1);
        m.cylinder(
          V3(top.x, top.y * .5, top.z),
          const V3(0, 1, 0),
          top.y,
          1.05,
          .70,
          0xff1c6ba2,
          Material3.plastic,
          segments: 12,
        );
        m.box(
          V3(top.x, .4, top.z),
          const V3(6, .8, 6),
          0xff205c91,
          Material3.plastic,
        );
      }
    }
    if (i % 8 == 0)
      m.box(
        a.point(0, -.48),
        V3(track.width + .6, .19, .4),
        0xffd55313,
        Material3.plastic,
        r: a.right,
        u: a.up,
        f: a.forward,
      );
    if (i % 48 == 0) {
      // Moulded joints, countersunk fasteners and dark seam across the ribbon.
      m.box(
        a.point(0, .015),
        V3(track.width - .8, .025, .11),
        0xffb64613,
        Material3.plastic,
        r: a.right,
        u: a.up,
        f: a.forward,
      );
      for (final side in [-1.0, 1.0]) {
        m.box(
          a.point(side * (w - 1.25), -.36),
          const V3(2.5, .25, 3.5),
          0xff236082,
          Material3.plastic,
          r: a.right,
          u: a.up,
          f: a.forward,
        );
        m.cylinder(
          a.point(side * (w - 1.2), .047),
          a.up,
          .06,
          .27,
          .27,
          0xffb9c3bb,
          Material3.metal,
          segments: 8,
        );
      }
    }
  }
  for (final ramp in track.ramps) {
    final f = ramp.frame,
        w = ramp.width / 2,
        l = ramp.length / 2,
        h = ramp.height;
    m.quad(
      f.point(-w) - f.forward * l,
      f.point(w) - f.forward * l,
      f.point(w, h) + f.forward * l,
      f.point(-w, h) + f.forward * l,
      0xffff922b,
      Material3.track,
    );
    m.triangle(
      f.point(-w) - f.forward * l,
      f.point(-w) + f.forward * l,
      f.point(-w, h) + f.forward * l,
      0xff225683,
      Material3.plastic,
    );
    m.triangle(
      f.point(w) - f.forward * l,
      f.point(w, h) + f.forward * l,
      f.point(w) + f.forward * l,
      0xff225683,
      Material3.plastic,
    );
    // Closed rear face matches the solid wedge collider.
    m.quad(
      f.point(-w) + f.forward * l,
      f.point(w) + f.forward * l,
      f.point(w, h) + f.forward * l,
      f.point(-w, h) + f.forward * l,
      0xff21516d,
      Material3.plastic,
    );
    final slope = (f.forward * ramp.length + f.up * h).unit;
    final normal = slope.cross(f.right).unit;
    for (final side in [-1.0, 1.0]) {
      m.box(
        f.point(side * (w - .15), h * .5 + .28),
        V3(.38, .56, math.sqrt(ramp.length * ramp.length + h * h)),
        0xffd7651c,
        Material3.track,
        r: f.right,
        u: normal,
        f: slope,
      );
      for (final z in [-l * .75, l * .75]) {
        final y = (z / ramp.length + .5) * h;
        m.cylinder(
          f.point(side * (w - .9), y + .055) + f.forward * z,
          normal,
          .07,
          .28,
          .28,
          0xffb2bbb5,
          Material3.metal,
          segments: 8,
        );
      }
    }
    for (var i = 0; i < 4; i++) {
      final z = -l + (i + .5) * ramp.length / 4;
      final y = (z / ramp.length + .5) * h * .5;
      m.box(
        f.point(0, y) + f.forward * z,
        V3(ramp.width - .8, math.max(.2, y * 2), .35),
        0xff285777,
        Material3.plastic,
        r: f.right,
        u: f.up,
        f: f.forward,
      );
    }
    for (var i = 0; i < 4; i++) {
      final z = -l + (i + .3) * ramp.length / 4,
          y = (z / ramp.length + .5) * h + .04;
      final a = f.point(-w * .9, y) + f.forward * z,
          b = f.point(w * .9, y) + f.forward * z;
      m.quad(
        a,
        b,
        b + f.forward * .5 + f.up * (.5 / ramp.length * h),
        a + f.forward * .5 + f.up * (.5 / ramp.length * h),
        0xffffe060,
        Material3.decal,
      );
    }
  }
  for (final obstacle in track.obstacles.where((o) => o.visible)) {
    final red = (obstacle.color >> 16) & 255,
        green = (obstacle.color >> 8) & 255;
    final cardboard =
        obstacle.size.x > 15 && obstacle.size.z > 15 && red > green * 1.13;
    m.roundedBox(
      obstacle.center,
      obstacle.size,
      .5,
      obstacle.color,
      cardboard ? Material3.wall : Material3.plastic,
    );
    final c = obstacle.center, s = obstacle.size;
    if (cardboard) {
      // Corrugated carton: taped lid seam, folded edges and a paper label.
      m.box(
        c + V3(0, s.y / 2 + .025, 0),
        V3(math.min(2.1, s.x * .15), .045, s.z - .3),
        0xffb79d68,
        Material3.fabric,
      );
      for (final x in [-1.0, 1.0])
        m.box(
          c + V3(x * (s.x / 2 - .2), s.y / 2 + .04, 0),
          V3(.13, .04, s.z - .3),
          0xff745637,
          Material3.decal,
        );
      m.box(
        c + V3(s.x * .2, s.y * .12, -s.z / 2 - .04),
        V3(s.x * .3, s.y * .22, .045),
        0xffddd5bc,
        Material3.fabric,
      );
      for (var j = 0; j < 5; j++)
        m.box(
          c + V3(s.x * (.09 + j * .045), s.y * .12, -s.z / 2 - .072),
          V3(.12, s.y * .15, .025),
          0xff4f5247,
          Material3.decal,
        );
    } else if (s.y > 4) {
      // Injection moulded storage box: lip, inset handle and reinforcing ribs.
      m.box(
        c + V3(0, s.y * .35, 0),
        V3(s.x + .12, .24, s.z + .12),
        0xff415d70,
        Material3.plastic,
      );
      m.roundedBox(
        c + V3(0, s.y * .16, -s.z / 2 - .06),
        V3(s.x * .36, math.min(1.1, s.y * .16), .12),
        .15,
        0xff283c48,
        Material3.rubber,
      );
      for (final x in [-.32, .32])
        m.box(
          c + V3(s.x * x, -s.y * .1, -s.z / 2 - .07),
          V3(.2, s.y * .62, .16),
          0xff6b8c9b,
          Material3.plastic,
        );
    }
    m.box(
      obstacle.center + V3(0, obstacle.size.y / 2 + .025, 0),
      V3(obstacle.size.x * .8, .05, 1.5),
      0xffffdb64,
      Material3.decal,
    );
  }
  for (var i = 1; i < TrackSpec.checkpointCount; i++) {
    final f = track.checkpoint(i);
    if (!track.isFloor(f.s)) continue;
    for (final side in [-1.0, 1.0]) {
      final p = f.point(side * track.widthAt(f.s) / 2);
      m.cylinder(
        V3(p.x, 1.65, p.z),
        const V3(0, 1, 0),
        3.3,
        1.5,
        .2,
        0xffff9b24,
        Material3.plastic,
        segments: 12,
      );
    }
  }
  final gate = track.at(0);
  for (final s in [-1.0, 1.0]) {
    m.box(
      gate.point(s * (w + 1), 5),
      const V3(1.2, 12, 1.7),
      0xff145292,
      Material3.paint,
      r: gate.right,
      u: gate.up,
      f: gate.forward,
    );
    m.box(
      gate.point(s * (w + 1), .2),
      const V3(4, .4, 4),
      0xff182b44,
      Material3.rubber,
      r: gate.right,
      u: gate.up,
      f: gate.forward,
    );
  }
  m.roundedBox(
    gate.point(0, 11.5),
    V3(w * 2 + 4, 3, 2.4),
    .6,
    0xff153e73,
    Material3.paint,
  );
  m.text(
    'CARWECE',
    gate.point(-8.7, 10.55) + gate.forward * -1.25,
    gate.right,
    gate.up,
    .64,
    0xffffd398,
  );
  if (track.outdoor) {
    buildExpansionWorld(m, track);
    buildCourseObjects(m, track);
    return m;
  }
  if (brazilLoopStars.containsKey(track.id)) {
    buildBrazilIndoorWorld(m, track);
    return m;
  }
  // Household floor material and wall color are selected by environment.
  m.box(
    const V3(0, -1, 0),
    const V3(1800, 2, 1800),
    track.room == 'QUARTO' || track.room == 'SALA'
        ? 0xffa67b52
        : track.room == 'ARCADE'
        ? 0xff30314b
        : track.floor,
    track.tiled
        ? Material3.tile
        : track.room == 'QUARTO' || track.room == 'SALA'
        ? Material3.wood
        : track.room == 'GARAGEM'
        ? Material3.concrete
        : Material3.wall,
  );
  final wall = track.wall;
  final wallMaterial = track.tiled ? Material3.tile : Material3.wall;
  m.box(const V3(0, 110, 880), const V3(1760, 220, 5), wall, wallMaterial);
  m.box(const V3(0, 110, -880), const V3(1760, 220, 5), wall, wallMaterial);
  m.box(const V3(-880, 110, 0), const V3(5, 220, 1760), wall, wallMaterial);
  m.box(const V3(880, 110, 0), const V3(5, 220, 1760), wall, wallMaterial);
  for (final s in [-1.0, 1.0]) {
    m.box(V3(0, 4, s * 876), const V3(1750, 8, 3), 0xffead6b2, Material3.wood);
    m.box(V3(s * 876, 4, 0), const V3(3, 8, 1750), 0xffead6b2, Material3.wood);
  }
  // Window panels, cross bars and a sill.
  m.box(
    const V3(-876, 113, -35),
    const V3(1, 94, 150),
    0xffb5def0,
    Material3.glow,
  );
  for (final z in [-112.0, -35.0, 42.0])
    m.box(V3(-873, 113, z), const V3(4, 100, 3), 0xfff5ead1, Material3.wood);
  for (final y in [64.0, 113.0, 162.0])
    m.box(V3(-873, y, -35), const V3(4, 3, 159), 0xfff5ead1, Material3.wood);
  m.box(
    const V3(-867, 64, -35),
    const V3(19, 4, 164),
    0xffe2c59d,
    Material3.wood,
  );
  // Large carpet, edge seam and fine weave supplied by the material shader.
  if (!track.tiled) {
    m.roundedBox(
      const V3(45, .14, 10),
      const V3(172, .30, 122),
      7,
      track.room == 'ARCADE' ? 0xff294764 : 0xff608ca0,
      Material3.fabric,
    );
    for (final s in [-1.0, 1.0])
      m.box(
        V3(45 + s * 81, .31, 10),
        const V3(2, .04, 108),
        0xffe8c994,
        Material3.fabric,
      );
  }
  if (track.room == 'QUARTO') {
    m.roundedBox(
      const V3(96, 20, 245),
      const V3(173, 36, 100),
      4,
      0xffa56c39,
      Material3.wood,
    );
    m.roundedBox(
      const V3(96, 45, 245),
      const V3(178, 20, 103),
      8,
      0xffe8dfc7,
      Material3.fabric,
    );
    m.roundedBox(
      const V3(70, 56, 245),
      const V3(126, 7, 104),
      4,
      0xff355f9a,
      Material3.fabric,
    );
    for (var i = 0; i < 7; i++)
      m.box(
        V3(18 + i * 17.0, 60, 245),
        const V3(2, .3, 99),
        0xffd8b36b,
        Material3.fabric,
      );
    m.roundedBox(
      const V3(155, 59, 245),
      const V3(45, 10, 80),
      9,
      0xfff3ead5,
      Material3.fabric,
    );
    m.roundedBox(
      const V3(190, 39, 245),
      const V3(8, 77, 108),
      3,
      0xffaf794b,
      Material3.wood,
    );
    for (var i = 0; i < 5; i++) {
      final c = [0xffb93f38, 0xff2a668c, 0xffe3aa4c, 0xff4c826c, 0xff82463e][i];
      m.box(
        V3(-238, 4 + i * 8.0, -100),
        V3(66 - i * 3.0, 7.2, 43 + i * 2.0),
        c,
        Material3.paint,
      );
      m.box(
        V3(-238, 4 + i * 8.0, -77.0 + i),
        V3(61 - i * 3.0, 5.7, 1.2),
        0xffeee0c3,
        Material3.fabric,
      );
      m.text(
        'CARWECE',
        V3(-266 + i * 1.5, 2 + i * 8.0, -75.0 + i),
        const V3(1, 0, 0),
        const V3(0, 1, 0),
        1,
        c,
      );
    }
    // Desk with brass reading lamp and a pencil cup.
    m.box(
      const V3(-90, 97, 266),
      const V3(142, 5, 70),
      0xffc79c62,
      Material3.wood,
    );
    for (final x in [-150.0, -30.0])
      for (final z in [241.0, 290.0])
        m.cylinder(
          V3(x, 48, z),
          const V3(0, 1, 0),
          96,
          2,
          2,
          0xff344659,
          Material3.metal,
          segments: 14,
        );
    m.cylinder(
      const V3(-118, 101, 265),
      const V3(0, 1, 0),
      4,
      16,
      16,
      0xff45566d,
      Material3.metal,
    );
    m.cylinder(
      const V3(-118, 126, 265),
      const V3(0, 1, 0),
      48,
      2,
      2,
      0xffb2a67d,
      Material3.metal,
    );
    m.cylinder(
      const V3(-118, 154, 265),
      const V3(0, 1, 0),
      21,
      27,
      12,
      0xffe8b751,
      Material3.paint,
    );
    m.cylinder(
      const V3(-118, 143, 265),
      const V3(0, 1, 0),
      1,
      23,
      23,
      0xffffe6ac,
      Material3.glow,
    );
    m.cylinder(
      const V3(-48, 111, 265),
      const V3(0, 1, 0),
      24,
      8,
      8,
      0xffad4238,
      Material3.paint,
    );
    for (var i = 0; i < 7; i++)
      m.cylinder(
        V3(-53 + i * 1.6, 133, 265 + math.sin(i) * 4),
        const V3(0, 1, 0),
        35,
        1,
        1,
        0xffe2c055,
        Material3.wood,
        segments: 8,
      );
  } else if (track.room == 'GARAGEM') {
    m.box(
      const V3(-30, 42, 560),
      const V3(200, 84, 66),
      0xffb73c31,
      Material3.paint,
    );
    for (var i = 0; i < 5; i++) {
      m.box(
        V3(-30, 10 + i * 15.0, 526),
        const V3(184, 12, 2),
        0xff952c28,
        Material3.paint,
      );
      m.box(
        V3(-30, 13 + i * 15.0, 524),
        const V3(130, 2, 2),
        0xffc8d0d6,
        Material3.metal,
      );
    }
    m.box(
      const V3(-30, 88, 560),
      const V3(211, 7, 71),
      0xffbd9c72,
      Material3.wood,
    );
    for (var i = 0; i < 4; i++)
      m.cylinder(
        V3(-720, 10 + i * 20.0, 380),
        const V3(0, 1, 0),
        19,
        38,
        38,
        0xff222b32,
        Material3.rubber,
        segments: 40,
      );
    m.box(
      const V3(730, 60, -50),
      const V3(52, 120, 100),
      0xff296c8f,
      Material3.paint,
    );
    m.text(
      'CARWECE',
      const V3(702, 74, -78),
      const V3(0, 0, 1),
      const V3(0, 1, 0),
      3,
      0xffe4d9bc,
    );
  } else if (track.room == 'ARCADE') {
    for (var i = 0; i < 5; i++) {
      final x = -230 + i * 110.0;
      m.roundedBox(
        V3(x, 63, 630),
        const V3(72, 126, 64),
        4,
        0xff182d49,
        Material3.paint,
      );
      m.box(
        V3(x, 89, 596),
        const V3(55, 43, 2),
        i.isEven ? 0xff8052c0 : 0xff1c93b8,
        Material3.glow,
      );
      m.box(V3(x, 130, 629), const V3(72, 9, 65), 0xffe46f3e, Material3.glow);
      m.box(V3(x, 60, 590), const V3(64, 6, 22), 0xffc24366, Material3.paint);
      for (var j = 0; j < 3; j++)
        m.cylinder(
          V3(x + j * 9 - 2, 64, 584),
          const V3(0, 1, 0),
          2,
          2,
          2,
          0xff7bf0da,
          Material3.glow,
          segments: 10,
        );
    }
    for (final x in [-317.0, 317.0])
      m.box(V3(x, 24, 0), const V3(3, 2, 620), 0xffa352e9, Material3.glow);
  }
  buildRoomDetails(m, track);
  buildRoomFinish(m, track);
  buildRoomProps(m, track);
  buildCourseObjects(m, track);
  // Toy blocks and bookcase make every room readable beyond the racing line.
  for (var i = 0; i < track.scenery.length; i++) {
    final block = track.scenery[i], p = block.center;
    if (track.tiled) {
      final r = math.min(block.size.x, block.size.z) * .42;
      m.cylinder(
        p,
        const V3(0, 1, 0),
        block.size.y * .82,
        r,
        r,
        block.color,
        track.room == 'BANHEIRO' ? Material3.plastic : Material3.ceramic,
        segments: 20,
      );
      m.cylinder(
        p + V3(0, block.size.y * .44, 0),
        const V3(0, 1, 0),
        block.size.y * .12,
        r * .7,
        r * .7,
        0xffbfc9b7,
        Material3.plastic,
        segments: 16,
      );
    } else {
      m.roundedBox(
        p,
        block.size,
        1.1,
        block.color,
        track.room == 'SALA' ? Material3.fabric : Material3.plastic,
      );
      if (track.room == 'QUARTO' || track.room == 'ARCADE')
        m.text(
          '${i % 10}',
          p + V3(-3, -3, block.size.z / 2 + .06),
          const V3(1, 0, 0),
          const V3(0, 1, 0),
          2,
          0xfff2e8cb,
        );
    }
  }
  if (track.room == 'QUARTO') {
    m.roundedBox(
      const V3(180, 65, 600),
      const V3(500, 130, 210),
      7,
      0xffb17b47,
      Material3.wood,
    );
    m.roundedBox(
      const V3(180, 137, 600),
      const V3(505, 20, 214),
      10,
      0xfff0e7d3,
      Material3.fabric,
    );
    m.roundedBox(
      const V3(85, 150, 600),
      const V3(305, 8, 214),
      5,
      0xff355f9a,
      Material3.fabric,
    );
    m.roundedBox(
      const V3(350, 154, 600),
      const V3(95, 18, 150),
      12,
      0xffe9dfcd,
      Material3.fabric,
    );
    m.box(
      const V3(-650, 112, 550),
      const V3(260, 5, 160),
      0xffbd935e,
      Material3.wood,
    );
    for (final x in [-750.0, -550.0]) {
      for (final z in [490.0, 610.0]) {
        m.cylinder(
          V3(x, 55, z),
          const V3(0, 1, 0),
          110,
          3,
          3,
          0xff344659,
          Material3.metal,
          segments: 12,
        );
      }
    }
  }
  if (!track.tiled) {
    m.box(
      const V3(799, 55, 380),
      const V3(52, 110, 130),
      0xffa4774a,
      Material3.wood,
    );
    for (var shelf = 0; shelf < 3; shelf++) {
      m.box(
        V3(771, 6 + shelf * 35.0, 380),
        const V3(9, 4, 126),
        0xffc49b68,
        Material3.wood,
      );
      for (var book = 0; book < 9; book++) {
        final h = 19 + (book * 13 + shelf * 9) % 13;
        m.box(
          V3(766, 10 + shelf * 35 + h / 2, 328 + book * 12.0),
          V3(17, h.toDouble(), 8),
          [0xff446f92, 0xffbd5842, 0xffd6a752, 0xff527d65][book % 4],
          Material3.paint,
        );
      }
    }
  }
  // High-contrast wall posters: all lettering and artwork are original geometry.
  for (var i = 0; i < 3; i++) {
    final x = -180 + i * 165.0;
    m.box(V3(x, 134, -876), const V3(125, 92, 2), 0xffead1a8, Material3.wood);
    m.box(
      V3(x, 134, -874.7),
      const V3(118, 85, .4),
      [0xff1f4878, 0xffb2492f, 0xff335f55][i],
      Material3.wall,
    );
    m.text(
      i == 0
          ? 'CAR'
          : i == 1
          ? 'WECE'
          : 'TURBO',
      V3(x - 48, 131, -874.3),
      const V3(1, 0, 0),
      const V3(0, 1, 0),
      3.5,
      0xfff4dba6,
    );
    m.text(
      '0${i + 1}',
      V3(x - 23, 103, -874.3),
      const V3(1, 0, 0),
      const V3(0, 1, 0),
      5,
      0xffffa23c,
    );
  }
  return m;
}

Mesh3 buildShowroom() {
  final m = Mesh3();
  m.box(const V3(0, -.6, 0), const V3(120, 1, 120), 0xff1b2e48, Material3.wall);
  m.cylinder(
    const V3(0, -.06, 0),
    const V3(0, 1, 0),
    .5,
    6.0,
    6.0,
    0xff263c54,
    Material3.metal,
    segments: 96,
  );
  m.cylinder(
    const V3(0, .13, 0),
    const V3(0, 1, 0),
    .11,
    5.90,
    5.90,
    0xff54768c,
    Material3.metal,
    segments: 96,
  );
  for (var i = 0; i < 80; i++) {
    final a = i / 80 * math.pi * 2, b = (i + 1) / 80 * math.pi * 2;
    m.quad(
      V3(math.cos(a) * 5.85, .22, math.sin(a) * 5.85),
      V3(math.cos(b) * 5.85, .22, math.sin(b) * 5.85),
      V3(math.cos(b) * 5.7, .22, math.sin(b) * 5.7),
      V3(math.cos(a) * 5.7, .22, math.sin(a) * 5.7),
      0xffffa642,
      Material3.glow,
    );
  }
  return m;
}

Mesh3 buildPickupMesh() {
  final m = Mesh3();
  m.roundedBox(
    const V3(0, 1.6, 0),
    const V3(2.0, 2.0, 2.0),
    .24,
    0xff2198c6,
    Material3.paint,
  );
  for (final sign in [-1.0, 1.0]) {
    m.text(
      'P',
      V3(-.5, 1.0, sign * 1.012),
      V3(sign, 0, 0),
      const V3(0, 1, 0),
      .3,
      0xffe7fdff,
    );
    m.box(
      V3(sign * 1.012, 1.6, 0),
      const V3(.025, .36, 1.4),
      0xff64f8fa,
      Material3.glow,
    );
  }
  return m;
}

Float32List poseMatrix(
  TrackFrame f,
  double lane, {
  double lift = 0,
  double yaw = 0,
  double roll = 0,
  double pitch = 0,
  double scale = 1,
}) {
  var r = f.right.rotate(f.up, yaw);
  var forward = f.forward.rotate(f.up, yaw);
  var up = f.up.rotate(r, pitch);
  forward = forward.rotate(r, pitch);
  r = r.rotate(forward, roll) * scale;
  up = up.rotate(forward, roll) * scale;
  forward = forward * scale;
  final p = f.point(lane, lift);
  return Float32List.fromList([
    r.x,
    r.y,
    r.z,
    0,
    up.x,
    up.y,
    up.z,
    0,
    forward.x,
    forward.y,
    forward.z,
    0,
    p.x,
    p.y,
    p.z,
    1,
  ]);
}
