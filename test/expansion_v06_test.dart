import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/main.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';
import 'package:carwece/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final pair in [
      ['RushDisplay', 'Display.ttf'],
      ['RushBody', 'Body.ttf'],
    ]) {
      await (FontLoader(
        pair[0],
      )..addFont(rootBundle.load('assets/fonts/${pair[1]}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final tracks = createTracks();
  RaceEngine isolated([TrackSpec? track]) => RaceEngine(
    track: track ?? tracks.first,
    car: cars.first,
    mode: RaceMode.timeTrial,
  )..countdown = 0;
  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) {
      e.update(1 / 120);
    }
  }

  RaceResult result(int position) => RaceResult(position, 180, 60, 220, 0, 0);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          GameStore.channel,
          (call) async => call.method == 'save' ? true : null,
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GameStore.channel, null),
  );

  test(
    'Stopped inverted car loses support, falls and lands without progress or teleport',
    () {
      final e = isolated(),
          top = tracks.first.frames.firstWhere((f) => f.up.y < -.999);
      e.placeDriver(e.player, top.s, 0);
      final p = e.player.position!, gate = e.player.nextCheckpoint;
      expect(e.contactForce(e.player, top), lessThan(-20));
      advance(e, .1);
      expect(e.player.airborne, isTrue);
      expect(e.player.position!.y, lessThan(p.y));
      expect((e.player.position! - p).length, lessThan(1));
      expect(e.player.nextCheckpoint, gate);
      advance(e, 4);
      expect(e.player.airborne, isFalse);
      expect(e.player.position!.y, inInclusiveRange(.15, 10));
      expect(e.player.completedLaps, 0);
      expect(e.effects.every((f) => f.progress.isFinite), isTrue);
      expect(raceGpuFrame(e).every((v) => v.isFinite), isTrue);
    },
  );
  test('Fast loop tires retain positive support while slow ones detach', () {
    final e = isolated(),
        top = tracks.first.frames.firstWhere((f) => f.up.y < -.999);
    e.player.speed = 85;
    e.placeDriver(e.player, top.s, 0);
    expect(e.contactForce(e.player, top), greaterThan(60));
    e.accelerating = true;
    advance(e, .2);
    expect(e.player.airborne, isFalse);
    expect(
      (e.player.position! - tracks.first.project(e.player.position!).frame.p)
          .length,
      lessThan(.1),
    );
  });
  test('No traction or steering changes ballistic momentum during a fall', () {
    final a = isolated(),
        b = isolated(),
        top = tracks.first.frames.firstWhere((f) => f.up.y < -.999);
    a.placeDriver(a.player, top.s, 0);
    b.placeDriver(b.player, top.s, 0);
    b.accelerating = true;
    b.steering = 1;
    b.brake = true;
    advance(a, .6);
    advance(b, .6);
    expect((a.player.position! - b.player.position!).length, lessThan(.00001));
    expect((a.player.velocity - b.player.velocity).length, lessThan(.00001));
    expect(b.player.wheelSpeeds.any((v) => v.abs() > 1), isTrue);
  });
  test(
    'A descending rocket detonates at ground contact and submits fire and shock ring',
    () {
      final e = isolated();
      e.projectiles.add(
        Projectile(0, 0)
          ..position = const V3(0, 10, -500)
          ..direction = const V3(0, -1, 0),
      );
      advance(e, .12);
      expect(e.projectiles, isEmpty);
      final blast = e.effects.firstWhere((f) => f.kind == ImpactKind.explosion);
      expect(blast.pose!.p.y, closeTo(TrackSpec.floorHeight + .3, .01));
      expect(e.events, contains('explosion'));
      final frame = raceGpuFrame(e),
          ids = [
            for (var i = 0; i < frame[14]; i++) frame[15 + i * 17].toInt(),
          ];
      expect(
        ids,
        containsAll([
          GpuMeshId.explosion,
          GpuMeshId.shockwave,
          GpuMeshId.smoke,
          GpuMeshId.sparks,
        ]),
      );
    },
  );
  test(
    'An untargeted rocket has gravity and explodes instead of vanishing',
    () {
      final e = isolated();
      e.projectiles.add(
        Projectile(0, 0)
          ..position = const V3(0, 2, -500)
          ..direction = const V3(0, 0, 1),
      );
      advance(e, 1.0);
      expect(e.projectiles, isEmpty);
      expect(e.effects.any((f) => f.kind == ImpactKind.explosion), isTrue);
    },
  );
  test(
    'Swept rocket collision hits an elevated road and a solid household object',
    () {
      final e = isolated(), f = tracks.first.at(75);
      e.projectiles.add(
        Projectile(75, 0)
          ..position = f.point(0, 8)
          ..direction = f.up * -1,
      );
      advance(e, .10);
      expect(e.projectiles, isEmpty);
      expect(e.effects.last.pose!.p.y, closeTo(f.p.y + .3, .1));
      e.effects.clear();
      e.track.obstacles.add(const WorldObstacle(V3(0, 8, -500), V3(2, 16, 6)));
      e.projectiles.add(
        Projectile(0, 0)
          ..position = const V3(-8, 8, -500)
          ..direction = const V3(1, 0, 0),
      );
      advance(e, .10);
      expect(e.projectiles, isEmpty);
      expect(e.effects.last.pose!.p.x, closeTo(-1.3, .02));
      e.track.obstacles.removeLast();
    },
  );
  test(
    'A missile hit animates damage and explosion even when shield absorbs damage',
    () {
      for (final shield in [false, true]) {
        final e = RaceEngine(track: tracks.first, car: cars.first)
          ..countdown = 0;
        e.bots.clear();
        final d = Driver('TARGET', cars[1], 0, 70, 0);
        e.bots.add(d);
        e.placeDriver(d, 70, 0);
        d.shield = shield ? 6 : 0;
        final f = e.driverFrame(d);
        e.projectiles.add(
          Projectile(0, 0, owner: e.player)
            ..position = f.point(0, 1.2) - f.forward * 7
            ..direction = f.forward,
        );
        advance(e, .07);
        expect(e.projectiles, isEmpty);
        expect(e.effects.any((f) => f.kind == ImpactKind.explosion), isTrue);
        if (shield) {
          expect(d.damage, 0);
          expect(e.effects.any((f) => f.kind == ImpactKind.blocked), isTrue);
        } else {
          expect(d.damage, greaterThan(.8));
          expect(d.spinTime, greaterThan(0));
          expect(d.hitFlash, greaterThan(0));
          expect(e.hitCount, 1);
        }
      }
    },
  );
  test(
    'Each layout has its own shape and figure-eight crossings have clearance',
    () {
      expect(
        tracks.map((t) => t.controls.length).toSet().length,
        greaterThanOrEqualTo(9),
      );
      for (var i = 0; i < tracks.length; i++)
        for (var j = i + 1; j < tracks.length; j++) {
          var difference = 0.0;
          for (var k = 0; k < 64; k++)
            difference +=
                (tracks[i].at(k / 64 * tracks[i].length).p -
                        tracks[j].at(k / 64 * tracks[j].length).p)
                    .length;
          expect(
            difference / 64,
            greaterThan(75),
            reason: '${tracks[i].id} / ${tracks[j].id}',
          );
        }
      final eight = tracks[2];
      var crossing = false;
      for (var s = 0.0; s < eight.length; s += 12)
        for (var q = s + 200; q < eight.length - 200; q += 12) {
          final a = eight.at(s).p, b = eight.at(q).p;
          if (V3(a.x - b.x, 0, a.z - b.z).length < 35) {
            crossing = true;
            expect((a.y - b.y).abs(), greaterThan(10));
          }
        }
      expect(crossing, isTrue);
    },
  );
  test(
    'New solid room props share bounds and leave every route corridor clear',
    () {
      for (final t in tracks) {
        expect(t.details.length, greaterThan(15));
        for (final p in t.details.where((p) => p.solid)) {
          expect(
            t.obstacles.any(
              (o) =>
                  (o.center - p.center).length < .001 &&
                  (o.size - p.size).length < .001,
            ),
            isTrue,
          );
          for (final f in t.frames) {
            if (f.p.y > p.center.y + p.size.y / 2 + 6) continue;
            final dx = (f.p.x - p.center.x).abs() - p.size.x / 2,
                dz = (f.p.z - p.center.z).abs() - p.size.z / 2;
            expect(
              math.max(dx, dz),
              greaterThanOrEqualTo(t.widthAt(f.s) / 2 + 13.9),
            );
          }
        }
      }
    },
  );
  test(
    'Podium stars improve once per circuit, time trial does not award wins or stars',
    () async {
      final store = GameStore();
      expect(tracks.where(store.trackUnlocked).length, 3);
      store.record(tracks.first, result(3), RaceMode.quick);
      expect(store.stars, 1);
      store.record(tracks.first, result(2), RaceMode.quick);
      expect(store.stars, 2);
      expect(store.lastStarsEarned, 1);
      store.record(tracks.first, result(1), RaceMode.quick);
      expect(store.stars, 3);
      store.record(tracks.first, result(1), RaceMode.quick);
      expect(store.stars, 3);
      expect(store.lastStarsEarned, 0);
      expect(store.trackUnlocked(tracks[4]), isTrue);
      final wins = store.wins;
      store.record(tracks[6], result(1), RaceMode.timeTrial);
      expect(store.stars, 3);
      expect(store.wins, wins);
      expect(store.trackUnlocked(tracks[6]), isFalse);
      await store.save();
      store.dispose();
    },
  );
  test(
    'Career cannot deadlock: each unlock threshold is reachable before next track',
    () {
      final ordered = tracks.toList()
        ..sort((a, b) => a.requiredStars.compareTo(b.requiredStars));
      var available = 0;
      for (final t in ordered) {
        expect(t.requiredStars, lessThanOrEqualTo(available), reason: t.id);
        available += 3;
      }
      expect(available, tracks.length * 3);
    },
  );
  test(
    'Purchases require earned eligibility and money; owned models are never charged again',
    () async {
      final store = GameStore()..coins = 20000;
      final exotic = cars.firstWhere((c) => c.id == 'huracan');
      expect(store.buyCar(exotic), isFalse);
      expect(store.coins, 20000);
      for (final t in tracks.take(10)) store.medals[t.id] = 3;
      expect(store.buyCar(exotic), isTrue);
      expect(store.coins, 9000);
      expect(store.buyCar(exotic), isTrue);
      expect(store.coins, 9000);
      expect(
        cars.where((c) => c.tier == 'EXÓTICO').every((c) => c.cost > 7000),
        isTrue,
      );
      await store.save();
      store.dispose();
    },
  );
  test(
    'New saves retain only earned cars, legacy saves retain all old free cars',
    () async {
      for (final legacy in [false, true]) {
        final data = jsonEncode({
          'owned': ['nsx'],
          'carId': 'nsx',
          'coins': 8765,
          'medals': {'garage': 2},
          if (!legacy) 'progressionVersion': 2,
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              GameStore.channel,
              (call) async => call.method == 'load' ? data : true,
            );
        final store = GameStore();
        await store.load();
        expect(store.coins, 8765);
        expect(store.stars, 2);
        expect(cars[store.selectedCar].id, 'nsx');
        expect(store.ownedCars.contains('350z'), legacy);
        expect(store.ownedCars, containsAll(['rx7', 'nsx']));
        store.dispose();
      }
    },
  );
  test(
    'Production shader has no fog operation and both clear scene pipelines compile in QA',
    () async {
      final shader = await rootBundle.loadString('assets/shaders/scene.frag');
      expect(shader.contains('float fog='), isFalse);
      expect(shader.contains('color=mix(color,uSky'), isFalse);
    },
  );
  for (final size in [const Size(1280, 720), const Size(800, 360)]) {
    testWidgets(
      'Locked circuit is previewable but cannot launch at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()..ready = true;
        await tester.pumpWidget(CarWeceApp(store: store, showIntro: false));
        await tester.pump();
        await tester.tap(find.text('CORRER'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('room-BANHEIRO')));
        await tester.pump();
        final start = find.byWidgetPredicate(
          (w) => w is RushButton && w.text == 'REQUER 5 ★',
        );
        expect(start, findsOneWidget);
        expect(tester.widget<RushButton>(start).onTap, isNull);
        expect(find.byType(RaceScreen), findsNothing);
        store.medals['bedroom'] = 3;
        store.medals['garage'] = 2;
        store.changed();
        await tester.pump();
        await tester.tap(find.text('VAMOS CORRER'));
        await tester.pump();
        expect(find.byType(RaceScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.save();
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
