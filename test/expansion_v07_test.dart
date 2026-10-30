import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tracks = createTracks();
  final flat = TrackSpec(
    'qa',
    'QA',
    'QA',
    'GARAGEM',
    0xffff7700,
    0xff606870,
    0xff303840,
    const [
      V3(-400, .16, -400),
      V3(-400, .16, 400),
      V3(400, .16, 400),
      V3(400, .16, -400),
    ],
  );
  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) e.update(1 / 120);
  }

  RaceEngine open({int seed = 42}) {
    final e = RaceEngine(
      track: flat,
      car: cars.first,
      mode: RaceMode.timeTrial,
      seed: seed,
    )..countdown = 0;
    e.placeDriver(e.player, 0, 0);
    e.player.position = const V3(0, .16, 0);
    e.player.forward = const V3(0, 0, 1);
    e.player.normal = const V3(0, 1, 0);
    e.player.velocity = V3.zero;
    return e;
  }

  Driver target(RaceEngine e, {V3 p = const V3(0, .16, 20)}) {
    final d = Driver('ALVO', cars[1], .6, 20, 0);
    e.bots.add(d);
    e.placeDriver(d, 20, 0);
    d.position = p;
    d.forward = const V3(0, 0, 1);
    d.normal = const V3(0, 1, 0);
    d.velocity = V3.zero;
    return d;
  }

  List<int> meshes(RaceEngine e) {
    final p = raceGpuFrame(e);
    return [for (var i = 0; i < p[14]; i++) p[15 + i * 17].toInt()];
  }

  test(
    'Faster rivals leave a common line and physically overtake a slower leader',
    () {
      final e = RaceEngine(
        track: tracks[1],
        car: cars.first,
        difficulty: 'easy',
      )..countdown = 0;
      e.bots.clear();
      e.placeDriver(e.player, -100, 0);
      final lead = Driver('LENTO', cars.first, .55, 65, 0)..speed = 35,
          fast = Driver('RÁPIDO', cars.first, 1.0, 37, 0)..speed = 65,
          third = Driver('TERCEIRO', cars.first, .94, 13, 0)..speed = 50;
      e.bots.addAll([lead, fast, third]);
      for (final d in e.bots) e.placeDriver(d, d.distance, 0);
      var maxSpread = 0.0, passed = false;
      for (var i = 0; i < 120 * 8; i++) {
        e.update(1 / 120);
        final x = e.bots.map((d) => d.lane * e.track.width / 2).toList();
        maxSpread = math.max(
          maxSpread,
          x.reduce(math.max) - x.reduce(math.min),
        );
        passed = passed || fast.distance > lead.distance + 8;
      }
      expect(maxSpread, greaterThan(5));
      expect(passed, isTrue);
      expect(e.bots.every((d) => d.aiRecoveries == 0), isTrue);
    },
  );
  test(
    'Object boundary stops sustained outward steering with a matching rotated collider',
    () {
      final e = RaceEngine(
        track: tracks[1],
        car: cars.first,
        mode: RaceMode.timeTrial,
      )..countdown = 0;
      final b = tracks[1].barriers.first, f = b.frame;
      e.player.speed = 45;
      e.placeDriver(e.player, f.s, 0);
      e.player.position = f.p - f.right * 13;
      e.player.forward = f.right;
      e.player.normal = const V3(0, 1, 0);
      e.player.velocity = f.right * 45;
      e.accelerating = true;
      advance(e, .8);
      expect((e.player.position! - f.p).dot(f.right), lessThan(-4.5));
      expect(e.events, contains('bump'));
    },
  );
  test(
    'Missile destroys an actual blocking gate; ice and ramming leave it solid',
    () {
      final t = tracks[1], path = t.shortcuts.single, g = path.gate;
      RaceEngine setup() {
        final e = RaceEngine(
          track: t,
          car: cars.first,
          mode: RaceMode.timeTrial,
        )..countdown = 0;
        e.player.speed = 60;
        e.placeDriver(e.player, path.entryS, 0);
        e.player.position = g.p - g.forward * 18;
        e.player.forward = g.forward;
        e.player.normal = g.up;
        e.player.velocity = g.forward * 60;
        e.accelerating = true;
        return e;
      }

      final e = setup();
      advance(e, .5);
      expect(e.brokenGates, isEmpty);
      expect((e.player.position! - g.p).dot(g.forward), lessThan(-4));
      e.giveItem(ItemType.ice);
      e.useItem();
      advance(e, .3);
      expect(e.brokenGates, isEmpty);
      e.player.velocity = V3.zero;
      e.player.speed = 0;
      e.player.position = g.p - g.forward * 16;
      e.player.forward = g.forward;
      e.giveItem(ItemType.missile);
      e.useItem();
      advance(e, .25);
      expect(e.brokenGates, contains(path.id));
      expect(e.effects.any((f) => f.kind == ImpactKind.debris), isTrue);
      expect(meshes(e), isNot(contains(GpuMeshId.gate)));
      e.player.position = g.p - g.forward * 12;
      e.player.forward = g.forward;
      e.player.velocity = g.forward * 55;
      e.player.speed = 55;
      advance(e, .5);
      expect((e.player.position! - g.p).dot(g.forward), greaterThan(2));
      final fresh = setup();
      expect(fresh.brokenGates, isEmpty);
      expect(meshes(fresh), contains(GpuMeshId.gate));
    },
  );
  test(
    'All alternate routes validate their portals and rejoin the right main checkpoint',
    () {
      expect(
        tracks.expand((t) => t.shortcuts).length,
        greaterThanOrEqualTo(10),
      );
      for (final t in tracks)
        for (final path in t.shortcuts) {
          expect(path.length, lessThan((path.exitS - path.entryS) * .92));
          final e = RaceEngine(
            track: t,
            car: cars.first,
            mode: RaceMode.timeTrial,
          )..countdown = 0;
          e.breakGate(path.id);
          e.player.speed = 40;
          e.placeDriver(e.player, path.entryS - 15, 0);
          e.player.plannedShortcut = path;
          var entered = false, completed = false;
          for (var i = 0; i < 120 * 35; i++) {
            final c = e.aiControls(e.player);
            e.steering = c.$1;
            e.accelerating = c.$2;
            e.brake = c.$3;
            e.update(1 / 120);
            entered = entered || e.shortcut;
            if (entered &&
                !e.shortcut &&
                e.player.nextCheckpoint == path.exitCheckpoint + 1) {
              completed = true;
              break;
            }
          }
          expect(entered, isTrue, reason: t.id);
          expect(
            completed,
            isTrue,
            reason:
                '${t.id} stage=${e.player.shortcutStage} gate=${e.player.nextCheckpoint}',
          );
          expect(e.player.completedLaps, 0);
        }
    },
  );
  test(
    'Entering each closed shortcut, shooting inside and rejoining counts without returning to its entrance',
    () {
      for (final t in tracks)
        for (final path in t.shortcuts) {
          final e = RaceEngine(
            track: t,
            car: cars.first,
            mode: RaceMode.timeTrial,
          )..countdown = 0;
          e.player.speed = 40;
          e.placeDriver(e.player, path.entryS - 15, 0);
          e.player.plannedShortcut = path;
          var enteredClosed = false, fired = false, completed = false;
          for (var i = 0; i < 120 * 35; i++) {
            final c = e.aiControls(e.player);
            e.steering = c.$1;
            e.accelerating = c.$2;
            e.brake = c.$3;
            if (e.shortcut && !e.brokenGates.contains(path.id)) {
              enteredClosed = true;
              final remaining =
                  path.length * .50 - path.project(e.player.position!).frame.s;
              if (!fired && remaining < 35 && remaining > 10) {
                e.giveItem(ItemType.missile);
                e.useItem();
                fired = true;
              }
            }
            e.update(1 / 120);
            if (enteredClosed &&
                !e.shortcut &&
                e.player.nextCheckpoint == path.exitCheckpoint + 1) {
              completed = true;
              break;
            }
          }
          expect(enteredClosed, isTrue, reason: t.id);
          expect(fired, isTrue, reason: t.id);
          expect(e.brokenGates, contains(path.id), reason: t.id);
          expect(completed, isTrue, reason: t.id);
          expect(e.player.completedLaps, 0);
          expect(e.player.aiRecoveries, 0, reason: t.id);
        }
    },
  );
  test(
    'Jumping directly to an open shortcut exit never awards the skipped checkpoints',
    () {
      final t = tracks.first, path = t.shortcuts.single;
      final e = RaceEngine(track: t, car: cars.first, mode: RaceMode.timeTrial)
        ..countdown = 0;
      e.breakGate(path.id);
      e.placeDriver(e.player, path.entryS + 1, 0);
      e.player.position = path.frames.last.p - path.frames.last.forward * 3;
      e.player.forward = path.frames.last.forward;
      e.player.velocity = e.player.forward! * 60;
      e.player.speed = 60;
      advance(e, .15);
      expect(e.player.nextCheckpoint, path.entryCheckpoint + 1);
      expect(e.player.completedLaps, 0);
      expect(e.shortcut, isFalse);
    },
  );
  test(
    'Full power shuffle bag covers every type and avoids immediate repeats across refills',
    () {
      final n = ItemType.values.length;
      final e = open(), items = [for (var i = 0; i < n * 10; i++) e.rollItem()];
      for (var i = 0; i < n * 10; i += n)
        expect(items.sublist(i, i + n).toSet(), ItemType.values.toSet());
      for (var i = 1; i < items.length; i++)
        expect(items[i], isNot(items[i - 1]));
      final other = open(seed: 973),
          sequence = [for (var i = 0; i < n; i++) other.rollItem()];
      expect(sequence, isNot(items.take(n).toList()));
    },
  );
  test(
    'Three rocket charges fire separately and supercharge requires the full power bar',
    () {
      final e = open();
      e.giveItem(ItemType.missile);
      expect(e.itemCharges, 3);
      e.nitro = 99;
      expect(e.superchargeItem(), isFalse);
      e.nitro = 100;
      expect(e.superchargeItem(), isTrue);
      expect(e.nitro, 0);
      for (var i = 0; i < 3; i++) {
        e.useItem();
        expect(e.projectiles.length, i + 1);
      }
      expect(e.item, isNull);
      expect(e.projectiles.every((p) => p.enhanced), isTrue);
    },
  );
  test('EMP clears nearby ordnance and blocks weapons temporarily', () {
    final e = open(), d = target(e);
    e.projectiles.add(Projectile(0, 0)..position = const V3(0, 2, 12));
    e.mines.add(Mine(const V3(4, .5, 0), d));
    e.giveItem(ItemType.emp);
    e.useItem();
    expect(e.projectiles, isEmpty);
    expect(e.mines, isEmpty);
    expect(d.weaponLock, greaterThan(2));
    expect(meshes(e), contains(GpuMeshId.pulse));
    e.player.weaponLock = 1;
    e.giveItem(ItemType.missile);
    e.useItem();
    expect(e.itemCharges, 3);
    expect(e.projectiles, isEmpty);
    advance(e, 1.1);
    e.useItem();
    expect(e.projectiles, isNotEmpty);
  });
  test(
    'Ice shot freezes its target, renders a shell and thaws without clearing held controls',
    () {
      final e = open(), d = target(e);
      e.giveItem(ItemType.ice, enhanced: true);
      e.useItem();
      advance(e, .25);
      expect(d.freezeTime, greaterThan(3));
      expect(meshes(e), contains(GpuMeshId.frost));
      e.accelerating = true;
      e.steering = .7;
      advance(e, 4.2);
      expect(d.freezeTime, 0);
      expect(e.accelerating, isTrue);
      expect(e.steering, .7);
    },
  );
  test(
    'Tesla has a visible beam and temporary motor failure; shield intercepts it',
    () {
      final e = open(), d = target(e);
      e.giveItem(ItemType.tesla);
      e.useItem();
      expect(e.beams, isNotEmpty);
      expect(d.electricTime, greaterThan(1));
      expect(meshes(e), contains(GpuMeshId.beam));
      advance(e, 2);
      expect(d.electricTime, 0);
      expect(e.beams, isEmpty);
      d.position = e.player.position! + e.player.forward! * 20;
      d.shield = 6;
      e.giveItem(ItemType.tesla);
      e.useItem();
      expect(d.electricTime, 0);
      expect(d.shield, lessThan(6));
    },
  );
  test(
    'Armed mines detonate visibly, and smoke only blinds cars inside its cloud',
    () {
      final e = open(), d = target(e, p: const V3(0, .16, -7));
      e.mines.add(Mine(d.position!, e.player)..arm = 0);
      advance(e, .02);
      expect(e.mines, isEmpty);
      expect(d.damage, greaterThan(0));
      expect(e.effects.any((f) => f.kind == ImpactKind.explosion), isTrue);
      e.giveItem(ItemType.smoke);
      e.useItem();
      advance(e, .1);
      expect(e.clouds, isNotEmpty);
      expect(d.smokeExposure, greaterThan(0));
      d.position = const V3(80, .16, 0);
      advance(e, 1 / 120);
      expect(d.smokeExposure, 0);
    },
  );
  test(
    'Trackside props and barriers add detail without blocking alternate routes',
    () {
      for (final t in tracks) {
        expect(t.barriers.length, greaterThan(240));
        expect(t.details.length, greaterThan(20));
        for (final path in t.shortcuts)
          for (var s = path.length * .18; s < path.length * .82; s += 10) {
            final p = path.at(s).p;
            for (final o in t.obstacles)
              if (o.center.y - o.size.y / 2 < 5)
                expect(
                  (p.x - o.center.x).abs() > o.size.x / 2 + 8 ||
                      (p.z - o.center.z).abs() > o.size.z / 2 + 8,
                  isTrue,
                  reason: t.id,
                );
          }
      }
    },
  );
  setUpAll(() async {
    for (final pair in [
      ['RushDisplay', 'Display.ttf'],
      ['RushBody', 'Body.ttf'],
    ])
      await (FontLoader(
        pair[0],
      )..addFont(rootBundle.load('assets/fonts/${pair[1]}'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [const Size(1280, 720), const Size(800, 360)])
    testWidgets(
      'Power charging HUD keeps the pedal and steering independent at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()..ready = true;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(GameStore.channel, (call) async => true);
        final e = open()..giveItem(ItemType.mine);
        await tester.pumpWidget(
          MaterialApp(
            home: RaceScreen(
              race: e,
              store: store,
              onFinish: (_) {},
              onExit: () {},
            ),
          ),
        );
        await tester.pump();
        final gas = find.byWidgetPredicate(
          (w) => w is HoldControl && w.label == 'ACELERAR',
        );
        final touch = await tester.startGesture(tester.getCenter(gas));
        await tester.pump();
        expect(e.accelerating, isTrue);
        await tester.tap(find.text('SUPER 100%'));
        await tester.pump();
        expect(e.itemEnhanced, isTrue);
        expect(e.itemCharges, 3);
        expect(e.accelerating, isTrue);
        await touch.up();
        await tester.pump();
        expect(e.accelerating, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.save();
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
}
