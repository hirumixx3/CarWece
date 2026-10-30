import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';

void main() {
  testWidgets(
    'The entire countdown waits for the first native 3D frame',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final family in ['RushDisplay', 'RushBody', 'MaterialIcons']) {
        final path = family == 'MaterialIcons'
            ? 'fonts/MaterialIcons-Regular.otf'
            : 'assets/fonts/${family == 'RushDisplay' ? 'Display' : 'Body'}.ttf';
        await (FontLoader(family)..addFont(rootBundle.load(path))).load();
      }
      final began = Completer<void>(), ready = Completer<int>();
      const channel = MethodChannel('com.hirumisu.carwece/graphics');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') {
          if (!began.isCompleted) began.complete();
          return ready.future;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(GameStore.channel, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(GameStore.channel, null);
      });
      final race = RaceEngine(track: createTracks().first, car: cars.first),
          store = GameStore()..ready = true;
      await tester.pumpWidget(
        MaterialApp(
          home: RaceScreen(
            race: race,
            store: store,
            onFinish: (_) {},
            onExit: () {},
          ),
        ),
      );
      for (var i = 0; i < 300 && !began.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(began.isCompleted, isTrue);
      await tester.pump(const Duration(seconds: 10));
      expect(race.countdown, 3.2);
      expect(race.time, 0);
      ready.complete(901);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Texture), findsOneWidget);
      expect(race.countdown, lessThan(3.2));
      expect(race.countdown, greaterThan(3));
      race.countdown = 0;
      await tester.pump(const Duration(milliseconds: 50));
      expect(race.time, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
