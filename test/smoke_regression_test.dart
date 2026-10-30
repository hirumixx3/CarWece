import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/gpu_ready.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final track = TrackSpec(
    'smoke_qa',
    'FUMAÇA',
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

  RaceEngine race() {
    final e = RaceEngine(
      track: track,
      car: cars.first,
      mode: RaceMode.timeTrial,
    )..countdown = 0;
    e.placeDriver(e.player, 0, 0);
    e.player.position = const V3(0, .16, 0);
    e.player.forward = const V3(0, 0, 1);
    e.player.normal = const V3(0, 1, 0);
    return e;
  }

  Driver enemy() => Driver('FUMAÇA ADVERSÁRIA', cars[1], .8, 0, 0);
  void step(RaceEngine e) => e.update(1 / 120);

  test(
    'Smoke clears on the first physics step outside and can be entered again',
    () {
      final e = race(), cloud = SmokeCloud(const V3(0, 1.26, 0), enemy());
      e.clouds.add(cloud);
      step(e);
      expect(e.player.smokeExposure, greaterThan(0));
      e.player.position = const V3(20, .16, 0);
      step(e);
      expect(e.clouds, contains(cloud));
      expect(e.player.smokeExposure, 0);
      e.player.position = cloud.center - e.player.normal! * 1.1;
      step(e);
      expect(e.player.smokeExposure, greaterThan(0));
      e.resetPlayer();
      expect(e.player.smokeExposure, 0);
    },
  );

  test(
    'A stopped car clears as the cloud expires; removed clouds cannot leave a timer',
    () {
      final e = race(), cloud = SmokeCloud(const V3(0, 1.26, 0), enemy());
      e.clouds.add(cloud);
      step(e);
      expect(e.player.smokeExposure, greaterThan(0));
      cloud.life = .001;
      step(e);
      expect(e.clouds, isEmpty);
      expect(e.player.smokeExposure, 0);
      e.clouds.add(SmokeCloud(e.player.position!, enemy()));
      step(e);
      expect(e.player.smokeExposure, greaterThan(0));
      e.clouds.clear();
      step(e);
      expect(e.player.smokeExposure, 0);
      expect(e.player.speed, closeTo(0, .001));
    },
  );

  test(
    'Own smoke is ignored; overlapping enemy clouds do not stack opacity',
    () {
      final e = race();
      e.clouds.add(SmokeCloud(const V3(0, 1.26, 0), e.player));
      step(e);
      expect(e.player.smokeExposure, 0);
      final owner = enemy();
      for (var i = 0; i < 25; i++) {
        e.clouds.add(SmokeCloud(const V3(0, 1.26, 0), owner));
      }
      step(e);
      expect(e.clouds.length, 22);
      expect(e.player.smokeExposure, inInclusiveRange(.9, 1.0));
      e.player.position = const V3(0, 20, 0);
      step(e);
      expect(e.player.smokeExposure, 0);
    },
  );

  test(
    'Visibility volume matches the rendered smoke sphere and softens at its edge',
    () {
      final e = race(),
          cloud = SmokeCloud(const V3(0, 1.26, 0), enemy())..life = 2;
      e.clouds.add(cloud);
      final p = raceGpuFrame(e);
      final i = [
        for (var i = 0; i < p[14]; i++) i,
      ].singleWhere((i) => p[15 + i * 17].toInt() == GpuMeshId.smoke);
      final start = 16 + i * 17;
      expect(p[start], closeTo(cloud.radius, .0001));
      expect(p[start + 12], closeTo(cloud.center.x, .0001));
      expect(p[start + 13], closeTo(cloud.center.y, .0001));
      expect(p[start + 14], closeTo(cloud.center.z, .0001));
      expect(cloud.densityAt(cloud.center), 1);
      expect(
        cloud.densityAt(cloud.center + V3(cloud.radius * .95, 0, 0)),
        inExclusiveRange(0, .2),
      );
      expect(
        cloud.densityAt(cloud.center + V3(cloud.radius, 0, 0)),
        closeTo(0, .00001),
      );
      expect(cloud.densityAt(cloud.center + V3(cloud.radius + .01, 0, 0)), 0);
      cloud.life = .1;
      expect(cloud.densityAt(cloud.center), lessThan(.25));
      cloud.life = 0;
      expect(cloud.densityAt(cloud.center), 0);
    },
  );

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

  for (final size in [const Size(1280, 720), const Size(800, 360)]) {
    testWidgets(
      'Enemy smoke does not break the Android HUD at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          GameStore.channel,
          (_) async => true,
        );
        const graphics = MethodChannel('com.hirumisu.carwece/graphics');
        messenger.setMockMethodCallHandler(
          graphics,
          (call) async => call.method == 'create' ? 73 : null,
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(GameStore.channel, null);
          messenger.setMockMethodCallHandler(graphics, null);
        });
        final e = race();
        final cloud = SmokeCloud(e.player.position!, enemy());
        e.clouds.add(cloud);
        final store = GameStore()..ready = true;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.fromLTRB(24, 18, 10, 12),
              ),
              child: RaceScreen(
                race: e,
                store: store,
                onFinish: (_) {},
                onExit: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
        await waitForGpu(tester);
        await tester.pump(const Duration(milliseconds:20));
        await tester.pump(const Duration(milliseconds:20));
        final veil = find.byKey(const ValueKey('smoke-veil'));
        expect(veil, findsOneWidget);
        expect(tester.getSize(veil), size);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: veil,
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration;
        expect(decoration.gradient!.colors.every((c) => c.a <= .62), isTrue);
        final gas = find.byWidgetPredicate(
          (w) => w is HoldControl && w.label == 'ACELERAR',
        );
        final right = find.byWidgetPredicate(
          (w) => w is HoldControl && w.label == 'DIREITA',
        );
        final pedal = await tester.startGesture(
          tester.getCenter(gas),
          pointer: 1,
        );
        final steering = await tester.startGesture(
          tester.getCenter(right),
          pointer: 2,
        );
        await tester.pump(const Duration(milliseconds: 20));
        for (var i = 0; i < 3; i++) {
          e.player.position = const V3(20, .16, 0);
          e.player.velocity = V3.zero;
          await tester.pump(const Duration(milliseconds: 20));
          expect(veil, findsNothing);
          expect(e.player.smokeExposure, 0);
          e.player.position = cloud.center - e.player.normal! * 1.1;
          e.player.velocity = V3.zero;
          await tester.pump(const Duration(milliseconds: 20));
          expect(veil, findsOneWidget);
          expect(e.accelerating, isTrue);
          expect(e.steering, 1);
          expect(tester.takeException(), isNull);
        }
        cloud.life = .001;
        await tester.pump(const Duration(milliseconds: 20));
        expect(veil, findsNothing);
        expect(e.accelerating, isTrue);
        expect(e.steering, 1);
        await pedal.up();
        await steering.up();
        await tester.pump();
        expect(e.accelerating, isFalse);
        expect(e.steering, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.save();
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
