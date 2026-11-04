import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';

ArenaSpec flatArena() {
  final t = TrackSpec(
    'arena_test',
    'LABORATÓRIO',
    'Teste físico',
    'TESTE',
    0xffffaa66,
    0xff666666,
    0xff333344,
    const [
      V3(-700, .16, -700),
      V3(700, .16, -700),
      V3(700, .16, 700),
      V3(-700, .16, 700),
    ],
    openArena: true,
  );
  t.obstacles.clear();
  t.ramps.clear();
  t.scenery.clear();
  return ArenaSpec(t, '', 0);
}

void place(Driver d, V3 p, {V3 forward = const V3(0, 0, 1)}) {
  d.position = p;
  d.forward = forward;
  d.normal = const V3(0, 1, 0);
  d.velocity = V3.zero;
  d.speed = 0;
  d.jump = 0;
  d.airborne = false;
}

void advance(BattleEngine e, double seconds) {
  for (var i = 0; i < (seconds * 120).round(); i++) e.update(1 / 120);
}

BattleEngine lab() {
  final e = BattleEngine(arena: flatArena(), car: cars.first, freeRoam: true)
    ..countdown = 0;
  place(e.player, const V3(0, .16, 0));
  for (var i = 0; i < e.bots.length; i++)
    place(e.bots[i], V3(500 + i * 50, .16, 550));
  place(e.bots.first, const V3(0, .16, 35));
  return e;
}

void equip(BattleEngine e, BattlePower p) {
  e.human.ammo[p] = 3;
  e.human.selected = p;
  e.human.fireDelay = 0;
  e.human.target = e.bots.first;
}

void main() {
  test(
    'Six open arenas are separate from all 26 race circuits and have nine independent loops',
    () {
      final arenas = createBattleArenas(),
          raceIds = createTracks().map((t) => t.id).toSet();
      expect(arenas.length, 11);
      expect(arenas.map((a) => a.track.room).toSet().length, 11);
      expect(arenas.take(6).map((a) => a.track.loops.length).toList(), [
        1,
        2,
        1,
        2,
        1,
        2,
      ]);
      for (final a in arenas) {
        expect(raceIds.contains(a.track.id), isFalse);
        expect(a.track.openArena, isTrue);
        expect(a.track.barriers, isEmpty);
        expect(a.track.shortcuts, isEmpty);
        expect(a.nav.length, greaterThan(130));
        expect(a.supplies.length, greaterThan(12));
        expect(a.health.length, 4);
        for (final p in a.spawns) {
          expect(a.clearFloor(p, 8), isTrue);
          expect(p.y, .16);
        }
        for (var i = 0; i < a.spawns.length; i++)
          for (var j = i + 1; j < a.spawns.length; j++)
            expect((a.spawns[i] - a.spawns[j]).length, greaterThan(25));
        for (final loop in a.track.loops) {
          expect(
            (a.track.at(loop.start).p - a.track.at(loop.end).p).length,
            greaterThan(75),
          );
          expect(a.track.at((loop.start + loop.end) * .5).up.y, lessThan(-.9));
        }
      }
    },
  );
  test(
    'All 44 adaptations have unique functional identities and positive cooldowns',
    () {
      expect(battleWeapons.length, 44);
      expect(BattlePower.values.length, 44);
      expect(battleWeapons.map((w) => w.power).toSet().length, 44);
      for (final p in BattlePower.values) {
        expect(battleWeapon(p).power, p);
        expect(battleWeapon(p).description, isNotEmpty);
        expect(battleWeapon(p).cooldown, greaterThan(0));
        expect(battleWeapon(p).ammo, greaterThan(0));
      }
    },
  );
  test(
    'Both arena modes start every car unarmed with no automatic fallback',
    () {
      for (final free in [false, true]) {
        final e = BattleEngine(
          arena: flatArena(),
          car: cars.first,
          freeRoam: free,
        )..countdown = 0;
        e.pickups.clear();
        for (final d in e.drivers) {
          expect(e.fighters[d]!.ammo, isEmpty);
          expect(e.fighters[d]!.selected, isNull);
          expect(e.fire(d), isFalse);
        }
        e.cycleWeapon();
        e.selectWeapon(BattlePower.quantumAnnihilator);
        e.useItem();
        e.triggerHeld = true;
        advance(e, 3);
        expect(e.human.shots, 0);
        expect(e.selectedWeapon, isNull);
        expect(e.selectedAmmo, 0);
        expect(e.drivers.every((d) => e.fighters[d]!.ammo.isEmpty), isTrue);
        expect(e.drivers.every((d) => e.fighters[d]!.shots == 0), isTrue);
      }
    },
  );
  test(
    'Every power including the machine gun is obtained from a map pickup and runs out',
    () {
      for (final power in BattlePower.values) {
        final e = lab();
        e.pickups
          ..clear()
          ..add(BattlePickup(e.player.position!, power));
        advance(e, .02);
        final count = battleWeapon(power).ammo;
        expect(e.human.selected, power);
        expect(e.selectedAmmo, count);
        expect(e.human.ammo.length, 1);
        expect(e.pickups.single.cooldown, greaterThan(11));
        for (var i = 0; i < count; i++) {
          e.human.fireDelay = 0;
          e.human.heat = 0;
          expect(e.fire(e.player), isTrue, reason: '$power shot $i');
        }
        e.human.fireDelay = 0;
        expect(e.fire(e.player), isFalse);
        expect(e.human.shots, count);
        expect(e.human.ammo, isEmpty);
        expect(e.human.selected, isNull);
        e.cycleWeapon();
        e.resetPlayer();
        expect(e.human.ammo, isEmpty);
      }
    },
  );
  test(
    'Only remaining collected ammo is selected when a weapon is exhausted',
    () {
      final e = lab();
      e.giveWeapon(e.player, BattlePower.energyShield, 1);
      e.giveWeapon(e.player, BattlePower.machineGun, 1);
      expect(e.fire(e.player), isTrue);
      expect(e.human.selected, BattlePower.energyShield);
      expect(e.human.ammo.containsKey(BattlePower.machineGun), isFalse);
      e.human.fireDelay = 0;
      expect(e.fire(e.player), isTrue);
      expect(e.human.selected, isNull);
      expect(e.human.armed, isFalse);
      expect(e.human.ammo, isEmpty);
    },
  );
  test(
    'Map loot cycles through all 44 powers with a finite three-weapon inventory',
    () {
      final e = lab(), seen = <BattlePower>{};
      final pickup = e.pickups.firstWhere((p) => !p.health);
      e.pickups
        ..clear()
        ..add(pickup);
      for (var i = 0; i < 88; i++) {
        pickup.cooldown = 0;
        final power = pickup.power;
        seen.add(power);
        place(e.player, pickup.position);
        advance(e, .02);
        expect(e.human.selected, power);
        expect(e.human.ammo.length, lessThanOrEqualTo(3));
        expect(e.human.ammo.values.every((n) => n > 0 && n <= 99), isTrue);
        expect(pickup.cooldown, greaterThan(11));
      }
      expect(seen, BattlePower.values.toSet());
    },
  );
  test(
    'Unarmed bots seek map supplies and receive ammo only on collecting them',
    () {
      final e = BattleEngine(arena: flatArena(), car: cars.first)
        ..countdown = 0;
      final bot = e.bots.first, f = e.fighters[e.bots.first]!;
      final p = BattlePickup(const V3(600, .16, 600), BattlePower.rocket);
      e.pickups
        ..clear()
        ..add(p);
      e.aiControls(bot);
      expect((f.goal! - p.position).length, lessThan(.01));
      expect(f.ammo, isEmpty);
      place(bot, p.position);
      advance(e, .02);
      expect(f.ammo[BattlePower.rocket], battleWeapon(BattlePower.rocket).ammo);
      expect(p.cooldown, greaterThan(11));
    },
  );
  test(
    'Player stays still without accelerator and can leave the road freely without checkpoints',
    () {
      final e = lab();
      place(e.player, const V3(250, .16, -300));
      final p = e.player.position!;
      advance(e, 2);
      expect((e.player.position! - p).length, lessThan(.01));
      e.accelerating = true;
      advance(e, 1.4);
      expect(e.player.speed, greaterThan(30));
      final forward = e.player.forward!;
      e.steering = 1;
      advance(e, .7);
      expect(e.player.forward!.dot(forward), lessThan(.9));
      expect(e.player.steeringAngle, greaterThan(0));
      expect(e.player.wheelAngles.any((a) => a.abs() > .1), isTrue);
      expect(e.player.completedLaps, 0);
      expect(e.player.nextCheckpoint, 1);
      expect(e.finished, isFalse);
    },
  );
  test(
    'Health is individual, shields block damage, repair restores health and removes statuses',
    () {
      final e = lab(), target = lab();
      e.applyDamage(e.player, 37, source: e.bots.first);
      expect(e.human.health, 63);
      expect(e.fighters[e.bots.first]!.health, 100);
      e.player.shield = 2;
      e.applyDamage(e.player, 100, source: e.bots.first);
      expect(e.human.health, 63);
      e.player.shield = 0;
      e.player.freezeTime = 5;
      e.player.electricTime = 3;
      e.human.burn = 3;
      equip(e, BattlePower.armorRepair);
      expect(e.fire(e.player), isTrue);
      expect(e.human.health, 100);
      expect(e.player.freezeTime, 0);
      expect(e.human.burn, 0);
      expect(target.human.health, 100);
    },
  );
  test(
    'Swept bullets hit a car before tunnelling and solid cover blocks ordinary shots and lasers',
    () {
      final e = lab();
      equip(e, BattlePower.machineGun);
      e.fire(e.player);
      advance(e, .25);
      expect(e.fighters[e.bots.first]!.health, lessThan(100));
      final b = lab();
      b.track.obstacles.add(const WorldObstacle(V3(0, 4, 17), V3(12, 8, 2)));
      equip(b, BattlePower.machineGun);
      b.fire(b.player);
      advance(b, .3);
      expect(b.fighters[b.bots.first]!.health, 100);
      equip(b, BattlePower.laserCannon);
      b.fire(b.player);
      expect(b.fighters[b.bots.first]!.health, 100);
      equip(b, BattlePower.deathRay);
      b.fire(b.player);
      expect(b.fighters[b.bots.first]!.health, lessThan(100));
    },
  );
  test(
    'Rocket, guided missile, disks, salvo and kinetic projectiles all cause visible damage',
    () {
      for (final power in [
        BattlePower.homingMissile,
        BattlePower.rocket,
        BattlePower.cannon,
        BattlePower.doomDisks,
        BattlePower.scatterMissiles,
        BattlePower.stampede,
        BattlePower.cowPuncher,
        BattlePower.buckshot,
        BattlePower.atomBlaster,
        BattlePower.tantrumGun,
      ]) {
        final e = lab();
        equip(e, power);
        expect(e.fire(e.player), isTrue, reason: power.name);
        expect(e.shots, isNotEmpty, reason: power.name);
        advance(e, 1.5);
        expect(
          e.fighters[e.bots.first]!.health,
          lessThan(100),
          reason: power.name,
        );
        expect(e.human.damageDealt, greaterThan(0), reason: power.name);
      }
    },
  );
  test(
    'Mortars use real ballistic gravity and freezing bombs apply temporary ice',
    () {
      for (final power in [
        BattlePower.mortar,
        BattlePower.craterMaker,
        BattlePower.turtleTurnover,
        BattlePower.freonBomb,
        BattlePower.oilDrum,
      ]) {
        final e = lab();
        place(e.bots.first, const V3(0, .16, 80));
        equip(e, power);
        e.fire(e.player);
        expect(e.shots.first.gravity, greaterThan(0));
        advance(e, 1.4);
        expect(
          e.fighters[e.bots.first]!.health,
          lessThan(100),
          reason: power.name,
        );
        if (power == BattlePower.freonBomb)
          expect(e.bots.first.freezeTime, greaterThan(0));
        if (power == BattlePower.oilDrum)
          expect(e.zones.any((z) => z.power == BattlePower.oilDrum), isTrue);
      }
    },
  );
  test(
    'Magnetic mine attaches then detonates; guided fire is disrupted by jammer or decoy',
    () {
      final e = lab();
      equip(e, BattlePower.magnetMine);
      e.fire(e.player);
      advance(e, .4);
      expect(e.shots.any((s) => s.attached == e.bots.first), isTrue);
      advance(e, 1);
      expect(e.fighters[e.bots.first]!.health, lessThan(100));
      final b = lab();
      b.fighters[b.bots.first]!.jammer = 5;
      equip(b, BattlePower.homingMissile);
      b.fire(b.player);
      expect(b.shots.single.target, isNull);
      final c = lab();
      equip(c, BattlePower.haloDecoy);
      c.fire(c.player);
      expect(c.zones.single.power, BattlePower.haloDecoy);
      expect(c.zones.single.life, greaterThan(0));
    },
  );
  test(
    'All three trap forms arm, consume ammo, detonate or attract and cannot remain forever',
    () {
      for (final power in [
        BattlePower.roadMine,
        BattlePower.bearHug,
        BattlePower.cactusPatch,
      ]) {
        final e = lab();
        place(
          e.bots.first,
          power == BattlePower.bearHug
              ? const V3(0, .16, -19)
              : const V3(0, .16, -8),
        );
        equip(e, power);
        e.fire(e.player);
        expect(e.zones, isNotEmpty);
        expect(e.human.ammo[power], 2);
        advance(e, 1.5);
        expect(
          e.fighters[e.bots.first]!.health,
          lessThan(100),
          reason: power.name,
        );
        e.zones.forEach((z) => z.life = .01);
        advance(e, .05);
        expect(e.zones, isEmpty);
      }
    },
  );
  test(
    'Sonic pulse, ground bass, grid, electrical attacks and orbital swarm have distinct effects',
    () {
      for (final power in [
        BattlePower.sonicBoom,
        BattlePower.bassQuake,
        BattlePower.gridlock,
        BattlePower.superZapper,
        BattlePower.whiteLightning,
        BattlePower.invasion,
        BattlePower.gammaSwarm,
        BattlePower.breathOfFire,
      ]) {
        final e = lab();
        place(e.bots.first, const V3(0, .16, 24));
        equip(e, power);
        e.fire(e.player);
        advance(e, 1.2);
        expect(
          e.fighters[e.bots.first]!.health,
          lessThan(100),
          reason: power.name,
        );
        expect(e.human.damageDealt, greaterThan(0), reason: power.name);
      }
      final e = lab();
      equip(e, BattlePower.discoInferno);
      e.fire(e.player);
      advance(e, .7);
      expect(e.zones.any((z) => z.power == BattlePower.discoInferno), isTrue);
      expect(e.shots.length, greaterThanOrEqualTo(8));
    },
  );
  test(
    'Toxic smoke affects health and visibility only inside its living volume',
    () {
      final e = lab();
      place(e.bots.first, const V3(0, .16, -12));
      equip(e, BattlePower.smogCheck);
      e.fire(e.player);
      advance(e, .6);
      expect(e.bots.first.smokeExposure, greaterThan(0));
      expect(e.fighters[e.bots.first]!.health, lessThan(100));
      place(e.bots.first, const V3(70, .16, 70));
      advance(e, .02);
      expect(e.bots.first.smokeExposure, 0);
      e.zones.single.life = .001;
      advance(e, .02);
      expect(e.zones, isEmpty);
    },
  );
  test(
    'Upgrade doubles standard damage, wheel blades hurt contacts and shield/boost buffs expire',
    () {
      final e = lab();
      equip(e, BattlePower.weaponUpgrade);
      e.fire(e.player);
      expect(e.human.doubled, 8);
      equip(e, BattlePower.machineGun);
      e.fire(e.player);
      advance(e, .2);
      expect(e.fighters[e.bots.first]!.health, closeTo(93.6, .1));
      final r = lab();
      place(r.bots.first, const V3(6, .16, 0));
      equip(r, BattlePower.ripperWheels);
      r.fire(r.player);
      advance(r, .6);
      expect(r.fighters[r.bots.first]!.health, lessThan(100));
      for (final power in [
        BattlePower.energyShield,
        BattlePower.jetBoosters,
        BattlePower.afterburner,
        BattlePower.radarJammer,
      ]) {
        final b = lab();
        equip(b, power);
        b.fire(b.player);
        expect(
          b.player.shield + b.human.turbo + b.human.jammer,
          greaterThan(0),
          reason: power.name,
        );
        b.human.turbo = 0;
        b.player.shield = 0;
        b.human.jammer = 0;
      }
    },
  );
  test(
    'Both high energy lasers deal damage immediately and generate beam geometry',
    () {
      for (final power in [
        BattlePower.laserCannon,
        BattlePower.quantumAnnihilator,
        BattlePower.alienLaser,
      ]) {
        final e = lab();
        equip(e, power);
        e.fire(e.player);
        expect(e.fighters[e.bots.first]!.health, lessThan(100));
        expect(e.rays.single.power, power);
      }
    },
  );
  test(
    'Kills are counted once, destroyed cars stop fighting and victory does not use race laps',
    () {
      final e = BattleEngine(arena: flatArena(), car: cars.first)
        ..countdown = 0;
      for (final bot in e.bots) e.applyDamage(bot, 500, source: e.player);
      expect(e.human.kills, 5);
      for (final bot in e.bots) e.applyDamage(bot, 500, source: e.player);
      expect(e.human.kills, 5);
      advance(e, 1.8);
      expect(e.finished, isTrue);
      expect(e.result!.position, 1);
      expect(e.reward, 1000);
      expect(e.result!.standings.length, 6);
      expect(e.player.completedLaps, 0);
      final loss = BattleEngine(arena: flatArena(), car: cars.first)
        ..countdown = 0;
      loss.applyDamage(loss.player, 200, source: loss.bots.first);
      advance(loss, 1.8);
      expect(loss.finished, isTrue);
      expect(loss.human.health, 0);
      expect(loss.result!.position, greaterThan(1));
    },
  );
  test(
    'Free exploration has passive rebuilding targets, no time limit or reward; pause freezes combat',
    () {
      final e = lab();
      expect(e.bots.length, 3);
      expect(e.human.ammo, isEmpty);
      e.applyDamage(e.bots.first, 200, source: e.player);
      advance(e, 2.2);
      expect(e.fighters[e.bots.first]!.health, 100);
      expect(e.finished, isFalse);
      expect(e.reward, 0);
      e.setPaused(true);
      final t = e.time, hp = e.human.health;
      e.triggerHeld = true;
      advance(e, 2);
      expect(e.time, t);
      expect(e.human.health, hp);
      expect(e.shots, isEmpty);
      e.setPaused(false);
      expect(e.triggerHeld, isFalse);
    },
  );
  test(
    'Every arena loop releases an inverted stationary car and battle frames fit native budgets',
    () {
      for (final a in createBattleArenas()) {
        final e = BattleEngine(arena: a, car: cars.first, freeRoam: true)
          ..countdown = 0;
        for (final loop in a.track.loops) {
          e.placeDriver(e.player, (loop.start + loop.end) / 2, 0);
          e.player.speed = 0;
          e.player.velocity = V3.zero;
          advance(e, .04);
          expect(e.player.airborne, isTrue, reason: a.track.id);
        }
        final frame = raceGpuFrame(e);
        expect(frame.every((n) => n.isFinite), isTrue);
        expect(frame[14], lessThanOrEqualTo(128));
        expect(BattleMesh.first, GpuResources.objects.length);
        expect(
          GpuResources.objectsFor([0]).length + BattleGpuMeshes.objects.length,
          lessThanOrEqualTo(1024),
        );
        for (var i = 0; i < frame[14].toInt(); i++)
          expect(frame[15 + i * 17], lessThan(BattleMesh.count));
      }
    },
  );
  test(
    'Navigation finds safe detours through cover and world projectiles use oriented collision bounds',
    () {
      final a = flatArena();
      a.track.obstacles.add(
        const WorldObstacle(V3(0, 10, 0), V3(100, 20, 180)),
      );
      final path = a.path(const V3(-160, .16, 0), const V3(160, .16, 0));
      expect(path.length, greaterThan(1));
      var last = const V3(-160, .16, 0);
      for (final p in path) {
        expect(a.lineClear(last, p, 5), isTrue);
        last = p;
      }
      final box = WorldObstacle(
        const V3(0, 4, 0),
        const V3(10, 8, 2),
        right: V3(math.cos(.5), 0, math.sin(.5)),
        forward: V3(-math.sin(.5), 0, math.cos(.5)),
      );
      expect(
        arenaBoxHit(box, const V3(0, 2, -10), const V3(0, 2, 10)),
        isNotNull,
      );
      expect(
        arenaBoxHit(box, const V3(0, 20, -10), const V3(0, 20, 10)),
        isNull,
      );
    },
  );
}
