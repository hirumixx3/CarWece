import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';
import 'battle_test.dart' show flatArena, place, advance;

void main() {
  test(
    'Every collectible has a distinct finite metal attachment within the native budget',
    () {
      final fingerprints = <int>{};
      for (final power in BattlePower.values) {
        final mesh = buildBattleWeapon(power).buffer;
        expect(mesh.length % 36, 0);
        expect(mesh.length, greaterThan(1000));
        expect(mesh.every((n) => n.isFinite), isTrue);
        fingerprints.add(Object.hashAll(mesh));
        expect(BattleMesh.weapon(power), 129 + power.index);
      }
      expect(fingerprints.length, 44);
      expect(BattleMesh.count, 174);
      expect(BattleGpuMeshes.objects.length, 60);
      expect(
        BattleGpuMeshes.objects.fold<int>(0, (n, m) => n + m.length * 4),
        lessThan(10 * 1024 * 1024),
      );
    },
  );
  test(
    'Only collected weapons are mounted and every selected item uses its own model',
    () {
      final e = BattleEngine(
        arena: flatArena(),
        car: cars.first,
        freeRoam: true,
      )..countdown = 0;
      List<int> ids() {
        final f = raceGpuFrame(e);
        return [for (var i = 0; i < f[14]; i++) f[15 + i * 17].toInt()];
      }

      expect(
        ids().any((n) => n >= 129 && n < BattleMesh.targetReticle),
        isFalse,
      );
      for (final power in BattlePower.values) {
        e.human.ammo.clear();
        e.human.selected = null;
        e.giveWeapon(e.player, power);
        expect(
          ids().where((n) => n >= 129 && n < BattleMesh.targetReticle).toList(),
          [BattleMesh.weapon(power)],
        );
        expect(ids().contains(BattleMesh.turret), isFalse);
      }
      e.giveWeapon(e.player, BattlePower.cannon);
      e.giveWeapon(e.player, BattlePower.energyShield);
      expect(
        ids().where((n) => n >= 129 && n < BattleMesh.targetReticle).length,
        3,
      );
    },
  );
  test(
    'Turret follows a moving target between shots and the muzzle matches projectile direction',
    () {
      final e = BattleEngine(
        arena: flatArena(),
        car: cars.first,
        freeRoam: true,
      )..countdown = 0;
      place(e.player, const V3(0, .16, 0));
      for (var i = 0; i < e.bots.length; i++)
        place(e.bots[i], V3(500 + i * 50, .16, 550));
      final target = e.bots.first;
      place(target, const V3(35, .16, 65));
      e.giveWeapon(e.player, BattlePower.cannon);
      e.human.target = target;
      e.human.manualTarget = true;
      advance(e, .5);
      final first = e.human.turretDirection!;
      place(target, const V3(-45, .16, 60));
      advance(e, .5);
      final direction = e.human.turretDirection!;
      expect(first.x, greaterThan(.3));
      expect(direction.x, lessThan(-.4));
      expect(e.human.shots, 0);
      final expected =
          (target.position! + const V3(0, 1.5, 0) - e.weaponMuzzle(e.player))
              .unit;
      expect(direction.dot(expected), greaterThan(.997));
      final muzzle = e.weaponMuzzle(e.player);
      expect(e.fire(e.player), isTrue);
      expect((e.shots.single.position - muzzle).length, lessThan(.001));
      expect(e.shots.single.velocity.unit.dot(direction), greaterThan(.999));
      expect(e.human.ammo[BattlePower.cannon], 9);
      expect(e.player.forward!.dot(const V3(0, 0, 1)), closeTo(1, .00001));
    },
  );
  test(
    'Manual target behind the car rotates the mount while the chassis stays manual',
    () {
      final e = BattleEngine(
        arena: flatArena(),
        car: cars.first,
        freeRoam: true,
      )..countdown = 0;
      place(e.player, const V3(0, .16, 0));
      place(e.bots.first, const V3(10, .16, -70));
      e.giveWeapon(e.player, BattlePower.laserCannon);
      e.human.target = e.bots.first;
      e.human.manualTarget = true;
      advance(e, .9);
      expect(e.human.turretDirection!.z, lessThan(-.95));
      expect(e.human.turretDirection!.length, closeTo(1, .00001));
      expect(e.player.speed, 0);
      expect(e.player.forward!.z, 1);
      final f = raceGpuFrame(e);
      expect(f.every((v) => v.isFinite), isTrue);
      expect(
        math.acos(e.human.turretDirection!.z.clamp(-1, 1)),
        greaterThan(2.9),
      );
    },
  );
}
