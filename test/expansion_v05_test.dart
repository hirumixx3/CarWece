import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/gpu_mesh.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/main.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';

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
  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) {
      e.update(1 / 120);
    }
  }

  RaceEngine openFloor({int car = 0}) {
    final e = RaceEngine(
      track: tracks[6],
      car: cars[car],
      mode: RaceMode.timeTrial,
    )..countdown = 0;
    e.placeDriver(e.player, tracks[6].length * .4, 0);
    e.player.position = const V3(-50, TrackSpec.floorHeight, -50);
    e.player.normal = const V3(0, 1, 0);
    e.player.forward = const V3(0, 0, 1);
    e.player.velocity = const V3(0, 0, 36);
    e.player.speed = 36;
    return e;
  }

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
    'Thirty-one real-name models have distinct silhouettes and a starter RX7',
    () {
      expect(cars.length, 156);
      expect(cars.take(4).map((c) => c.id), ['rx7', 'evo9', 'r34', '350z']);
      expect(cars.map((c) => c.body).toSet().length, 156);
      expect(
        cars
            .map(
              (c) =>
                  '${c.design.roof}:${c.design.halfLength}:${c.design.roofRear}',
            )
            .toSet()
            .length,
        156,
      );
      expect(cars.where((c) => c.cost == 0).map((c) => c.id), ['rx7']);
      expect(GpuResources.objects.length, cars.length * 3 + 21);
      final store = GameStore();
      expect(store.ownedCars, {'rx7'});
      store.dispose();
    },
  );
  test(
    'Every room has at least four circuits and matching tire surface grip',
    () {
      expect(tracks.length, 126);
      final rooms = tracks.map((t) => t.room).toSet();
      expect(rooms, {
        'QUARTO',
        'GARAGEM',
        'ARCADE',
        'BANHEIRO',
        'COZINHA',
        'SALA',
        ...expansionBiomes.keys,
      });
      for (final room in rooms) {
        expect(
          tracks.where((t) => t.room == room).length,
          greaterThanOrEqualTo(4),
          reason: room,
        );
      }
      expect(tracks[6].tiled, isTrue);
      expect(tracks[6].floorGrip, lessThan(tracks.first.floorGrip));
      expect(tracks.every((t) => t.length > 3500 && t.width >= 46), isTrue);
    },
  );
  test(
    'Steering rack animates at rest without moving the car or rear wheels',
    () {
      final e = openFloor();
      e.player.velocity = V3.zero;
      e.player.speed = 0;
      final p = e.player.position!;
      e.steering = 1;
      advance(e, .25);
      expect(e.player.steeringAngle, greaterThan(.45));
      expect((e.player.position! - p).length, lessThan(.001));
      expect(wheelSteer(e.player, 0), 0);
      expect(wheelSteer(e.player, 1), 0);
      expect(wheelSteer(e.player, 3), greaterThan(wheelSteer(e.player, 2)));
      e.steering = -1;
      advance(e, .45);
      expect(e.player.steeringAngle, lessThan(-.45));
      expect(wheelSteer(e.player, 2), lessThan(wheelSteer(e.player, 3)));
    },
  );
  test('Tire roll comes from signed traveled speed and stops at rest', () {
    final e = openFloor(), p = e.player.position!;
    advance(e, .08);
    final traveled = (e.player.position! - p).length;
    expect(
      e.player.wheelAngles[0],
      closeTo(traveled / e.car.design.wheelRadius, .08),
    );
    expect(e.player.wheelAngles.every((v) => v > 0), isTrue);
    e.player.velocity = V3.zero;
    e.player.speed = 0;
    final angles = List<double>.from(e.player.wheelAngles);
    advance(e, .3);
    expect(e.player.wheelAngles, angles);
    e.player.velocity = const V3(0, 0, -5);
    e.player.speed = -5;
    advance(e, .05);
    expect(e.player.wheelSpeeds.every((v) => v < 0), isTrue);
  });
  test(
    'Separate wheel transforms retain axle center, spin and front steer',
    () {
      final e = openFloor()..steering = .8;
      advance(e, .15);
      final packet = raceGpuFrame(e);
      final offsets = [
        for (var i = 0; i < packet[14].toInt(); i++) 15 + i * 17,
      ];
      final wheels = offsets
          .where((o) => packet[o] == GpuMeshId.wheel)
          .toList();
      expect(wheels.length, 4);
      for (final o in wheels) {
        final matrix = packet.sublist(o + 1, o + 17);
        expect(matrix.every((v) => v.isFinite), isTrue);
        final r = V3(matrix[0], matrix[1], matrix[2]),
            up = V3(matrix[4], matrix[5], matrix[6]);
        expect(r.length, closeTo(1, .00001));
        expect(r.dot(up), closeTo(0, .00001));
      }
      final a = packet.sublist(wheels[0] + 1, wheels[0] + 4),
          b = packet.sublist(wheels[2] + 1, wheels[2] + 4);
      expect(
        (V3(a[0], a[1], a[2]) - V3(b[0], b[1], b[2])).length,
        greaterThan(.08),
      );
    },
  );
  test(
    'Drift requires its own button and releases rear grip without braking gas',
    () {
      final normal = openFloor()
        ..steering = .6
        ..accelerating = true
        ..nitro = 30;
      final drift = openFloor()
        ..steering = .6
        ..accelerating = true
        ..nitro = 30
        ..driftPressed = true;
      advance(normal, .6);
      advance(drift, .6);
      expect(normal.drifting, isFalse);
      expect(drift.drifting, isTrue);
      expect(drift.player.tireSlip, greaterThan(normal.player.tireSlip));
      expect(drift.nitro, greaterThan(normal.nitro));
      expect(drift.player.speed, greaterThan(20));
      expect(drift.effects.any((e) => e.kind == ImpactKind.skid), isTrue);
      drift.setPaused(true);
      final angles = List<double>.from(drift.player.wheelAngles);
      advance(drift, 1);
      expect(drift.player.wheelAngles, angles);
      expect(drift.driftPressed, isFalse);
      expect(drift.drifting, isFalse);
    },
  );
  test('Wheel meshes have correct normals and readable material diversity', () {
    for (final car in cars) {
      final data = buildWheelMesh(car).buffer;
      expect(data.length % 36, 0);
      expect(data.every((v) => v.isFinite), isTrue);
      final materials = <int>{};
      for (var i = 0; i < data.length; i += 12) {
        final n = V3(data[i + 3], data[i + 4], data[i + 5]);
        expect(n.length, closeTo(1, .00001));
        materials.add(data[i + 11].toInt());
      }
      expect(
        materials,
        containsAll([Material3.rubber, Material3.metal, Material3.decal]),
      );
    }
  });
  test(
    'Legacy car purchases and selected index migrate without losing currency',
    () async {
      final old = jsonEncode({
        'coins': 777,
        'car': 3,
        'owned': ['spark', 'viper', 'phantom'],
        'records': {'bedroom:quick:layout4': 60.5},
        'settings': {},
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            GameStore.channel,
            (call) async => call.method == 'load' ? old : true,
          );
      final store = GameStore();
      await store.load();
      expect(store.coins, 777);
      expect(cars[store.selectedCar].id, '350z');
      expect(store.ownedCars, containsAll(['rx7', 'evo9', 'r34', '350z']));
      expect(store.records['bedroom:quick:layout4'], 60.5);
      store.dispose();
    },
  );

  Finder control(String label) =>
      find.byWidgetPredicate((w) => w is HoldControl && w.label == label);
  for (final size in [const Size(1280, 720), const Size(800, 360)]) {
    testWidgets(
      'Room filters and slide-to-drift controls fit $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()
          ..ready = true
          ..medals['bedroom'] = 3
          ..medals['garage'] = 2;
        await tester.pumpWidget(CarWeceApp(store: store, showIntro: false));
        await tester.pump();
        await tester.tap(find.text('CORRER'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const ValueKey('room-BANHEIRO')));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('MARÉ DE AZULEJOS'), findsOneWidget);
        expect(find.text('CURVA DO RALO'), findsOneWidget);
        expect(find.text('QUARTO EM CHAMAS'), findsNothing);
        await tester.tap(find.text('VAMOS CORRER'));
        await tester.pump();
        final race = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
        expect(race.track.room, 'BANHEIRO');
        race.countdown = 0;
        race.player.speed = 40;
        race.bots.clear();
        final gas = await tester.startGesture(
          tester.getCenter(control('ACELERAR')),
          pointer: 31,
        );
        final steer = await tester.startGesture(
          tester.getCenter(control('DIREITA')),
          pointer: 32,
        );
        await tester.pump(const Duration(milliseconds: 25));
        expect(race.accelerating, isTrue);
        expect(race.steering, 1);
        await gas.moveTo(tester.getCenter(control('DRIFT')));
        await tester.pump(const Duration(milliseconds: 25));
        expect(race.driftPressed, isTrue);
        expect(race.accelerating, isTrue);
        await gas.moveTo(tester.getCenter(control('ACELERAR')));
        await tester.pump(const Duration(milliseconds: 25));
        expect(race.driftPressed, isFalse);
        expect(race.accelerating, isTrue);
        await gas.cancel();
        await steer.cancel();
        await tester.pump();
        expect(race.accelerating, isFalse);
        expect(race.driftPressed, isFalse);
        expect(race.steering, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.save();
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
