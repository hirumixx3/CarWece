part of 'gpu_frame.dart';

class BattleMesh {
  static int get first => GpuMeshId.repair + 1;
  static int get bullet => first;
  static int get disc => first + 1;
  static int get barrel => first + 2;
  static int get tire => first + 3;
  static int get drone => first + 4;
  static int get globe => first + 5;
  static int get redBeam => first + 6;
  static int get hpGreen => first + 7;
  static int get hpRed => first + 8;
  static int get hpBack => first + 9;
  static int get ammo => first + 10;
  static int get trap => first + 11;
  static int get fire => first + 12;
  static int get swarm => first + 13;
  static int get turret => first + 14;
  static int weapon(BattlePower power) => first + 15 + power.index;
  static int get targetReticle => first + 15 + BattlePower.values.length;
  static int get count => targetReticle + 1;
}

class BattleGpuMeshes {
  static final List<Float32List> objects = [
    _box(const V3(.22, .22, 1.8), 0xffffdd70, Material3.glow).buffer,
    _disc().buffer,
    _barrel().buffer,
    _tire().buffer,
    _drone().buffer,
    _globe().buffer,
    _beam().buffer,
    _box(const V3(1, 1, .05), 0xff54d879, 18).buffer,
    _box(const V3(1, 1, .05), 0xffed613f, 18).buffer,
    _box(const V3(1, 1, .08), 0xff101825, 18).buffer,
    _crate().buffer,
    _trap().buffer,
    GpuResources._sphere(0xffff7839, Material3.glow).buffer,
    GpuResources._sphere(0xff8fb557, 12).buffer,
    _turret().buffer,
    for (final power in BattlePower.values) buildBattleWeapon(power).buffer,
    _targetReticle().buffer,
  ];
  static Mesh3 _targetReticle() {
    const green = 0xff42ff67;
    final mesh = Mesh3();
    for (final x in [-1.0, 1.0]) {
      for (final y in [-1.0, 1.0]) {
        mesh.box(
          V3(x * 2.6, y * 2.1, 0),
          const V3(1.4, .18, .12),
          green,
          Material3.glow,
        );
        mesh.box(
          V3(x * 3.2, y * 1.5, 0),
          const V3(.18, 1.4, .12),
          green,
          Material3.glow,
        );
      }
    }
    for (final x in [-1.0, 1.0]) {
      mesh.box(
        V3(x * 1.25, 0, 0),
        const V3(.65, .13, .12),
        green,
        Material3.glow,
      );
    }
    mesh.box(const V3(0, .9, 0), const V3(.13, .6, .12), green, Material3.glow);
    mesh.box(
      const V3(0, -.9, 0),
      const V3(.13, .6, .12),
      green,
      Material3.glow,
    );
    return mesh;
  }

  static Mesh3 _box(V3 size, int color, int material) =>
      Mesh3()..box(V3.zero, size, color, material);
  static Mesh3 _disc() {
    final m = Mesh3()
      ..cylinder(
        V3.zero,
        const V3(0, 1, 0),
        .2,
        1.5,
        1.5,
        0xff9fbed5,
        Material3.metal,
      );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p = V3(math.cos(a) * 2, 0, math.sin(a) * 2);
      m.triangle(
        p,
        V3(math.cos(a - .2) * 1.2, .1, math.sin(a - .2) * 1.2),
        V3(math.cos(a + .2) * 1.2, .1, math.sin(a + .2) * 1.2),
        0xffe8e3cc,
        Material3.metal,
      );
    }
    return m;
  }

  static Mesh3 _barrel() {
    final m = Mesh3()
      ..cylinder(
        V3.zero,
        const V3(0, 1, 0),
        2,
        .95,
        .95,
        0xffbb6443,
        Material3.metal,
      );
    for (final y in [-.7, .7])
      m.cylinder(
        V3(0, y, 0),
        const V3(0, 1, 0),
        .12,
        1.02,
        1.02,
        0xff333c49,
        Material3.metal,
      );
    return m;
  }

  static Mesh3 _tire() => Mesh3()
    ..cylinder(
      V3.zero,
      const V3(1, 0, 0),
      1.25,
      1.9,
      1.9,
      0xff1a2229,
      Material3.rubber,
    )
    ..cylinder(
      const V3(.65, 0, 0),
      const V3(1, 0, 0),
      .08,
      .8,
      .8,
      0xffbfc6bf,
      Material3.metal,
    )
    ..cylinder(
      const V3(-.65, 0, 0),
      const V3(1, 0, 0),
      .08,
      .8,
      .8,
      0xffbfc6bf,
      Material3.metal,
    );
  static Mesh3 _drone() => Mesh3()
    ..cylinder(
      V3.zero,
      const V3(0, 1, 0),
      .5,
      2.8,
      1.5,
      0xff97b3bc,
      Material3.metal,
    )
    ..cylinder(
      const V3(0, .5, 0),
      const V3(0, 1, 0),
      .65,
      1.3,
      .4,
      0xff61e8be,
      Material3.glow,
    );
  static Mesh3 _globe() {
    final m = GpuResources._sphere(0xfff477d5, Material3.metal);
    for (var i = 0; i < m.data.length; i += 12) {
      m.data[i] *= 1.7;
      m.data[i + 1] *= 1.7;
      m.data[i + 2] *= 1.7;
      if ((i ~/ 36) % 3 == 0) {
        m.data[i + 6] = .3;
        m.data[i + 7] = .9;
        m.data[i + 8] = 1;
        m.data[i + 11] = Material3.glow.toDouble();
      }
    }
    return m;
  }

  static Mesh3 _beam() => Mesh3()
    ..cylinder(
      V3.zero,
      const V3(0, 0, 1),
      1,
      .16,
      .16,
      0xffff5c4d,
      Material3.glow,
      segments: 8,
    );
  static Mesh3 _crate() => Mesh3()
    ..box(const V3(0, 1, 0), const V3(3.4, 2.5, 3), 0xff2c718e, Material3.metal)
    ..box(
      const V3(0, 1, 0),
      const V3(3.5, .35, 3.1),
      0xffffc974,
      Material3.glow,
    )
    ..box(
      const V3(0, 1, 0),
      const V3(.35, 2.6, 3.1),
      0xffffc974,
      Material3.glow,
    );
  static Mesh3 _trap() {
    final m = Mesh3()
      ..cylinder(
        V3.zero,
        const V3(0, 1, 0),
        .4,
        2,
        2,
        0xff9569c4,
        Material3.metal,
      );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      m.box(
        V3(math.cos(a) * 2, .5, math.sin(a) * 2),
        const V3(.4, 1, .4),
        0xffc9a7ff,
        Material3.glow,
      );
    }
    return m;
  }

  static Mesh3 _turret() => Mesh3()
    ..cylinder(
      V3.zero,
      const V3(0, 1, 0),
      .45,
      .8,
      .8,
      0xff526473,
      Material3.metal,
    )
    ..box(
      const V3(0, .25, .4),
      const V3(1.1, .7, 1.2),
      0xff435362,
      Material3.metal,
    )
    ..cylinder(
      const V3(0, .32, 1.5),
      const V3(0, 0, 1),
      2.1,
      .15,
      .15,
      0xffa9b7b8,
      Material3.metal,
      segments: 8,
    );
}

Float32List _battleScale(TrackFrame frame, V3 size) {
  final m = poseMatrix(frame, 0);
  for (var i = 0; i < 3; i++) {
    m[i] *= size.x;
    m[4 + i] *= size.y;
    m[8 + i] *= size.z;
  }
  return m;
}

void appendBattleInstances(
  BattleEngine battle,
  List<GpuInstance> instances,
  V3 eye,
) {
  final playerFrame = battle.driverFrame(battle.player), origin = playerFrame.p;
  TrackFrame frame(
    V3 p, {
    V3 direction = const V3(0, 0, 1),
    V3 up = const V3(0, 1, 0),
  }) {
    if (direction.cross(up).length < .001) up = const V3(1, 0, 0);
    final right = up.cross(direction).unit;
    return TrackFrame(p, right, direction.cross(right).unit, direction.unit, 0);
  }

  for (final d in battle.drivers) {
    final f = battle.fighters[d]!;
    if (!f.alive) continue;
    final pose = battle.driverFrame(d);
    if (f.armed && f.selected != null)
      instances.add(
        GpuInstance(
          BattleMesh.weapon(f.selected!),
          poseMatrix(
            frame(
              pose.p +
                  pose.up * 2.3 -
                  (f.turretDirection ?? pose.forward) * (f.recoil * .7),
              direction: battleTracksTarget(f.selected!)
                  ? f.turretDirection ?? pose.forward
                  : pose.forward,
              up: pose.up,
            ),
            0,
          ),
        ),
      );
    var holster = 0;
    for (final power in f.ammo.keys.where((p) => p != f.selected)) {
      final side = holster++ == 0 ? -1.0 : 1.0;
      instances.add(
        GpuInstance(
          BattleMesh.weapon(power),
          poseMatrix(
            frame(
              pose.p +
                  pose.right * side * 1.15 -
                  pose.forward * 1.5 +
                  pose.up * 1.6,
              direction: pose.forward,
              up: pose.up,
            ),
            0,
            scale: .43,
          ),
        ),
      );
    }
    if (d != battle.player) {
      final bar = pose.p + const V3(0, 6.3, 0), towards = (eye - bar).unit;
      final right = const V3(0, 1, 0).cross(towards).unit,
          up = towards.cross(right).unit;
      final facing = TrackFrame(bar, right, up, towards, 0),
          hp = f.health / 100;
      instances.add(
        GpuInstance(
          BattleMesh.hpBack,
          _battleScale(facing, const V3(6.4, .65, 1)),
        ),
      );
      final fg = TrackFrame(
        bar + right * ((hp - 1) * 3.0) + towards * .08,
        right,
        up,
        towards,
        0,
      );
      instances.add(
        GpuInstance(
          hp > .35 ? BattleMesh.hpGreen : BattleMesh.hpRed,
          _battleScale(fg, V3(6.0 * hp, .4, 1)),
        ),
      );
    }
    if (d == battle.selectedTarget) {
      final center = pose.p + pose.up * 2.2;
      final towards = (eye - center).unit;
      final right = const V3(0, 1, 0).cross(towards).unit;
      final facing = TrackFrame(
        center + towards * 2,
        right,
        towards.cross(right).unit,
        towards,
        0,
      );
      instances.add(
        GpuInstance(
          BattleMesh.targetReticle,
          poseMatrix(
            facing,
            0,
            scale: ((eye - center).length / 65).clamp(1.0, 4.0),
          ),
        ),
      );
    }
    if (f.ripper > 0) {
      for (final side in [-1.0, 1.0])
        for (final z in [-1.9, 1.8])
          instances.add(
            GpuInstance(
              BattleMesh.disc,
              poseMatrix(
                frame(
                  pose.p +
                      pose.right * side * 2.15 +
                      pose.forward * z +
                      pose.up * .6,
                  direction: pose.forward,
                  up: pose.right,
                ),
                0,
                yaw: battle.time * 15,
                scale: .65,
              ),
            ),
          );
    }
    if (f.turbo > 0 &&
        !(d == battle.player && battle.nitroActive) &&
        !d.usingBoost)
      instances.add(GpuInstance(GpuMeshId.flame, poseMatrix(pose, 0)));
    if (f.burn > 0)
      instances.add(
        GpuInstance(
          BattleMesh.fire,
          poseMatrix(
            pose,
            0,
            lift: 2,
            scale: 1.3 + math.sin(battle.time * 15) * .2,
          ),
        ),
      );
    if (f.jammer > 0)
      instances.add(
        GpuInstance(
          GpuMeshId.pulse,
          poseMatrix(pose, 0, lift: .15, scale: 3 + (battle.time * 2) % 4),
        ),
      );
  }
  for (final p in battle.pickups) {
    if (p.cooldown > 0 || (p.position - origin).length > 230) continue;
    instances.add(
      GpuInstance(
        p.health ? GpuMeshId.repair : BattleMesh.ammo,
        poseMatrix(
          frame(p.position),
          0,
          lift: 1 + math.sin(battle.time * 2) * .3,
          yaw: battle.time * .8,
          scale: p.health ? 1.6 : 1,
        ),
      ),
    );
  }
  for (final ray in battle.rays) {
    final red = ray.power == BattlePower.quantumAnnihilator;
    final matrix = beamMatrix(ray.from, ray.to);
    if (red) {
      for (var i = 0; i < 8; i++) matrix[i] *= 1.8;
    }
    instances.add(
      GpuInstance(red ? BattleMesh.redBeam : GpuMeshId.beam, matrix),
    );
  }
  final shots =
      battle.shots.where((s) => (s.position - origin).length < 250).toList()
        ..sort(
          (a, b) => (a.position - origin).length.compareTo(
            (b.position - origin).length,
          ),
        );
  for (final s in shots.take(28)) {
    var mesh = GpuMeshId.rocket, scale = 1.0;
    switch (s.power) {
      case BattlePower.machineGun:
      case BattlePower.atomBlaster:
      case BattlePower.cannon:
      case BattlePower.tantrumGun:
      case BattlePower.buckshot:
      case BattlePower.cowPuncher:
        mesh = BattleMesh.bullet;
        scale = s.power == BattlePower.cannon ? 1.8 : 1;
        break;
      case BattlePower.doomDisks:
        mesh = BattleMesh.disc;
        break;
      case BattlePower.oilDrum:
        mesh = BattleMesh.barrel;
        break;
      case BattlePower.steelBelter:
        mesh = BattleMesh.tire;
        break;
      case BattlePower.freonBomb:
        mesh = GpuMeshId.ice;
        break;
      case BattlePower.mortar:
      case BattlePower.craterMaker:
      case BattlePower.turtleTurnover:
      case BattlePower.magnetMine:
        mesh = GpuMeshId.grenade;
        scale = 1.4;
        break;
      case BattlePower.breathOfFire:
      case BattlePower.discoInferno:
      case BattlePower.gridlock:
        mesh = BattleMesh.fire;
        scale = .65;
        break;
      default:
        break;
    }
    final p =
        s.position - (mesh == GpuMeshId.rocket ? const V3(0, 1.6, 0) : V3.zero);
    instances.add(
      GpuInstance(
        mesh,
        poseMatrix(
          frame(p, direction: s.velocity.unit),
          0,
          scale: scale,
          roll: s.power == BattlePower.steelBelter ? battle.time * 14 : 0,
          yaw: mesh == BattleMesh.disc ? battle.time * 15 : 0,
        ),
      ),
    );
    if (mesh == GpuMeshId.rocket || s.power == BattlePower.breathOfFire) {
      for (final tail
          in s.trail.where((t) => (t - s.position).length > 7).take(2))
        instances.add(
          GpuInstance(GpuMeshId.trail, poseMatrix(frame(tail), 0, scale: .5)),
        );
    }
  }
  for (final z in battle.zones.where(
    (z) => (z.position - origin).length < 240,
  )) {
    var mesh = GpuMeshId.mine, scale = 1.0;
    switch (z.power) {
      case BattlePower.smogCheck:
        mesh = BattleMesh.swarm;
        scale = z.radius;
        break;
      case BattlePower.oilDrum:
        mesh = GpuMeshId.oil;
        scale = z.radius / 3;
        break;
      case BattlePower.bearHug:
        mesh = BattleMesh.trap;
        scale = 1.5;
        break;
      case BattlePower.craterMaker:
        mesh = GpuMeshId.oil;
        scale = 7;
        break;
      case BattlePower.haloDecoy:
        mesh = GpuMeshId.pulse;
        scale = 4;
        break;
      case BattlePower.discoInferno:
        mesh = BattleMesh.globe;
        break;
      case BattlePower.gammaSwarm:
        for (var i = 0; i < 6; i++) {
          final a = i * 2.4 + z.age * 6;
          instances.add(
            GpuInstance(
              BattleMesh.fire,
              poseMatrix(
                frame(
                  z.position +
                      V3(math.cos(a) * 4, math.sin(a * 2) * 2, math.sin(a) * 4),
                ),
                0,
                scale: .22,
              ),
            ),
          );
        }
        continue;
      case BattlePower.invasion:
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi * 2 / 3 + z.age;
          instances.add(
            GpuInstance(
              BattleMesh.drone,
              poseMatrix(
                frame(z.position + V3(math.cos(a) * 8, 0, math.sin(a) * 8)),
                0,
                yaw: a,
              ),
            ),
          );
        }
        continue;
      default:
        break;
    }
    instances.add(
      GpuInstance(
        mesh,
        poseMatrix(
          frame(z.position),
          0,
          scale: scale,
          yaw: z.power == BattlePower.discoInferno ? z.age * 4 : 0,
        ),
      ),
    );
  }
}
