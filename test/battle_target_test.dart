import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';
import 'battle_test.dart' show flatArena, place;

void main() {
  BattleEngine arena() {
    final b = BattleEngine(arena: flatArena(), car: cars.first, freeRoam: true)
      ..countdown = 0;
    place(b.player, V3.zero, forward: const V3(0, 0, 1));
    place(b.bots[0], const V3(0, 0, 40));
    place(b.bots[1], const V3(15, 0, 60));
    place(b.bots[2], const V3(-15, 0, 80));
    return b;
  }

  test(
    'Mira alterna entre rivais válidos e não seleciona morto, bloqueado ou distante',
    () {
      final b = arena();
      b.cycleTarget();
      expect(b.selectedTarget, b.bots[0]);
      b.cycleTarget();
      expect(b.selectedTarget, b.bots[1]);
      b.cycleTarget();
      expect(b.selectedTarget, b.bots[2]);
      b.cycleTarget();
      expect(b.selectedTarget, b.bots[0]);
      b.fighters[b.bots[1]]!.jammer = 5;
      b.fighters[b.bots[2]]!.health = 0;
      b.cycleTarget();
      expect(b.selectedTarget, b.bots[0]);
      place(b.bots[0], const V3(0, 0, 500));
      b.cycleTarget();
      expect(b.selectedTarget, isNull);
      expect(b.human.manualTarget, isFalse);
      expect(b.selectTarget(b.player), isFalse);
      expect(b.selectTarget(b.bots[1]), isFalse);
    },
  );
  test('A mira verde acompanha o alvo que a arma usa, sem alterar munição', () {
    final b = arena();
    b.giveWeapon(b.player, BattlePower.homingMissile, 3);
    b.selectTarget(b.bots[1]);
    final packet = raceGpuFrame(b);
    final ids = [
      for (var i = 0; i < packet[14]; i++) packet[15 + i * 17].toInt(),
    ];
    expect(ids.where((n) => n == BattleMesh.targetReticle).length, 1);
    final reticle = BattleGpuMeshes.objects.last;
    // Each vertex uses the requested green and emissive material.
    expect(reticle.every((n) => n.isFinite), isTrue);
    expect(reticle[7], closeTo(1, .001));
    b.fire(b.player);
    expect(b.shots.single.target, b.bots[1]);
    expect(b.selectedAmmo, 2);
    b.fighters[b.bots[1]]!.health = 0;
    expect(b.selectedTarget, isNull);
  });
}
