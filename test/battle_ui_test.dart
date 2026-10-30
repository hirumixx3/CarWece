import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/gpu_ready.dart';
import 'package:carwece/main.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/music.dart';
import 'package:carwece/ui/race_screen.dart';
import 'package:carwece/ui/battle_widgets.dart';
import 'package:carwece/ui/battle_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const graphics = MethodChannel('com.hirumisu.carwece/graphics');
  String? saved;
  final createCalls = <Map>[];
  setUp(() {
    saved = null;
    createCalls.clear();
    messenger.setMockMethodCallHandler(GameStore.channel, (c) async {
      if (c.method == 'load') return saved;
      if (c.method == 'save') {
        saved = c.arguments as String;
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      SoundtrackController.channel,
      (c) async => {
        'trackId': 'attention',
        'scene': 'race',
        'status': 'playing',
        'shuffle': true,
        'userPaused': false,
      },
    );
    messenger.setMockMethodCallHandler(graphics, (c) async {
      if (c.method == 'create') {
        createCalls.add(c.arguments as Map);
        return 417;
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(GameStore.channel, null);
    messenger.setMockMethodCallHandler(SoundtrackController.channel, null);
    messenger.setMockMethodCallHandler(graphics, null);
    SoundtrackController.channel.setMethodCallHandler(null);
  });
  setUpAll(() async {
    for (final f in [
      ['RushDisplay', 'Display.ttf'],
      ['RushBody', 'Body.ttf'],
    ]) {
      await (FontLoader(
        f[0],
      )..addFont(rootBundle.load('assets/fonts/${f[1]}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(
    WidgetTester tester,
    GlobalKey boundary,
    String name,
  ) async {
    if (!const bool.fromEnvironment('EXPORT_BATTLE_PREVIEW')) return;
    await tester.runAsync(() async {
      final im =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
      final p = File('previews/battle_v011/$name.png');
      p.parent.createSync(recursive: true);
      await p.writeAsBytes(bytes!.buffer.asUint8List());
      im.dispose();
    });
  }

  testWidgets(
    'Battle rewards and history persist separately from race medals and records',
    (tester) async {
      final store = GameStore()
        ..ready = true
        ..coins = 123;
      store.medals['bedroom'] = 3;
      store.records['race-old'] = 10;
      store.settings.hud.items.clear();
      final e = BattleEngine(arena: createBattleArenas().first, car: cars.first)
        ..countdown = 0
        ..time = 20;
      for (final bot in e.bots) e.applyDamage(bot, 500, source: e.player);
      for (var i = 0; i < 220; i++) e.update(1 / 120);
      expect(e.finished, isTrue);
      store.recordBattle(e);
      await store.save();
      final count = store.coins;
      store.recordBattle(e);
      expect(store.coins, count);
      expect(store.battles, 1);
      expect(store.battleWins, 1);
      expect(store.eliminations, 5);
      expect(store.races, 0);
      expect(store.wins, 0);
      expect(store.medals, {'bedroom': 3});
      expect(store.records, {'race-old': 10});
      final restored = GameStore();
      await restored.load();
      expect(restored.battles, 1);
      expect(restored.battleWins, 1);
      expect(restored.coins, count);
      expect(restored.stars, 3);
      expect(restored.battleRecords[e.track.id], 5);
      expect(jsonDecode(saved!)['battle']['played'], 1);
      restored.dispose();
      store.dispose();
    },
  );
  for (final size in [const Size(1280, 720), const Size(800, 360)])
    testWidgets(
      'Battle difficulty can be chosen before launch at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()..ready = true;
        store.settings.difficulty = 'hard';
        await tester.pumpWidget(CarWeceApp(store: store, showIntro: false));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('BATALHA / MUNDO ABERTO'));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('battle-difficulty-normal')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('battle-difficulty-easy')));
        await tester.pump();
        expect(store.settings.battleDifficulty, 'easy');
        expect(store.settings.difficulty, 'hard');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('INICIAR BATALHA'));
        await tester.pump();
        final e =
            tester.widget<RaceScreen>(find.byType(RaceScreen)).race
                as BattleEngine;
        expect(e.difficulty, 'easy');
        expect(e.human.ammo, isEmpty);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

  for (final size in [const Size(1280, 720), const Size(800, 360)])
    testWidgets(
      'Home to arenas, free exploration, multitouch firing, arsenal and HUD remain usable at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()..ready = true;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: CarWeceApp(store: store, showIntro: false),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('BATALHA / MUNDO ABERTO'));
        await tester.pump();
        expect(find.byType(BattleSelection), findsOneWidget);
        await capture(tester, boundary, 'arenas_${size.width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('battle-arena-5')));
        await tester.pump();
        await tester.tap(find.text('EXPLORAR / TESTAR PODERES'));
        await tester.pump();
        await tester.tap(find.text('EXPLORAR ARENA'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        final e =
            tester.widget<RaceScreen>(find.byType(RaceScreen)).race
                as BattleEngine;
        expect(e.freeRoam, isTrue);
        expect(e.track.id, 'arena_6');
        expect(e.autoAccelerate, isFalse);
        await waitForGpu(tester);
        e.countdown = 0;
        await tester.pump(const Duration(milliseconds: 20));
        expect(e.human.ammo, isEmpty);
        expect(find.text('SEM PODER\nCOLETE NO MAPA'), findsOneWidget);
        e.triggerHeld = true;
        await tester.pump(const Duration(milliseconds: 20));
        expect(e.human.shots, 0);
        e.triggerHeld = false;
        expect(
          createCalls.any((c) => (c['objects'] as List).length == BattleMesh.count),
          isTrue,
        );
        e.applyDamage(e.player, 30, source: e.bots.first);
        await tester.pump(const Duration(milliseconds: 40));
        final health = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('battle-player-health')),
        );
        expect(health.value, .7);
        await capture(tester, boundary, 'hud_${size.width.toInt()}');
        final pickup = e.pickups.firstWhere((p) => !p.health);
        pickup.power = BattlePower.machineGun;
        e.player.position = pickup.position;
        await tester.pump(const Duration(milliseconds: 20));
        expect(e.selectedAmmo, 60);
        final gas = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('hud-gas'))),
          pointer: 1,
        );
        final turn = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('hud-right'))),
          pointer: 2,
        );
        final fire = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('hud-item'))),
          pointer: 3,
        );
        await tester.pump(const Duration(milliseconds: 70));
        expect(e.accelerating, isTrue);
        expect(e.steering, 1);
        expect(e.triggerHeld, isTrue);
        expect(e.human.shots, greaterThan(0));
        await fire.cancel();
        expect(e.triggerHeld, isFalse);
        expect(e.accelerating, isTrue);
        await turn.up();
        expect(e.steering, 0);
        await gas.up();
        expect(e.accelerating, isFalse);
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump();
        expect(e.paused, isTrue);
        await tester.ensureVisible(find.text('ARSENAL'));
        await tester.tap(find.text('ARSENAL'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(find.byType(BattleArmory), findsOneWidget);
        await tester.tap(find.text('CATÁLOGO'));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('battle-weapon-search')),
          'aniquilador',
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('battle-weapon-quantumAnnihilator')),
        );
        await tester.pump();
        expect(e.human.selected, BattlePower.machineGun);
        expect(
          e.human.ammo.containsKey(BattlePower.quantumAnnihilator),
          isFalse,
        );
        expect(find.text('COLETE'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('battle-weapon-search')),
          'metralhadora',
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('battle-weapon-machineGun')),
        );
        await tester.pump();
        expect(e.human.selected, BattlePower.machineGun);
        final t = e.time;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
        await tester.pump(const Duration(seconds: 1));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
        expect(e.time, t);
        expect(e.accelerating, isFalse);
        await tester.tap(find.byTooltip('Fechar arsenal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(e.paused, isTrue);
        await tester.ensureVisible(find.text('EDITAR HUD'));
        await tester.tap(find.text('EDITAR HUD'));
        await tester.pump();
        final before = tester.getTopLeft(find.byKey(const ValueKey('hud-map')));
        await tester.drag(
          find.byKey(const ValueKey('hud-map')),
          const Offset(24, 12),
        );
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('hud-map'))),
          isNot(before),
        );
        await tester.tap(find.text('SALVAR'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(store.settings.hud.items.containsKey('map'), isTrue);
        expect(e.paused, isTrue);
        await tester.ensureVisible(find.text('CONTINUAR'));
        await tester.tap(find.text('CONTINUAR'));
        await tester.pump();
        expect(e.paused, isFalse);
        expect(e.triggerHeld, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
}
