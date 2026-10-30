import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/platform.dart';
import 'battle_test.dart' show flatArena;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GameStore.channel, (_) async => true);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GameStore.channel, null);
  });
  test(
    'Every race difficulty pays exactly the podium, without hit bonuses',
    () async {
      final t = createTracks().first;
      for (final difficulty in ['easy', 'normal', 'hard'])
        for (var rank = 1; rank <= 6; rank++) {
          final e =
              RaceEngine(track: t, car: cars.first, difficulty: difficulty)
                ..countdown = 0
                ..time = 25
                ..hitCount = 19;
          final order = [...e.bots]..insert(rank - 1, e.player);
          for (var i = 0; i < order.length; i++)
            order[i].finishTime = 20 + i * .2;
          e.update(1 / 120);
          final expected = rank == 1
              ? 1000
              : rank == 2
              ? 500
              : rank == 3
              ? 250
              : 0;
          expect(e.result!.position, rank);
          expect(e.result!.coins, expected);
          final store = GameStore()..ready = true;
          store.record(t, e.result!, RaceMode.quick);
          expect(store.coins, expected);
          await store.save();
          store.dispose();
        }
    },
  );
  test(
    'Battle podium payouts match results and are recorded only once',
    () async {
      for (var rank = 1; rank <= 6; rank++) {
        final e = BattleEngine(arena: flatArena(), car: cars.first)
          ..countdown = 0
          ..time = 20;
        expect(e.reward, 0);
        final kills = 6 - rank;
        for (var i = 0; i < kills; i++) {
          e.applyDamage(e.bots[i], 500, source: e.player);
          e.time += .01;
        }
        if (rank > 1) e.applyDamage(e.player, 500, source: e.bots.last);
        for (var i = 0; i < 220; i++) e.update(1 / 120);
        final expected = rank == 1
            ? 1000
            : rank == 2
            ? 500
            : rank == 3
            ? 250
            : 0;
        expect(e.result!.position, rank);
        expect(e.result!.coins, expected);
        expect(e.reward, expected);
        final store = GameStore()..ready = true;
        store.recordBattle(e);
        store.recordBattle(e);
        expect(store.coins, expected);
        expect(store.battles, 1);
        await store.save();
        store.dispose();
      }
    },
  );
  test(
    'Battle settings persist independently and tiers change real weapon damage',
    () {
      final settings = GameSettings()
        ..difficulty = 'hard'
        ..battleDifficulty = 'easy';
      final restored = GameSettings()..restore(settings.toJson());
      expect(restored.difficulty, 'hard');
      expect(restored.battleDifficulty, 'easy');
      final damage = <double>[];
      for (final level in ['easy', 'normal', 'hard']) {
        final e = BattleEngine(
          arena: flatArena(),
          car: cars.first,
          difficulty: level,
        )..countdown = 0;
        final bot = e.bots.first;
        e.giveWeapon(bot, BattlePower.rocket);
        e.fire(bot);
        expect(e.shots, isNotEmpty);
        damage.add(e.shots.first.damage);
        expect(bot.skill, lessThan(e.player.skill + .01));
      }
      expect(damage[0], lessThan(damage[1]));
      expect(damage[1], lessThan(damage[2]));
      expect(damage[2], lessThan(battleWeapon(BattlePower.rocket).damage));
    },
  );
}
