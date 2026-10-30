import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'content.dart';
import 'engine.dart';
import 'math3d.dart';
import '../ui/map_geometry.dart';

class Face3 {
  final List<V3> vertices;
  final Color color;
  final bool glow;
  late final V3 center =
      vertices.reduce((a, b) => a + b) * (1 / vertices.length);
  Face3(this.vertices, this.color, [this.glow = false]);
}

class _Projected {
  final List<Offset> points;
  final double z;
  final Color color;
  _Projected(this.points, this.z, this.color);
}

class Scene3 {
  final List<Face3> faces = [];
  void quad(V3 a, V3 b, V3 c, V3 d, Color color, [bool glow = false]) =>
      faces.add(Face3([a, b, c, d], color, glow));
  void box(V3 p, V3 size, Color color, {V3? right, V3? up, V3? forward}) {
    final r = (right ?? const V3(1, 0, 0)) * (size.x / 2);
    final u = (up ?? const V3(0, 1, 0)) * size.y;
    final f = (forward ?? const V3(0, 0, 1)) * (size.z / 2);
    final a = p - r - f, b = p + r - f, c = p + r + f, d = p - r + f;
    quad(a, b, b + u, a + u, color);
    quad(b, c, c + u, b + u, shade(color, .83));
    quad(c, d, d + u, c + u, shade(color, .74));
    quad(d, a, a + u, d + u, shade(color, .9));
    quad(a + u, b + u, c + u, d + u, shade(color, 1.2));
  }

  void car(
    CarSpec spec,
    TrackFrame frame,
    double lane, {
    double jump = 0,
    double steer = 0,
    bool turbo = false,
    bool shield = false,
    double yaw = 0,
    double roll = 0,
    double pitch = 0,
    bool hitFlash = false,
  }) {
    var r = frame.right.rotate(frame.up, yaw - steer * .14);
    var f = frame.forward.rotate(frame.up, yaw - steer * .14);
    var u = frame.up.rotate(r, pitch);
    f = f.rotate(r, pitch);
    r = r.rotate(f, roll);
    u = u.rotate(f, roll);
    final pos = frame.point(lane, .5 + jump);
    final color = hitFlash ? const Color(0xffffdb91) : Color(spec.color),
        accent = Color(spec.accent);
    V3 local(double x, double y, double z) => pos + r * x + u * y + f * z;
    void part(
      double x,
      double y,
      double z,
      double w,
      double h,
      double l,
      Color c,
    ) => box(local(x, y, z), V3(w, h, l), c, right: r, up: u, forward: f);
    // Shadow sits on the track instead of following a jumping body.
    final shadow = frame.point(lane, .07);
    quad(
      shadow - r * 1.75 - f * 3,
      shadow + r * 1.75 - f * 3,
      shadow + r * 1.75 + f * 3,
      shadow - r * 1.75 + f * 3,
      const Color(0x65000000),
      true,
    );
    part(0, .15, 0, 2.6, .45, 5.5, const Color(0xff1b1e2b));
    const outline = <(double, double)>[
      (-1.25, 3),
      (1.25, 3),
      (1.55, 1.8),
      (1.55, -1.9),
      (1.25, -3),
      (-1.25, -3),
      (-1.55, -1.9),
      (-1.55, 1.8),
    ];
    for (var i = 0; i < outline.length; i++) {
      final a = outline[i], b = outline[(i + 1) % outline.length];
      quad(
        local(a.$1, .55, a.$2),
        local(b.$1, .55, b.$2),
        local(b.$1 * .94, 1.2, b.$2 * .95),
        local(a.$1 * .94, 1.2, a.$2 * .95),
        color,
      );
    }
    faces.add(
      Face3(
        outline.map((p) => local(p.$1 * .94, 1.2, p.$2 * .95)).toList(),
        shade(color, 1.12),
      ),
    );
    // Sloping glass and a tapered roof keep the miniature silhouette recognizable.
    quad(
      local(-1.2, 1.23, 1),
      local(1.2, 1.23, 1),
      local(.96, 1.98, .2),
      local(-.96, 1.98, .2),
      const Color(0xff24526c),
    );
    quad(
      local(-1.18, 1.23, -1.9),
      local(1.18, 1.23, -1.9),
      local(.96, 1.98, -.9),
      local(-.96, 1.98, -.9),
      const Color(0xff1c354e),
    );
    quad(
      local(-.96, 1.98, .2),
      local(.96, 1.98, .2),
      local(.96, 1.98, -.9),
      local(-.96, 1.98, -.9),
      color,
    );
    for (final side in [-1, 1]) {
      quad(
        local(side * 1.2, 1.23, 1),
        local(side * .96, 1.98, .2),
        local(side * .96, 1.98, -.9),
        local(side * 1.18, 1.23, -1.9),
        const Color(0xff19364d),
      );
      part(side * 1.12, 1.21, -.4, .14, .08, 2.75, accent);
    }
    part(0, 1.205, 1.9, .48, .02, 1.8, accent);
    part(0, 1.205, -2.3, .48, .02, 1.0, accent);
    part(0, 1.985, -.35, .42, .02, 1.08, accent);
    for (final x in [-1.52, 1.52]) {
      for (final z in [-1.85, 1.85]) {
        final sign = x.sign;
        for (var i = 0; i < 10; i++) {
          final a = i / 10 * math.pi * 2, b = (i + 1) / 10 * math.pi * 2;
          V3 tire(double side, double angle, double radius) => local(
            x + sign * side,
            .52 + math.sin(angle) * radius,
            z + math.cos(angle) * radius,
          );
          quad(
            tire(-.22, a, .64),
            tire(.32, a, .64),
            tire(.32, b, .64),
            tire(-.22, b, .64),
            const Color(0xff101725),
          );
          faces.add(
            Face3([
              local(x + sign * .33, .52, z),
              tire(.33, a, .62),
              tire(.33, b, .62),
            ], const Color(0xff222a37)),
          );
          faces.add(
            Face3([
              local(x + sign * .34, .52, z),
              tire(.34, a, .34),
              tire(.34, b, .34),
            ], const Color(0xffb5c2cf)),
          );
        }
      }
    }
    for (final x in [-.95, .95]) {
      part(x, .86, 3.0, .65, .2, .08, const Color(0xffe2f7ff));
      part(x, .86, -3.0, .7, .2, .08, const Color(0xffff3c41));
    }
    if (spec.body == 1)
      part(0, 1.3, 1.5, 1.2, .5, 1.2, const Color(0xffb0b6c1));
    if (spec.body >= 2) {
      part(-1.1, 1.3, -2.4, .14, .6, .2, accent);
      part(1.1, 1.3, -2.4, .14, .6, .2, accent);
      part(0, 1.9, -2.4, 3.5, .18, .8, accent);
    }
    if (turbo) {
      for (final x in [-.85, .85]) {
        final a = local(x - .35, .5, -3), b = local(x + .35, .5, -3);
        faces.add(
          Face3([a, b, local(x, .7, -6.5)], const Color(0xff34dbff), true),
        );
        faces.add(
          Face3([a, b, local(x, 1.25, -5)], const Color(0xffffe4a6), true),
        );
      }
    }
    if (shield) {
      for (var i = 0; i < 12; i++) {
        final a = i / 12 * math.pi * 2, b = (i + 1) / 12 * math.pi * 2;
        final p1 = local(math.cos(a) * 2.1, .1, math.sin(a) * 3.9);
        final p2 = local(math.cos(b) * 2.1, .1, math.sin(b) * 3.9);
        quad(p1, p2, p2 + u * 2.8, p1 + u * 2.8, const Color(0x4237e6ff), true);
      }
    }
  }
}

Color shade(Color c, double k) => Color.fromARGB(
  (c.a * 255).round().clamp(0, 255),
  (c.r * 255 * k).round().clamp(0, 255),
  (c.g * 255 * k).round().clamp(0, 255),
  (c.b * 255 * k).round().clamp(0, 255),
);

class TrackScene {
  final TrackSpec track;
  final Scene3 road = Scene3(), room = Scene3();
  TrackScene(this.track) {
    _road();
    _room();
  }
  void _road() {
    final w = track.width / 2;
    final fs = track.frames;
    for (var i = 0; i < fs.length; i++) {
      final a = fs[i], b = fs[(i + 1) % fs.length];
      final base = i ~/ 4 % 2 == 0
          ? const Color(0xfff4782e)
          : const Color(0xffed6b24);
      final green = track.isShortcut(a.s, .8);
      road.quad(a.point(-w), a.point(w), b.point(w), b.point(-w), base, true);
      if (green) {
        road.quad(
          a.point(w * .55, .025),
          a.point(w * .96, .025),
          b.point(w * .96, .025),
          b.point(w * .55, .025),
          const Color(0xff92d835),
          true,
        );
      }
      for (final edge in [-1, 1]) {
        final e = edge * w;
        road.quad(
          a.point(e),
          b.point(e),
          b.point(e, 1.05),
          a.point(e, 1.05),
          i ~/ 4 % 2 == 0 ? const Color(0xffffb149) : const Color(0xffff9b32),
          true,
        );
        road.quad(
          a.point(e, 1.05),
          b.point(e, 1.05),
          b.point(e - edge * .35, 1.05),
          a.point(e - edge * .35, 1.05),
          const Color(0xffffd17c),
          true,
        );
        road.quad(
          a.point(e),
          b.point(e),
          b.point(e, -1),
          a.point(e, -1),
          const Color(0xffae421c),
        );
      }
      if (i % 12 < 4) {
        road.quad(
          a.point(-.07, .025),
          a.point(.07, .025),
          b.point(.07, .025),
          b.point(-.07, .025),
          const Color(0xffffbc67),
          true,
        );
      }
      if (track.isBoost(a.s, 0)) {
        final c = i % 4 < 2 ? const Color(0xff55e6fd) : const Color(0xff2459b2);
        road.quad(
          a.point(-w * .52, .04),
          a.point(w * .52, .04),
          b.point(w * .52, .04),
          b.point(-w * .52, .04),
          c,
          true,
        );
      }
      if (a.s < 7) {
        for (var j = 0; j < 10; j++) {
          final x1 = -w + j * w / 5, x2 = x1 + w / 5;
          road.quad(
            a.point(x1, .05),
            a.point(x2, .05),
            b.point(x2, .05),
            b.point(x1, .05),
            (i + j) % 2 == 0
                ? const Color(0xfff6eee2)
                : const Color(0xff242a3b),
            true,
          );
        }
      }
      if (i % 48 == 0 && a.p.y > 8 && a.up.y > .5) {
        room.box(
          V3(a.p.x, 0, a.p.z),
          V3(2.2, a.p.y - 1, 3),
          const Color(0xff225fb3),
        );
      }
    }
    final start = track.at(8);
    for (final side in [-1, 1]) {
      road.box(
        start.point(side * (w + 1), -1),
        const V3(1.5, 13, 2),
        const Color(0xff1456b1),
        right: start.right,
        up: start.up,
        forward: start.forward,
      );
    }
    road.box(
      start.point(0, 11.5),
      V3(w * 2 + 4, 2.8, 2),
      const Color(0xff16478b),
      right: start.right,
      up: start.up,
      forward: start.forward,
    );
    for (var i = 0; i < 8; i++) {
      road.box(
        start.point(-w + i * w / 4, 12),
        const V3(.8, .8, 2.08),
        i.isEven ? Colors.white : const Color(0xfffca243),
        right: start.right,
        up: start.up,
        forward: start.forward,
      );
    }
    final ramp = track.at(track.length * .41);
    final rp = ramp.p;
    road.quad(
      rp - ramp.right * 4 - ramp.forward * 5,
      rp + ramp.right * 4 - ramp.forward * 5,
      rp + ramp.right * 4 + ramp.forward * 2 + ramp.up * 2,
      rp - ramp.right * 4 + ramp.forward * 2 + ramp.up * 2,
      const Color(0xffffd36d),
      true,
    );
    for (final side in [-1, 1]) {
      road.faces.add(
        Face3([
          rp + ramp.right * (side * 4) - ramp.forward * 5,
          rp + ramp.right * (side * 4) + ramp.forward * 2,
          rp + ramp.right * (side * 4) + ramp.forward * 2 + ramp.up * 2,
        ], const Color(0xffd7752c)),
      );
    }
  }

  void _room() {
    final dark = track.id == 'arcade';
    for (var x = -5; x <= 5; x++) {
      for (var z = -5; z <= 5; z++) {
        final a = V3(x * 65, -.4, z * 65);
        room.quad(
          a,
          a + const V3(65, 0, 0),
          a + const V3(65, 0, 65),
          a + const V3(0, 0, 65),
          shade(Color(track.floor), (x + z).isEven ? .94 : 1.06),
          true,
        );
      }
    }
    room.box(const V3(0, 0, 300), const V3(660, 200, 6), Color(track.wall));
    room.box(const V3(-310, 0, 0), const V3(6, 200, 600), Color(track.wall));
    room.box(const V3(310, 0, 0), const V3(6, 200, 600), Color(track.wall));
    room.box(const V3(0, 0, -300), const V3(660, 200, 6), Color(track.wall));
    // Window, shelves, building blocks and oversized room props are procedural.
    room.box(
      const V3(-307, 65, 50),
      const V3(2, 85, 130),
      const Color(0xff84acc7),
    );
    room.box(
      const V3(-305, 65, 50),
      const V3(3, 85, 3),
      const Color(0xffd2c8ac),
    );
    room.box(
      const V3(-305, 105, 50),
      const V3(3, 3, 130),
      const Color(0xffd2c8ac),
    );
    if (track.id == 'bedroom') {
      room.box(
        const V3(80, 0, 230),
        const V3(170, 32, 95),
        const Color(0xff876551),
      );
      room.box(
        const V3(80, 32, 230),
        const V3(173, 20, 97),
        const Color(0xff4173ba),
      );
      room.box(
        const V3(128, 52, 230),
        const V3(50, 10, 78),
        const Color(0xffece2ce),
      );
      room.box(
        const V3(85, 52, 230),
        const V3(8, .8, 95),
        const Color(0xffeeb84b),
      );
      for (var i = 0; i < 5; i++) {
        room.box(
          V3(-225, i * 8.0, -90),
          V3(65 - i * 3.0, 7, 40 + i * 4.0),
          [
            const Color(0xffc65b50),
            const Color(0xffd0ab5c),
            const Color(0xff3a8b80),
          ][i % 3],
        );
      }
      room.box(
        const V3(-25, 0, 200),
        const V3(55, 65, 20),
        const Color(0xffca574b),
      );
    } else if (track.id == 'garage') {
      room.box(
        const V3(-30, 0, 245),
        const V3(180, 78, 55),
        const Color(0xffbd4943),
      );
      for (var i = 0; i < 4; i++) {
        room.box(
          V3(-30, 10.0 + i * 17, 216),
          const V3(165, 2, 2),
          const Color(0xffd8d4ca),
        );
      }
      room.box(
        const V3(240, 0, -90),
        const V3(45, 130, 80),
        const Color(0xff306585),
      );
      for (var i = 0; i < 3; i++) {
        room.box(
          V3(-220, i * 19.0, 70),
          const V3(68, 17, 68),
          const Color(0xff222a34),
        );
      }
    } else {
      for (var i = 0; i < 4; i++) {
        room.box(
          V3(-210 + i * 100.0, 0, 240),
          const V3(65, 130, 55),
          const Color(0xff202c53),
        );
        room.box(
          V3(-210 + i * 100.0, 65, 211),
          const V3(49, 40, 1),
          i.isEven ? const Color(0xff9f5cff) : const Color(0xff2bcbdf),
        );
      }
    }
    for (var i = 0; i < 18; i++) {
      final angle = i * 2.4;
      final p = V3(
        math.cos(angle) * (215 + i % 3 * 13),
        0,
        math.sin(angle) * (210 + i % 4 * 8),
      );
      room.box(
        p,
        V3(12 + i % 3 * 8, 10 + i % 4 * 7, 18),
        [
          const Color(0xffe2b757),
          const Color(0xff518fc5),
          const Color(0xffb65b60),
          const Color(0xff64a893),
        ][i % 4],
      );
    }
    if (dark) {
      for (final x in [-290.0, 290.0]) {
        room.box(V3(x, 20, 0), const V3(2, 1, 560), const Color(0xff9c5de8));
      }
    }
  }
}

class Camera3 {
  final V3 position, right, up, forward;
  Camera3.lookAt(this.position, V3 target, V3 worldUp)
    : forward = (target - position).unit,
      right = worldUp.cross((target - position).unit).unit,
      up = (target - position).unit
          .cross(worldUp.cross((target - position).unit).unit)
          .unit;
  V3 view(V3 p) {
    final d = p - position;
    return V3(d.dot(right), d.dot(up), d.dot(forward));
  }
}

void render3(
  Canvas canvas,
  Size size,
  Camera3 camera,
  List<Face3> faces, {
  double fov = .92,
  double far = 500,
  Color fog = const Color(0xff394156),
  bool fogEnabled = false,
}) {
  final queue = <_Projected>[];
  final focal = size.width * fov;
  for (final face in faces) {
    final center = camera.view(face.center);
    if (center.z > far ||
        center.z < -60 ||
        center.x.abs() > center.z.abs() * 1.8 + 200)
      continue;
    final input = face.vertices.map(camera.view).toList();
    final clipped = <V3>[];
    for (var i = 0; i < input.length; i++) {
      final a = input[i], b = input[(i + 1) % input.length];
      final ai = a.z >= .8, bi = b.z >= .8;
      if (ai) clipped.add(a);
      if (ai != bi) clipped.add(a.lerp(b, (.8 - a.z) / (b.z - a.z)));
    }
    if (clipped.length < 3) continue;
    final points = clipped
        .map(
          (p) => Offset(
            size.width / 2 + p.x * focal / p.z,
            size.height * .5 - p.y * focal / p.z,
          ),
        )
        .toList();
    if (points.every((p) => p.dx < -10) ||
        points.every((p) => p.dx > size.width + 10) ||
        points.every((p) => p.dy < -10) ||
        points.every((p) => p.dy > size.height + 10))
      continue;
    var color = face.color;
    if (!face.glow && input.length >= 3) {
      final normal = (face.vertices[1] - face.vertices[0])
          .cross(face.vertices[2] - face.vertices[0])
          .unit;
      color = shade(
        color,
        .72 + normal.dot(const V3(.3, .85, -.4).unit).abs() * .36,
      );
    }
    if (fogEnabled)
      color = Color.lerp(
        color,
        fog,
        ((center.z - 150) / (far - 100)).clamp(0, .65),
      )!;
    queue.add(
      _Projected(
        points,
        input.fold<double>(0, (sum, p) => sum + p.z) / input.length,
        color,
      ),
    );
  }
  queue.sort((a, b) => b.z.compareTo(a.z));
  final paint = Paint()..isAntiAlias = false;
  for (final face in queue) {
    final path = Path()..addPolygon(face.points, true);
    paint.color = face.color;
    canvas.drawPath(path, paint);
  }
}

class RacePainter extends CustomPainter {
  final RaceEngine race;
  final TrackScene scene;
  final String quality;
  final double cameraDistance;
  RacePainter(
    this.race,
    this.scene, {
    this.quality = 'medium',
    this.cameraDistance = 1,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final night = race.track.id == 'arcade';
    final background = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        night
            ? [const Color(0xff10192f), const Color(0xff34415f)]
            : [const Color(0xff45536e), const Color(0xffb7a58b)],
      );
    canvas.drawRect(Offset.zero & size, background);
    final player = race.player;
    final frame = race.driverFrame(player);
    final origin = frame.point(0, 0);
    final look = frame.p + frame.forward * 14 + frame.up;
    final shake = race.impact * math.sin(race.time * 83) * .25;
    final camera = Camera3.lookAt(
      origin -
          frame.forward * (20 * cameraDistance + (race.nitroActive ? 2 : 0)) +
          frame.up * (10 * cameraDistance + shake),
      look,
      frame.up,
    );
    final dynamic = Scene3();
    dynamic.car(
      race.car,
      frame,
      0,
      yaw: player.spinAngle,
      roll: -player.lateralSpeed * .008,
      pitch: -player.jumpVelocity * .009,
      hitFlash: player.hitFlash > 0 && (race.time * 24).floor().isEven,
      turbo: race.nitroActive,
      shield: player.shield > 0,
    );
    for (final bot in race.bots) {
      if (bot.finishTime != null) continue;
      dynamic.car(
        bot.car,
        race.driverFrame(bot),
        0,
        yaw: bot.spinAngle,
        roll: -bot.lateralSpeed * .008,
        pitch: -bot.jumpVelocity * .009,
        hitFlash: bot.hitFlash > 0 && (race.time * 24).floor().isEven,
      );
    }
    if (race.mode != RaceMode.timeTrial) {
      final currentLap = (player.distance / race.track.length).floor();
      for (var i = 0; i < 8; i++) {
        if (race.collected.contains('$currentLap:$i')) continue;
        final f = race.track.at((.09 + i * .115) * race.track.length);
        final a = race.time * 1.6 + i;
        final right = f.right.rotate(f.up, a),
            forward = f.forward.rotate(f.up, a);
        dynamic.box(
          f.point(
            (i % 3 - 1) * .6 * race.track.width / 2,
            1.4 + math.sin(a * 2) * .4,
          ),
          const V3(2.3, 2.3, 2.3),
          const Color(0xff37d7f1),
          right: right,
          up: f.up,
          forward: forward,
        );
      }
    }
    for (final rocket in race.projectiles) {
      final f = race.track.at(rocket.distance);
      dynamic.box(
        f.point(rocket.lane * race.track.width / 2, 1),
        const V3(.7, .7, 3.8),
        const Color(0xffffed9a),
        right: f.right,
        up: f.up,
        forward: f.forward,
      );
    }
    for (final patch in race.oil) {
      final f = race.track.at(patch.distance),
          p = f.point(patch.lane * race.track.width / 2, .06);
      dynamic.quad(
        p - f.right * 3 - f.forward * 3,
        p + f.right * 3 - f.forward * 3,
        p + f.right * 3 + f.forward * 3,
        p - f.right * 3 + f.forward * 3,
        const Color(0xff24334c),
        true,
      );
    }
    for (final e in race.effects) {
      final f = race.track.at(e.distance), t = e.progress;
      final size = (e.kind == ImpactKind.explosion ? 3.0 : 1.5) * (1 + t);
      dynamic.box(
        f.point(e.lane * race.track.width / 2, 1 + t * 3),
        V3(size, size, size),
        e.kind == ImpactKind.explosion
            ? const Color(0xffffb72e)
            : const Color(0xffe6d5a3),
        right: f.right,
        up: f.up,
        forward: f.forward,
      );
    }
    final far = quality == 'low'
        ? 300.0
        : quality == 'high'
        ? 600.0
        : 430.0;
    render3(
      canvas,
      size,
      camera,
      [...scene.room.faces, ...scene.road.faces, ...dynamic.faces],
      fov: .68,
      far: far,
      fog: night ? const Color(0xff222d4a) : const Color(0xff687080),
    );
    if (race is BattleEngine) {
      final target = (race as BattleEngine).selectedTarget;
      if (target != null) {
        final p = camera.view(target.position! + target.normal! * 2.2);
        if (p.z > .8) {
          final focal = size.width * .68;
          final center = Offset(
            size.width / 2 + p.x / p.z * focal,
            size.height / 2 - p.y / p.z * focal,
          );
          final radius = (3.2 / p.z * focal).clamp(12.0, 40.0);
          final paint = Paint()
            ..color = const Color(0xff42ff67)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          for (final x in [-1.0, 1.0]) {
            for (final y in [-1.0, 1.0]) {
              final corner = center + Offset(x * radius, y * radius * .7);
              canvas.drawLine(
                corner,
                corner - Offset(x * radius * .4, 0),
                paint,
              );
              canvas.drawLine(
                corner,
                corner - Offset(0, y * radius * .3),
                paint,
              );
            }
          }
        }
      }
    }
    if (race.nitroActive) {
      final paint = Paint()
        ..color = const Color(0x7046d9ff)
        ..strokeWidth = 1.7;
      for (var i = 0; i < 20; i++) {
        final a = (i / 20 * math.pi * 2), t = wrap(race.time * 2 + i * .18, 1);
        final center = Offset(size.width * .5, size.height * .45);
        final direction = Offset(
          math.cos(a) * size.width,
          math.sin(a) * size.height,
        );
        canvas.drawLine(
          center + direction * (.35 + t * .35),
          center + direction * (.42 + t * .35),
          paint,
        );
      }
    }
    if (race.impact > .3)
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(255, 91, 56, race.impact * .12),
      );
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * .5, size.height * .4),
        size.width * .68,
        [Colors.transparent, const Color(0x65070c19)],
        [.3, 1],
      );
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant RacePainter old) => true;
}

class GaragePainter extends CustomPainter {
  final CarSpec car;
  final double angle;
  GaragePainter(this.car, this.angle, {Listenable? repaint})
    : super(repaint: repaint);
  @override
  void paint(Canvas canvas, Size size) {
    final scene = Scene3();
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * math.pi * 2, b = (i + 1) / 48 * math.pi * 2;
      final p1 = V3(math.cos(a) * 5.8, 0, math.sin(a) * 5.8);
      final p2 = V3(math.cos(b) * 5.8, 0, math.sin(b) * 5.8);
      scene.faces.add(Face3([V3.zero, p1, p2], const Color(0xff24304a), true));
      scene.quad(
        p1,
        p2,
        p2 - const V3(0, .3, 0),
        p1 - const V3(0, .3, 0),
        const Color(0xffeb7a37),
        true,
      );
    }
    scene.car(
      car,
      const TrackFrame(V3.zero, V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1), 0),
      0,
    );
    final camera = Camera3.lookAt(
      V3(math.sin(angle) * 12, 6.5, math.cos(angle) * 12),
      const V3(0, .8, 0),
      const V3(0, 1, 0),
    );
    render3(
      canvas,
      size,
      camera,
      scene.faces,
      fov: .74,
      far: 100,
      fogEnabled: false,
    );
  }

  @override
  bool shouldRepaint(covariant GaragePainter old) =>
      old.angle != angle || old.car != car;
}

class TrackMapPainter extends CustomPainter {
  final TrackSpec track;
  final Color color;
  final RaceEngine? race;
  TrackMapPainter(
    this.track, {
    this.color = const Color(0xfff4a465),
    this.race,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final geometry = RouteMapGeometry.forTrack(track, size);
    final point = geometry.point, path = geometry.route;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = race == null ? 10 : 4
        ..color = const Color(0xff0b1425)
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = race == null ? 5 : 2
        ..color = color
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < track.shortcuts.length; i++) {
      final shortcut = track.shortcuts[i], branch = geometry.branches[i];
      canvas.drawPath(
        branch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xff6de7b6),
      );
      if (race == null || !race!.brokenGates.contains(shortcut.id)) {
        final gate = geometry.gates[i];
        canvas.drawLine(
          gate - const Offset(3, 3),
          gate + const Offset(3, 3),
          Paint()
            ..color = const Color(0xffff6552)
            ..strokeWidth = 2,
        );
      }
    }
    if (race != null) {
      for (final bot in race!.bots) {
        canvas.drawCircle(
          point(race!.driverFrame(bot).p),
          2.2,
          Paint()..color = Color(bot.car.color),
        );
      }
      canvas.drawCircle(
        point(race!.driverFrame(race!.player).p),
        4,
        Paint()..color = Colors.white,
      );
    } else {
      canvas.drawCircle(
        point(track.frames.first.p),
        5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TrackMapPainter old) =>
      race != null ||
      old.race != null ||
      track != old.track ||
      color != old.color;
}
