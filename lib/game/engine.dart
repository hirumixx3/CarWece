import 'dart:math' as math;
import 'content.dart';
import 'math3d.dart';

part 'combat.dart';
part 'rival_tuning.dart';
part 'battle_engine.dart';
part 'battle_tuning.dart';
part 'surface_contacts.dart';
part 'network_simulation.dart';

int podiumCoins(int position) => switch (position) {
  1 => 1000,
  2 => 500,
  3 => 250,
  _ => 0,
};

/// Arcade vehicle dynamics in the local coordinates of the road, at 120 Hz.
/// Distances, collider sizes, lateral velocity and gravity use world units.
class Driver {
  static const halfWidth = DriverDimensions.width,
      halfLength = DriverDimensions.length;
  V3? ceilingCheckedPosition, ceilingCheckedNormal;
  final String name;
  final CarSpec car;
  double skill;
  double distance, lane, speed = 0, lateralSpeed = 0;
  double stun = 0, shield = 0, jump = 0, jumpVelocity = 0;
  double hitFlash = 0, damage = 0, spinTime = 0, spinDuration = 0;
  double wallCooldown = 0, rampCooldown = 0, padCooldown = 0;
  double recoveryTime = 0;
  double steeringAngle = 0, tireSlip = 0, driftTime = 0, skidClock = 0;
  final List<double> wheelAngles = [0, 0, 0, 0];
  final List<double> wheelSpeeds = [0, 0, 0, 0];
  V3? position, forward, normal;
  V3 velocity = V3.zero;
  double angularSpeed = 0, syncedDistance = double.nan, syncedLane = double.nan;
  double routeS = 0, reverseTime = 0, stuckTime = 0;
  double punctureTime = 0, repairGlow = 0, ghostTime = 0;
  double freezeTime = 0,
      electricTime = 0,
      weaponLock = 0,
      smokeExposure = 0,
      smokeEmit = 0,
      emitClock = 0;
  bool shieldEnhanced = false;
  bool airborne = false;
  WorldRamp? activeRamp;
  double contactCooldown = 0, fallTime = 0;
  double aiOffset = 0, aiTarget = 0, aiDecisionAt = -1;
  double aiReverseUntil = 0, aiRecoverUntil = 0;
  double aiProgressAt = 0, aiProgressMark = 0;
  int aiRecoveries = 0;
  double boostEnergy = 70, boostSeconds = 0;
  bool usingBoost = false;
  ShortcutSpec? activeShortcut, plannedShortcut;
  int shortcutStage = 1;
  int completedLaps = 0, nextCheckpoint = 1;
  bool started = true;
  double? finishTime;
  Driver(this.name, this.car, this.skill, this.distance, this.lane);
  double get heading => math.atan2(lateralSpeed, math.max(18, speed));
  double get spinAngle =>
      spinTime <= 0 ? 0 : math.pi * 2 * (1 - spinTime / spinDuration);
  double get yaw => heading + spinAngle;
  double get colliderWidth =>
      halfWidth * math.cos(yaw).abs() + halfLength * math.sin(yaw).abs();
  double get colliderLength =>
      halfLength * math.cos(yaw).abs() + halfWidth * math.sin(yaw).abs();
}

class Projectile {
  double distance, lane, life = 3.2;
  final Driver? owner, target;
  final double speed;
  final double spawnDistance;
  final ItemType kind;
  final bool enhanced;
  V3? position, direction;
  final List<V3> trail = [];
  double dropSpeed = 0;
  V3? ballisticVelocity;
  int bounces = 0;
  Projectile(
    this.distance,
    this.lane, {
    this.owner,
    this.target,
    this.speed = 125,
    this.kind = ItemType.missile,
    this.enhanced = false,
  }) : spawnDistance = distance;
  double get age => 3.2 - life;
}

class OilPatch {
  final double distance, lane;
  final Driver? owner;
  double life = 9;
  V3? position;
  OilPatch(this.distance, this.lane, {this.owner});
}

enum ImpactKind {
  explosion,
  sparks,
  skid,
  blocked,
  debris,
  electric,
  frost,
  pulse,
  force,
  repair,
}

class ImpactEffect {
  final double distance, lane, height, duration;
  final ImpactKind kind;
  double age = 0;
  TrackFrame? pose;
  ImpactEffect(this.distance, this.lane, this.kind, {this.height = 0})
    : duration = kind == ImpactKind.debris
          ? 2.0
          : kind == ImpactKind.explosion
          ? 1.1
          : .65;
  double get progress => (age / duration).clamp(0, 1);
}

class RaceStanding {
  final int position;
  final String name;
  final CarSpec car;
  final double? finishTime;
  final double remaining;
  const RaceStanding(
    this.position,
    this.name,
    this.car,
    this.finishTime,
    this.remaining,
  );
}

class RaceResult {
  final int position, coins, hits, boosts;
  final double time, bestLap;
  final List<RaceStanding> standings;
  const RaceResult(
    this.position,
    this.time,
    this.bestLap,
    this.coins,
    this.hits,
    this.boosts, {
    this.standings = const [],
  });
}

class RaceEngine {
  final TrackSpec track;
  final CarSpec car;
  final RaceMode mode;
  final String difficulty;
  final int laps;
  late Driver player;
  bool networked = false;
  final List<Driver> networkDrivers = [];
  final Map<Driver, NetworkInput> networkInputs = {};
  final Map<Driver, NetworkPower> networkPowers = {};
  void Function(double)? remoteUpdate;
  void Function(String)? remoteAction;
  late List<String> gridOrder;
  int get startingPosition =>
      gridOrder.indexOf(networked ? player.name : 'VOCÊ') + 1;
  final List<Driver> bots = [];
  final List<Projectile> projectiles = [];
  final List<OilPatch> oil = [];
  final Set<String> brokenGates = {};
  final List<Mine> mines = [];
  final List<SpikeStrip> spikeStrips = [];
  final List<SmokeCloud> clouds = [];
  final List<ElectricBeam> beams = [];
  final List<ItemType> itemBag = [], itemHistory = [];
  final Map<Driver, ItemType> botLastPower = {};
  int itemCharges = 0;
  bool itemEnhanced = false, drafting = false;
  final List<ImpactEffect> effects = [];
  final Set<String> collected = {};
  final List<double> lapTimes = [];
  final math.Random random;
  double countdown = 3.2, time = 0, lastLapTime = 0, nitro = 100;
  double steering = 0,
      sensitivity = 1,
      impact = 0,
      flash = 0,
      messageLife = 0,
      _accumulator = 0,
      _botAttack = 10;
  bool accelerating = false,
      brake = false,
      boosting = false,
      autoAccelerate = false;
  bool paused = false, finished = false, drifting = false, driftPressed = false;
  ItemType? item;
  int hitCount = 0, boostCount = 0;
  String message = '';
  RaceResult? result;
  final List<String> events = [];
  List<Driver>? _finalOrder;
  RaceEngine({
    required this.track,
    required this.car,
    this.mode = RaceMode.quick,
    this.difficulty = 'normal',
    this.laps = 3,
    int seed = 42,
    List<String>? previousChampionshipOrder,
  }) : random = math.Random(seed) {
    const defaultOrder = ['NOVA', 'BOLT', 'RAVEN', 'REX', 'PIXEL', 'VOCÊ'];
    final order = <String>[];
    if (mode == RaceMode.championship && previousChampionshipOrder != null) {
      for (final name in previousChampionshipOrder) {
        if (defaultOrder.contains(name) && !order.contains(name))
          order.add(name);
      }
    }
    for (final name in defaultOrder) if (!order.contains(name)) order.add(name);
    gridOrder = List.unmodifiable(
      mode == RaceMode.timeTrial ? ['VOCÊ'] : order,
    );
    final rank = startingPosition - 1;
    player = Driver(
      'VOCÊ',
      car,
      1,
      mode == RaceMode.timeTrial ? 0 : -12 - rank * 10.0,
      mode == RaceMode.timeTrial
          ? 0
          : rank.isEven
          ? -.35
          : .35,
    );
    if (mode != RaceMode.timeTrial) {
      const names = ['NOVA', 'BOLT', 'RAVEN', 'REX', 'PIXEL'];
      final rivals = cars
          .where(
            (c) => difficulty == 'easy'
                ? c.requiredStars <= track.requiredStars + 5
                : c.speed >= car.speed * .92 &&
                      c.speed <= car.speed * 1.08 &&
                      c.acceleration >= car.acceleration * .80,
          )
          .toList();
      for (var i = 0; i < 5; i++) {
        bots.add(
          Driver(
            names[i],
            rivals[(i + 1 + seed.abs()) % rivals.length],
            opponentTuning.skill + i * (difficulty == 'easy' ? .008 : .005),
            -12 - gridOrder.indexOf(names[i]) * 10.0,
            gridOrder.indexOf(names[i]).isEven ? -.35 : .35,
          ),
        );
      }
    }
  }
  List<Driver> get drivers =>
      networked ? [...networkDrivers] : [player, ...bots];
  OpponentTuning get opponentTuning => OpponentTuning.forDifficulty(difficulty);
  double get jump => player.jump;
  set jump(double v) => player.jump = v;
  double get jumpVelocity => player.jumpVelocity;
  set jumpVelocity(double v) => player.jumpVelocity = v;
  int get lap => math.min(laps, player.completedLaps + 1);
  int get position => standings.indexOf(player) + 1;
  double get speedKmh => player.speed.abs() * 3.2;
  bool get shortcut => player.activeShortcut != null;
  TrackFrame navigationFrame(Driver d) {
    final path = d.activeShortcut;
    if (path == null) return track.checkpoint(d.nextCheckpoint);
    return d.shortcutStage < 2 ? path.gate : path.exit;
  }

  bool get nitroActive =>
      boosting &&
      (accelerating || autoAccelerate) &&
      nitro > 0 &&
      player.speed > 10 &&
      countdown <= 0 &&
      !finished &&
      player.stun <= 0;
  List<Driver> get standings {
    if (_finalOrder != null) return List.unmodifiable(_finalOrder!);
    return drivers..sort((a, b) {
      if (a.finishTime != null && b.finishTime != null)
        return a.finishTime!.compareTo(b.finishTime!);
      if (a.finishTime != null) return -1;
      if (b.finishTime != null) return 1;
      final delta = b.distance.compareTo(a.distance);
      return delta != 0
          ? delta
          : drivers.indexOf(a).compareTo(drivers.indexOf(b));
    });
  }

  double separation(double a, double b) =>
      wrap(b - a + track.length * .5, track.length) - track.length * .5;
  void tell(String text, [double duration = 1.8]) {
    message = text;
    messageLife = duration;
  }

  void clearControls() {
    steering = 0;
    accelerating = false;
    brake = false;
    boosting = false;
    driftPressed = false;
    drifting = false;
  }

  void setPaused(bool value) {
    paused = value;
    _accumulator = 0;
    clearControls();
    if (value) remoteAction?.call('idle');
  }

  void placeDriver(
    Driver d,
    double distance,
    double lane, {
    bool setProgress = true,
  }) {
    final f = track.at(distance);
    d.distance = distance;
    d.lane = lane;
    d.routeS = f.s;
    d.position = f.point(lane * track.width / 2);
    d.forward = f.forward;
    d.normal = f.up;
    d.velocity = f.forward * d.speed;
    d.angularSpeed = 0;
    d.airborne = false;
    d.activeRamp = null;
    d.contactCooldown = 0;
    d.fallTime = 0;
    d.usingBoost = false;
    d.smokeExposure = 0;
    d.activeShortcut = null;
    d.plannedShortcut = null;
    d.shortcutStage = 1;
    d.aiOffset = lane * track.width / 2;
    d.aiTarget = d.aiOffset;
    d.aiDecisionAt = -1;
    d.steeringAngle = 0;
    d.tireSlip = 0;
    d.wheelSpeeds.fillRange(0, 4, 0);
    if (setProgress) {
      d.completedLaps = math.max(0, (distance / track.length).floor());
      d.nextCheckpoint =
          ((f.s / track.length * TrackSpec.checkpointCount).floor() + 1) %
          TrackSpec.checkpointCount;
      d.started = distance >= 0;
    }
    _remember(d);
  }

  void _remember(Driver d) {
    d.syncedDistance = d.distance;
    d.syncedLane = d.lane;
  }

  void _ensure(Driver d) {
    if (d.position == null ||
        !d.syncedDistance.isFinite ||
        (d.distance - d.syncedDistance).abs() > .001 ||
        (d.lane - d.syncedLane).abs() > .001) {
      placeDriver(d, d.distance, d.lane);
    }
  }

  TrackFrame driverFrame(Driver d) {
    _ensure(d);
    final up = d.normal!, forward = d.forward!, p = d.position! + up * d.jump;
    return TrackFrame(p, up.cross(forward).unit, up, forward, d.routeS);
  }

  void resetPlayer() {
    if (remoteAction != null) {
      remoteAction!('reset');
      return;
    }
    var index = (player.nextCheckpoint - 1) % TrackSpec.checkpointCount;
    final frame = track.checkpoint(index);
    final loop = track.loopAt(frame.s);
    if (loop != null) {
      index = (loop.start / track.length * TrackSpec.checkpointCount).floor();
      player.nextCheckpoint = index + 1;
    }
    final s = index / TrackSpec.checkpointCount * track.length;
    player.speed = 0;
    player.jump = 0;
    player.jumpVelocity = 0;
    player.spinTime = 0;
    placeDriver(
      player,
      player.completedLaps * track.length + s,
      0,
      setProgress: false,
    );
    clearControls();
    impact = .4;
    tell('REPOSICIONADO NO CHECKPOINT');
  }

  void update(double dt) {
    if (remoteUpdate != null) {
      remoteUpdate!(dt);
      return;
    }
    if (paused || finished || !dt.isFinite || dt <= 0) return;
    _accumulator += dt.clamp(0, .1);
    while (_accumulator + 1e-10 >= 1 / 120) {
      _step(1 / 120);
      _accumulator -= 1 / 120;
      if (finished) {
        _accumulator = 0;
        break;
      }
    }
  }

  void _effect(Driver d, ImpactKind kind) {
    effects.add(ImpactEffect(d.distance, d.lane, kind)..pose = driverFrame(d));
  }

  void _step(double dt) {
    impact = math.max(0, impact - dt * 2.8);
    flash = math.max(0, flash - dt * 2);
    messageLife = math.max(0, messageLife - dt);
    for (final e in effects) {
      e.age += dt;
    }
    effects.removeWhere((e) => e.age >= e.duration);
    for (final d in drivers) {
      _ensure(d);
    }
    if (countdown > 0) {
      countdown -= dt;
      if (countdown <= 0) {
        tell('VAI! • VOCÊ FAZ AS CURVAS');
        events.add('go');
      }
      return;
    }
    final before = {for (final d in drivers) d: d.position!};
    final start = time;
    time += dt;
    final turbo = nitroActive;
    this._combatStatus(dt);
    drifting =
        driftPressed &&
        (steering.abs() > .12 || player.lateralSpeed.abs() > 3) &&
        player.speed > 22 &&
        player.jump <= 0 &&
        player.stun <= 0;
    for (final d in drivers) {
      if (d.finishTime != null) continue;
      d.stun = math.max(0, d.stun - dt);
      d.shield = math.max(0, d.shield - dt);
      d.ghostTime = math.max(0, d.ghostTime - dt);
      d.hitFlash = math.max(0, d.hitFlash - dt);
      d.damage = math.max(0, d.damage - dt * .28);
      d.spinTime = math.max(0, d.spinTime - dt);
      d.wallCooldown -= dt;
      d.padCooldown -= dt;
      if (networked) {
        _driveNetwork(d, dt);
        continue;
      }
      final human = d == player;
      final ai = human ? null : aiControls(d);
      final botTurbo = !human && d.usingBoost;
      if (!human) {
        d.boostEnergy =
            (d.boostEnergy + dt * (botTurbo ? -27 : opponentTuning.boostRegen))
                .clamp(0, 100);
        if (botTurbo) d.boostSeconds += dt;
      }
      _drive(
        d,
        dt,
        (human ? (autoAccelerate || accelerating) : ai!.$2) &&
            d.freezeTime <= 0 &&
            d.electricTime <= 0,
        (human ? steering * sensitivity : ai!.$1) *
            (d.freezeTime > 0 ? .15 : 1),
        human ? brake : ai!.$3,
        human ? turbo : botTurbo,
        human && drifting,
      );
    }
    nitro = networked
        ? player.boostEnergy
        : turbo
        ? math.max(0, nitro - dt * 27)
        : math.min(100, nitro + dt * (drifting ? 15 : 4));
    final active = drivers.where((d) => d.finishTime == null).toList();
    for (var pass = 0; pass < 6; pass++) {
      for (var i = 0; i < active.length; i++) {
        for (var j = i + 1; j < active.length; j++) {
          _collide(active[i], active[j], pass == 0);
        }
      }
      for (final d in active) {
        _obstacles(d, pass == 0);
      }
    }
    for (final d in active) {
      _progress(d, before[d]!, start, dt);
      _remember(d);
    }
    if (networked) {
      for (final d in networkDrivers) {
        if (d.finishTime == null) asNetworkDriver(d, _collect);
      }
    } else {
      _collect();
    }
    _weapons(dt);
    _finish();
  }

  (double, bool, bool) aiControls(Driver d) {
    _ensure(d);
    final wasBoosting = d.usingBoost;
    d.usingBoost = false;
    final tuning = d == player ? OpponentTuning.easy : opponentTuning;
    final p = track.project(d.position!);
    final currentBranch = d.activeShortcut ?? d.plannedShortcut;
    final branchS = currentBranch?.project(d.position!).frame.s;
    TrackFrame routeAhead(double ahead) {
      if (currentBranch == null) return track.at(p.frame.s + ahead);
      final future = branchS! + ahead;
      return future > currentBranch.length
          ? track.at(currentBranch.exitS + future - currentBranch.length)
          : currentBranch.at(future);
    }

    // Oscillation against an object does not renew the progress deadline.
    if (d.distance > d.aiProgressMark + 5) {
      d.aiProgressMark = d.distance;
      d.aiProgressAt = time;
    }
    if (d != player &&
        time - d.aiProgressAt > 8 &&
        !d.airborne &&
        d.stun <= 0 &&
        d.freezeTime <= 0 &&
        d.electricTime <= 0) {
      var checkpoint = (d.nextCheckpoint - 1) % TrackSpec.checkpointCount;
      final safe = track.checkpoint(checkpoint);
      final loop = track.loopAt(safe.s);
      if (loop != null) {
        checkpoint = (loop.start / track.length * TrackSpec.checkpointCount)
            .floor();
        d.nextCheckpoint = checkpoint + 1;
      }
      var distance =
          d.completedLaps * track.length +
          checkpoint / TrackSpec.checkpointCount * track.length +
          2;
      var lane = (bots.indexOf(d) - 2) * .24;
      for (var i = 0; i < 4; i++) {
        final candidate = track.at(distance).point(lane * track.width / 2);
        if (drivers.every(
          (o) =>
              o == d ||
              o.position == null ||
              (o.position! - candidate).length > 10,
        ))
          break;
        distance -= 8;
        lane = -lane;
      }
      d.speed = 0;
      placeDriver(d, distance, lane, setProgress: false);
      d.aiProgressMark = d.distance;
      d.aiProgressAt = time;
      d.aiRecoveries++;
      d.shield = 1;
      return (0, true, false);
    }

    if (d.stuckTime > 1.3 && time > d.aiRecoverUntil) {
      d.aiReverseUntil = time + 1.4;
      d.aiRecoverUntil = time + 2.6;
      d.stuckTime = 0;
      d.aiTarget = 0;
      d.aiDecisionAt = time + 2.6;
    }
    if (time < d.aiReverseUntil)
      return ((-d.lane).clamp(-1, 1).toDouble(), false, true);
    final curve = (routeAhead(15).forward - routeAhead(0).forward).length / 15;
    final radius = 1 / math.max(.001, curve);
    final lookAhead = math.min(
      (15 + d.speed.abs() * tuning.lookAhead).clamp(15, 43),
      math.max(12, radius * .45),
    );
    final usable = math.min(
      [0.0, 25.0, 60.0]
          .map((ahead) => track.widthAt(p.frame.s + ahead) / 2 - 6)
          .reduce(math.min),
      math.max(5.0, radius * .26),
    );
    // Individual preferences persist through checkpoints instead of collapsing
    // every opponent onto the same center target once per sector.
    final index = d == player ? 2 : math.max(0, bots.indexOf(d));
    final preference = (index - 2) * .24;
    if (time >= d.aiDecisionAt) {
      d.aiDecisionAt = time + tuning.decision;
      var score = double.infinity, chosen = d.aiTarget;
      final look = track.at(p.frame.s + lookAhead);
      for (final fraction in [-.72, -.48, -.24, 0.0, .24, .48, .72]) {
        final offset = fraction * usable;
        var value =
            (fraction - preference).abs() * 2 +
            (offset - d.aiTarget).abs() * .11;
        for (final other in drivers) {
          if (other == d || other.finishTime != null || other.position == null)
            continue;
          final delta = other.position! - d.position!,
              ahead = delta.dot(p.frame.forward);
          final lateral = (other.position! - p.frame.p).dot(p.frame.right);
          if (ahead > -10 && ahead < 55) {
            final gap = (lateral - offset).abs();
            if (gap < 7)
              value +=
                  (7 - gap) *
                  (ahead < 9 ? 19 : 7) /
                  (1 + math.max(0, ahead) * .045);
          }
        }
        for (final o in track.obstacles) {
          final delta = o.center - look.p,
              along = delta.dot(look.forward),
              lateral = delta.dot(look.right);
          if (along.abs() < 22 && o.center.y - o.size.y / 2 < look.p.y + 4) {
            final extent =
                o.size.x / 2 * look.right.x.abs() +
                o.size.z / 2 * look.right.z.abs();
            final margin = extent + 4.5 - (lateral - offset).abs();
            if (margin > 0) value += margin * 18;
          }
        }
        // Choose a physical line around jump ramps when following the circuit.
        // A launch cannot be corrected by steering in midair.
        for (final ramp in track.ramps) {
          if (track.at(ramp.frame.s + 60).forward.dot(ramp.frame.forward) > .97)
            continue;
          final delta = ramp.frame.p - look.p;
          if (delta.dot(look.forward).abs() > ramp.length / 2 + 32) continue;
          final lateral = delta.dot(look.right);
          final margin = ramp.width / 2 + 5 - (lateral - offset).abs();
          if (margin > 0) value += margin * 25;
        }
        if (value < score) {
          score = value;
          chosen = offset;
        }
      }
      d.aiTarget = chosen;
    }
    d.aiOffset = _approach(d.aiOffset, d.aiTarget, .105).clamp(-usable, usable);
    for (final path in track.shortcuts) {
      if (brokenGates.contains(path.id) &&
          d.nextCheckpoint == path.entryCheckpoint + 1 &&
          d.routeS >= path.entryS - 3 &&
          d.routeS < path.entryS + track.length / 32 &&
          (index + path.entryCheckpoint) % 3 != 0)
        d.plannedShortcut = path;
    }
    final branch = d.activeShortcut ?? d.plannedShortcut;
    TrackFrame target;
    if (branch != null) {
      final q = branch.project(d.position!);
      final future = q.frame.s + lookAhead;
      final route = future > branch.length
          ? track.at(branch.exitS + future - branch.length)
          : branch.at(future);
      target = TrackFrame(
        route.point(d.aiOffset.clamp(-6.5, 6.5)),
        route.right,
        route.up,
        route.forward,
        route.s,
      );
    } else {
      final gate = track.checkpoint(d.nextCheckpoint),
          gap = separation(p.frame.s, gate.s);
      final route = (gap > 0 && gap < lookAhead)
          ? gate
          : track.at(p.frame.s + lookAhead);
      target = TrackFrame(
        route.point(d.aiOffset),
        route.right,
        route.up,
        route.forward,
        route.s,
      );
    }
    final to = target.p - d.position!, right = d.normal!.cross(d.forward!).unit;
    final angle = math.atan2(to.dot(right), to.dot(d.forward!));
    var cornerBudget = math.sqrt(
      tuning.cornerForce * math.max(12, radius - d.aiOffset.abs()),
    );
    var desired = math.min(d.car.speed * d.skill, cornerBudget);
    var roadClear = radius > 210 && branch == null;
    if ((d != player && difficulty != 'easy') || currentBranch != null) {
      // Brake for an approaching corner, rather than accelerating into its wall.
      for (final ahead in [25.0, 50.0, 85.0]) {
        final k =
            (routeAhead(ahead + 12).forward - routeAhead(ahead - 3).forward)
                .length /
            15;
        final r = 1 / math.max(.001, k);
        final cornerSpeedSquared =
            tuning.cornerForce * math.max(12, r - d.aiOffset.abs());
        cornerBudget = math.min(
          cornerBudget,
          math.sqrt(cornerSpeedSquared + 2 * 43 * math.max(0, ahead - 8)),
        );
        desired = math.min(desired, cornerBudget);
        if (r < 140) roadClear = false;
      }
    }
    for (final other in drivers) {
      if (other == d || other.position == null || other.finishTime != null)
        continue;
      final v = other.position! - d.position!, ahead = v.dot(d.forward!);
      if (ahead > 0 &&
          ahead < 65 &&
          v.dot(right).abs() < 7 &&
          v.dot(d.normal!).abs() < 6)
        roadClear = false;
      if (ahead > 0 &&
          ahead < 13 &&
          v.dot(right).abs() < 4.4 &&
          (d.aiTarget - p.lateral).abs() < 3)
        desired = math.min(desired, math.max(10, other.speed - 3));
    }
    final loopRunning = track.loopAt(p.frame.s, before: 100, after: 10) != null;
    if (d != player &&
        difficulty != 'easy' &&
        !loopRunning &&
        roadClear &&
        angle.abs() < .14 &&
        d.speed > 35 &&
        !d.airborne &&
        d.stun <= 0 &&
        d.freezeTime <= 0 &&
        d.electricTime <= 0 &&
        d.boostEnergy > (wasBoosting ? 0 : tuning.boostStart)) {
      d.usingBoost = true;
      desired = math.min(cornerBudget, d.car.speed * d.skill * 1.22);
    }
    if (loopRunning)
      return ((angle * 2.2).clamp(-1, 1).toDouble(), true, false);
    return (
      (angle * 2.2).clamp(-1, 1).toDouble(),
      d.speed < desired + 2,
      d.speed > desired + 7,
    );
  }

  void _transport(Driver d, V3 up) {
    final old = d.normal!, axis = old.cross(up);
    var f = d.forward!;
    if (axis.length > .000001) {
      f = f.rotate(axis.unit, math.atan2(axis.length, old.dot(up)));
    }
    d.normal = up;
    d.forward = (f - up * f.dot(up)).unit;
  }

  static const gravity = V3(0, -27, 0);

  /// Signed normal force per unit mass. A road can push tires, never pull them.
  double contactForce(Driver d, TrackFrame f) {
    final curvature =
        (track.at(f.s + 1.5).forward - track.at(f.s - 1.5).forward) * (1 / 3);
    final along = d.velocity.dot(f.forward);
    return along * along * curvature.dot(f.up) - gravity.dot(f.up);
  }

  void _fly(Driver d, double dt, bool gas) {
    if (d.jump > 0 || d.jumpVelocity > 0) {
      d.position = d.position! + d.normal! * d.jump;
      d.velocity += d.normal! * d.jumpVelocity;
      d.jump = 0;
      d.jumpVelocity = 0;
    }
    final before = d.position!;
    d.contactCooldown = math.max(0, d.contactCooldown - dt);
    d.fallTime += dt;
    d.velocity += gravity * dt;
    var next = before + d.velocity * dt;
    final shell = _roadShell(d, before, next, d.velocity);
    next = shell.$1;
    d.velocity = shell.$2;
    final rampWall = _rampMotion(
      d,
      before,
      next,
      d.velocity,
      allowSupport: false,
    );
    if (!rampWall.$3) {
      next = rampWall.$1;
      d.velocity = rampWall.$2;
    }
    // Body inertia is visible during the fall; no steering or traction in air.
    final turn = d.normal!.cross(const V3(0, 1, 0));
    final axis = turn.length > .001 ? turn.unit : d.forward!;
    final angle = math.acos(d.normal!.y.clamp(-1, 1));
    final amount = math.min(angle, dt * (1.1 + d.fallTime * .7));
    d.normal = d.normal!.rotate(axis, amount).unit;
    d.forward = d.forward!.rotate(axis, amount).unit;
    for (var i = 0; i < 4; i++) {
      final driven =
          d.car.drive == DriveType.all ||
          (d.car.drive == DriveType.front ? i >= 2 : i < 2);
      d.wheelSpeeds[i] =
          d.wheelSpeeds[i] * math.exp(-dt * .35) +
          (gas && driven ? 18 * dt : 0);
      d.wheelAngles[i] =
          (d.wheelAngles[i] + d.wheelSpeeds[i] * dt) % (math.pi * 2);
    }
    final p = track.project(next), f = p.frame;
    final roadHit = _landRoad(d, before, next);
    if (roadHit != null &&
        (roadHit.$1.normal.y <= .25 ||
            d.normal!.dot(roadHit.$1.normal) < .65)) {
      // A roof/side impact is a collision, not tire adhesion. Continue falling
      // and rotating; only wheels facing the deck can acquire support.
      next = roadHit.$2;
      final n = roadHit.$1.normal, into = d.velocity.dot(n);
      if (into < 0) d.velocity -= n * (into * 1.12);
      d.damage = math.max(d.damage, .3);
      d.hitFlash = .3;
      if (d.wallCooldown <= 0) {
        d.wallCooldown = .2;
        _effect(d, ImpactKind.sparks);
      }
      d.position = next;
      d.speed = d.velocity.dot(d.forward!);
      d.lateralSpeed = d.velocity.dot(d.normal!.cross(d.forward!).unit);
      return;
    }
    final landedOnRoad = roadHit != null;
    final landedRamp = _landRamp(d, before, next);
    if (landedOnRoad || landedRamp != null || next.y <= TrackSpec.floorHeight) {
      final normal = landedRamp != null
          ? (landedRamp.frame.up -
                    landedRamp.frame.forward *
                        (landedRamp.height / landedRamp.length))
                .unit
          : landedOnRoad
          ? roadHit.$1.normal
          : const V3(0, 1, 0);
      final hitSpeed = -d.velocity.dot(normal);
      next = landedRamp != null
          ? next -
                normal *
                    ((next - landedRamp.frame.p).dot(normal) -
                        landedRamp.height *
                            .5 *
                            landedRamp.frame.up.dot(normal))
          : landedOnRoad
          ? next - normal * ((next - roadHit.$1.a).dot(normal) - .008)
          : V3(next.x, TrackSpec.floorHeight, next.z);
      _transport(d, normal);
      d.velocity -= normal * d.velocity.dot(normal);
      d.airborne = false;
      d.activeRamp = landedRamp;
      d.fallTime = 0;
      d.angularSpeed = 0;
      if (hitSpeed > 5) {
        d.damage = math.max(d.damage, (hitSpeed / 80).clamp(.15, .7));
        final pose = TrackFrame(
          next,
          normal.cross(d.forward!).unit,
          normal,
          d.forward!,
          f.s,
        );
        effects.add(
          ImpactEffect(d.distance, d.lane, ImpactKind.sparks)..pose = pose,
        );
        if (d == player) {
          impact = (hitSpeed / 60).clamp(.2, .75);
          events.add('land');
        }
      }
    }
    d.position = next;
    d.speed = d.velocity.dot(d.forward!);
    d.lateralSpeed = d.velocity.dot(d.normal!.cross(d.forward!).unit);
  }

  void _drive(
    Driver d,
    double dt,
    bool gas,
    double steer,
    bool braking,
    bool turbo,
    bool drift,
  ) {
    if (d.airborne) {
      _fly(d, dt, gas);
      return;
    }
    final contact = track.project(d.position!);
    if (d.activeRamp == null &&
        !track.isFloor(contact.frame.s) &&
        contact.height.abs() < 1 &&
        contact.lateral.abs() < track.width / 2 + 1 &&
        d.jump <= .01) {
      final force = contactForce(d, contact.frame);
      if (force < -.1 || (contact.frame.up.y < .5 && force <= .05)) {
        d.airborne = true;
        d.contactCooldown = .22;
        d.fallTime = 0;
        d.position = d.position! + contact.frame.up * .08;
        if (d == player && contact.frame.up.y < .5)
          tell('SEM APOIO • QUEDA NO LOOP');
        _fly(d, dt, gas);
        return;
      }
    }
    if (d.speed.abs() < 3 &&
        gas &&
        d.stun <= 0 &&
        d.freezeTime <= 0 &&
        d.electricTime <= 0) {
      d.stuckTime += dt;
    } else {
      d.stuckTime = math.max(0, d.stuckTime - dt * .5);
    }
    var up = d.normal!, forward = d.forward!;
    final long = d.velocity.dot(forward);
    final maxAngle = .54 / (1 + long.abs() * .015);
    d.steeringAngle +=
        (steer.clamp(-1, 1) * maxAngle - d.steeringAngle) *
        (1 - math.exp(-dt * 16));
    final turn =
        (d.steeringAngle / maxAngle) *
        math.min(1.85, long.abs() * .047) *
        d.car.handling *
        (d.punctureTime > 0 ? .78 : 1) *
        (long < 0 ? -1 : 1);
    d.angularSpeed += (turn - d.angularSpeed) * (1 - math.exp(-dt * 12));
    if (d.velocity.length < .12) d.angularSpeed = 0;
    forward = forward.rotate(up, d.angularSpeed * dt);
    d.forward = forward;
    final right = up.cross(forward).unit;
    var speed = d.velocity.dot(forward), side = d.velocity.dot(right);
    final maxSpeed =
        d.car.speed *
        d.skill *
        (turbo ? 1.36 : 1) *
        (d.punctureTime > 0 ? .80 : 1);
    final force = gas
        ? d.car.acceleration *
              (1 - math.pow(math.max(0, speed) / maxSpeed, 2)).clamp(-1, 1)
        : 0.0;
    d.reverseTime = braking && !gas && (speed < 1 || d.reverseTime > .4)
        ? d.reverseTime + dt
        : 0;
    if (braking && d.reverseTime > .4) {
      speed -= 20 * dt;
    } else if (braking) {
      speed = RaceEngine._approach(speed, 0, (drift ? 13 : 62) * dt);
    }
    final drag = speed.abs() > .02
        ? (2.2 + speed.abs() * .025) * speed.sign
        : 0.0;
    speed = (speed + (force - drag) * dt).clamp(-18, d.car.speed * 1.6);
    if (!gas && !braking && speed.abs() < .05) speed = 0;
    if (d.stun > 0) speed *= math.exp(-dt * 1.2);
    side *= math.exp(
      -dt *
          (d.jump > .1
              ? 1.2
              : drift
              ? 2.3
              : 8.0) *
          d.car.handling *
          (track.isFloor(d.routeS) ? track.floorGrip : 1.0) *
          (d.punctureTime > 0 ? .50 : 1.0),
    );
    // The dedicated handbrake releases rear grip while retaining propulsion.
    // Countersteering remains the player's input, never an automatic yaw assist.
    if (drift) {
      speed *= math.exp(-dt * .12);
      d.driftTime += dt;
    } else {
      d.driftTime = math.max(0, d.driftTime - dt * 2);
    }
    d.tireSlip = math.atan2(side.abs(), math.max(1, speed.abs()));
    d.skidClock += dt;
    if (drift && d.skidClock > .10 && side.abs() > 2) {
      d.skidClock = 0;
      _effect(d, ImpactKind.skid);
    }
    // Contact patch speed at each axle/wheel drives rotation. Front wheel axes
    // follow the smoothed steering rack; rear axes stay straight.
    final design = d.car.design;
    for (var i = 0; i < 4; i++) {
      final front = i >= 2,
          x = (i.isEven ? -1.0 : 1.0) * design.wheelTrack,
          z = front ? design.frontAxle : design.rearAxle;
      final localV = V3(
        side + d.angularSpeed * z,
        0,
        speed - d.angularSpeed * x,
      );
      final angle = front ? d.steeringAngle : 0.0;
      final wheelV = localV.dot(V3(math.sin(angle), 0, math.cos(angle)));
      final driven =
          d.car.drive == DriveType.all ||
          (d.car.drive == DriveType.front ? front : !front);
      final spin = drift && !front ? wheelV * .48 : wheelV;
      var omega = spin / design.wheelRadius;
      if (d.jump > .1) {
        omega =
            d.wheelSpeeds[i] * math.exp(-dt * .35) +
            (driven && gas ? 18 * dt : 0);
      }
      d.wheelSpeeds[i] = omega;
      // Signed integration is bounded for long races and correctly reverses.
      d.wheelAngles[i] = (d.wheelAngles[i] + omega * dt) % (math.pi * 2);
    }
    var velocity = forward * speed + right * side;
    final slopeGravity = gravity - up * gravity.dot(up);
    velocity += slopeGravity * dt;
    // Static tire contact holds a stopped car on gentle road slopes. Steering
    // changes the rack, never the car position, until traction moves the tires.
    if (!gas &&
        !(braking && d.reverseTime > .4) &&
        d.velocity.length < .12 &&
        up.y > .98 &&
        slopeGravity.length < 3.5)
      velocity = V3.zero;
    if (up.y > .999999 && !gas && !braking && velocity.length < .05)
      velocity = V3.zero;
    var next = d.position! + velocity * dt;
    final shell = _roadShell(d, d.position!, next, velocity);
    next = shell.$1;
    velocity = shell.$2;
    final ramp = _rampMotion(d, d.position!, next, velocity);
    next = ramp.$1;
    velocity = ramp.$2;
    if (d.airborne) {
      d.velocity = velocity;
      _fly(d, dt, gas);
      return;
    }
    final projection = track.project(next), f = projection.frame;
    final onPlastic =
        !track.isFloor(f.s) &&
        projection.height.abs() < .85 &&
        projection.lateral.abs() < track.width / 2 - .4 &&
        contact.lateral.abs() < track.width / 2 - .4 &&
        (track.isFloor(contact.frame.s) ||
            (contact.height.abs() < .3 &&
                d.normal!.dot(contact.frame.up) > .65));
    if (ramp.$3) {
      // The wedge contact has already placed all four tires on its slope.
    } else if (onPlastic) {
      final limit = track.width / 2 - 2.3;
      var lateral = projection.lateral;
      if (lateral.abs() > limit) {
        lateral = lateral.clamp(-limit, limit);
        final outward = velocity.dot(f.right) * projection.lateral.sign;
        if (outward > 0)
          velocity -= f.right * (outward * 1.22 * projection.lateral.sign);
        if (d.wallCooldown <= 0 && speed.abs() > 4) {
          d.wallCooldown = .3;
          _effect(d, ImpactKind.sparks);
          if (d == player) {
            impact = .3;
            events.add('bump');
          }
        }
      }
      // Project only the surface normal and rail penetration. Reconstructing
      // from centerline S erased the tangential residual of an offset curve,
      // creeping a stationary car sideways every physics step.
      next += f.right * (lateral - projection.lateral);
      next -= f.up * (next - f.p).dot(f.up);
      _transport(d, f.up);
      velocity -= f.up * velocity.dot(f.up);
    } else {
      if (d.position!.y > TrackSpec.floorHeight + .4) {
        d.airborne = true;
        d.contactCooldown = .1;
        d.velocity = velocity;
        _fly(d, dt, gas);
        return;
      }
      if (next.y <= TrackSpec.floorHeight + .05) {
        next = V3(next.x, TrackSpec.floorHeight, next.z);
        if (d.normal!.y < .5 || d.velocity.y < -10) {
          _effect(d, ImpactKind.sparks);
        }
        _transport(d, const V3(0, 1, 0));
        velocity = V3(velocity.x, 0, velocity.z);
      }
    }
    d.position = next;
    d.velocity = velocity;
    d.speed = velocity.dot(d.forward!);
    d.lateralSpeed = velocity.dot(d.normal!.cross(d.forward!).unit);
    if (d.jump > 0 || d.jumpVelocity > 0) {
      d.jump += d.jumpVelocity * dt;
      d.jumpVelocity -= 27 * dt;
      if (d.jump <= 0) {
        d.jump = 0;
        d.jumpVelocity = 0;
        _effect(d, ImpactKind.sparks);
        if (d == player) {
          impact = .25;
          events.add('land');
        }
      }
    }
    if (track.isBoost(f.s, projection.lateral / (track.width / 2)) &&
        projection.height.abs() < 3 &&
        projection.lateral.abs() < track.width * .5 &&
        d.padCooldown <= 0 &&
        d.speed > 4) {
      d.velocity = d.forward! * math.max(d.speed, d.car.speed * 1.23);
      d.speed = d.velocity.dot(d.forward!);
      d.padCooldown = 2;
      if (networked) d.boostEnergy = math.min(100, d.boostEnergy + 18);
      if (d == player) {
        if (!networked) nitro = math.min(100, nitro + 18);
        boostCount++;
        tell('TURBO NA PISTA!');
        events.add('boost');
      }
    }
  }

  void _obstacles(Driver d, bool report) {
    var p = d.position!;
    final road = _roadShell(d, p, p, d.velocity);
    p = road.$1;
    d.velocity = road.$2;
    final edge = TrackSpec.roomHalf - 3;
    if (p.x.abs() > edge) {
      p = V3(p.x.clamp(-edge, edge), p.y, p.z);
      d.velocity = V3(-d.velocity.x * .2, d.velocity.y, d.velocity.z);
    }
    if (p.z.abs() > edge) {
      p = V3(p.x, p.y, p.z.clamp(-edge, edge));
      d.velocity = V3(d.velocity.x, d.velocity.y, -d.velocity.z * .2);
    }
    for (final obstacle in [
      ...track.nearbyObstacles(p),
      for (final path in track.shortcuts)
        if (!brokenGates.contains(path.id)) path.gateCollider,
    ]) {
      if (p.y + d.jump > obstacle.center.y + obstacle.size.y / 2 + 1 ||
          p.y + 3 < obstacle.center.y - obstacle.size.y / 2)
        continue;
      final delta = p - obstacle.center,
          dx = delta.dot(obstacle.right),
          dz = delta.dot(obstacle.forward);
      final bodyRight = d.normal!.cross(d.forward!).unit;
      final extentX =
          d.forward!.dot(obstacle.right).abs() * 3.7 +
          bodyRight.dot(obstacle.right).abs() * 2 +
          .1;
      final extentZ =
          d.forward!.dot(obstacle.forward).abs() * 3.7 +
          bodyRight.dot(obstacle.forward).abs() * 2 +
          .1;
      final px = obstacle.size.x / 2 + extentX - dx.abs(),
          pz = obstacle.size.z / 2 + extentZ - dz.abs();
      if (px <= 0 || pz <= 0) continue;
      final n = px < pz
          ? obstacle.right * (dx >= 0 ? 1 : -1)
          : obstacle.forward * (dz >= 0 ? 1 : -1);
      p += n * (math.min(px, pz) + .005);
      final inward = d.velocity.dot(n);
      if (inward < 0) {
        d.velocity -= n * (inward * 1.35);
      }
      if (report && inward < -2) {
        _effect(d, ImpactKind.sparks);
        d.hitFlash = .25;
        if (d == player) {
          impact = .45;
          events.add('bump');
        }
      }
    }
    d.position = p;
    d.speed = d.velocity.dot(d.forward!);
  }

  void _collide(Driver a, Driver b, bool report) {
    if (a.ghostTime > 0 || b.ghostTime > 0) return; // ghosts pass through
    final pa = a.position! + a.normal! * a.jump,
        pb = b.position! + b.normal! * b.jump,
        delta = pb - pa;
    if (delta.length > 12) return;
    final up = (a.normal! + b.normal!).unit;
    if (delta.dot(up).abs() > 2.7) return;
    final ar = up.cross(a.forward!).unit, br = up.cross(b.forward!).unit;
    var overlap = double.infinity;
    V3? normal;
    for (final axis in [ar, a.forward!, br, b.forward!]) {
      final extent =
          2.0 * (axis.dot(ar).abs() + axis.dot(br).abs()) +
          3.7 * (axis.dot(a.forward!).abs() + axis.dot(b.forward!).abs()) +
          .1;
      final penetration = extent - delta.dot(axis).abs();
      if (penetration <= 0) return;
      if (penetration < overlap) {
        overlap = penetration;
        normal = axis * (delta.dot(axis) >= 0 ? 1 : -1);
      }
    }
    final n = normal!;
    a.position = a.position! - n * ((overlap + .003) / 2);
    b.position = b.position! + n * ((overlap + .003) / 2);
    final closing = (a.velocity - b.velocity).dot(n);
    if (closing > 0) {
      a.velocity -= n * (closing * .57);
      b.velocity += n * (closing * .57);
    }
    a.speed = a.velocity.dot(a.forward!);
    b.speed = b.velocity.dot(b.forward!);
    if (report && closing > 2) {
      a.hitFlash = .3;
      b.hitFlash = .3;
      _effect(a, ImpactKind.sparks);
      if (a == player || b == player) {
        impact = (closing / 45).clamp(.2, .7);
        events.add('bump');
      }
    }
  }

  double? _portalCrossing(
    V3 before,
    V3 after,
    TrackFrame f,
    double halfWidth, {
    double halfHeight = 9,
    double? minHeight,
  }) {
    final a = (before - f.p).dot(f.forward),
        b = (after - f.p).dot(f.forward),
        advance = b - a;
    // Sample the actual intersection, not the end of the physics step. Cars
    // can also start exactly on a plane after a contact or a stopped wheel.
    if (a > .02 || b < 0 || advance <= .000001) return null;
    final fraction = (-a / advance).clamp(0.0, 1.0);
    final hit = before.lerp(after, fraction) - f.p;
    final height = hit.dot(f.up);
    if (hit.dot(f.right).abs() > halfWidth ||
        height > halfHeight ||
        height < (minHeight ?? -halfHeight))
      return null;
    return fraction;
  }

  bool _shortcutProgress(Driver d, V3 before) {
    final after = d.position!;
    bool eligible(ShortcutSpec path) =>
        d.started &&
        d.nextCheckpoint >= path.entryCheckpoint &&
        d.nextCheckpoint <= path.exitCheckpoint;
    double? crossing(TrackFrame frame, double halfWidth) => _portalCrossing(
      before,
      after,
      frame,
      halfWidth,
      halfHeight: 24,
      minHeight: -3,
    );
    void approach(ShortcutSpec path) {
      d.activeShortcut = path;
      d.plannedShortcut = path;
      d.shortcutStage = 1; // navigation only: no branch checkpoint credit yet
      if (d == player) {
        tell(
          brokenGates.contains(path.id)
              ? 'ATALHO ABERTO'
              : 'ATALHO • DESTRUA O PORTÃO-ALVO',
        );
      }
    }

    void cancel() {
      d.activeShortcut = null;
      d.plannedShortcut = null;
      d.shortcutStage = 1;
    }

    // The physical gate plane, not a hidden earlier portal, is the proof that
    // this branch was entered. It works even if the entrance portal was missed.
    // Closed panels are still handled by the existing solid collision solver.
    for (final path in track.shortcuts) {
      if (!eligible(path)) continue;
      if (crossing(path.gate, path.width / 2 + Driver.halfWidth + 3) != null) {
        d.activeShortcut = path;
        d.plannedShortcut = path;
        d.shortcutStage = 2; // gate crossed; only the exit remains
        if (d == player) tell('ATALHO VALIDADO • SIGA ATÉ A SAÍDA');
        break;
      }
      if (d.activeShortcut == null &&
          (networked || d == player || brokenGates.contains(path.id)) &&
          crossing(path.entrance, path.width / 2 + Driver.halfWidth + 3) !=
              null) {
        approach(path);
      }
    }

    // Entering the branch anywhere along its corridor also arms the attempt:
    // a jump, a shove or a wide merge can put the car inside the branch
    // without ever crossing the entrance or gate planes. Moving forward
    // inside the corridor past the gate point is the same traversal proof as
    // crossing the gate plane, and presence before it arms navigation like
    // the entrance does. The merge zones at both ends are excluded: there
    // the branch and the main road overlap, so presence alone proves nothing.
    if (d.activeShortcut == null) {
      for (final path in track.shortcuts) {
        if (!eligible(path)) continue;
        final proj = path.project(after);
        final s = proj.frame.s;
        if (s < path.length * .08 || s > path.length - 20) continue;
        if ((after - before).dot(proj.frame.forward) <= 0) continue;
        // Near both merges the branch overlaps the main road: a car still
        // on the main road must never arm the branch from presence alone,
        // or navigation would drag it into a branch it never entered.
        final main = track.project(after);
        if (main.lateral.abs() <= track.widthAt(main.frame.s) / 2 + 3) {
          continue;
        }
        final pastGate = s >= path.length * .5;
        final half = path.width / 2 + Driver.halfWidth + (pastGate ? 0 : 3);
        if (proj.squaredDistance > half * half) continue;
        if (!pastGate &&
            !(networked || d == player || brokenGates.contains(path.id))) {
          continue;
        }
        d.activeShortcut = path;
        d.plannedShortcut = path;
        d.shortcutStage = pastGate ? 2 : 1;
        if (d == player) {
          tell(
            pastGate
                ? 'ATALHO VALIDADO • SIGA ATÉ A SAÍDA'
                : brokenGates.contains(path.id)
                ? 'ATALHO ABERTO'
                : 'ATALHO • DESTRUA O PORTÃO-ALVO',
          );
        }
        break;
      }
    }

    final path = d.activeShortcut;
    if (path == null) return false;
    if (d.shortcutStage < 2 && !eligible(path)) {
      cancel();
      return false;
    }

    // A lateral or airborne pass can carry the car past the gate point
    // without a clean plane crossing; reaching the gate point inside the
    // corridor, moving forward, is the same traversal proof.
    if (d.shortcutStage < 2) {
      final proj = path.project(after);
      final half = path.width / 2 + Driver.halfWidth + 3;
      if (proj.frame.s >= path.length * .5 &&
          proj.squaredDistance <= half * half &&
          (after - before).dot(proj.frame.forward) > 0) {
        d.shortcutStage = 2;
        if (d == player) tell('ATALHO VALIDADO • SIGA ATÉ A SAÍDA');
      }
    }

    // Reversing back through the gate revokes this attempt. A later forward
    // crossing can arm a fresh attempt, but the main road cannot finish this one.
    if (d.shortcutStage >= 2 &&
        _portalCrossing(
              after,
              before,
              path.gate,
              path.width / 2 + Driver.halfWidth + 3,
              halfHeight: 24,
              minHeight: -3,
            ) !=
            null) {
      cancel();
      return false;
    }

    // Test the swept exit intersection BEFORE projecting/cancelling the branch.
    // At the merge a wide line or a fast step can already be outside the narrow
    // branch's final bounds, while still physically crossing the correct exit.
    final exitHalfWidth =
        math.max(path.width, track.widthAt(path.exitS)) / 2 +
        Driver.halfWidth +
        3;
    void complete() {
      d.nextCheckpoint = (path.exitCheckpoint + 1) % TrackSpec.checkpointCount;
      d.activeShortcut = null;
      d.plannedShortcut = null;
      d.shortcutStage = 4;
      final main = track.project(after);
      d.routeS = main.frame.s;
      d.lane = main.lateral / (track.width / 2);
      final upper = d.nextCheckpoint == 0
          ? track.length
          : track.checkpoint(d.nextCheckpoint).s;
      d.distance =
          d.completedLaps * track.length +
          main.frame.s.clamp(path.exitS, upper);
      if (d == player) {
        nitro = math.min(100, nitro + 12);
        tell('ATALHO CONCLUÍDO!');
        events.add('shortcut');
      }
    }

    // True when the car is back on the main road at or just past the exit
    // merge: it physically rejoined, even if the exact exit plane was never
    // crossed (wide line, airborne pass or a shove through the merge).
    bool mergedPastExit() {
      final main = track.project(after);
      final ahead = wrap(main.frame.s - path.exitS, track.length);
      final sector = track.length / TrackSpec.checkpointCount;
      return ahead <= sector &&
          main.lateral.abs() <= track.widthAt(main.frame.s) / 2 + 3;
    }

    if (d.shortcutStage >= 2 && crossing(path.exit, exitHalfWidth) != null) {
      complete();
      // Do not immediately reprocess the same swept motion as a main portal.
      return true;
    }

    final p = path.project(after);
    final atMerge = p.frame.s >= path.length - math.min(64, path.length * .20);
    final corridor = d.shortcutStage >= 2 && atMerge
        ? math.max(path.width + 12, exitHalfWidth)
        : path.width + 12;
    if (d.shortcutStage >= 2 && atMerge && mergedPastExit()) {
      complete();
      return true;
    }
    if (p.squaredDistance > corridor * corridor) {
      // Leaving the corridor after the gate with the merge already passed
      // completes the branch. Leaving it earlier just abandons the attempt:
      // the remaining main-road checkpoints are still ahead, so no lap is
      // lost either way.
      if (d.shortcutStage >= 2 && mergedPastExit()) {
        complete();
        return true;
      }
      cancel();
      return false;
    }
    if (d.shortcutStage < 2) return false;

    // While armed, map real branch travel into the equivalent main-road arc so
    // standings remain correct. No intermediate invisible portal can get stuck.
    d.routeS =
        path.entryS + (path.exitS - path.entryS) * (p.frame.s / path.length);
    d.lane = p.lateral / (path.width / 2);
    d.distance = d.completedLaps * track.length + d.routeS;
    return true;
  }

  void _progress(Driver d, V3 before, double start, double dt) {
    if (_shortcutProgress(d, before)) return;
    final p = track.project(d.position!);
    d.routeS = p.frame.s;
    d.lane = p.lateral / (track.width / 2);
    final gate = track.checkpoint(d.nextCheckpoint);
    final floor = track.isFloor(gate.s);
    final crossing = _portalCrossing(
      before,
      d.position!,
      gate,
      track.widthAt(gate.s) / 2 + 3,
      halfHeight: floor ? 24 : 9,
      minHeight: floor ? -3 : -9,
    );
    if (crossing != null) {
      final crossTime = start + dt * crossing;
      if (d.nextCheckpoint == 0) {
        if (d.started) {
          d.completedLaps++;
          if (d == player) {
            lapTimes.add(crossTime - lastLapTime);
            lastLapTime = crossTime;
            if (d.completedLaps < laps) {
              tell(
                d.completedLaps == laps - 1
                    ? 'ÚLTIMA VOLTA!'
                    : 'VOLTA ${d.completedLaps + 1}',
              );
              events.add('lap');
            }
          }
          if (d.completedLaps >= laps) {
            d.finishTime = crossTime;
            d.distance = laps * track.length;
            return;
          }
        } else {
          d.started = true;
        }
      }
      d.nextCheckpoint = (d.nextCheckpoint + 1) % TrackSpec.checkpointCount;
    }
    if (!d.started) {
      d.distance = separation(0, p.frame.s);
      return;
    }
    final sector = d.nextCheckpoint == 0
        ? TrackSpec.checkpointCount - 1
        : d.nextCheckpoint - 1;
    final lower = sector / TrackSpec.checkpointCount * track.length;
    final upper = (sector + 1) / TrackSpec.checkpointCount * track.length;
    d.distance = d.completedLaps * track.length + p.frame.s.clamp(lower, upper);
  }

  void _damage(
    Driver d,
    ImpactKind kind, {
    Driver? source,
    bool spawnEffect = true,
    String? weapon,
  }) {
    if (d.ghostTime > 0) return; // intangible: nothing negative connects
    if (d.shield > 0) {
      d.shield = math.max(0, d.shield - 2);
      if (networked &&
          d.shieldEnhanced &&
          networkPowers[d]!.item == null &&
          source != null) {
        asNetworkDriver(d, () => giveItem(ItemType.missile));
      } else if (!networked &&
          d == player &&
          d.shieldEnhanced &&
          item == null &&
          source != null)
        giveItem(ItemType.missile);
      _effect(d, ImpactKind.blocked);
      if (d == player) tell('ESCUDO • BLOQUEADO!');
      events.add('hit');
      return;
    }
    d.stun = kind == ImpactKind.skid ? 1.5 : 1.1;
    d.spinTime = d.stun;
    d.spinDuration = d.stun;
    d.hitFlash = .65;
    d.damage = 1;
    d.velocity *= kind == ImpactKind.skid ? .65 : .52;
    d.speed = d.velocity.dot(d.forward!);
    d.jumpVelocity = kind == ImpactKind.explosion ? 5 : 0;
    if (spawnEffect) _effect(d, kind);
    if (source == player && d != player) {
      hitCount++;
      tell(
        '${weapon ?? (kind == ImpactKind.skid ? 'ÓLEO' : 'FOGUETE')} • ACERTO!',
      );
    }
    if (d == player) {
      impact = .85;
      tell('ATINGIDO!');
    }
    events.add('hit');
  }

  void _weapons(double dt) {
    _botAttack -= dt;
    if (!networked && _botAttack <= 0 && difficulty != 'easy') {
      _botAttack =
          opponentTuning.attackMin +
          random.nextDouble() * opponentTuning.attackRange;
      final ready = bots
          .where(
            (d) =>
                d.finishTime == null &&
                d.weaponLock <= 0 &&
                d.stun <= 0 &&
                (d.position! - player.position!).length < 160,
          )
          .toList();
      if (ready.isNotEmpty) {
        final d = ready[random.nextInt(ready.length)];
        final front = _targetOf(d, 150);
        final rear = drivers.any(
          (o) =>
              o != d &&
              o.position != null &&
              (o.position! - d.position!).dot(d.forward!) < -4 &&
              (o.position! - d.position!).length < 40,
        );
        final options = <ItemType>[
          ItemType.shield,
          if (d.damage > .25 || d.punctureTime > 0 || d.freezeTime > 0)
            ItemType.repair,
          if (drivers.any(
            (o) =>
                o != d &&
                o.finishTime == null &&
                (o.position! - d.position!).length < 32,
          ))
            ItemType.shockwave,
          if (front != null) ...[
            ItemType.missile,
            ItemType.ice,
            ItemType.salvo,
            if ((front.position! - d.position!).length < 110) ItemType.grenade,
            if ((front.position! - d.position!).length < 60) ItemType.tesla,
            if ((front.position! - d.position!).length < 90) ItemType.dreno,
          ],
          if (rear) ...[
            ItemType.mine,
            ItemType.oil,
            ItemType.smoke,
            ItemType.spikes,
          ],
          if (front == null && !rear) ...[ItemType.nitro, ItemType.propulsor],
          if (rear || d.damage > .5) ItemType.fantasma,
        ]..remove(botLastPower[d]);
        if (options.isEmpty) options.add(ItemType.shield);
        final kind = options[random.nextInt(options.length)];
        botLastPower[d] = kind;
        this._activatePower(
          d,
          kind,
          random.nextDouble() < opponentTuning.enhancedChance,
        );
      }
    }
    for (final p in projectiles) {
      p.position ??= track.at(p.distance).point(p.lane * track.width / 2, 1.6);
      p.direction ??= track.at(p.distance).forward;
      final grenade = p.kind == ItemType.grenade;
      final hasTarget =
          !grenade && p.target != null && p.target!.finishTime == null;
      if (hasTarget) {
        final aim =
            p.target!.position! +
            p.target!.normal! * (1.2 + p.target!.jump) -
            p.position!;
        p.direction = p.direction!
            .lerp(aim.unit, 1 - math.exp(-dt * (p.enhanced ? 7.5 : 2.8)))
            .unit;
      } else if (grenade) {
        p.ballisticVelocity =
            (p.ballisticVelocity ?? p.direction! * p.speed) + gravity * dt;
        if (p.ballisticVelocity!.length > .1)
          p.direction = p.ballisticVelocity!.unit;
      } else {
        p.dropSpeed -= 6 * dt;
      }
      final before = p.position!;
      final next =
          before +
          (grenade
                  ? p.ballisticVelocity!
                  : p.direction! * p.speed + V3(0, p.dropSpeed, 0)) *
              dt;
      p.life -= dt;
      p.trail.add(before);
      if (p.trail.length > 12) p.trail.removeAt(0);
      final terrain = _worldHit(before, next);
      var hitT = terrain?.$1 ?? double.infinity;
      Driver? victim;
      for (final d in drivers) {
        if (d == p.owner || d.finishTime != null || d.ghostTime > 0) continue;
        final center = d.position! + d.normal! * (1.2 + d.jump);
        final t = _sphereHit(before, next, center, 3.0);
        if (t != null && t < hitT) {
          hitT = t;
          victim = d;
        }
      }
      p.position = next;
      if (hitT.isFinite) {
        final point = before.lerp(next, hitT);
        final normal = victim != null ? const V3(0, 1, 0) : terrain!.$2;
        if (grenade && victim == null && p.life > 0 && p.bounces < 4) {
          final v = p.ballisticVelocity!;
          p.ballisticVelocity = (v - normal * (2 * v.dot(normal))) * .55;
          p.position = point + normal * .65;
          p.bounces++;
          continue;
        }
        if (p.kind == ItemType.missile || grenade) {
          if (p.kind == ItemType.missile &&
              victim == null &&
              terrain?.$3 != null)
            breakGate(terrain!.$3!);
          _detonate(p, point, normal, direct: victim);
        } else {
          this._iceImpact(p, point, victim);
        }
        p.life = 0;
      } else if (p.life <= 0) {
        if (p.kind == ItemType.missile || grenade) {
          _detonate(p, next, const V3(0, 1, 0));
        } else {
          this._iceImpact(p, next, null);
        }
      }
    }
    projectiles.removeWhere((p) => p.life <= 0);
    for (final patch in oil) {
      patch.life -= dt;
      patch.position ??= track
          .at(patch.distance)
          .point(patch.lane * track.width / 2);
      for (final d in drivers) {
        if (d == patch.owner ||
            d.finishTime != null ||
            d.stun > 0 ||
            d.ghostTime > 0 ||
            d.jump > .5)
          continue;
        if ((d.position! - patch.position!).length < 4.8) {
          _damage(d, ImpactKind.skid, source: patch.owner);
          patch.life = 0;
          break;
        }
      }
    }
    oil.removeWhere((p) => p.life <= 0);
    this._combatObjects(dt);
    if (effects.length > 32) effects.removeRange(0, effects.length - 32);
  }

  static double? _sphereHit(V3 a, V3 b, V3 center, double radius) {
    final v = b - a, offset = a - center;
    final aa = v.dot(v),
        bb = offset.dot(v),
        cc = offset.dot(offset) - radius * radius;
    if (cc <= 0) return 0;
    final discriminant = bb * bb - aa * cc;
    if (aa < 1e-9 || discriminant < 0) return null;
    final t = (-bb - math.sqrt(discriminant)) / aa;
    return t >= 0 && t <= 1 ? t : null;
  }

  /// Swept segment/AABB collision: no tunneling even at boost speed.
  static (double, V3)? _boxHit(V3 a, V3 b, V3 center, V3 size) {
    final starts = [a.x, a.y, a.z], ends = [b.x, b.y, b.z];
    final lo = [
      center.x - size.x / 2 - .3,
      center.y - size.y / 2 - .3,
      center.z - size.z / 2 - .3,
    ];
    final hi = [
      center.x + size.x / 2 + .3,
      center.y + size.y / 2 + .3,
      center.z + size.z / 2 + .3,
    ];
    var enter = 0.0, leave = 1.0;
    var normal = const V3(0, 1, 0);
    for (var i = 0; i < 3; i++) {
      final v = ends[i] - starts[i];
      if (v.abs() < 1e-8) {
        if (starts[i] < lo[i] || starts[i] > hi[i]) return null;
        continue;
      }
      final near = (lo[i] - starts[i]) / v, far = (hi[i] - starts[i]) / v;
      final first = math.min(near, far), last = math.max(near, far);
      if (first > enter) {
        enter = first;
        final sign = v > 0 ? -1.0 : 1.0;
        normal = V3(i == 0 ? sign : 0, i == 1 ? sign : 0, i == 2 ? sign : 0);
      }
      leave = math.min(leave, last);
      if (enter > leave) return null;
    }
    return enter >= 0 && enter <= 1 ? (enter, normal) : null;
  }

  static (double, V3)? _obstacleHit(V3 a, V3 b, WorldObstacle o) {
    V3 local(V3 p) {
      final d = p - o.center;
      return V3(d.dot(o.right), d.y, d.dot(o.forward));
    }

    final hit = _boxHit(local(a), local(b), V3.zero, o.size);
    if (hit == null) return null;
    return (
      hit.$1,
      o.right * hit.$2.x + const V3(0, 1, 0) * hit.$2.y + o.forward * hit.$2.z,
    );
  }

  (double, V3, String?)? _worldHit(V3 before, V3 next) {
    var first = double.infinity;
    String? gateId;
    var normal = const V3(0, 1, 0);
    const level = TrackSpec.floorHeight + .30;
    if (next.y <= level && before.y >= level)
      first = (before.y - level) / (before.y - next.y);
    if (before.y < level) first = 0;
    for (final o in track.nearbyObstacles((before + next) * .5)) {
      final hit = _obstacleHit(before, next, o);
      if (hit != null && hit.$1 < first) {
        first = hit.$1;
        normal = hit.$2;
      }
    }
    for (final path in track.shortcuts) {
      if (brokenGates.contains(path.id)) continue;
      final hit = _obstacleHit(before, next, path.gateCollider);
      if (hit != null && hit.$1 < first) {
        first = hit.$1;
        normal = hit.$2;
        gateId = path.id;
      }
    }
    for (final wall in [
      (const V3(-880, 110, 0), const V3(5, 220, 1760)),
      (const V3(880, 110, 0), const V3(5, 220, 1760)),
      (const V3(0, 110, -880), const V3(1760, 220, 5)),
      (const V3(0, 110, 880), const V3(1760, 220, 5)),
    ]) {
      final hit = _boxHit(before, next, wall.$1, wall.$2);
      if (hit != null && hit.$1 < first) {
        gateId = null;
        first = hit.$1;
        normal = hit.$2;
      }
    }
    // Short steps test the actual road ribbon, including tilted loop surfaces.
    for (var j = 1; j <= 4; j++) {
      final t = j / 4,
          point = before.lerp(next, t),
          p = track.project(point),
          f = p.frame;
      if (track.isFloor(f.s) || p.lateral.abs() > track.width / 2 + .35)
        continue;
      final old = (before - f.p).dot(f.up), height = p.height;
      if (old * height <= 0 || (height.abs() <= .3 && old.abs() > .3)) {
        final fraction =
            ((old.abs() - .3) / math.max(.0001, old.abs() - height.abs()))
                .clamp(0, 1);
        final hit = t * fraction;
        if (hit < first) {
          gateId = null;
          first = hit;
          normal = f.up * (old >= 0 ? 1 : -1);
        }
      }
    }
    return first.isFinite ? (first, normal, gateId) : null;
  }

  void breakGate(String id) {
    _ensure(player);
    if (!brokenGates.add(id)) return;
    final path = track.shortcuts.firstWhere((p) => p.id == id);
    effects.add(
      ImpactEffect(path.entryS, 0, ImpactKind.debris)..pose = path.gate,
    );
    if ((player.position! - path.gate.p).length < 120)
      tell('PORTÃO QUEBRADO • ATALHO ABERTO!');
    events.add('gate');
  }

  void _detonate(Projectile p, V3 point, V3 normal, {Driver? direct}) {
    final projected = track.project(point);
    var forward = normal.cross(const V3(1, 0, 0));
    if (forward.length < .1) forward = normal.cross(const V3(0, 0, 1));
    forward = forward.unit;
    effects.add(
      ImpactEffect(projected.frame.s, 0, ImpactKind.explosion)
        ..pose = TrackFrame(
          point,
          normal.cross(forward).unit,
          normal,
          forward,
          projected.frame.s,
        ),
    );
    // Layered aftermath: spark burst, debris and two lingering smoke puffs
    // ride the same effect so explosions read with weight, not one flash.
    for (final kind in [ImpactKind.sparks, ImpactKind.debris]) {
      effects.add(
        ImpactEffect(projected.frame.s, 0, kind)
          ..pose = TrackFrame(
            point,
            normal.cross(forward).unit,
            normal,
            forward,
            projected.frame.s,
          ),
      );
    }
    for (var i = 0; i < 2; i++) {
      clouds.add(
        SmokeCloud(point + normal * (1.5 + i * 1.2), p.owner ?? player)
          ..life = 2.6,
      );
    }
    for (final d in drivers) {
      final delta = d.position! + d.normal! * (1 + d.jump) - point;
      if (d.finishTime != null ||
          (d != direct &&
              delta.length >
                  (p.kind == ItemType.grenade ? (p.enhanced ? 16 : 11) : 7)))
        continue;
      final protected = d.shield > 0 || d.ghostTime > 0;
      _damage(
        d,
        ImpactKind.explosion,
        source: p.owner,
        spawnEffect: false,
        weapon: p.kind == ItemType.grenade ? 'GRANADA' : 'FOGUETE',
      );
      if (!protected) d.velocity += delta.unit * (d == direct ? 9 : 4);
    }
    final distance = (player.position! - point).length;
    if (distance < 45) impact = math.max(impact, (1 - distance / 45) * .65);
    events.add('explosion');
  }

  void _collect() {
    if (item != null || mode == RaceMode.timeTrial || player.jump > 3) return;
    for (final path in track.shortcuts) {
      final key = '${player.completedLaps}:gate:${path.id}';
      if (collected.contains(key) || brokenGates.contains(path.id)) continue;
      final p = track.at(path.entryS - 45).point(0, 1.3);
      if ((player.position! - p).length < 7) {
        collected.add(key);
        giveItem(ItemType.missile);
        tell('MÍSSEIS • ABRA O PORTÃO-ALVO');
        events.add('pickup');
        return;
      }
    }
    for (var i = 0; i < 8; i++) {
      final s = (.09 + i * .115) * track.length,
          key = '${player.completedLaps}:$i';
      if (collected.contains(key)) continue;
      final p = track.at(s).point((i % 3 - 1) * .6 * track.width / 2, 1.2);
      if ((player.position! - p).length < 6) {
        collected.add(key);
        giveItem(rollItem());
        tell('${itemName(item!)} • $itemCharges CARGA(S)');
        events.add('pickup');
        break;
      }
    }
  }

  void useItem() {
    if (remoteAction != null) {
      remoteAction!('fire');
      return;
    }
    if (item == null || paused || finished || countdown > 0) return;
    if (player.weaponLock > 0) {
      tell('EMP • ARMA TEMPORARIAMENTE BLOQUEADA');
      return;
    }
    _ensure(player);
    if (itemCharges <= 0) itemCharges = initialCharges(item!, itemEnhanced);
    final kind = item!;
    this._activatePower(player, kind, itemEnhanced);
    itemCharges--;
    if (itemCharges <= 0) {
      item = null;
      itemEnhanced = false;
    }
    events.add('item');
  }

  void _finish() {
    if (networked) return;
    if (player.finishTime == null) return;
    _finalOrder = List.unmodifiable(standings);
    finished = true;
    time = player.finishTime!;
    clearControls();
    final rank = position, earned = podiumCoins(position);
    result = RaceResult(
      rank,
      time,
      lapTimes.isEmpty ? time : lapTimes.reduce(math.min),
      earned,
      hitCount,
      boostCount,
      standings: List.unmodifiable([
        for (var i = 0; i < _finalOrder!.length; i++)
          RaceStanding(
            i + 1,
            _finalOrder![i].name,
            _finalOrder![i].car,
            _finalOrder![i].finishTime,
            math.max(0, laps * track.length - _finalOrder![i].distance),
          ),
      ]),
    );
    events.add('finish');
  }

  static double _approach(double a, double b, double amount) =>
      a < b ? math.min(a + amount, b) : math.max(a - amount, b);
}

String formatTime(double seconds) {
  final ms = (seconds * 1000).round();
  return '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${((ms % 1000) ~/ 10).toString().padLeft(2, '0')}';
}
