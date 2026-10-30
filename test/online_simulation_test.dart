import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/online/client.dart';
import 'package:carwece/platform.dart';

void main() {
  final tracks = createTracks(), arenas = createBattleArenas();
  final people = [
    for (var i = 0; i < 6; i++) NetworkParticipant('Piloto_$i', i),
  ];
  test('six online drivers require their own gas and steering, with no AI', () {
    final e = RaceEngine(track: tracks.first, car: cars.first)
      ..configureNetwork(people)
      ..countdown = 0;
    final before = e.drivers.map((d) => d.position!).toList();
    for (var i = 0; i < 120; i++) e.update(1 / 120);
    for (var i = 0; i < 6; i++)
      expect((e.networkDrivers[i].position! - before[i]).length, lessThan(.05));
    final controlled = e.networkDrivers.first;
    e.networkInputs[controlled] = const NetworkInput(
      gas: true,
      steer: .3,
      boost: true,
      drift: true,
    );
    for (var i = 0; i < 100; i++) e.update(1 / 120);
    expect((controlled.position! - before.first).length, greaterThan(1));
    expect(controlled.steeringAngle, greaterThan(0));
    for (final d in e.networkDrivers.skip(1))
      expect(d.speed.abs(), lessThan(.1));
  });
  test(
    'race inventories, missile owner and turbo are independent for every peer',
    () {
      final e = RaceEngine(track: tracks.first, car: cars.first)
        ..configureNetwork(people)
        ..countdown = 0;
      final second = e.networkDrivers[1];
      e.asNetworkDriver(second, () => e.giveItem(ItemType.missile));
      expect(e.item, isNull);
      expect(e.networkPowers[second]!.charges, 3);
      e.networkCommand(second, 'fire');
      expect(e.projectiles.single.owner, same(second));
      expect(e.networkPowers[second]!.charges, 2);
      expect(e.networkPowers[e.player]!.charges, 0);
      e.networkCommand(e.player, 'fire');
      expect(e.projectiles.length, 1);
      e.networkInputs[second] = const NetworkInput(gas: true, boost: true);
      second.speed = 50;
      second.velocity = second.forward! * 50;
      for (var i = 0; i < 24; i++) e.update(1 / 120);
      expect(second.boostEnergy, lessThan(100));
      expect(e.player.boostEnergy, 100);
    },
  );
  test(
    'battle snapshot preserves all 44 weapons, finite ammo and the selected local driver',
    () {
      final e = BattleEngine(arena: arenas.first, car: cars.first)
        ..configureNetwork(people)
        ..countdown = 0;
      final view = BattleEngine(arena: arenas.first, car: cars[4])
        ..configureNetwork(people, local: 4);
      expect(e.fighters.values.every((f) => f.ammo.isEmpty), isTrue);
      for (final power in BattlePower.values) {
        e.giveWeapon(e.networkDrivers[4], power, 7);
        e.fighters[e.networkDrivers[4]]!.turretDirection = const V3(
          .4,
          .1,
          .9,
        ).unit;
        final packet =
            jsonDecode(jsonEncode(NetworkSnapshot.capture(e)))
                as Map<String, dynamic>;
        NetworkSnapshot.apply(view, packet);
        expect(view.player.name, 'Piloto_4');
        expect(view.human.ammo[power], 7);
        expect(view.human.selected, power);
        expect(view.human.ammo.length, lessThanOrEqualTo(3));
        expect(
          view.human.turretDirection!.x,
          closeTo(e.fighters[e.networkDrivers[4]]!.turretDirection!.x, .001),
        );
      }
      e.networkCommand(e.networkDrivers[4], 'fire');
      expect(
        e.fighters[e.networkDrivers[4]]!.ammo[BattlePower.weaponUpgrade],
        6,
      );
    },
  );
  test(
    'race snapshots preserve smoke, explosions, projectiles, wheels and gates',
    () {
      final e = RaceEngine(track: tracks.first, car: cars.first)
        ..configureNetwork(people)
        ..countdown = 0;
      final view = RaceEngine(track: tracks.first, car: cars[3])
        ..configureNetwork(people, local: 3);
      e.asNetworkDriver(
        e.networkDrivers[2],
        () => e.giveItem(ItemType.missile),
      );
      e.networkCommand(e.networkDrivers[2], 'fire');
      e.clouds.add(SmokeCloud(e.player.position!, e.player)..life = 1.2);
      e.effects.add(
        ImpactEffect(2, .1, ImpactKind.explosion)
          ..age = .4
          ..pose = e.driverFrame(e.player),
      );
      e.player.wheelAngles[0] = 1.23;
      e.player.steeringAngle = .2;
      e.brokenGates.add('gate-test');
      NetworkSnapshot.apply(
        view,
        jsonDecode(jsonEncode(NetworkSnapshot.capture(e))),
      );
      expect(view.clouds.single.life, 1.2);
      expect(view.effects.single.kind, ImpactKind.explosion);
      expect(view.projectiles.single.owner!.name, 'Piloto_2');
      expect(view.networkDrivers[0].wheelAngles.first, 1.23);
      expect(view.networkDrivers[0].steeringAngle, .2);
      expect(view.brokenGates, contains('gate-test'));
    },
  );
  test(
    'online finish waits for the room, and client actions cannot create local damage',
    () {
      final e = RaceEngine(track: tracks.first, car: cars.first)
        ..configureNetwork(people)
        ..countdown = 0;
      e.player.finishTime = 10;
      e.update(1 / 120);
      expect(e.finished, isFalse);
      final commands = <String>[];
      e.remoteAction = commands.add;
      e.item = ItemType.missile;
      e.itemCharges = 3;
      e.useItem();
      e.resetPlayer();
      e.superchargeItem();
      expect(commands, ['fire', 'reset', 'super']);
      expect(e.itemCharges, 3);
      expect(e.projectiles, isEmpty);
      final input = NetworkInput.read({
        's': double.nan,
        'g': true,
        'f': true,
        'position': [999, 999, 999],
      });
      expect(input.steer, 0);
      expect(input.gas, isTrue);
      expect(NetworkInput.read({'s': 99}).steer, 1);
    },
  );
  test(
    'public accounts require HTTPS; cleartext is restricted to private LAN addresses',
    () {
      for (final u in [
        'https://game.example.org',
        'http://127.0.0.1:8080',
        'http://192.168.1.4:8080',
        'http://10.0.0.1:8080',
        'http://172.31.9.9:8080',
      ])
        expect(onlineEndpoint(u).host, isNotEmpty);
      for (final u in [
        'http://game.example.org',
        'http://8.8.8.8',
        'http://172.32.0.1',
        'https://user:password@game.example.org',
        'https://game.example.org?token=secret',
        'ws://example.org',
      ])
        expect(() => onlineEndpoint(u), throwsFormatException);
      final s = GameSettings()
        ..onlineEndpoint = 'https://game.example.org'
        ..onlineUsername = 'Marcos';
      final restored = GameSettings()..restore(s.toJson());
      expect(restored.onlineUsername, 'Marcos');
      expect(restored.onlineEndpoint, s.onlineEndpoint);
      expect(
        s.toJson().keys.any(
          (k) =>
              k.toLowerCase().contains('password') ||
              k.toLowerCase().contains('token'),
        ),
        isFalse,
      );
    },
  );
  test(
    'online slipstream, track pads and enhanced shields work for non-hosts',
    () {
      RaceEngine create() => RaceEngine(track: tracks.first, car: cars.first)
        ..configureNetwork(people.take(2).toList())
        ..countdown = 0;
      final draft = create();
      for (var i = 0; i < 2; i++) {
        final d = draft.networkDrivers[i];
        draft.placeDriver(d, 120 - i * 20, 0);
        d.speed = 40;
        d.velocity = d.forward! * 40;
        d.boostEnergy = 50;
      }
      draft.nitro = 50;
      draft.update(1 / 120);
      expect(
        draft.networkDrivers[1].boostEnergy,
        greaterThan(draft.networkDrivers[0].boostEnergy),
      );
      final pad = create();
      final s = [.145, .345, .735]
          .map((f) => f * pad.track.length)
          .firstWhere((s) => pad.track.at(s).up.y > .95);
      for (var i = 0; i < 2; i++) {
        final d = pad.networkDrivers[i];
        pad.placeDriver(d, s, i == 0 ? -.3 : .3);
        d.speed = 30;
        d.velocity = d.forward! * 30;
        d.boostEnergy = 20;
      }
      pad.nitro = 20;
      pad.update(1 / 120);
      for (final d in pad.networkDrivers)
        expect(d.boostEnergy, greaterThan(37));
      final shield = create(), defender = shield.networkDrivers[1];
      shield.placeDriver(shield.player, 100, 0);
      shield.placeDriver(defender, 120, 0);
      defender.shield = 8;
      defender.shieldEnhanced = true;
      shield.asNetworkDriver(
        shield.player,
        () => shield.giveItem(ItemType.missile),
      );
      shield.networkCommand(shield.player, 'fire');
      for (var i = 0; i < 120; i++) shield.update(1 / 120);
      expect(shield.networkPowers[defender]!.item, ItemType.missile);
      expect(shield.networkPowers[defender]!.charges, 3);
      expect(shield.player, shield.networkDrivers[0]);
    },
  );
}
