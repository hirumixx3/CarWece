import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';

// v1.4 race powers: Salva Tripla, Dreno de Energia and Fantasma
// are original additions appended to ItemType (indices 13-16), so saved
// games, network item indices and the pickup bag keep their meaning.
void main() {
  final track = createTracks().first;

  RaceEngine race() =>
      RaceEngine(track: track, car: cars.first, mode: RaceMode.quick)
        ..countdown = 0;

  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) {
      e.update(1 / 120);
    }
  }

  test('The pickup roll can produce every power, including the new four', () {
    final e = race();
    final seen = <ItemType>{};
    for (var i = 0; i < 600 && seen.length < ItemType.values.length; i++) {
      seen.add(e.rollItem());
    }
    expect(seen, ItemType.values.toSet());
    expect(ItemType.values.length, 16);
  });

  test('Salva Tripla fires a fan of three rockets with two charges', () {
    final e = race();
    e.placeDriver(e.player, 100, 0);
    e.giveItem(ItemType.salvo);
    expect(e.itemCharges, 2);
    e.useItem();
    expect(e.projectiles.length, 3);
    expect(e.projectiles.every((p) => p.kind == ItemType.missile), isTrue);
    // The fan actually spreads: directions are not all identical.
    final dirs = e.projectiles.map((p) => p.direction!.x).toSet();
    expect(dirs.length, greaterThan(1));
    expect(e.item, ItemType.salvo);
    e.useItem();
    expect(e.projectiles.length, 6);
    expect(e.item, isNull);
  });

  test('Dreno slows the rival ahead and feeds the owner nitro', () {
    final e = race();
    final bot = e.bots.first;
    e.placeDriver(e.player, 100, 0);
    e.placeDriver(bot, 150, 0);
    bot.speed = 40;
    e.nitro = 10;
    e.giveItem(ItemType.dreno);
    e.useItem();
    expect(bot.electricTime, greaterThan(0));
    expect(e.nitro, 45);
    expect(e.item, isNull);
  });

  test('Dreno respects a shielded rival and gains nothing', () {
    final e = race();
    final bot = e.bots.first;
    e.placeDriver(e.player, 100, 0);
    e.placeDriver(bot, 150, 0);
    bot.shield = 5;
    e.nitro = 10;
    e.giveItem(ItemType.dreno);
    e.useItem();
    expect(bot.electricTime, 0);
    expect(e.nitro, 10);
  });

  test('Fantasma makes the driver intangible until the timer ends', () {
    final e = race();
    final bot = e.bots.first;
    e.placeDriver(bot, 100, 0);
    e.placeDriver(e.player, 150, 0);
    e.giveItem(ItemType.fantasma);
    e.useItem();
    expect(e.player.ghostTime, closeTo(4.5, .2));
    // A homing rocket fired by the bot cannot connect with a ghost.
    e.projectiles.add(
      Projectile(0, 0, owner: bot, target: e.player, speed: 160)
        ..position = bot.position!
        ..direction = bot.forward!,
    );
    advance(e, 1.2);
    expect(e.player.spinTime, 0);
    expect(e.player.stun, 0);
    expect(e.hitCount, 0);
    advance(e, 4);
    expect(e.player.ghostTime, 0);
  });
}
