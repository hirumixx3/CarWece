import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/hud_layout.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final track = createTracks()[1];
  const graphics = MethodChannel('com.hirumisu.carwece/graphics');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  String? saved;
  setUp(() {
    saved = null;
    messenger.setMockMethodCallHandler(GameStore.channel, (call) async {
      if (call.method == 'save') {
        saved = call.arguments as String;
        return true;
      }
      if (call.method == 'load') return saved;
      return null;
    });
    messenger.setMockMethodCallHandler(
      graphics,
      (call) async => call.method == 'create' ? 61 : null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(GameStore.channel, null);
    messenger.setMockMethodCallHandler(graphics, null);
  });
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
  Finder element(String id) => find.byKey(ValueKey('hud-$id'));
  Future<void> pump(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
  }

  Future<void> mount(
    WidgetTester tester,
    GameStore store, {
    bool editorOnly = false,
    VoidCallback? onExit,
  }) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('hud-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xff0b1222),
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'RushBody'),
            colorScheme: const ColorScheme.dark(primary: Color(0xffff833d)),
          ),
          home: RaceScreen(
            race: RaceEngine(
              track: track,
              car: cars.first,
              mode: RaceMode.timeTrial,
            )..countdown = 0,
            store: store,
            hudEditorOnly: editorOnly,
            onFinish: (_) {},
            onExit: onExit ?? () {},
          ),
        ),
      ),
    );
    await pump(tester);
  }

  test(
    'HUD customization survives settings serialization and older saves use the defaults',
    () {
      final settings = GameSettings();
      settings.hud.items['gas'] = const HudPlacement(.2, .7, 1.3);
      settings.hud.items['map'] = const HudPlacement(.8, .1, 1.5);
      final restored = GameSettings()
        ..restore(
          jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
        );
      expect(restored.hud.toJson(), settings.hud.toJson());
      expect((GameSettings()..restore({})).hud.items, isEmpty);
      final edited = settings.hud.copy()..items.clear();
      expect(edited.items, isEmpty);
      expect(settings.hud.items.length, 2);
    },
  );

  test(
    'Invalid saved coordinates cannot lose HUD elements beyond the screen',
    () {
      final layout = HudLayout.restore({
        'gas': {'x': -10, 'y': 99, 'scale': 20},
        'map': {'x': double.nan, 'y': .2, 'scale': 1},
        'unknown': {'x': .2, 'y': .3, 'scale': 1},
      });
      expect(layout.items.length, 1);
      expect(layout.items['gas']!.x, 0);
      expect(layout.items['gas']!.y, 1);
      expect(layout.items['gas']!.scale, 1.8);
      for (final size in [const Size(800, 360), const Size(1280, 720)]) {
        for (final id in hudLabels.keys) {
          layout.resize(id, 1.8, size, .8);
          layout.move(id, const Offset(9999, -9999), size, .8);
          final rect = layout.rect(id, size, .8);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width + .001));
          expect(rect.bottom, lessThanOrEqualTo(size.height + .001));
        }
      }
    },
  );

  for (final size in [const Size(1280, 720), const Size(800, 360)]) {
    testWidgets(
      'Move/resize/save HUD and keep multi-touch and sliding controls at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()
          ..ready = true
          ..coins = 2468;
        store.ownedCars.add('350z');
        await mount(tester, store);
        final race = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
        await tester.tap(element('pause'));
        await pump(tester);
        await tester.ensureVisible(find.text('EDITAR HUD'));
        await tester.tap(find.text('EDITAR HUD'));
        await pump(tester);
        expect(find.text('EDITOR HUD'), findsOneWidget);
        expect(race.paused, isTrue);
        final time = race.time;
        if (const bool.fromEnvironment('EXPORT_HUD_PREVIEW')) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('hud-capture')),
            );
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = File(
              'previews/hud_v08/editor_${size.width.toInt()}.png',
            );
            output.parent.createSync(recursive: true);
            output.writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final mapBefore = tester.getRect(element('map'));
        await tester.drag(element('map'), const Offset(80, 25));
        await pump(tester);
        expect(
          tester.getRect(element('map')).left,
          closeTo(mapBefore.left + 80, 2),
        );
        await tester.drag(
          find.byKey(const ValueKey('hud-size-slider')),
          const Offset(70, 0),
        );
        await pump(tester);
        expect(
          tester.getSize(element('map')).width,
          greaterThan(mapBefore.width),
        );
        final gasBefore = tester.getRect(element('gas'));
        await tester.drag(element('gas'), const Offset(-80, -25));
        await pump(tester);
        expect(
          tester.getRect(element('gas')).left,
          closeTo(gasBefore.left - 80, 2),
        );
        expect(race.time, time);
        expect(race.accelerating, isFalse);
        await tester.tap(find.text('SALVAR'));
        await pump(tester);
        expect(find.text('PAUSADO'), findsOneWidget);
        expect(store.settings.hud.items.keys, containsAll(['map', 'gas']));
        expect(store.settings.hud.items['map']!.scale, greaterThan(1));
        expect(saved, isNotNull);
        await tester.tap(find.text('CONTINUAR'));
        await pump(tester);
        final pedal = await tester.startGesture(
          tester.getCenter(element('gas')),
          pointer: 71,
        );
        final steer = await tester.startGesture(
          tester.getCenter(element('right')),
          pointer: 72,
        );
        await pump(tester);
        expect(race.accelerating, isTrue);
        expect(race.steering, 1);
        await pedal.moveTo(tester.getCenter(element('drift')));
        await pump(tester);
        expect(race.driftPressed, isTrue);
        expect(race.accelerating, isTrue);
        await steer.moveTo(tester.getCenter(element('left')));
        await pump(tester);
        expect(race.steering, -1);
        await pedal.moveTo(tester.getCenter(element('gas')));
        await pump(tester);
        expect(race.driftPressed, isFalse);
        expect(race.accelerating, isTrue);
        await pedal.cancel();
        await steer.cancel();
        await pump(tester);
        expect(race.steering, 0);
        expect(race.accelerating, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        final restored = GameStore();
        await restored.load();
        expect(restored.settings.hud.toJson(), store.settings.hud.toJson());
        expect(restored.coins, 2468);
        expect(restored.ownedCars, contains('350z'));
        restored.dispose();
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'Reset is a draft until saved and cancelling preserves the previous layout',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = GameStore()..ready = true;
      store.settings.hud.items['map'] = const HudPlacement(.8, .2, 1.4);
      var exits = 0;
      await mount(tester, store, editorOnly: true, onExit: () => exits++);
      await tester.tap(find.text('PADRÃO'));
      await pump(tester);
      expect(store.settings.hud.items, isNotEmpty);
      await tester.tap(find.text('CANCELAR'));
      await pump(tester);
      expect(exits, 1);
      expect(saved, isNull);
      expect(store.settings.hud.items['map']!.scale, 1.4);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, store, editorOnly: true, onExit: () => exits++);
      await tester.tap(find.text('PADRÃO'));
      await tester.tap(find.text('SALVAR'));
      await pump(tester);
      expect(exits, 2);
      expect(store.settings.hud.items, isEmpty);
      expect(saved, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Failed HUD save keeps the editor open and preserves the stored layout',
    (tester) async {
      final store = GameStore()..ready = true;
      store.settings.hud.items['map'] = const HudPlacement(.7, .2, 1.4);
      messenger.setMockMethodCallHandler(GameStore.channel, (call) async {
        if (call.method == 'save')
          throw PlatformException(code: 'write_failed');
        return null;
      });
      await mount(tester, store, editorOnly: true);
      await tester.tap(find.text('PADRÃO'));
      await tester.tap(find.text('SALVAR'));
      await pump(tester);
      expect(find.text('EDITOR HUD'), findsOneWidget);
      expect(store.settings.hud.items['map']!.scale, 1.4);
      expect(
        find.text('Não foi possível salvar o HUD. Tente novamente.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
