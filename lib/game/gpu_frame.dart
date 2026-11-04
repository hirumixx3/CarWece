import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:isolate';
import 'content.dart';
import 'engine.dart';
import 'gpu_mesh.dart';
import 'math3d.dart';
part 'battle_gpu.dart';
part 'battle_weapon_mesh.dart';

/// All indices derive from the roster, so adding cars cannot silently remap FX.
class GpuMeshId {
  static int get pickup => cars.length;
  static int get rocket => pickup + 1;
  static int get oil => pickup + 2;
  static int get shield => pickup + 3;
  static int get flame => pickup + 4;
  static int get trail => pickup + 5;
  static int get explosion => pickup + 6;
  static int get smoke => pickup + 7;
  static int get sparks => pickup + 8;
  static int get damage => pickup + 9;
  static int get wheel => damage + cars.length;
  static int get shockwave => wheel + cars.length;
  static int get gate => shockwave + 1;
  static int get debris => shockwave + 2;
  static int get mine => shockwave + 3;
  static int get ice => shockwave + 4;
  static int get frost => shockwave + 5;
  static int get beam => shockwave + 6;
  static int get pulse => shockwave + 7;
  static int get supply => shockwave + 8;
  static int get grenade => supply + 1;
  static int get spikes => supply + 2;
  static int get repair => supply + 3;
}

class GpuResources {
  /// Build meshes on a short-lived worker. Isolate.run transfers the result on
  /// exit, keeping large procedural builds away from Flutter input/animation.
  static Future<(Float32List, List<Float32List>)> prepare({
    TrackSpec? track,
    required Set<int> bodies,
    bool battle = false,
  }) async {
    final cached = track == null ? null : _worlds[track.id];
    final neededTrack = cached == null ? track : null;
    final showroom = track == null;
    final result = await Isolate.run(
      () => (
        showroom
            ? GpuResources.showroom
            : neededTrack == null
            ? Float32List(0)
            : buildWorldMesh(neededTrack).buffer,
        [...objectsFor(bodies), if (battle) ...BattleGpuMeshes.objects],
      ),
    );
    final worldData = cached ?? result.$1;
    if (track != null && cached == null) {
      _cacheWorld(track.id, worldData);
    }
    return (worldData, result.$2);
  }

  // Cache by bytes, not number of tracks: two detailed rooms alone exceed 60 MB.
  static const worldCacheBudgetBytes = 16 * 1024 * 1024;
  static final Map<String, Float32List> _worlds = {};
  static void _cacheWorld(String id, Float32List data) {
    _worlds.clear();
    if (data.lengthInBytes <= worldCacheBudgetBytes) _worlds[id] = data;
  }

  static Float32List world(TrackSpec track) {
    final existing = _worlds.remove(track.id);
    if (existing != null) {
      _worlds[track.id] = existing;
      return existing;
    }
    final data = buildWorldMesh(track).buffer;
    _cacheWorld(track.id, data);
    return data;
  }

  static final Float32List showroom = buildShowroom().buffer;
  static final Map<int, Float32List> _carMeshes = {};
  static final Float32List _unused =
      (Mesh3()..triangle(
            const V3(0, -100, 0),
            const V3(0, -100, 1),
            const V3(1, -100, 0),
            0xff101010,
            Material3.rubber,
          ))
          .buffer;
  static final List<Float32List> _beforeCars = [
    buildPickupMesh().buffer,
    _rocket().buffer,
    _oil().buffer,
    _shield().buffer,
    _flame().buffer,
    _trail().buffer,
    _explosion().buffer,
    _sphere(0xff526079, 12).buffer,
    _sparks().buffer,
  ];
  static final List<Float32List> _afterCars = [
    _shockwave().buffer,
    _gate().buffer,
    _debris().buffer,
    _mine().buffer,
    _ice().buffer,
    _frost().buffer,
    _beam().buffer,
    _pulse().buffer,
    _supply().buffer,
    _grenade().buffer,
    _spikes().buffer,
    _repair().buffer,
  ];
  static Float32List _object(int id) {
    if (id >= GpuMeshId.pickup && id < GpuMeshId.damage)
      return _beforeCars[id - GpuMeshId.pickup];
    if (id >= GpuMeshId.shockwave) return _afterCars[id - GpuMeshId.shockwave];
    final old = _carMeshes.remove(id);
    if (old != null) {
      _carMeshes[id] = old;
      return old;
    }
    late final Float32List data;
    if (id < cars.length) {
      data = buildCarMesh(cars[id]).buffer;
    } else if (id < GpuMeshId.wheel) {
      data = buildCarMesh(cars[id - GpuMeshId.damage]).buffer;
      for (var i = 0; i < data.length; i += 12) {
        data[i + 6] = 1;
        data[i + 7] = .74;
        data[i + 8] = .35;
        data[i + 11] = Material3.glow.toDouble();
      }
    } else {
      data = buildWheelMesh(cars[id - GpuMeshId.wheel]).buffer;
    }
    if (_carMeshes.length >= 24) _carMeshes.remove(_carMeshes.keys.first);
    _carMeshes[id] = data;
    return data;
  }

  // Full inventory is lazy and used by exporters/contract QA only.
  static final List<Float32List> objects = List.generate(
    cars.length * 3 + 21,
    _object,
  );
  static List<Float32List> objectsFor(Iterable<int> bodies) {
    final used = bodies.toSet();
    return List.generate(cars.length * 3 + 21, (id) {
      final body = id < cars.length
          ? id
          : id >= GpuMeshId.damage && id < GpuMeshId.wheel
          ? id - GpuMeshId.damage
          : id >= GpuMeshId.wheel && id < GpuMeshId.shockwave
          ? id - GpuMeshId.wheel
          : null;
      return body == null || used.contains(body) ? _object(id) : _unused;
    });
  }

  static Mesh3 _grenade() {
    final m = _sphere(0xff5e723e, Material3.metal);
    for (var i = 0; i < m.data.length; i += 12) {
      m.data[i] *= .72;
      m.data[i + 1] *= .72;
      m.data[i + 2] *= .72;
    }
    m.box(
      const V3(0, .75, 0),
      const V3(.32, .30, .30),
      0xffaeb9a6,
      Material3.metal,
    );
    m.box(
      const V3(0, .88, -.22),
      const V3(.18, .12, .68),
      0xffffae3c,
      Material3.glow,
    );
    for (final y in [-.35, 0.0, .35])
      m.cylinder(
        V3(0, y, 0),
        const V3(0, 1, 0),
        .045,
        .72 * math.sqrt(1 - y * y / .52),
        .72 * math.sqrt(1 - y * y / .52),
        0xff39492d,
        Material3.metal,
        segments: 18,
      );
    return m;
  }

  static Mesh3 _spikes() {
    final m = Mesh3();
    m.box(
      const V3(0, .12, 0),
      const V3(12, .24, 2.1),
      0xff29343d,
      Material3.rubber,
    );
    for (var i = 0; i < 9; i++)
      for (final z in [-.58, .58])
        m.cylinder(
          V3(-5.3 + i * 1.32, .53, z),
          const V3(0, 1, 0),
          .85,
          .22,
          0,
          0xffbfccd0,
          Material3.metal,
          segments: 5,
        );
    for (final x in [-5.7, 5.7])
      m.box(
        V3(x, .28, 0),
        const V3(.22, .10, 2.12),
        0xffffa82a,
        Material3.glow,
      );
    return m;
  }

  static Mesh3 _repair() {
    final m = Mesh3();
    m.box(V3.zero, const V3(.35, 1.35, .18), 0xff69ffad, Material3.glow);
    m.box(V3.zero, const V3(1.35, .35, .18), 0xff69ffad, Material3.glow);
    return m;
  }

  static Mesh3 _gate() {
    final m = Mesh3();
    m.box(const V3(0, 5, 0), const V3(20, 10, 1.8), 0xff996a42, Material3.wood);
    for (final x in [-8.0, 0.0, 8.0])
      m.box(V3(x, 5, -1.0), const V3(.5, 10, .25), 0xffd2b282, Material3.wood);
    for (final y in [1.0, 9.0])
      m.box(V3(0, y, -1.05), const V3(20, .8, .3), 0xff5e655b, Material3.metal);
    for (final sign in [-1.0, 1.0])
      for (var i = 0; i < 3; i++)
        m.cylinder(
          V3(0, 5, sign * (1.02 + i * .07)),
          const V3(0, 0, 1),
          .08,
          3 - i * .85,
          3 - i * .85,
          i.isEven ? 0xffc83f2f : 0xffe7dbc0,
          Material3.paint,
          segments: 32,
        );
    return m;
  }

  static Mesh3 _debris() =>
      Mesh3()..box(V3.zero, const V3(2.2, .4, 1.3), 0xffb8905c, Material3.wood);
  static Mesh3 _mine() {
    final m = Mesh3();
    m.cylinder(
      const V3(0, .3, 0),
      const V3(0, 1, 0),
      .6,
      1.6,
      1.3,
      0xff3e4e58,
      Material3.metal,
      segments: 24,
    );
    m.cylinder(
      const V3(0, .65, 0),
      const V3(0, 1, 0),
      .15,
      .5,
      .5,
      0xffff4530,
      Material3.glow,
      segments: 16,
    );
    return m;
  }

  static Mesh3 _ice() {
    final m = Mesh3();
    m.cylinder(
      V3.zero,
      const V3(0, 0, 1),
      2.8,
      .48,
      0,
      0xff83ddf1,
      Material3.glass,
      segments: 6,
    );
    return m;
  }

  static Mesh3 _frost() {
    final m = _shield();
    for (var i = 0; i < m.data.length; i += 12) {
      m.data[i + 6] = .45;
      m.data[i + 7] = .8;
      m.data[i + 8] = 1;
      m.data[i + 11] = 17;
    }
    return m;
  }

  static Mesh3 _beam() {
    final m = Mesh3();
    for (var i = 0; i < 7; i++) {
      final a = V3(i.isEven ? .17 : -.17, 0, -.5 + i / 7),
          b = V3(i.isOdd ? .17 : -.17, 0, -.5 + (i + 1) / 7),
          v = b - a;
      m.cylinder(
        (a + b) * .5,
        v.unit,
        v.length,
        .045,
        .045,
        0xff9deaff,
        Material3.glow,
        segments: 5,
      );
    }
    return m;
  }

  static Mesh3 _pulse() {
    final m = _shockwave();
    for (var i = 0; i < m.data.length; i += 12) {
      m.data[i + 6] = .05;
      m.data[i + 7] = .7;
      m.data[i + 8] = 1;
    }
    return m;
  }

  static Mesh3 _supply() {
    final m = buildPickupMesh();
    for (var i = 0; i < m.data.length; i += 12) {
      m.data[i + 6] = .96;
      m.data[i + 7] = .44;
      m.data[i + 8] = .1;
    }
    return m;
  }

  static Mesh3 _shockwave() {
    final m = Mesh3();
    for (var i = 0; i < 48; i++) {
      final a = i / 48 * math.pi * 2, b = (i + 1) / 48 * math.pi * 2;
      V3 p(double angle, double radius) =>
          V3(math.cos(angle) * radius, .06, math.sin(angle) * radius);
      m.quad(
        p(a, .92),
        p(b, .92),
        p(b, 1),
        p(a, 1),
        0xffffbd67,
        Material3.glow,
      );
    }
    return m;
  }

  /// Layered blast: a jittered outer fireball, a bright core and six small
  /// satellite blobs, so one instanced mesh reads as a real explosion
  /// instead of a smooth ball.
  static Mesh3 _explosion() {
    final m = Mesh3();
    void blob(V3 center, double radius, int color, int seed) {
      V3 p(double a, double b) {
        final jitter =
            1 + .16 * math.sin(a * 3 + seed * 1.7) * math.cos(b * 4 + seed);
        return center +
            V3(
                  math.cos(a) * math.sin(b),
                  math.cos(b),
                  math.sin(a) * math.sin(b),
                ) *
                (radius * jitter);
      }

      for (var a = 0; a < 12; a++) {
        for (var b = 0; b < 6; b++) {
          final a0 = a / 12 * math.pi * 2, a1 = (a + 1) / 12 * math.pi * 2;
          final b0 = b / 6 * math.pi, b1 = (b + 1) / 6 * math.pi;
          m.quad(
            p(a0, b0),
            p(a0, b1),
            p(a1, b1),
            p(a1, b0),
            color,
            Material3.glow,
          );
        }
      }
    }

    blob(V3.zero, 1, 0xffff8a1e, 1);
    blob(V3.zero, .58, 0xffffe9a8, 5);
    for (var i = 0; i < 6; i++) {
      final a = i * 1.13 + .4;
      blob(
        V3(math.cos(a) * .95, .25 + (i % 3) * .3, math.sin(a) * .95),
        .34,
        i.isEven ? 0xffffa63d : 0xffff7a1a,
        i + 2,
      );
    }
    return m;
  }

  static Mesh3 _sphere(int color, int material) {
    final m = Mesh3();
    V3 p(double a, double b) =>
        V3(math.cos(a) * math.sin(b), math.cos(b), math.sin(a) * math.sin(b));
    for (var a = 0; a < 16; a++) {
      for (var b = 0; b < 10; b++) {
        final p0 = p(a * math.pi / 8, b * math.pi / 10),
            p1 = p((a + 1) * math.pi / 8, b * math.pi / 10),
            p2 = p((a + 1) * math.pi / 8, (b + 1) * math.pi / 10),
            p3 = p(a * math.pi / 8, (b + 1) * math.pi / 10);
        m.quad(
          p0,
          p1,
          p2,
          p3,
          color,
          material,
          na: p0.unit,
          nb: p1.unit,
          nc: p2.unit,
          nd: p3.unit,
        );
      }
    }
    return m;
  }

  static Mesh3 _trail() {
    final m = Mesh3();
    m.cylinder(
      const V3(0, 1.5, 0),
      const V3(0, 0, 1),
      2.5,
      .18,
      .32,
      0xffffd94e,
      Material3.glow,
      segments: 12,
    );
    return m;
  }

  static Mesh3 _sparks() {
    final m = Mesh3();
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      final direction = V3(math.cos(a), .2 + (i % 3) * .4, math.sin(a)).unit;
      m.cylinder(
        direction * 1.2,
        direction,
        1.3,
        .035,
        .08,
        i.isEven ? 0xffffdc56 : 0xfff4f9ed,
        Material3.glow,
        segments: 5,
      );
    }
    return m;
  }

  static Mesh3 _rocket() {
    final m = Mesh3();
    m.cylinder(
      const V3(0, 1.6, 0),
      const V3(0, 0, 1),
      3.8,
      .42,
      .42,
      0xffd7e5f0,
      Material3.metal,
      segments: 20,
    );
    m.cylinder(
      const V3(0, 1.6, 2.5),
      const V3(0, 0, 1),
      1.2,
      .42,
      0,
      0xfff04c21,
      Material3.paint,
      segments: 20,
    );
    m.cylinder(
      const V3(0, 1.6, -2.75),
      const V3(0, 0, 1),
      1.7,
      .03,
      .32,
      0xffffbe25,
      Material3.glow,
      segments: 12,
    );
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2, radial = V3(math.cos(a), math.sin(a), 0);
      m.triangle(
        const V3(0, 1.6, -1.6) + radial * .35,
        const V3(0, 1.6, -1.9) + radial * 1.0,
        const V3(0, 1.6, -.4) + radial * .35,
        0xfff14b20,
        Material3.paint,
      );
    }
    return m;
  }

  static Mesh3 _oil() {
    final m = Mesh3();
    m.cylinder(
      const V3(0, .07, 0),
      const V3(0, 1, 0),
      .055,
      3.1,
      3.1,
      0xff122334,
      Material3.paint,
      segments: 40,
    );
    return m;
  }

  static Mesh3 _shield() {
    final m = Mesh3();
    V3 point(double a, double b) => V3(
      math.cos(a) * math.sin(b) * 2.4,
      1.1 + math.cos(b) * 1.7,
      math.sin(a) * math.sin(b) * 4.1,
    );
    V3 normal(V3 p) => V3(p.x / 5.76, (p.y - 1.1) / 2.89, p.z / 16.81).unit;
    for (var a = 0; a < 32; a++)
      for (var b = 0; b < 12; b++) {
        final p = point(a / 32 * math.pi * 2, b / 12 * math.pi),
            q = point((a + 1) / 32 * math.pi * 2, b / 12 * math.pi),
            r = point((a + 1) / 32 * math.pi * 2, (b + 1) / 12 * math.pi),
            s = point(a / 32 * math.pi * 2, (b + 1) / 12 * math.pi);
        m.quad(
          p,
          q,
          r,
          s,
          0xff22ccf5,
          11,
          na: normal(p),
          nb: normal(q),
          nc: normal(r),
          nd: normal(s),
        );
      }
    return m;
  }

  static Mesh3 _flame() {
    final m = Mesh3();
    for (final x in [-.86, .86]) {
      m.cylinder(
        V3(x, .49, -4.7),
        const V3(0, 0, 1),
        2.7,
        .01,
        .29,
        0xff1baeff,
        Material3.glow,
        segments: 16,
      );
      m.cylinder(
        V3(x, .49, -4.15),
        const V3(0, 0, 1),
        1.4,
        .01,
        .17,
        0xfff3f8d1,
        Material3.glow,
        segments: 12,
      );
    }
    return m;
  }
}

class GpuInstance {
  final int mesh;
  final Float32List model;
  GpuInstance(this.mesh, this.model);
}

Float32List framePacket(
  V3 eye,
  V3 target,
  V3 up,
  V3 focus,
  double time,
  List<GpuInstance> instances, {
  bool boost = false,
}) {
  // Filled directly into the packet buffer: the previous version built a
  // growable list of ~2200 doubles and copied it every frame, feeding the
  // garbage collector during races.
  final count = math.min(128, instances.length);
  final data = Float32List(15 + count * 17);
  data[0] = eye.x;
  data[1] = eye.y;
  data[2] = eye.z;
  data[3] = target.x;
  data[4] = target.y;
  data[5] = target.z;
  data[6] = up.x;
  data[7] = up.y;
  data[8] = up.z;
  data[9] = time;
  data[10] = focus.x;
  data[11] = focus.y;
  data[12] = focus.z;
  data[13] = boost ? 1 : 0;
  data[14] = count.toDouble();
  for (var i = 0; i < count; i++) {
    final offset = 15 + i * 17;
    data[offset] = instances[i].mesh.toDouble();
    data.setRange(offset + 1, offset + 17, instances[i].model);
  }
  return data;
}

Float32List raceGpuFrame(RaceEngine race, {double cameraDistance = 1}) {
  final f = race.driverFrame(race.player), width = race.track.width / 2;
  final origin = f.p;
  final look = origin + f.forward * 14 + f.up * 1.5;
  final shake = race.impact * math.sin(race.time * 83) * .13;
  final eye =
      origin -
      f.forward * (19 * cameraDistance + (race.nitroActive ? 1.5 : 0)) +
      f.up * (9.3 * cameraDistance + shake);
  final instances = <GpuInstance>[];
  Float32List driverPose(Driver d) => poseMatrix(
    race.driverFrame(d),
    0,
    lift:
        .12 + 0 + (d.hitFlash > .1 ? math.sin(d.hitFlash * 24).abs() * .28 : 0),
    yaw: d.spinAngle,
    roll:
        -d.lateralSpeed * .008 +
        (d.damage > .1 ? math.sin(race.time * 22) * d.damage * .05 : 0) +
        (d.punctureTime > 0 ? math.sin(race.time * 32) * .025 : 0),
    pitch: -d.jumpVelocity * .009,
  );
  for (final d in race.drivers) {
    if (d.finishTime != null && d != race.player) continue;
    final pose = driverPose(d);
    instances.add(GpuInstance(d.car.body, pose));
    for (var i = 0; i < 4; i++) {
      instances.add(
        GpuInstance(
          GpuMeshId.wheel + d.car.body,
          wheelModel(
            pose,
            d.car,
            i,
            steer: wheelSteer(d, i),
            roll: d.wheelAngles[i],
          ),
        ),
      );
    }
    if (d.hitFlash > 0 && (race.time * 24).floor().isEven) {
      instances.add(GpuInstance(GpuMeshId.damage + d.car.body, pose));
    }
    if (d.repairGlow > 0) {
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + race.time * 1.7, base = race.driverFrame(d);
        final point =
            base.point(math.cos(a) * 3, 1.8 + (1.4 - d.repairGlow) * 2) +
            base.forward * math.sin(a) * 3;
        instances.add(
          GpuInstance(
            GpuMeshId.repair,
            poseMatrix(
              TrackFrame(point, base.right, base.up, base.forward, base.s),
              0,
              scale: .7,
            ),
          ),
        );
      }
    }
    if (d.freezeTime > 0) instances.add(GpuInstance(GpuMeshId.frost, pose));
    if (d.electricTime > 0 && (race.time * 20).floor().isEven)
      instances.add(GpuInstance(GpuMeshId.frost, pose));
    if (d.shield > 0) instances.add(GpuInstance(GpuMeshId.shield, pose));
    if ((d == race.player && race.nitroActive) || d.usingBoost)
      instances.add(GpuInstance(GpuMeshId.flame, pose));
    if (d.damage > .1) {
      for (var i = 0; i < 2; i++) {
        final t = (race.time * 1.7 + i * .5) % 1;
        instances.add(
          GpuInstance(
            GpuMeshId.smoke,
            poseMatrix(
              race.driverFrame(d),
              0,
              lift: 2 + t * 3,
              scale: .35 + t * .8,
            ),
          ),
        );
      }
    }
  }
  for (final path in race.track.shortcuts) {
    if (!race.brokenGates.contains(path.id))
      instances.add(GpuInstance(GpuMeshId.gate, poseMatrix(path.gate, 0)));
    final key = '${race.player.completedLaps}:gate:${path.id}';
    if (race.mode != RaceMode.timeTrial &&
        !race.collected.contains(key) &&
        !race.brokenGates.contains(path.id))
      instances.add(
        GpuInstance(
          GpuMeshId.supply,
          poseMatrix(
            race.track.at(path.entryS - 45),
            0,
            lift: 1.2,
            yaw: race.time,
          ),
        ),
      );
  }
  for (final strip in race.spikeStrips) {
    if ((strip.frame.p - origin).length < 180)
      instances.add(GpuInstance(GpuMeshId.spikes, poseMatrix(strip.frame, 0)));
  }
  for (final mine in race.mines) {
    final f = TrackFrame(
      mine.position,
      const V3(1, 0, 0),
      const V3(0, 1, 0),
      const V3(0, 0, 1),
      0,
    );
    instances.add(
      GpuInstance(
        GpuMeshId.mine,
        poseMatrix(f, 0, scale: mine.arm > 0 ? .8 : 1),
      ),
    );
  }
  for (final cloud in race.clouds.where(
    (c) => (c.position - origin).length < 180,
  )) {
    final f = TrackFrame(
      cloud.center,
      const V3(1, 0, 0),
      const V3(0, 1, 0),
      const V3(0, 0, 1),
      0,
    );
    instances.add(
      GpuInstance(GpuMeshId.smoke, poseMatrix(f, 0, scale: cloud.radius)),
    );
  }
  for (final beam in race.beams)
    instances.add(GpuInstance(GpuMeshId.beam, beamMatrix(beam.from, beam.to)));
  if (race.mode != RaceMode.timeTrial && race is! BattleEngine) {
    final lap = race.player.completedLaps;
    for (var i = 0; i < 8; i++) {
      if (race.collected.contains('$lap:$i')) continue;
      final frame = race.track.at((.09 + i * .115) * race.track.length);
      instances.add(
        GpuInstance(
          GpuMeshId.pickup,
          poseMatrix(
            frame,
            (i % 3 - 1) * .6 * width,
            lift: .25 + math.sin(race.time * 2 + i) * .3,
            yaw: race.time * 1.3,
          ),
        ),
      );
    }
  }
  TrackFrame worldFrame(V3 p, V3 direction, [V3 up = const V3(0, 1, 0)]) {
    final right = up.cross(direction).unit;
    final correctedUp = direction.cross(right).unit;
    return TrackFrame(p, right, correctedUp, direction, 0);
  }

  for (final p in race.projectiles) {
    final fallback = race.track.at(p.distance);
    final normal = p.owner?.normal ?? fallback.up,
        dir = p.direction ?? fallback.forward;
    final origin = p.position ?? fallback.point(p.lane * width, 1.6);
    instances.add(
      GpuInstance(
        p.kind == ItemType.ice
            ? GpuMeshId.ice
            : p.kind == ItemType.grenade
            ? GpuMeshId.grenade
            : GpuMeshId.rocket,
        poseMatrix(
          worldFrame(
            origin - (p.kind == ItemType.missile ? normal * 1.6 : V3.zero),
            dir,
            normal,
          ),
          0,
        ),
      ),
    );
    for (var i = 0; i < p.trail.length; i += p.kind == ItemType.ice ? 5 : 2) {
      instances.add(
        GpuInstance(
          GpuMeshId.trail,
          poseMatrix(
            worldFrame(p.trail[i] - normal * 1.5, dir, normal),
            0,
            scale: .45 + i * .05,
          ),
        ),
      );
    }
  }
  for (final p in race.oil) {
    final frame = p.position == null
        ? race.track.at(p.distance)
        : worldFrame(p.position!, const V3(0, 0, 1));
    instances.add(
      GpuInstance(
        GpuMeshId.oil,
        poseMatrix(frame, p.position == null ? p.lane * width : 0),
      ),
    );
  }
  if (race is BattleEngine) appendBattleInstances(race, instances, eye);
  for (final e in race.effects.reversed.take(10)) {
    final t = e.progress,
        f = e.pose ?? race.track.at(e.distance),
        x = e.pose == null ? e.lane * width : 0.0;
    switch (e.kind) {
      case ImpactKind.debris:
        for (var i = 0; i < 12; i++) {
          final age = e.age,
              part =
                  f.p +
                  f.right * ((i % 4 - 1.5) * 4 * (1 + age * .8)) +
                  f.forward * ((i.isEven ? 1 : -1) * age * 5) +
                  const V3(0, 1, 0) *
                      math.max(
                        .3,
                        2 + (i % 3) * 2 + age * 8 - age * age * 13.5,
                      );
          final pose = TrackFrame(part, f.right, f.up, f.forward, f.s);
          instances.add(
            GpuInstance(
              GpuMeshId.debris,
              poseMatrix(pose, 0, yaw: age * (i + 2), roll: age * 3, scale: .8),
            ),
          );
        }
      case ImpactKind.electric:
        instances.add(
          GpuInstance(GpuMeshId.frost, poseMatrix(f, x, scale: 1 + t * .2)),
        );
        instances.add(
          GpuInstance(
            GpuMeshId.sparks,
            poseMatrix(f, x, lift: 1.2, scale: 1.5),
          ),
        );
      case ImpactKind.frost:
        for (var i = 0; i < 8; i++) {
          final a = i * 2.4,
              part = TrackFrame(
                f.p +
                    f.right * math.cos(a) * t * 5 +
                    f.forward * math.sin(a) * t * 5,
                f.right,
                f.up,
                f.forward,
                f.s,
              );
          instances.add(
            GpuInstance(
              GpuMeshId.ice,
              poseMatrix(
                part,
                x,
                lift: 1 + t * 3,
                scale: .4,
                yaw: a,
                pitch: t * 3,
              ),
            ),
          );
        }
      case ImpactKind.force:
        instances.add(
          GpuInstance(
            GpuMeshId.shockwave,
            poseMatrix(f, x, lift: .25, scale: 1 + t * 58),
          ),
        );
      case ImpactKind.repair:
        for (var i = 0; i < 5; i++)
          instances.add(
            GpuInstance(
              GpuMeshId.repair,
              poseMatrix(
                f,
                x + (i - 2) * .85,
                lift: 1 + t * 4 + (i % 2),
                scale: .6,
              ),
            ),
          );
      case ImpactKind.pulse:
        instances.add(
          GpuInstance(
            GpuMeshId.pulse,
            poseMatrix(f, x, lift: .15, scale: 1 + t * 70),
          ),
        );
      case ImpactKind.explosion:
        if (t >= .25 && t < 1) {
          // Lingering smoke column after the flash.
          instances.add(
            GpuInstance(
              GpuMeshId.smoke,
              poseMatrix(
                f,
                x,
                lift: .8 + (t - .25) * 4,
                scale: 1.4 + (t - .25) * 3.4,
              ),
            ),
          );
        }
        if (t < .18) {
          instances.add(
            GpuInstance(
              GpuMeshId.debris,
              poseMatrix(f, x, lift: .3 + t * 5, scale: 1.2),
            ),
          );
        }
        if (t < .6) {
          final size = .5 + math.sin(t / .6 * math.pi) * 3.0;
          for (var i = 0; i < 5; i++) {
            final a = i * 2.4;
            final blob = TrackFrame(
              f.p +
                  f.right * (math.cos(a) * t * 3) +
                  f.forward * (math.sin(a) * t * 3),
              f.right,
              f.up,
              f.forward,
              f.s,
            );
            instances.add(
              GpuInstance(
                GpuMeshId.explosion,
                poseMatrix(
                  blob,
                  x,
                  lift: .45 + i * .35 + t * 2.5,
                  scale: size * (1 - i * .12),
                ),
              ),
            );
          }
          instances.add(
            GpuInstance(
              GpuMeshId.shockwave,
              poseMatrix(f, x, lift: .09, scale: 1 + t * 18),
            ),
          );
        }
        instances.add(
          GpuInstance(
            GpuMeshId.sparks,
            poseMatrix(f, x, lift: 1 + e.height, yaw: t * 2, scale: .7 + t * 4),
          ),
        );
        for (var i = 0; i < 5; i++) {
          instances.add(
            GpuInstance(
              GpuMeshId.smoke,
              poseMatrix(
                f,
                x + math.sin(i * 2.4) * t * 4,
                lift: .8 + e.height + t * (4 + i),
                scale: (.5 + t * 3) * (1 - t * .6),
              ),
            ),
          );
        }
      case ImpactKind.sparks:
        instances.add(
          GpuInstance(
            GpuMeshId.sparks,
            poseMatrix(f, x, lift: .3 + t, scale: .4 + t * 2),
          ),
        );
      case ImpactKind.skid:
        instances.add(
          GpuInstance(
            GpuMeshId.smoke,
            poseMatrix(f, x, lift: .4 + t, scale: .7 + t * 2),
          ),
        );
      case ImpactKind.blocked:
        instances.add(
          GpuInstance(
            GpuMeshId.shield,
            poseMatrix(f, x, scale: 1 + math.sin(t * math.pi) * .2),
          ),
        );
    }
  }
  return framePacket(
    eye,
    look,
    f.up,
    f.p,
    race.time,
    instances,
    boost: race.nitroActive,
  );
}

Float32List beamMatrix(V3 from, V3 to) {
  final forward = (to - from).unit,
      up = forward.y.abs() > .9 ? const V3(1, 0, 0) : const V3(0, 1, 0);
  final right = up.cross(forward).unit,
      f = TrackFrame(
        (from + to) * .5,
        right,
        forward.cross(right).unit,
        forward,
        0,
      );
  final m = poseMatrix(f, 0), length = (to - from).length;
  for (var i = 8; i < 11; i++) m[i] *= length;
  return m;
}

/// Ackermann geometry: the inner front tire turns slightly farther than outer.
double wheelSteer(Driver d, int index) {
  if (index < 2 || d.steeringAngle.abs() < .0001) return 0;
  final design = d.car.design,
      wb = design.frontAxle - design.rearAxle,
      radius = wb / math.tan(d.steeringAngle.abs()),
      side = index.isEven ? -1.0 : 1.0;
  return math.atan(
        wb / (radius - d.steeringAngle.sign * side * design.wheelTrack),
      ) *
      d.steeringAngle.sign;
}

Float32List wheelModel(
  Float32List chassis,
  CarSpec car,
  int index, {
  double steer = 0,
  double roll = 0,
}) {
  final d = car.design, side = index.isEven ? -1.0 : 1.0;
  final local = V3(
    side * d.wheelTrack,
    d.wheelRadius,
    index < 2 ? d.rearAxle : d.frontAxle,
  );
  V3 vector(V3 v) => V3(
    chassis[0] * v.x + chassis[4] * v.y + chassis[8] * v.z,
    chassis[1] * v.x + chassis[5] * v.y + chassis[9] * v.z,
    chassis[2] * v.x + chassis[6] * v.y + chassis[10] * v.z,
  );
  final axle = const V3(1, 0, 0).rotate(const V3(0, 1, 0), steer);
  final r = vector(axle),
      u = vector(const V3(0, 1, 0).rotate(axle, roll)),
      f = vector(
        const V3(0, 0, 1).rotate(const V3(0, 1, 0), steer).rotate(axle, roll),
      ),
      p = vector(local) + V3(chassis[12], chassis[13], chassis[14]);
  return Float32List.fromList([
    r.x,
    r.y,
    r.z,
    0,
    u.x,
    u.y,
    u.z,
    0,
    f.x,
    f.y,
    f.z,
    0,
    p.x,
    p.y,
    p.z,
    1,
  ]);
}

Float32List garageGpuFrame(CarSpec car, double angle) {
  final body = poseMatrix(
    const TrackFrame(V3.zero, V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1), 0),
    0,
    lift: .33,
  );
  return framePacket(
    V3(math.sin(angle) * 11.8, 5.0, math.cos(angle) * 11.8),
    const V3(0, 1.0, 0),
    const V3(0, 1, 0),
    const V3(0, 1, 0),
    angle,
    [
      GpuInstance(car.body, body),
      for (var i = 0; i < 4; i++)
        GpuInstance(GpuMeshId.wheel + car.body, wheelModel(body, car, i)),
    ],
  );
}
