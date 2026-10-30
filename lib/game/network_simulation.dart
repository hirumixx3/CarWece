part of 'engine.dart';

/// Only controls cross the client/server boundary. Transforms and damage are
/// computed by this same 120 Hz simulation on the server.
class NetworkInput {
  final double steer;
  final bool gas, brake, boost, drift, fire;
  const NetworkInput({
    this.steer = 0,
    this.gas = false,
    this.brake = false,
    this.boost = false,
    this.drift = false,
    this.fire = false,
  });
  factory NetworkInput.read(Map<String, dynamic> m) => NetworkInput(
    steer: m['s'] is num && (m['s'] as num).isFinite
        ? (m['s'] as num).toDouble().clamp(-1, 1)
        : 0,
    gas: m['g'] == true,
    brake: m['b'] == true,
    boost: m['t'] == true,
    drift: m['d'] == true,
    fire: m['f'] == true,
  );
  Map<String, dynamic> toJson() => {
    's': steer,
    'g': gas,
    'b': brake,
    't': boost,
    'd': drift,
    'f': fire,
  };
}

class NetworkParticipant {
  final String name;
  final int car;
  const NetworkParticipant(this.name, this.car);
}

class NetworkPower {
  ItemType? item;
  int charges = 0;
  bool enhanced = false;
}

extension NetworkSimulation on RaceEngine {
  void configureNetwork(List<NetworkParticipant> people, {int local = 0}) {
    if (people.length < 2 ||
        people.length > 6 ||
        local < 0 ||
        local >= people.length)
      throw ArgumentError('Uma sala precisa de 2 a 6 jogadores.');
    networked = true;
    networkDrivers.clear();
    networkInputs.clear();
    networkPowers.clear();
    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      if (p.car < 0 || p.car >= cars.length)
        throw ArgumentError('Carro inválido');
      final d = Driver(
        p.name,
        cars[p.car],
        1,
        -12 - i * 10.0,
        i.isEven ? -.35 : .35,
      )..boostEnergy = 100;
      networkDrivers.add(d);
      networkInputs[d] = const NetworkInput();
      networkPowers[d] = NetworkPower();
      placeDriver(d, d.distance, d.lane);
    }
    player = networkDrivers[local];
    bots
      ..clear()
      ..addAll(networkDrivers.where((d) => d != player));
    gridOrder = List.unmodifiable(people.map((p) => p.name));
    if (this is BattleEngine) {
      final b = this as BattleEngine;
      b.fighters.clear();
      for (var i = 0; i < networkDrivers.length; i++) {
        final d = networkDrivers[i];
        b.fighters[d] = BattleFighter();
        b._spawn(d, b.arena.spawns[i]);
      }
    }
    countdown = 3.2;
    time = 0;
    nitro = 100;
    autoAccelerate = false;
    result = null;
    finished = false;
    paused = false;
    item = null;
    itemCharges = 0;
    itemEnhanced = false;
  }

  void _saveNetworkPower(Driver d) {
    final p = networkPowers[d]!;
    p.item = item;
    p.charges = itemCharges;
    p.enhanced = itemEnhanced;
    d.boostEnergy = nitro;
  }

  void _loadNetworkPower(Driver d) {
    final p = networkPowers[d]!;
    item = p.item;
    itemCharges = p.charges;
    itemEnhanced = p.enhanced;
    nitro = d.boostEnergy;
  }

  void asNetworkDriver(Driver d, void Function() action) {
    final old = player;
    _saveNetworkPower(old);
    player = d;
    bots
      ..clear()
      ..addAll(networkDrivers.where((x) => x != d));
    _loadNetworkPower(d);
    try {
      action();
    } finally {
      _saveNetworkPower(d);
      player = old;
      bots
        ..clear()
        ..addAll(networkDrivers.where((x) => x != old));
      _loadNetworkPower(old);
    }
  }

  void _driveNetwork(Driver d, double dt, {bool forcedTurbo = false}) {
    final c = networkInputs[d] ?? const NetworkInput();
    final drift = c.drift && d.speed.abs() > 18 && c.steer.abs() > .12;
    final turbo =
        c.boost && c.gas && d.boostEnergy > 0 && d.speed > 10 && d.stun <= 0;
    d.usingBoost = turbo || forcedTurbo;
    d.boostEnergy =
        (d.boostEnergy +
                dt *
                    (turbo
                        ? -27
                        : drift
                        ? 15
                        : 4))
            .clamp(0, 100);
    _drive(
      d,
      dt,
      (c.gas || forcedTurbo) && d.freezeTime <= 0 && d.electricTime <= 0,
      c.steer * (d.freezeTime > 0 ? .15 : 1),
      c.brake,
      d.usingBoost,
      drift,
    );
    if (d == player) drifting = drift;
  }

  void networkCommand(Driver d, String command) {
    if (!networked || finished || d.finishTime != null) return;
    asNetworkDriver(d, () {
      if (command == 'reset') {
        resetPlayer();
        return;
      }
      if (this is BattleEngine) {
        final b = this as BattleEngine;
        if (command == 'fire') b.useItem();
        if (command == 'cycle' || command == 'super') b.cycleWeapon();
        if (command == 'target') b.cycleTarget();
        if (command.startsWith('weapon:')) {
          final i = int.tryParse(command.substring(7)) ?? -1;
          if (i >= 0 && i < BattlePower.values.length)
            b.selectWeapon(BattlePower.values[i]);
        }
        if (command.startsWith('target:')) {
          final i = int.tryParse(command.substring(7)) ?? -1;
          if (i >= 0 &&
              i < networkDrivers.length &&
              networkDrivers[i] != d &&
              b.fighters[networkDrivers[i]]!.alive) {
            b.selectTarget(networkDrivers[i]);
          }
        }
      } else {
        if (command == 'fire') useItem();
        if (command == 'super') superchargeItem();
      }
    });
  }
}

/// One shared wire format for the headless server and Android renderer.
/// Snapshots contain visual state too: wheels, missiles, explosions, smoke,
/// equipped weapons, ammunition and breakable gates.
class NetworkSnapshot {
  static double _n(num v) => (v * 1000).roundToDouble() / 1000;
  static List<double> v(V3? x) =>
      x == null ? [0, 0, 0] : [_n(x.x), _n(x.y), _n(x.z)];
  static V3 rv(dynamic x) => V3(
    (x[0] as num).toDouble(),
    (x[1] as num).toDouble(),
    (x[2] as num).toDouble(),
  );
  static List<dynamic> frame(TrackFrame f) => [
    v(f.p),
    v(f.right),
    v(f.up),
    v(f.forward),
    _n(f.s),
  ];
  static TrackFrame rf(dynamic f) => TrackFrame(
    rv(f[0]),
    rv(f[1]),
    rv(f[2]),
    rv(f[3]),
    (f[4] as num).toDouble(),
  );
  static Map<String, dynamic> capture(RaceEngine e) {
    e._saveNetworkPower(e.player);
    final ds = e.networkDrivers;
    int id(Driver? d) => d == null ? -1 : ds.indexOf(d);
    final m = <String, dynamic>{
      'time': _n(e.time),
      'count': _n(e.countdown),
      'gates': e.brokenGates.toList(),
      'col': e.collected.toList(),
      'd': [
        for (final d in ds)
          [
            v(d.position),
            v(d.forward),
            v(d.normal),
            v(d.velocity),
            _n(d.distance),
            _n(d.lane),
            _n(d.speed),
            _n(d.lateralSpeed),
            _n(d.routeS),
            _n(d.steeringAngle),
            _n(d.tireSlip),
            d.wheelAngles.map(_n).toList(),
            _n(d.stun),
            _n(d.shield),
            _n(d.hitFlash),
            _n(d.damage),
            _n(d.spinTime),
            _n(d.spinDuration),
            d.airborne,
            _n(d.boostEnergy),
            d.usingBoost,
            _n(d.jump),
            d.completedLaps,
            d.nextCheckpoint,
            d.finishTime,
            _n(d.freezeTime),
            _n(d.electricTime),
            _n(d.punctureTime),
            _n(d.repairGlow),
            _n(d.weaponLock),
            _n(d.smokeExposure),
            d.activeShortcut?.id,
            d.shortcutStage,
            d.started,
            _n(d.jumpVelocity),
          ],
      ],
      'power': [
        for (final d in ds)
          [
            e.networkPowers[d]!.item?.index,
            e.networkPowers[d]!.charges,
            e.networkPowers[d]!.enhanced,
          ],
      ],
      'fx': [
        for (final f in e.effects)
          [
            f.distance,
            f.lane,
            f.kind.index,
            f.height,
            _n(f.age),
            f.pose == null ? null : frame(f.pose!),
          ],
      ],
      'p': [
        for (final p in e.projectiles)
          [
            p.distance,
            p.lane,
            id(p.owner),
            id(p.target),
            p.speed,
            p.kind.index,
            p.enhanced,
            v(p.position),
            v(p.direction),
            p.life,
            p.dropSpeed,
            p.ballisticVelocity == null ? null : v(p.ballisticVelocity),
            p.bounces,
            p.trail.map(v).toList(),
          ],
      ],
      'oil': [
        for (final p in e.oil)
          [p.distance, p.lane, id(p.owner), p.life, v(p.position)],
      ],
      'mine': [
        for (final p in e.mines) [v(p.position), id(p.owner), p.life, p.arm],
      ],
      'smoke': [
        for (final p in e.clouds) [v(p.position), id(p.owner), p.life],
      ],
      'spike': [
        for (final p in e.spikeStrips)
          [frame(p.frame), id(p.owner), p.enhanced, p.life, p.arm],
      ],
      'beam': [
        for (final p in e.beams) [v(p.from), v(p.to), p.life],
      ],
    };
    if (e is BattleEngine) {
      m['f'] = [for (final d in ds) _fighter(e.fighters[d]!, id)];
      m['shots'] = [
        for (final p in e.shots)
          [
            p.power.index,
            id(p.owner),
            v(p.position),
            v(p.velocity),
            p.damage,
            id(p.target),
            p.life,
            p.age,
            p.gravity,
            p.homing,
            p.splash,
            p.bounces,
            p.trail.map(v).toList(),
          ],
      ];
      m['zones'] = [
        for (final z in e.zones)
          [
            z.power.index,
            id(z.owner),
            v(z.position),
            z.radius,
            z.life,
            z.age,
            z.damage,
            id(z.target),
          ],
      ];
      m['rays'] = [
        for (final r in e.rays) [r.power.index, v(r.from), v(r.to), r.life],
      ];
      m['pick'] = [
        for (final p in e.pickups) [p.power.index, p.cooldown],
      ];
    }
    return m;
  }

  static List<dynamic> _fighter(BattleFighter f, int Function(Driver?) id) => [
    f.health,
    f.selected?.index,
    [
      for (final a in f.ammo.entries) [a.key.index, a.value],
    ],
    f.kills,
    f.damageDealt,
    id(f.target),
    f.turretDirection == null ? null : v(f.turretDirection),
    f.recoil,
    f.ripper,
    f.turbo,
    f.jammer,
    f.doubled,
    f.burn,
    f.shock,
    f.deathTime.isFinite ? f.deathTime : null,
    f.deadFor,
  ];

  static void apply(RaceEngine e, Map<String, dynamic> m) {
    final ds = e.networkDrivers;
    Driver? driver(dynamic i) =>
        i is int && i >= 0 && i < ds.length ? ds[i] : null;
    double n(dynamic x) => (x as num).toDouble();
    e.time = n(m['time']);
    e.countdown = n(m['count']);
    e.brokenGates
      ..clear()
      ..addAll(List<String>.from(m['gates']));
    e.collected
      ..clear()
      ..addAll(List<String>.from(m['col']));
    for (var i = 0; i < ds.length; i++) {
      final d = ds[i], a = m['d'][i];
      d.position = rv(a[0]);
      d.forward = rv(a[1]);
      d.normal = rv(a[2]);
      d.velocity = rv(a[3]);
      d.distance = n(a[4]);
      d.lane = n(a[5]);
      d.speed = n(a[6]);
      d.lateralSpeed = n(a[7]);
      d.routeS = n(a[8]);
      d.steeringAngle = n(a[9]);
      d.tireSlip = n(a[10]);
      for (var j = 0; j < 4; j++) d.wheelAngles[j] = n(a[11][j]);
      d.stun = n(a[12]);
      d.shield = n(a[13]);
      d.hitFlash = n(a[14]);
      d.damage = n(a[15]);
      d.spinTime = n(a[16]);
      d.spinDuration = n(a[17]);
      d.airborne = a[18];
      d.boostEnergy = n(a[19]);
      d.usingBoost = a[20];
      d.jump = n(a[21]);
      d.completedLaps = a[22];
      d.nextCheckpoint = a[23];
      d.finishTime = a[24] == null ? null : n(a[24]);
      d.freezeTime = n(a[25]);
      d.electricTime = n(a[26]);
      d.punctureTime = n(a[27]);
      d.repairGlow = n(a[28]);
      d.weaponLock = n(a[29]);
      d.smokeExposure = n(a[30]);
      d.activeShortcut = null;
      for (final s in e.track.shortcuts)
        if (s.id == a[31]) d.activeShortcut = s;
      d.shortcutStage = a[32];
      d.started = a[33];
      d.jumpVelocity = n(a[34]);
      e._remember(d);
      final p = e.networkPowers[d]!, b = m['power'][i];
      p.item = b[0] == null ? null : ItemType.values[b[0]];
      p.charges = b[1];
      p.enhanced = b[2];
    }
    e._loadNetworkPower(e.player);
    e.effects
      ..clear()
      ..addAll([
        for (final a in m['fx'])
          ImpactEffect(
              n(a[0]),
              n(a[1]),
              ImpactKind.values[a[2]],
              height: n(a[3]),
            )
            ..age = n(a[4])
            ..pose = a[5] == null ? null : rf(a[5]),
      ]);
    e.projectiles
      ..clear()
      ..addAll([
        for (final a in m['p'])
          Projectile(
              n(a[0]),
              n(a[1]),
              owner: driver(a[2]),
              target: driver(a[3]),
              speed: n(a[4]),
              kind: ItemType.values[a[5]],
              enhanced: a[6],
            )
            ..position = rv(a[7])
            ..direction = rv(a[8])
            ..life = n(a[9])
            ..dropSpeed = n(a[10])
            ..ballisticVelocity = a[11] == null ? null : rv(a[11])
            ..bounces = a[12]
            ..trail.addAll([for (final p in a[13]) rv(p)]),
      ]);
    e.oil
      ..clear()
      ..addAll([
        for (final a in m['oil'])
          OilPatch(n(a[0]), n(a[1]), owner: driver(a[2]))
            ..life = n(a[3])
            ..position = rv(a[4]),
      ]);
    e.mines
      ..clear()
      ..addAll([
        for (final a in m['mine'])
          Mine(rv(a[0]), driver(a[1])!)
            ..life = n(a[2])
            ..arm = n(a[3]),
      ]);
    e.clouds
      ..clear()
      ..addAll([
        for (final a in m['smoke'])
          SmokeCloud(rv(a[0]), driver(a[1])!)..life = n(a[2]),
      ]);
    e.spikeStrips
      ..clear()
      ..addAll([
        for (final a in m['spike'])
          SpikeStrip(rf(a[0]), driver(a[1])!, a[2])
            ..life = n(a[3])
            ..arm = n(a[4]),
      ]);
    e.beams
      ..clear()
      ..addAll([
        for (final a in m['beam'])
          ElectricBeam(rv(a[0]), rv(a[1]))..life = n(a[2]),
      ]);
    if (e is BattleEngine) {
      for (var i = 0; i < ds.length; i++) {
        final f = e.fighters[ds[i]]!, a = m['f'][i];
        f.health = n(a[0]);
        f.selected = a[1] == null ? null : BattlePower.values[a[1]];
        f.ammo
          ..clear()
          ..addEntries([
            for (final p in a[2])
              MapEntry(BattlePower.values[p[0]], p[1] as int),
          ]);
        f.kills = a[3];
        f.damageDealt = n(a[4]);
        f.target = driver(a[5]);
        f.turretDirection = a[6] == null ? null : rv(a[6]);
        f.recoil = n(a[7]);
        f.ripper = n(a[8]);
        f.turbo = n(a[9]);
        f.jammer = n(a[10]);
        f.doubled = n(a[11]);
        f.burn = n(a[12]);
        f.shock = n(a[13]);
        f.deathTime = a[14] == null ? double.infinity : n(a[14]);
        f.deadFor = n(a[15]);
      }
      e.shots
        ..clear()
        ..addAll([
          for (final a in m['shots'])
            BattleShot(
                BattlePower.values[a[0]],
                driver(a[1])!,
                rv(a[2]),
                rv(a[3]),
                n(a[4]),
                target: driver(a[5]),
                life: n(a[6]),
                gravity: n(a[8]),
                homing: n(a[9]),
                splash: n(a[10]),
              )
              ..age = n(a[7])
              ..bounces = a[11]
              ..trail.addAll([for (final p in a[12]) rv(p)]),
        ]);
      e.zones
        ..clear()
        ..addAll([
          for (final a in m['zones'])
            BattleZone(
              BattlePower.values[a[0]],
              driver(a[1])!,
              rv(a[2]),
              n(a[3]),
              n(a[4]),
              damage: n(a[6]),
              target: driver(a[7]),
            )..age = n(a[5]),
        ]);
      e.rays
        ..clear()
        ..addAll([
          for (final a in m['rays'])
            BattleRay(BattlePower.values[a[0]], rv(a[1]), rv(a[2]))
              ..life = n(a[3]),
        ]);
      for (var i = 0; i < e.pickups.length; i++) {
        e.pickups[i].power = BattlePower.values[m['pick'][i][0]];
        e.pickups[i].cooldown = n(m['pick'][i][1]);
      }
    }
  }
}
