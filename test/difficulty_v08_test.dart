import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';

void main() {
  final track = createTracks()[1];
  test(
    'Normal and hard select a competitive car class and keep the player unchanged',
    () {
      for (final car in [cars[7], cars.first, cars[10], cars.last]) {
        for (final mode in ['normal', 'hard']) {
          final race = RaceEngine(track: track, car: car, difficulty: mode);
          expect(race.bots.length, 5);
          expect(
            race.bots.every(
              (d) =>
                  d.car.speed >= car.speed * .92 &&
                  d.car.speed <= car.speed * 1.08,
            ),
            isTrue,
          );
          expect(race.player.skill, 1);
          expect(race.autoAccelerate, isFalse);
        }
      }
      final normal = RaceEngine(track: track, car: cars.first),
          hard = RaceEngine(track: track, car: cars.first, difficulty: 'hard');
      expect(hard.bots.first.skill, greaterThan(normal.bots.last.skill));
      expect(
        hard.opponentTuning.attackMin,
        lessThan(normal.opponentTuning.attackMin),
      );
    },
  );

  test(
    'Rival turbo uses finite energy and actual motion, with no boost on easy',
    () {
      for (final mode in ['easy', 'normal', 'hard']) {
        final race = RaceEngine(track: track, car: cars.first, difficulty: mode)
          ..countdown = 0;
        final d = race.bots.first;
        race.bots.removeWhere((other) => other != d);
        race.placeDriver(race.player, -100, 0);
        d.speed = 60;
        d.boostEnergy = 100;
        race.placeDriver(d, 180, 0);
        for (var i = 0; i < 120 * 8; i++) {
          final before = d.position!;
          race.update(1 / 120);
          expect((d.position! - before).length, lessThan(2));
          expect(d.boostEnergy, inInclusiveRange(0, 100));
        }
        expect(d.aiRecoveries, 0);
        if (mode == 'easy') {
          expect(d.boostSeconds, 0);
        } else {
          expect(d.boostSeconds, greaterThan(.1));
        }
      }
    },
  );

  test(
    'Difficulty never reduces the player acceleration, steering or wheel dynamics',
    () {
      final races = [
        for (final mode in ['easy', 'normal', 'hard'])
          RaceEngine(
              track: track,
              car: cars.first,
              difficulty: mode,
              mode: RaceMode.timeTrial,
            )
            ..countdown = 0
            ..accelerating = true
            ..steering = .12,
      ];
      for (var i = 0; i < 120 * 2; i++) {
        for (final race in races) race.update(1 / 120);
      }
      for (final race in races.skip(1)) {
        expect(
          (race.player.position! - races.first.player.position!).length,
          0,
        );
        expect(race.player.wheelAngles, races.first.player.wheelAngles);
        expect(race.player.speed, races.first.player.speed);
      }
    },
  );
}
