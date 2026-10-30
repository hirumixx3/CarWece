part of 'engine.dart';

class BattleFighter {
  double health = 100, fireDelay = 0, heat = 0, deadFor = 0;
  double ripper = 0, turbo = 0, jammer = 0, doubled = 0, burn = 0, shock = 0;
  double periodic = 0, targetAt = 0, pathAt = 0, attackAt = 0, stuck = 0;
  double damageDealt = 0, deathTime = double.infinity;
  double escapeUntil = 0, progressAt = 0;
  double recoil = 0;
  int escapeAttempts = 0;
  bool manualTarget = false;
  int kills = 0, shots = 0;
  BattlePower? selected;
  final Map<BattlePower, int> ammo = {};
  final List<V3> path = [];
  V3? goal, lastPosition, escapeGoal;
  Driver? target, lastAttacker;
  V3? turretDirection;
  bool get alive => health > 0;
  bool get armed => ammo.values.any((n) => n > 0);
}

class BattleShot {
  final BattlePower power;
  final Driver owner;
  final double damage;
  Driver? target, attached;
  V3 position, velocity;
  double life, age = 0, gravity, homing, splash;
  int bounces = 0;
  final List<V3> trail = [];
  BattleShot(
    this.power,
    this.owner,
    this.position,
    this.velocity,
    this.damage, {
    this.target,
    this.life = 4,
    this.gravity = 0,
    this.homing = 0,
    this.splash = 0,
  });
}

class BattleRay {
  final BattlePower power;
  final V3 from, to;
  double life = .24;
  BattleRay(this.power, this.from, this.to);
}

class BattleZone {
  final BattlePower power;
  final Driver owner;
  V3 position;
  final double radius;
  double life, age = 0, pulse = 0;
  double damage;
  Driver? target;
  BattleZone(
    this.power,
    this.owner,
    this.position,
    this.radius,
    this.life, {
    this.target,
    this.damage = 0,
  });
}

class BattlePickup {
  final V3 position;
  final bool health;
  double cooldown = 0;
  BattlePower power;
  BattlePickup(this.position, this.power, {this.health = false});
}

class BattleEngine extends RaceEngine {
  final ArenaSpec arena;
  final bool freeRoam;
  final double timeLimit;
  final Map<Driver, BattleFighter> fighters = {};
  final List<BattleShot> shots = [];
  final List<BattleRay> rays = [];
  final List<BattleZone> zones = [];
  final List<BattlePickup> pickups = [];
  final List<BattlePower> _loot = [];
  BattlePower? _lastLoot;
  final Map<(Driver, Driver), double> _ramAt = {};
  bool triggerHeld = false, timedOut = false, rewardRecorded = false;
  double _battleAccumulator = 0, _endDelay = 0;
  BattleEngine({
    required this.arena,
    required CarSpec car,
    String difficulty = 'normal',
    int seed = 42,
    this.freeRoam = false,
    this.timeLimit = 300,
  }) : super(track: arena.track, car: car, difficulty: difficulty, seed: seed) {
    if (freeRoam) {
      bots.clear();
      for (var i = 0; i < 3; i++)
        bots.add(Driver('ALVO ${i + 1}', cars[(i + 1) * 3], 1, 0, 0));
    }
    for (var i = 0; i < drivers.length; i++) {
      final d = drivers[i], f = BattleFighter();
      fighters[d] = f;
      _spawn(d, arena.spawns[i]);
      f.lastPosition = d.position;
      if (d != player) d.skill = battleTuning.skill + i * .004;
      f.attackAt = 3.4 + i * .5;
    }
    for (final p in arena.supplies) pickups.add(BattlePickup(p, _nextLoot()));
    for (final p in arena.health)
      pickups.add(BattlePickup(p, BattlePower.armorRepair, health: true));
    tell(
      freeRoam
          ? 'EXPLORAÇÃO • COLETE PODERES NAS CAIXAS'
          : 'BATALHA • COLETE PODERES PARA COMBATER',
      4,
    );
  }
  BattleFighter get human => fighters[player]!;
  List<Driver> get living => drivers.where((d) => fighters[d]!.alive).toList();
  double get remaining => math.max(0, timeLimit - time);
  BattleWeapon? get selectedWeapon =>
      human.selected == null ? null : battleWeapon(human.selected!);
  int get selectedAmmo => human.ammo[human.selected] ?? 0;
  Driver? get selectedTarget {
    final target = human.target?.letAlive(fighters);
    return human.alive && target != null && _targetable(player, target)
        ? target
        : null;
  }

  bool _targetable(Driver owner, Driver other, [double range = 320]) =>
      other != owner &&
      fighters[other]?.alive == true &&
      fighters[other]!.jammer <= 0 &&
      (other.position! - owner.position!).length < range;

  bool selectTarget(Driver other) {
    if (!human.alive || !_targetable(player, other)) return false;
    if (remoteAction != null) {
      remoteAction!('target:${networkDrivers.indexOf(other)}');
      return true;
    }
    human.target = other;
    human.manualTarget = true;
    return true;
  }

  int get reward => freeRoam || !finished
      ? 0
      : podiumCoins(result?.position ?? standings.indexOf(player) + 1);
  BattleTuning get battleTuning => BattleTuning.forDifficulty(difficulty);
  @override
  List<Driver> get standings => drivers
    ..sort((a, b) {
      final x = fighters[a]!, y = fighters[b]!;
      if (x.alive != y.alive) return x.alive ? -1 : 1;
      if (!x.alive) return y.deathTime.compareTo(x.deathTime);
      var c = y.kills.compareTo(x.kills);
      if (c != 0) return c;
      c = y.damageDealt.compareTo(x.damageDealt);
      if (c != 0) return c;
      return y.health.compareTo(x.health);
    });
  @override
  TrackFrame navigationFrame(Driver d) {
    final p =
        fighters[d]?.goal ??
        fighters[d]?.target?.position ??
        d.position ??
        V3.zero;
    return TrackFrame(
      p,
      const V3(1, 0, 0),
      const V3(0, 1, 0),
      const V3(0, 0, 1),
      0,
    );
  }

  void _spawn(Driver d, V3 point) {
    final p = track.project(point);
    d.position = point;
    d.forward = V3(-point.x, 0, -point.z).unit;
    d.normal = const V3(0, 1, 0);
    d.velocity = V3.zero;
    d.speed = 0;
    d.lateralSpeed = 0;
    d.distance = p.frame.s;
    d.routeS = p.frame.s;
    d.lane = p.lateral / (track.width / 2);
    d.angularSpeed = 0;
    d.airborne = false;
    d.activeRamp = null;
    d.jump = 0;
    d.jumpVelocity = 0;
    d.freezeTime = 0;
    d.stun = 0;
    d.spinTime = 0;
    d.electricTime = 0;
    d.smokeExposure = 0;
    d.damage = 0;
    d.finishTime = null;
    _remember(d);
  }

  @override
  void resetPlayer() {
    if (remoteAction != null) {
      remoteAction!('reset');
      return;
    }
    if (!human.alive) return;
    final nearest = arena.safeFloor(player.position!);
    _spawn(player, nearest);
    clearControls();
    tell('REPOSICIONADO • VIDA E MUNIÇÃO MANTIDAS');
  }

  @override
  void clearControls() {
    super.clearControls();
    triggerHeld = false;
  }

  @override
  void useItem() {
    if (remoteAction != null) {
      remoteAction!('fire');
      return;
    }
    fire(player);
  }

  void superchargeItem() => cycleWeapon();
  void selectWeapon(BattlePower power) {
    if (remoteAction != null) {
      remoteAction!('weapon:${power.index}');
      return;
    }
    if (paused || human.alive) {
      if ((human.ammo[power] ?? 0) > 0) {
        human.selected = power;
        human.target = null;
        human.manualTarget = false;
      }
    }
  }

  void cycleWeapon() {
    if (remoteAction != null) {
      remoteAction!('cycle');
      return;
    }
    if (!human.alive) return;
    final available = BattlePower.values
        .where((p) => (human.ammo[p] ?? 0) > 0)
        .toList();
    if (available.isEmpty) {
      human.selected = null;
      tell('SEM PODER • COLETE UMA CAIXA NO MAPA');
      return;
    }
    human.selected =
        available[(available.indexWhere((p) => p == human.selected) + 1) %
            available.length];
    human.target = null;
    human.manualTarget = false;
    tell('${selectedWeapon!.name} • $selectedAmmo');
  }

  void cycleTarget() {
    if (remoteAction != null) {
      remoteAction!('target');
      return;
    }
    if (!human.alive) return;
    final options = living.where((d) => _targetable(player, d)).toList();
    if (options.isEmpty) {
      human.target = null;
      human.manualTarget = false;
      tell('SEM ALVO NO ALCANCE');
      return;
    }
    options.sort(
      (a, b) => (a.position! - player.position!).length.compareTo(
        (b.position! - player.position!).length,
      ),
    );
    human.target =
        options[(options.indexWhere((d) => d == human.target) + 1) %
            options.length];
    human.manualTarget = true;
    tell('ALVO: ${human.target!.name}');
  }

  void giveWeapon(Driver d, BattlePower power, [int? amount]) {
    final f = fighters[d]!;
    final n = amount ?? battleWeapon(power).ammo;
    if (n <= 0) return;
    f.ammo.removeWhere((p, ammo) => ammo <= 0);
    if (!f.ammo.containsKey(power) && f.ammo.length >= 3) {
      final discard = f.ammo.containsKey(f.selected)
          ? f.selected!
          : f.ammo.keys.first;
      f.ammo.remove(discard);
    }
    f.ammo[power] = ((f.ammo[power] ?? 0) + n).clamp(1, 99);
    f.selected = power;
  }

  void _selectLoaded(BattleFighter f) {
    f.ammo.removeWhere((p, n) => n <= 0);
    if ((f.ammo[f.selected] ?? 0) <= 0)
      f.selected = f.ammo.isEmpty ? null : f.ammo.keys.first;
  }

  BattlePower _nextLoot() {
    if (_loot.isEmpty) {
      _loot.addAll(BattlePower.values.toList()..shuffle(random));
      if (_loot.last == _lastLoot) {
        final first = _loot.first;
        _loot[0] = _loot.last;
        _loot[_loot.length - 1] = first;
      }
    }
    return _lastLoot = _loot.removeLast();
  }

  @override
  void update(double dt) {
    if (remoteUpdate != null) {
      remoteUpdate!(dt);
      return;
    }
    if (paused || finished || !dt.isFinite || dt <= 0) return;
    _battleAccumulator += dt.clamp(0, .1);
    while (_battleAccumulator + 1e-10 >= 1 / 120) {
      _battleStep(1 / 120);
      _battleAccumulator -= 1 / 120;
      if (finished) {
        _battleAccumulator = 0;
        break;
      }
    }
  }

  @override
  void setPaused(bool value) {
    super.setPaused(value);
    _battleAccumulator = 0;
  }

  void _battleStep(double dt) {
    impact = math.max(0, impact - dt * 2.8);
    messageLife = math.max(0, messageLife - dt);
    for (final e in effects) e.age += dt;
    effects.removeWhere((e) => e.age >= e.duration);
    for (final b in beams) b.life -= dt;
    beams.removeWhere((b) => b.life <= 0);
    for (final ray in rays) ray.life -= dt;
    rays.removeWhere((ray) => ray.life <= 0);
    if (countdown > 0) {
      countdown -= dt;
      if (countdown <= 0) {
        tell(
          freeRoam
              ? 'EXPLORE • SEM VOLTAS OU CHECKPOINTS'
              : 'COMBATE LIBERADO!',
        );
        events.add('go');
      }
      return;
    }
    time += dt;
    for (final d in drivers) {
      final f = fighters[d]!;
      f.fireDelay = math.max(0, f.fireDelay - dt);
      f.recoil = math.max(0, f.recoil - dt);
      f.heat = math.max(0, f.heat - dt * .3);
      if (!f.alive) {
        f.deadFor += dt;
        if (f.deadFor > 1.4) d.finishTime = time;
        if (freeRoam && f.deadFor > 2) {
          f.health = 100;
          f.deadFor = 0;
          _spawn(d, arena.spawns[drivers.indexOf(d)]);
        }
        continue;
      }
      d.stun = math.max(0, d.stun - dt);
      d.shield = math.max(0, d.shield - dt);
      d.hitFlash = math.max(0, d.hitFlash - dt);
      d.spinTime = math.max(0, d.spinTime - dt);
      d.freezeTime = math.max(0, d.freezeTime - dt);
      d.electricTime = math.max(0, d.electricTime - dt);
      d.weaponLock = math.max(0, d.weaponLock - dt);
      d.punctureTime = math.max(0, d.punctureTime - dt);
      d.repairGlow = math.max(0, d.repairGlow - dt);
      d.wallCooldown -= dt;
      d.padCooldown -= dt;
      d.smokeExposure = 0;
      d.damage = math.max(0, (1 - f.health / 100) * .8);
      f.ripper = math.max(0, f.ripper - dt);
      f.turbo = math.max(0, f.turbo - dt);
      f.jammer = math.max(0, f.jammer - dt);
      f.doubled = math.max(0, f.doubled - dt);
      f.burn = math.max(0, f.burn - dt);
      f.shock = math.max(0, f.shock - dt);
      f.periodic += dt;
      if (f.periodic >= .5) {
        f.periodic = 0;
        if (f.burn > 0) _hurt(d, 3, f.lastAttacker, ImpactKind.explosion);
        if (f.shock > 0) _hurt(d, 2, f.lastAttacker, ImpactKind.electric);
        if (f.ripper > 0) {
          for (final other in living.where(
            (v) =>
                v != d &&
                (v.position! - d.position!).length < 9 &&
                (v.position!.y - d.position!.y).abs() < 4,
          ))
            _hurt(other, 9, d, ImpactKind.sparks);
        }
      }
      if (!f.alive) continue;
      final humanDriver = d == player;
      if (networked) {
        _driveNetwork(d, dt, forcedTurbo: f.turbo > 0);
        continue;
      }
      final control = humanDriver
          ? (steering * sensitivity, accelerating || autoAccelerate, brake)
          : aiControls(d);
      final turbo = f.turbo > 0 || (humanDriver ? nitroActive : d.usingBoost);
      if (humanDriver)
        drifting = driftPressed && d.speed.abs() > 18 && control.$1.abs() > .12;
      _drive(
        d,
        dt,
        (control.$2 || f.turbo > 0) && d.freezeTime <= 0 && d.electricTime <= 0,
        control.$1 * (d.freezeTime > 0 ? 0.15 : 1),
        control.$3,
        turbo,
        humanDriver && drifting,
      );
      if (d.position!.y < -15 || d.position!.y > 500 || !d.position!.x.isFinite)
        _spawn(d, arena.spawns[drivers.indexOf(d)]);
    }
    final active = living;
    for (var pass = 0; pass < 4; pass++) {
      for (var i = 0; i < active.length; i++) {
        final a = active[i];
        for (var j = i + 1; j < active.length; j++) {
          final b = active[j], separation = (a.position! - b.position!).length;
          final closing = (a.velocity - b.velocity).length;
          _collide(a, b, pass == 0);
          if (pass == 0 &&
              separation < 9 &&
              closing > 12 &&
              time - (_ramAt[(a, b)] ?? -10) > .9) {
            _ramAt[(a, b)] = time;
            final hit = (closing * .17).clamp(1.0, 12.0);
            _hurt(a, hit, b, ImpactKind.sparks);
            _hurt(b, hit, a, ImpactKind.sparks);
            if (fighters[a]!.ripper > 0 || fighters[a]!.turbo > 0)
              _hurt(b, 9, a, ImpactKind.sparks);
            if (fighters[b]!.ripper > 0 || fighters[b]!.turbo > 0)
              _hurt(a, 9, b, ImpactKind.sparks);
          }
        }
        _obstacles(a, pass == 0);
      }
    }
    for (final d in drivers) {
      final p = track.project(d.position!);
      d.routeS = p.frame.s;
      d.distance = p.frame.s;
      d.lane = p.lateral / (track.width / 2);
      _remember(d);
    }
    final turbo = nitroActive;
    nitro = networked
        ? player.boostEnergy
        : turbo
        ? math.max(0, nitro - dt * 27)
        : math.min(100, nitro + dt * (drifting ? 15 : 4));
    for (final d in active) _updateWeaponAim(d, dt);
    if (networked) {
      for (final d in active) {
        if (networkInputs[d]?.fire == true) fire(d);
      }
    } else if (triggerHeld && human.alive)
      fire(player);
    _updateShots(dt);
    _updateZones(dt);
    _updatePickups(dt);
    if (shots.length > 64) shots.removeRange(0, shots.length - 64);
    if (zones.length > 36) zones.removeRange(0, zones.length - 36);
    if (effects.length > 24) effects.removeRange(0, effects.length - 24);
    if (events.length > 12) events.removeRange(0, events.length - 12);
    if (freeRoam) return;
    if ((!networked && !human.alive) ||
        living.length <= 1 ||
        time >= timeLimit) {
      _endDelay += dt;
      if (_endDelay >= 1.6) {
        timedOut = time >= timeLimit;
        finished = true;
        clearControls();
        final order = standings;
        result = RaceResult(
          order.indexOf(player) + 1,
          time,
          0,
          reward,
          hitCount,
          boostCount,
          standings: [
            for (var i = 0; i < order.length; i++)
              RaceStanding(
                i + 1,
                order[i].name,
                order[i].car,
                fighters[order[i]]!.alive
                    ? null
                    : fighters[order[i]]!.deathTime,
                100 - fighters[order[i]]!.health,
              ),
          ],
        );
      }
    } else {
      _endDelay = 0;
    }
  }

  @override
  (double, bool, bool) aiControls(Driver d) {
    if (freeRoam) return (0, false, false);
    final f = fighters[d]!;
    if (!f.alive) return (0, false, true);
    if (d.airborne) return (0, true, false);
    if (f.lastPosition == null || (d.position! - f.lastPosition!).length > 20) {
      f.lastPosition = d.position;
      f.progressAt = time;
    }
    if (time - f.progressAt > 6 && time >= f.escapeUntil) {
      f.escapeUntil = time + 4;
      f.escapeAttempts++;
      f.progressAt = time;
      f.pathAt = 0;
      f.stuck = 0;
      f.escapeGoal = arena.safeFloor(
        d.position! -
            d.forward! * 110 +
            d.normal!.cross(d.forward!).unit * (random.nextBool() ? 120 : -120),
      );
    }
    final surface = track.project(d.position!);
    if (!track.isFloor(surface.frame.s) &&
        surface.height.abs() < 4 &&
        surface.lateral.abs() < track.width / 2) {
      final ahead = track.at(surface.frame.s + math.max(16, d.speed * .3));
      final delta = ahead.p - d.position!;
      final angle = math.atan2(
        delta.dot(d.normal!.cross(d.forward!)),
        delta.dot(d.forward!),
      );
      return ((angle * 2.5).clamp(-1, 1), true, false);
    }
    if (time >= f.targetAt || f.target == null || !fighters[f.target]!.alive) {
      f.targetAt = time + 1.2 + random.nextDouble();
      final choices = living
          .where((b) => b != d && fighters[b]!.jammer <= 0)
          .toList();
      choices.sort(
        (a, b) =>
            ((a.position! - d.position!).length + fighters[a]!.health * .3)
                .compareTo(
                  (b.position! - d.position!).length + fighters[b]!.health * .3,
                ),
      );
      f.target = choices.isEmpty ? null : choices.first;
    }
    var destination =
        f.target?.position ??
        arena.supplies[drivers.indexOf(d) % arena.supplies.length];
    final loot = pickups
        .where((p) => p.cooldown <= 0 && (f.health < 45 ? p.health : !p.health))
        .toList();
    loot.sort(
      (a, b) => (a.position - d.position!).length.compareTo(
        (b.position - d.position!).length,
      ),
    );
    final hasAttack = f.ammo.keys.any(
      (p) => (f.ammo[p] ?? 0) > 0 && !battleWeapon(p).support,
    );
    if (loot.isNotEmpty &&
        (!hasAttack ||
            f.health < 45 ||
            (loot.first.position - d.position!).length < 90))
      destination = loot.first.position;
    if (f.escapeUntil > time && f.escapeGoal != null)
      destination = f.escapeGoal!;
    f.goal = destination;
    if (f.path.isEmpty || time >= f.pathAt) {
      f.pathAt = time + 1.3 + random.nextDouble() * .7;
      f.path
        ..clear()
        ..addAll(arena.path(d.position!, destination));
    }
    while (f.path.length > 1 && (f.path.first - d.position!).length < 24)
      f.path.removeAt(0);
    final waypoint = arena.lineClear(d.position!, destination)
        ? destination
        : f.path.first;
    final to = waypoint - d.position!;
    final angle = math.atan2(
      to.dot(d.normal!.cross(d.forward!).unit),
      to.dot(d.forward!),
    );
    var steer = (angle * 2).clamp(-1.0, 1.0);
    f.stuck = d.speed.abs() < 3
        ? f.stuck + 1 / 120
        : math.max(0, f.stuck - 1 / 60);
    var braking = false;
    if (f.stuck > 2 && f.stuck < 3.7) {
      braking = true;
      steer = -steer;
    }
    if (f.stuck > 4) {
      f.stuck = 0;
      f.pathAt = 0;
      f.escapeUntil = time + 3;
      f.escapeGoal = arena.safeFloor(
        d.position! -
            d.forward! * 90 +
            d.normal!.cross(d.forward!).unit * (random.nextBool() ? 100 : -100),
      );
    }
    d.usingBoost = d.boostEnergy > 25 && angle.abs() < .25 && to.length > 110;
    d.boostEnergy = (d.boostEnergy + (d.usingBoost ? -26 : 5) / 120).clamp(
      0,
      100,
    );
    if (time >= f.attackAt && f.target != null && f.armed) {
      f.attackAt = time + battleTuning.attackDelay + random.nextDouble() * .4;
      final support = f.ammo.keys
          .where((p) => battleWeapon(p).support && (f.ammo[p] ?? 0) > 0)
          .toList();
      if (f.health < 38 && f.ammo.containsKey(BattlePower.armorRepair))
        f.selected = BattlePower.armorRepair;
      else if (f.health < 50 &&
          d.shield <= 0 &&
          support.contains(BattlePower.energyShield))
        f.selected = BattlePower.energyShield;
      else if (f.jammer <= 0 &&
          f.health < 50 &&
          support.contains(BattlePower.radarJammer))
        f.selected = BattlePower.radarJammer;
      else if (f.doubled <= 0 && support.contains(BattlePower.weaponUpgrade))
        f.selected = BattlePower.weaponUpgrade;
      else {
        final options = f.ammo.keys
            .where((p) => (f.ammo[p] ?? 0) > 0 && !battleWeapon(p).support)
            .toList();
        if (options.isNotEmpty)
          f.selected = options[random.nextInt(options.length)];
      }
      fire(d);
    }
    return (
      steer,
      !braking && !(angle.abs() > .75 && d.speed > 30),
      braking || (angle.abs() > .85 && d.speed > 40),
    );
  }

  void _fx(V3 p, ImpactKind kind) {
    effects.add(
      ImpactEffect(0, 0, kind)
        ..pose = TrackFrame(
          p,
          const V3(1, 0, 0),
          const V3(0, 1, 0),
          const V3(0, 0, 1),
          0,
        ),
    );
  }

  void _hurt(Driver target, double amount, Driver? source, ImpactKind kind) {
    final f = fighters[target]!;
    if (!f.alive || amount <= 0) return;
    if (target.shield > 0) {
      _fx(target.position!, ImpactKind.blocked);
      return;
    }
    final actual = math.min(f.health, amount);
    f.health = math.max(0, f.health - actual);
    if (source != null && source != target) {
      fighters[source]!.damageDealt += actual;
      f.lastAttacker = source;
      if (source == player) hitCount++;
    }
    target.hitFlash = .75;
    target.damage = math.max(target.damage, .2);
    _fx(target.position! + const V3(0, 1, 0), kind);
    if (target == player) {
      impact = .5;
      events.add('hit');
    }
    if (!f.alive) {
      f.deathTime = time;
      target.damage = 1;
      f.deadFor = 0;
      target.velocity *= .2;
      target.speed *= .2;
      target.freezeTime = 0;
      target.electricTime = 0;
      target.smokeExposure = 0;
      f.burn = 0;
      f.shock = 0;
      _fx(target.position!, ImpactKind.explosion);
      _fx(target.position!, ImpactKind.debris);
      if (source != null && source != target && fighters[source] != null)
        fighters[source]!.kills++;
      tell(target == player ? 'CARRO DESTRUÍDO' : '${target.name} ELIMINADO!');
      events.add('explosion');
    }
  }

  Driver? _target(Driver d, {double range = 320, bool frontal = false}) {
    final f = fighters[d]!;
    bool eligible(Driver other) =>
        _targetable(d, other, range) &&
        (!frontal ||
            f.manualTarget ||
            (other.position! - d.position!).unit.dot(d.forward!) > .15);
    if (f.target != null && eligible(f.target!)) return f.target;
    f.manualTarget = false;
    final choices = living.where(eligible).toList()
      ..sort(
        (a, b) => (a.position! - d.position!).length.compareTo(
          (b.position! - d.position!).length,
        ),
      );
    f.target = choices.isEmpty ? null : choices.first;
    return f.target;
  }

  V3 _aimSolution(Driver d, Driver? target, {BattlePower? powerOverride}) {
    if (target == null) return d.forward!;
    final origin = d.position! + d.normal! * (d.jump + 2.9);
    final destination = target.position! + target.normal! * (target.jump + 1.5);
    var delta = destination - origin;
    final power = powerOverride ?? fighters[d]!.selected;
    final ballistic = switch (power) {
      BattlePower.mortar => (90.0, 46.0),
      BattlePower.oilDrum => (72.0, 27.0),
      BattlePower.freonBomb => (76.0, 30.0),
      BattlePower.turtleTurnover => (85.0, 40.0),
      BattlePower.craterMaker => (76.0, 42.0),
      _ => null,
    };
    if (ballistic != null) {
      final horizontal = V3(delta.x, 0, delta.z);
      final duration = (horizontal.length / ballistic.$1).clamp(.35, 2.6);
      return (horizontal.unit * ballistic.$1 +
              const V3(0, 1, 0) *
                  (delta.y / duration + ballistic.$2 * duration * .5))
          .unit;
    }
    if (!const {
      BattlePower.laserCannon,
      BattlePower.deathRay,
      BattlePower.quantumAnnihilator,
      BattlePower.alienLaser,
      BattlePower.superZapper,
      BattlePower.whiteLightning,
    }.contains(power)) {
      final travel = (delta.length / 180).clamp(0.0, .65);
      delta += target.velocity * travel;
    }
    return delta.unit;
  }

  void _updateWeaponAim(Driver d, double dt) {
    final f = fighters[d]!;
    final target = f.alive
        ? _target(d, frontal: networked || d == player)
        : null;
    if (!f.alive || f.selected == null || !battleTracksTarget(f.selected!)) {
      f.turretDirection = d.forward;
      return;
    }
    final desired = _aimSolution(d, target);
    final previous = f.turretDirection ?? d.forward!;
    final angle = math.acos(previous.dot(desired).clamp(-1, 1));
    var axis = previous.cross(desired);
    if (axis.length < .00001) axis = d.normal!;
    f.turretDirection = angle < .00001
        ? desired
        : previous.rotate(axis.unit, math.min(angle, dt * 5.5)).unit;
  }

  V3 _aim(Driver d, Driver? target, {bool turret = false}) => turret
      ? fighters[d]!.turretDirection ?? d.forward!
      : _aimSolution(d, target);

  V3 weaponMuzzle(Driver d) {
    final direction = fighters[d]!.turretDirection ?? d.forward!;
    final right = d.normal!.cross(direction).unit;
    final up = direction.cross(right).unit;
    return d.position! + d.normal! * (d.jump + 2.3) + up * .6 + direction * 2.5;
  }

  bool fire(Driver d) {
    final f = fighters[d]!;
    if (paused ||
        finished ||
        countdown > 0 ||
        !f.alive ||
        f.fireDelay > 0 ||
        d.weaponLock > 0)
      return false;
    final power = f.selected;
    if (power == null) return false;
    final w = battleWeapon(power), ammo = f.ammo[power] ?? 0;
    if (ammo <= 0) {
      _selectLoaded(f);
      return false;
    }
    if (power == BattlePower.machineGun && f.heat > .92) {
      f.fireDelay = .45;
      return false;
    }
    final target = _target(d, frontal: networked || d == player);
    f.turretDirection ??= _aimSolution(d, target, powerOverride: power);
    final origin = weaponMuzzle(d);
    f.fireDelay = w.cooldown;
    f.recoil = .18;
    f.shots++;
    f.ammo[power] = ammo - 1;
    _selectLoaded(f);
    if (power == BattlePower.machineGun) f.heat = (f.heat + .075).clamp(0, 1.2);
    var damage =
        w.damage * (networked || d == player ? 1 : battleTuning.weaponDamage);
    if (f.doubled > 0 && power.index <= BattlePower.roadMine.index) damage *= 2;
    void shoot({
      int count = 1,
      double spread = 0,
      double speed = 140,
      double homing = 0,
      double gravity = 0,
      double splash = 0,
      double life = 4,
      bool aimed = false,
      bool turret = false,
    }) {
      final direction = battleTracksTarget(power)
          ? _aim(d, target, turret: true)
          : d.forward!;
      for (var i = 0; i < count; i++) {
        final a = count == 1 ? 0.0 : (i / (count - 1) - .5) * spread;
        final error = networked || d == player
            ? 0.0
            : (random.nextDouble() - .5) * battleTuning.aimSpread;
        final dir = direction.rotate(d.normal!, a + error).unit;
        var velocity = dir * speed + d.velocity * .16;
        if (gravity > 0) {
          if (target == null) {
            velocity += const V3(0, 14, 0);
          } else {
            final horizontal = math.sqrt(dir.x * dir.x + dir.z * dir.z);
            velocity = dir * (speed / math.max(.25, horizontal));
          }
        }
        shots.add(
          BattleShot(
            power,
            d,
            origin + d.normal! * (gravity > 0 ? 1 : 0),
            velocity,
            damage,
            target: target,
            life: life,
            gravity: gravity,
            homing: homing,
            splash: splash,
          ),
        );
      }
    }

    switch (power) {
      case BattlePower.machineGun:
        shoot(speed: 250, life: 1);
        break;
      case BattlePower.homingMissile:
        shoot(speed: 135, homing: 2.4, splash: 11, life: 5);
        break;
      case BattlePower.rocket:
        shoot(speed: 160, splash: 13, life: 3.4);
        break;
      case BattlePower.mortar:
        shoot(speed: 90, gravity: 46, splash: 18, aimed: true, life: 5);
        break;
      case BattlePower.cannon:
        shoot(speed: 195, aimed: true, turret: true, splash: 4, life: 2);
        break;
      case BattlePower.roadMine:
        _lay(d, power, damage: damage);
        break;
      case BattlePower.ripperWheels:
        f.ripper = 7;
        _fx(d.position!, ImpactKind.sparks);
        break;
      case BattlePower.armorRepair:
        _repair(d, 100);
        break;
      case BattlePower.oilDrum:
        shoot(speed: 72, gravity: 27, life: 3.2, aimed: true);
        break;
      case BattlePower.laserCannon:
        _ray(
          d,
          origin,
          _aim(d, target, turret: true),
          damage,
          330,
          false,
          power,
        );
        break;
      case BattlePower.sonicBoom:
        _radial(d, d.position!, 48, damage, power);
        _fx(d.position!, ImpactKind.force);
        break;
      case BattlePower.atomBlaster:
        shoot(count: 2, spread: .045, speed: 230, life: 1.1);
        break;
      case BattlePower.freonBomb:
        shoot(speed: 76, gravity: 30, splash: 22, life: 2.5, aimed: true);
        break;
      case BattlePower.energyShield:
        d.shield = 5;
        _fx(d.position!, ImpactKind.blocked);
        break;
      case BattlePower.jetBoosters:
        f.turbo = 3;
        d.velocity += d.forward! * 25;
        nitro = math.max(nitro, 30);
        break;
      case BattlePower.superZapper:
      case BattlePower.whiteLightning:
        if (target != null &&
            _canSee(origin, target.position! + const V3(0, 2, 0)) &&
            (target.position! - origin).length < 125) {
          beams.add(ElectricBeam(origin, target.position! + const V3(0, 2, 0)));
          _hit(target, damage, d, power);
          if (power == BattlePower.whiteLightning)
            for (final other in living.where(
              (o) =>
                  o != d &&
                  o != target &&
                  (o.position! - target.position!).length < 35,
            )) {
              beams.add(
                ElectricBeam(
                  target.position! + const V3(0, 2, 0),
                  other.position! + const V3(0, 2, 0),
                ),
              );
              _hit(other, damage * .6, d, power);
            }
        }
        break;
      case BattlePower.magnetMine:
        shoot(speed: 80, homing: 3.2, splash: 15, aimed: true, life: 5);
        break;
      case BattlePower.doomDisks:
        shoot(count: 3, spread: .8, speed: 125, homing: 2.7, life: 4.2);
        break;
      case BattlePower.quantumAnnihilator:
        _ray(
          d,
          origin,
          _aim(d, target, turret: true),
          damage,
          450,
          false,
          power,
        );
        break;
      case BattlePower.gridlock:
        shoot(count: 9, spread: 1.2, speed: 105, splash: 8, life: 2.8);
        break;
      case BattlePower.tantrumGun:
        shoot(
          count: 3,
          spread: .08,
          speed: 230,
          life: 1.4,
          aimed: true,
          turret: true,
        );
        break;
      case BattlePower.bassQuake:
        _radial(d, d.position!, 65, damage, power);
        _fx(d.position!, ImpactKind.force);
        break;
      case BattlePower.invasion:
        if (target != null)
          zones.add(BattleZone(power, d, origin, 24, 4, target: target));
        break;
      case BattlePower.steelBelter:
        shoot(speed: 105, homing: 1.2, splash: 20, life: 5, aimed: true);
        break;
      case BattlePower.scatterMissiles:
        shoot(
          count: 6,
          spread: 1.5,
          speed: 128,
          homing: 2,
          splash: 6,
          life: 4.5,
        );
        break;
      case BattlePower.deathRay:
        _ray(
          d,
          origin,
          _aim(d, target, turret: true),
          damage,
          400,
          true,
          power,
        );
        break;
      case BattlePower.discoInferno:
        zones.add(
          BattleZone(power, d, d.position! + const V3(0, 9, 0), 30, 3.6),
        );
        break;
      case BattlePower.gammaSwarm:
        if (target != null)
          zones.add(BattleZone(power, d, origin, 9, 5, target: target));
        break;
      case BattlePower.smogCheck:
        zones.add(
          BattleZone(
            power,
            d,
            d.position! - d.forward! * 12 + const V3(0, 4, 0),
            19,
            9,
          ),
        );
        break;
      case BattlePower.breathOfFire:
        shoot(
          count: 3,
          spread: .22,
          speed: 100,
          homing: .5,
          splash: 6,
          life: 2.4,
        );
        break;
      case BattlePower.alienLaser:
        _ray(
          d,
          origin,
          _aim(d, target, turret: true),
          damage,
          480,
          true,
          power,
        );
        break;
      case BattlePower.haloDecoy:
        zones.add(
          BattleZone(
            power,
            d,
            d.position! - d.forward! * 22 + const V3(0, 3, 0),
            3.5,
            5,
          ),
        );
        break;
      case BattlePower.afterburner:
        f.turbo = 1.8;
        d.velocity += d.forward! * 32;
        break;
      case BattlePower.roadRunner:
        shoot(speed: 135, homing: 1.2, life: 3.5);
        break;
      case BattlePower.stampede:
        shoot(count: 5, spread: .18, speed: 155, splash: 7, life: 3);
        break;
      case BattlePower.turtleTurnover:
        shoot(speed: 85, gravity: 40, aimed: true, splash: 12, life: 4.5);
        break;
      case BattlePower.craterMaker:
        shoot(speed: 76, gravity: 42, aimed: true, splash: 34, life: 5);
        break;
      case BattlePower.cowPuncher:
        shoot(speed: 210, aimed: true, turret: true, life: 2.2);
        break;
      case BattlePower.buckshot:
        shoot(count: 6, spread: .5, speed: 215, life: .75);
        break;
      case BattlePower.bearHug:
        _lay(d, power);
        break;
      case BattlePower.cactusPatch:
        for (var i = 0; i < 6; i++)
          _lay(
            d,
            BattlePower.roadMine,
            damage: damage,
            offset:
                d.normal!.cross(d.forward!).unit * ((i - 2.5) * 5) -
                d.forward! * (i.isEven ? 0 : 6),
          );
        break;
      case BattlePower.radarJammer:
        f.jammer = 7;
        human.target = null;
        _fx(d.position!, ImpactKind.pulse);
        break;
      case BattlePower.weaponUpgrade:
        f.doubled = 8;
        _fx(d.position!, ImpactKind.electric);
        break;
    }
    if (d == player || (d.position! - player.position!).length < 60)
      events.add(
        [
              BattlePower.machineGun,
              BattlePower.atomBlaster,
              BattlePower.tantrumGun,
              BattlePower.cannon,
              BattlePower.buckshot,
            ].contains(power)
            ? 'gun'
            : [
                BattlePower.laserCannon,
                BattlePower.alienLaser,
                BattlePower.deathRay,
                BattlePower.quantumAnnihilator,
              ].contains(power)
            ? 'laser'
            : [
                BattlePower.superZapper,
                BattlePower.whiteLightning,
              ].contains(power)
            ? 'electric'
            : power == BattlePower.energyShield
            ? 'shield'
            : power == BattlePower.armorRepair
            ? 'repair'
            : 'missile',
      );
    if (d == player) tell(w.name, .9);
    return true;
  }

  void _repair(Driver d, double amount) {
    final f = fighters[d]!;
    if (!f.alive) return;
    f.health = math.min(100, f.health + amount);
    f.burn = 0;
    f.shock = 0;
    d.freezeTime = 0;
    d.electricTime = 0;
    d.stun = 0;
    d.spinTime = 0;
    d.punctureTime = 0;
    d.weaponLock = 0;
    d.damage = 0;
    d.smokeExposure = 0;
    d.repairGlow = 1.4;
    _fx(d.position!, ImpactKind.repair);
  }

  void _lay(
    Driver d,
    BattlePower power, {
    V3 offset = V3.zero,
    double damage = 8,
  }) {
    zones.add(
      BattleZone(
        power,
        d,
        d.position! - d.forward! * 8 + offset,
        power == BattlePower.bearHug ? 18 : 5,
        16,
        damage: damage,
      ),
    );
  }

  bool _canSee(V3 from, V3 to) =>
      !track.obstacles.any((o) => arenaBoxHit(o, from, to) != null);
  double? _carHit(V3 from, V3 to, Driver d, [double radius = 4.2]) {
    final center = d.position! + d.normal! * (d.jump + 1.4), delta = to - from;
    final t = ((center - from).dot(delta) / math.max(.000001, delta.dot(delta)))
        .clamp(0.0, 1.0);
    return (from + delta * t - center).length < radius ? t : null;
  }

  void _ray(
    Driver d,
    V3 from,
    V3 direction,
    double damage,
    double range,
    bool penetrate,
    BattlePower power,
  ) {
    var to = from + direction * range, stop = 1.0;
    if (!penetrate) {
      for (final o in track.obstacles) {
        final t = arenaBoxHit(o, from, to);
        if (t != null) stop = math.min(stop, t);
      }
    }
    final hits = <Driver, double>{};
    for (final other in living.where((v) => v != d)) {
      final t = _carHit(from, to, other, 3.6);
      if (t != null && t <= stop) hits[other] = t;
    }
    final ordered = hits.keys.toList()
      ..sort((a, b) => hits[a]!.compareTo(hits[b]!));
    if (!penetrate && ordered.isNotEmpty) stop = hits[ordered.first]!;
    to = from + (to - from) * stop;
    rays.add(BattleRay(power, from, to));
    for (final other in (penetrate ? ordered : ordered.take(1))) {
      _hit(other, damage, d, power);
    }
    _fx(to, ImpactKind.sparks);
  }

  void _hit(Driver d, double damage, Driver source, BattlePower power) {
    final guarded = d.shield > 0;
    _hurt(
      d,
      damage,
      source,
      power == BattlePower.freonBomb
          ? ImpactKind.frost
          : [
              BattlePower.superZapper,
              BattlePower.whiteLightning,
            ].contains(power)
          ? ImpactKind.electric
          : ImpactKind.sparks,
    );
    if (guarded || !fighters[d]!.alive) return;
    final f = fighters[d]!;
    if (power == BattlePower.freonBomb) d.freezeTime = 2.2;
    if (power == BattlePower.superZapper ||
        power == BattlePower.whiteLightning) {
      d.electricTime = .7;
      f.shock = 2.8;
      f.lastAttacker = source;
    }
    if (power == BattlePower.gridlock) d.electricTime = .6;
    if (power == BattlePower.breathOfFire) {
      f.burn = 3.2;
      f.lastAttacker = source;
    }
    if (power == BattlePower.roadRunner) {
      d.spinTime = 1.2;
      d.spinDuration = 1.2;
      d.velocity += source.forward! * 32;
    }
    if (power == BattlePower.sonicBoom) {
      d.spinTime = .6;
      d.spinDuration = .6;
      d.velocity += (d.position! - source.position!).unit * 18;
    }
    if (power == BattlePower.cowPuncher)
      d.velocity +=
          (d.position! - source.position!).unit * 50 + const V3(0, 6, 0);
    if (power == BattlePower.turtleTurnover ||
        power == BattlePower.bassQuake ||
        power == BattlePower.gammaSwarm) {
      d.airborne = true;
      d.contactCooldown = .25;
      d.fallTime = 0;
      d.position = d.position! + const V3(0, .5, 0);
      d.velocity += const V3(0, 16, 0);
      if (power == BattlePower.turtleTurnover)
        d.normal = d.normal!.rotate(d.forward!, math.pi * .8);
    }
    if (power == BattlePower.tantrumGun && random.nextDouble() < .16) {
      final options = f.ammo.keys.toList();
      if (options.isNotEmpty) {
        f.ammo.remove(options.last);
        _selectLoaded(f);
      }
    }
  }

  void _radial(
    Driver owner,
    V3 center,
    double radius,
    double damage,
    BattlePower power,
  ) {
    for (final d in living.where((d) => d != owner)) {
      final distance = (d.position! + d.normal! * d.jump - center).length;
      if (distance > radius) continue;
      if (power == BattlePower.bassQuake && d.position!.y + d.jump > 8)
        continue;
      if (power == BattlePower.sonicBoom &&
          !_canSee(center + const V3(0, 2, 0), d.position! + const V3(0, 2, 0)))
        continue;
      _hit(d, damage * (.45 + .55 * (1 - distance / radius)), owner, power);
    }
  }

  void _explode(BattleShot shot, V3 position, {Driver? direct}) {
    if (shot.splash > 0) {
      _fx(position, ImpactKind.explosion);
      _radial(shot.owner, position, shot.splash, shot.damage, shot.power);
    } else if (direct != null)
      _hit(direct, shot.damage, shot.owner, shot.power);
    else
      _fx(position, ImpactKind.sparks);
    if (shot.power == BattlePower.oilDrum)
      zones.add(BattleZone(shot.power, shot.owner, position, 15, 10));
    if (shot.power == BattlePower.craterMaker)
      zones.add(
        BattleZone(
          shot.power,
          shot.owner,
          V3(position.x, .19, position.z),
          25,
          12,
        ),
      );
    if (direct == player || shot.owner == player) events.add('explosion');
  }

  void _updateShots(double dt) {
    for (final s in shots.toList()) {
      s.age += dt;
      s.life -= dt;
      if (!fighters[s.owner]!.alive && s.age > 7) {
        shots.remove(s);
        continue;
      }
      if (s.attached != null) {
        final target = s.attached!;
        s.position = target.position! + target.normal! * (target.jump + 2);
        if (s.life <= 0 || !fighters[target]!.alive) {
          _explode(s, s.position, direct: target);
          shots.remove(s);
        }
        continue;
      }
      V3? goal;
      if (s.target != null &&
          fighters[s.target]!.alive &&
          fighters[s.target]!.jammer <= 0) {
        goal = s.target!.position! + s.target!.normal! * (s.target!.jump + 1.6);
        final decoys = zones
            .where(
              (z) =>
                  z.power == BattlePower.haloDecoy &&
                  z.owner == s.target &&
                  z.life > 0,
            )
            .toList();
        if (decoys.isNotEmpty) goal = decoys.first.position;
      }
      if (goal != null && s.homing > 0) {
        final speed = s.velocity.length, desired = (goal - s.position).unit;
        s.velocity =
            s.velocity.unit.lerp(desired, math.min(1, s.homing * dt)).unit *
            speed;
        if ((goal - s.position).length < 3 &&
            zones.any(
              (z) =>
                  z.power == BattlePower.haloDecoy &&
                  (z.position - goal!).length < 1,
            )) {
          _fx(s.position, ImpactKind.sparks);
          shots.remove(s);
          continue;
        }
      }
      s.velocity += V3(0, -s.gravity * dt, 0);
      final before = s.position, next = before + s.velocity * dt;
      var first = 1.01;
      Driver? hit;
      bool obstacle = false;
      for (final o in track.obstacles) {
        final at = arenaBoxHit(o, before, next);
        if (at != null && at < first) {
          first = at;
          hit = null;
          obstacle = true;
        }
      }
      for (final d in living.where((d) => d != s.owner)) {
        final at = _carHit(before, next, d);
        if (at != null && at < first) {
          first = at;
          hit = d;
          obstacle = false;
        }
      }
      var grounded = next.y <= .18;
      final road = track.project(next);
      if (!track.isFloor(road.frame.s) &&
          road.lateral.abs() < track.width / 2 &&
          (before - road.frame.p).dot(road.frame.up) > 0 &&
          road.height <= 0)
        grounded = true;
      if (hit != null && s.power == BattlePower.magnetMine) {
        s.attached = hit;
        s.life = .8;
        s.position = next;
        _fx(next, ImpactKind.electric);
        continue;
      }
      if (s.power == BattlePower.freonBomb &&
          hit == null &&
          (grounded || obstacle) &&
          s.bounces < 2 &&
          s.life > .4) {
        s.bounces++;
        s.position = V3(next.x, math.max(.45, next.y), next.z);
        s.velocity = V3(
          s.velocity.x * .7,
          s.velocity.y.abs() * .52 + 2,
          s.velocity.z * .7,
        );
        continue;
      }
      if (first <= 1 ||
          grounded ||
          s.life <= 0 ||
          next.x.abs() > 865 ||
          next.z.abs() > 865) {
        s.position = first <= 1 ? before.lerp(next, first) : next;
        _explode(s, s.position, direct: hit);
        shots.remove(s);
        continue;
      }
      s.position = next;
      if (s.trail.isEmpty || (s.trail.last - next).length > 4) {
        s.trail.add(next);
        if (s.trail.length > 8) s.trail.removeAt(0);
      }
    }
  }

  void _updateZones(double dt) {
    for (final z in zones.toList()) {
      z.life -= dt;
      z.age += dt;
      z.pulse += dt;
      if (z.life <= 0) {
        zones.remove(z);
        continue;
      }
      if (z.power == BattlePower.discoInferno) {
        if (!fighters[z.owner]!.alive) {
          zones.remove(z);
          continue;
        }
        z.position = z.owner.position! + z.owner.normal! * (z.owner.jump + 8);
        if (z.pulse > .65) {
          z.pulse = 0;
          for (var i = 0; i < 8; i++) {
            final a = i * math.pi / 4 + z.age;
            final v = V3(math.sin(a) * 105, -18, math.cos(a) * 105);
            shots.add(
              BattleShot(
                z.power,
                z.owner,
                z.position,
                v,
                8,
                life: 2.5,
                splash: 5,
              ),
            );
          }
        }
        continue;
      }
      if (z.power == BattlePower.invasion ||
          z.power == BattlePower.gammaSwarm) {
        final target = z.target;
        if (target == null || !fighters[target]!.alive) {
          zones.remove(z);
          continue;
        }
        final goal =
            target.position! +
            target.normal! *
                (target.jump + (z.power == BattlePower.invasion ? 14 : 2));
        final delta = goal - z.position;
        z.position +=
            delta.unit *
            math.min(
              delta.length,
              dt * (z.power == BattlePower.invasion ? 90 : 65),
            );
        if (z.pulse > .5 && delta.length < 18) {
          z.pulse = 0;
          if (z.power == BattlePower.invasion) {
            for (var i = 0; i < 3; i++) {
              final a = i * math.pi * 2 / 3 + z.age;
              final from = z.position + V3(math.cos(a) * 8, 0, math.sin(a) * 8);
              if (_canSee(from, target.position! + const V3(0, 2, 0))) {
                beams.add(
                  ElectricBeam(from, target.position! + const V3(0, 2, 0)),
                );
                _hit(target, 3, z.owner, z.power);
              }
            }
          } else {
            _hit(target, 7, z.owner, z.power);
          }
        }
        continue;
      }
      final pulse = z.pulse > .5;
      if (pulse) z.pulse = 0;
      for (final d in living) {
        if (d == z.owner &&
            (z.age < 1.5 ||
                ![BattlePower.bearHug, BattlePower.roadMine].contains(z.power)))
          continue;
        final delta = d.position! + d.normal! * d.jump - z.position;
        if (delta.length > z.radius || delta.y.abs() > 9) continue;
        if (z.power == BattlePower.smogCheck) {
          d.smokeExposure = math.max(
            d.smokeExposure,
            (1 - delta.length / z.radius) * .85,
          );
          if (pulse) _hurt(d, 3.5, z.owner, ImpactKind.skid);
        } else if (z.power == BattlePower.oilDrum && d.shield <= 0) {
          if (d.spinTime <= 0 && pulse) {
            d.spinTime = .65;
            d.spinDuration = .65;
            d.stun = .35;
            _fx(d.position!, ImpactKind.skid);
          }
        } else if (z.power == BattlePower.roadMine &&
            z.age > .5 &&
            d.jump < 2.5) {
          _radial(z.owner, z.position, 16, z.damage, z.power);
          if (d == z.owner) _hurt(d, z.damage, z.owner, ImpactKind.explosion);
          _fx(z.position, ImpactKind.explosion);
          zones.remove(z);
          break;
        } else if (z.power == BattlePower.bearHug &&
            z.age > .5 &&
            d.shield <= 0) {
          d.velocity -= delta.unit * dt * 75;
          d.stun = .25;
          if (pulse) _hurt(d, 4, z.owner, ImpactKind.electric);
          z.life = math.min(z.life, 3.5);
          _fx(z.position, ImpactKind.pulse);
        }
      }
    }
    // Exposure is recomputed spatially each step; it is never a lingering timer.
  }

  void _updatePickups(double dt) {
    for (final p in pickups) {
      if (p.cooldown > 0) {
        p.cooldown -= dt;
        continue;
      }
      for (final d in living) {
        if ((d.position! + d.normal! * d.jump - p.position).length > 9)
          continue;
        if (p.health) {
          if (fighters[d]!.health >= 99) continue;
          _repair(d, 32);
          p.cooldown = 20;
        } else {
          giveWeapon(d, p.power);
          p.cooldown = 12;
          p.power = _nextLoot();
        }
        if (d == player) {
          tell(p.health ? 'REPARO +32' : selectedWeapon!.name);
          events.add('pickup');
        }
        break;
      }
    }
  }

  void applyDamage(Driver target, double amount, {Driver? source}) =>
      _hurt(target, amount, source, ImpactKind.explosion);
}

extension _BattleTarget on Driver {
  Driver? letAlive(Map<Driver, BattleFighter> states) =>
      states[this]?.alive == true ? this : null;
}
