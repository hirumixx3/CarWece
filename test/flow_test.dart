import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/ui/gpu_view.dart';
import 'package:carwece/main.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';
import 'package:carwece/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void linuxWidgets(String description, WidgetTesterCallback callback) =>
      testWidgets(
        description,
        callback,
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
      );
  const capture = bool.fromEnvironment('CAPTURE');
  final boundaryKey = GlobalKey();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          GameStore.channel,
          (call) async => call.method == 'save' ? true : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GameStore.channel, null);
  });
  setUpAll(() async {
    for (final pair in [
      ['RushDisplay', 'Display.ttf'],
      ['RushBody', 'Body.ttf'],
    ]) {
      final loader = FontLoader(pair[0])
        ..addFont(rootBundle.load('assets/fonts/${pair[1]}'));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!capture) return;
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('previews/compatibility').create(recursive: true);
      await File(
        'previews/compatibility/$name.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> launch(WidgetTester tester, GameStore store) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: CarWeceApp(store: store, showIntro: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> finishRace(WidgetTester tester) async {
    final race = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
    race.countdown = 0;
    race.time = 80;
    race.player.distance = race.track.length * 3 - .1;
    race.player.speed = 80;
    race.lapTimes.addAll([26, 27]);
    race.lastLapTime = 53;
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }

  linuxWidgets(
    'Menu, garage purchase, settings, multi-touch driving, pause and finish',
    (tester) async {
      final store = GameStore()
        ..ready = true
        ..coins = 4400
        ..medals['bedroom'] = 3
        ..medals['garage'] = 3
        ..medals['bedroom_sprint'] = 3
        ..medals['garage_drift'] = 3;
      await launch(tester, store);
      expect(find.text('CarWece'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await screenshot(tester, '01_menu');
      await tap(tester, 'CORRER');
      expect(find.text('ESCOLHA A CORRIDA'), findsOneWidget);
      await screenshot(tester, '02_circuitos');
      await tap(tester, 'GARAGEM');
      await tester.ensureVisible(find.text('TOYOTA SUPRA A80'));
      await tester.pump();
      await tap(tester, 'TOYOTA SUPRA A80');
      await screenshot(tester, '03_garagem');
      await tap(tester, 'COMPRAR • 4200');
      expect(store.selectedCar, 4);
      expect(store.coins, 200);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byTooltip('Configurações'));
      await tester.pump(const Duration(milliseconds: 20));
      await screenshot(tester, '04_configuracoes');
      expect(find.text('CONFIGURAÇÕES'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('EDITOR DE HUD'));
      await tester.tap(find.text('EDITOR DE HUD'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('EDITOR HUD'), findsOneWidget);
      expect(
        tester.widget<RaceScreen>(find.byType(RaceScreen)).race.paused,
        isTrue,
      );
      await tester.tap(find.text('CANCELAR'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('CONFIGURAÇÕES'), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pump(const Duration(milliseconds: 20));
      await tap(tester, 'CORRER');
      await tap(tester, 'VAMOS CORRER');
      final race = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
      race.countdown = 0;
      race.time = 12;
      race.player.distance = 30;
      race.player.speed = 60;
      await tester.pump(const Duration(milliseconds: 20));
      await screenshot(tester, '05_corrida');
      Finder control(String name) =>
          find.byWidgetPredicate((w) => w is HoldControl && w.label == name);
      final left = await tester.startGesture(
        tester.getCenter(control('ESQUERDA')),
        pointer: 1,
      );
      final boost = await tester.startGesture(
        tester.getCenter(control('TURBO')),
        pointer: 2,
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(race.steering, -1);
      expect(race.boosting, isTrue);
      await left.up();
      await boost.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.steering, 0);
      expect(race.boosting, isFalse);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.paused, isTrue);
      expect(find.text('PAUSADO'), findsOneWidget);
      await screenshot(tester, '06_pausa');
      await tap(tester, 'CONTINUAR');
      expect(race.paused, isFalse);
      await finishRace(tester);
      expect(find.text('VITÓRIA!'), findsOneWidget);
      expect(store.races, 1);
      expect(store.coins, greaterThan(200));
      await screenshot(tester, '07_resultado');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.save();
      store.dispose();
    },
  );

  linuxWidgets(
    'Manual pedal supports three simultaneous touches and losing shows the actual winner',
    (tester) async {
      final store = GameStore()..ready = true;
      await launch(tester, store);
      await tap(tester, 'CORRER');
      await tap(tester, 'VAMOS CORRER');
      final race = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
      race.bots.clear();
      race.countdown = 0;
      expect(race.autoAccelerate, isFalse);
      await tester.pump(const Duration(milliseconds: 100));
      expect(race.player.speed, 0);
      Finder control(String name) =>
          find.byWidgetPredicate((w) => w is HoldControl && w.label == name);
      final gas = await tester.startGesture(
        tester.getCenter(control('ACELERAR')),
        pointer: 11,
      );
      final left = await tester.startGesture(
        tester.getCenter(control('ESQUERDA')),
        pointer: 12,
      );
      final turbo = await tester.startGesture(
        tester.getCenter(control('TURBO')),
        pointer: 13,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(race.accelerating, isTrue);
      expect(race.steering, -1);
      expect(race.boosting, isTrue);
      expect(race.player.speed, greaterThan(0));
      await gas.up();
      await left.up();
      await turbo.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.accelerating, isFalse);
      expect(race.steering, 0);
      expect(race.boosting, isFalse);
      race.time = 80;
      race.player.distance = race.track.length * 3 - .1;
      race.player.speed = 80;
      race.lapTimes.addAll([26, 27]);
      race.lastLapTime = 53;
      race.bots.addAll([
        Driver('NOVA', cars[1], 1, race.track.length * 3, -.6)..finishTime = 76,
        Driver('BOLT', cars[2], 1, race.track.length * 3, .6)..finishTime = 78,
      ]);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('VITÓRIA!'), findsNothing);
      expect(find.text('3º'), findsOneWidget);
      expect(find.text('Vencedor: NOVA'), findsOneWidget);
      expect(
        tester.widget<GpuGarageView>(find.byType(GpuGarageView)).car,
        cars[1],
      );
      expect(store.wins, 0);
      expect(store.coins, 250);
      await screenshot(tester, '08_resultado_terceiro');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.save();
      store.dispose();
    },
  );

  linuxWidgets(
    'Held controls survive countdown, messages and sliding between arrows',
    (tester) async {
      final store = GameStore()..ready = true;
      await launch(tester, store);
      await tap(tester, 'CORRER');
      await tap(tester, 'VAMOS CORRER');
      final race = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
      race.bots.clear();
      race.countdown = .05;
      Finder control(String name) =>
          find.byWidgetPredicate((w) => w is HoldControl && w.label == name);
      final gas = await tester.startGesture(
        tester.getCenter(control('ACELERAR')),
        pointer: 31,
      );
      final wheel = await tester.startGesture(
        tester.getCenter(control('ESQUERDA')),
        pointer: 32,
      );
      final turbo = await tester.startGesture(
        tester.getCenter(control('TURBO')),
        pointer: 33,
      );
      for (var i = 0; i < 12; i++) {
        race.tell('HUD $i');
        await tester.pump(const Duration(milliseconds: 20));
        race.messageLife = 0;
        await tester.pump(const Duration(milliseconds: 20));
        expect(race.accelerating, isTrue);
        expect(race.steering, -1);
        expect(race.boosting, isTrue);
      }
      await wheel.moveTo(tester.getCenter(control('DIREITA')));
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.steering, 1);
      expect(race.accelerating, isTrue);
      await wheel.cancel();
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.steering, 0);
      await gas.up();
      await turbo.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.accelerating, isFalse);
      expect(race.boosting, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.save();
      store.dispose();
    },
  );

  linuxWidgets(
    'Pause clears old pointers and keyboard direction survives touch release',
    (tester) async {
      final store = GameStore()..ready = true;
      await launch(tester, store);
      await tap(tester, 'CORRER');
      await tap(tester, 'VAMOS CORRER');
      final race = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
      race.bots.clear();
      race.countdown = 0;
      Finder control(String name) =>
          find.byWidgetPredicate((w) => w is HoldControl && w.label == name);
      final gas = await tester.startGesture(
        tester.getCenter(control('ACELERAR')),
        pointer: 41,
      );
      final left = await tester.startGesture(
        tester.getCenter(control('ESQUERDA')),
        pointer: 42,
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.accelerating, isFalse);
      expect(race.steering, 0);
      await gas.cancel();
      await left.cancel();
      await tap(tester, 'CONTINUAR');
      final gas2 = await tester.startGesture(
        tester.getCenter(control('ACELERAR')),
        pointer: 43,
      );
      final right = await tester.startGesture(
        tester.getCenter(control('DIREITA')),
        pointer: 44,
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.accelerating, isTrue);
      expect(race.steering, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await right.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.steering, 1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await gas2.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(race.steering, 0);
      expect(race.accelerating, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.save();
      store.dispose();
    },
  );

  linuxWidgets(
    'Championship runs through all three circuits and awards points',
    (tester) async {
      final store = GameStore()..ready = true;
      await launch(tester, store);
      await tap(tester, 'CORRER');
      await tap(tester, 'CAMPEONATO');
      await tap(tester, 'VAMOS CORRER');
      final seen = <String>[];
      var expectedStart = 6;
      List<String>? expectedGrid;
      for (var i = 0; i < 3; i++) {
        seen.add(
          tester.widget<RaceScreen>(find.byType(RaceScreen)).race.track.id,
        );
        final engine = tester.widget<RaceScreen>(find.byType(RaceScreen)).race;
        expect(engine.startingPosition, expectedStart);
        if (expectedGrid != null) expect(engine.gridOrder, expectedGrid);
        final desiredFinish = [4, 2, 5][i];
        for (var j = 0; j < desiredFinish - 1; j++) {
          engine.bots[j].finishTime = 70 + j.toDouble();
          engine.bots[j].distance = engine.track.length * 3;
          engine.bots[j].completedLaps = 3;
        }
        await finishRace(tester);
        expect(engine.result!.position, desiredFinish);
        expectedStart = engine.result!.position;
        expectedGrid = engine.result!.standings.map((s) => s.name).toList();
        if (i < 2) {
          await tap(tester, 'PRÓXIMA ETAPA');
        }
      }
      expect(seen, ['bedroom', 'garage', 'bedroom_sprint']);
      expect(store.races, 3);
      expect(find.text('CAMPEONATO CONCLUÍDO'), findsOneWidget);
      await tap(tester, 'CORRER DE NOVO');
      expect(
        tester
            .widget<RaceScreen>(find.byType(RaceScreen))
            .race
            .startingPosition,
        6,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.save();
      store.dispose();
    },
  );

  linuxWidgets('Menus remain usable on a small landscape screen', (
    tester,
  ) async {
    final store = GameStore()..ready = true;
    await launch(tester, store);
    tester.view.physicalSize = const Size(800, 360);
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);
    await tap(tester, 'COMO JOGAR');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pump(const Duration(milliseconds: 20));
    await tap(tester, 'RECORDES');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await store.save();
    store.dispose();
  });

  test(
    'Settings, purchased cars, coins and records survive save and reload',
    () async {
      String? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(GameStore.channel, (call) async {
            if (call.method == 'save') {
              saved = call.arguments as String;
              return true;
            }
            return saved;
          });
      final first = GameStore()..coins = 900;
      first.settings.music = .17;
      first.settings.autoAccelerate = false;
      first.buyCar(cars[7]);
      first.selectedCar = 7;
      first.records['bedroom:quick'] = 63.14;
      await first.save();
      final second = GameStore();
      await second.load();
      expect(second.coins, 400);
      expect(second.selectedCar, 7);
      expect(second.settings.music, .17);
      expect(second.settings.autoAccelerate, isFalse);
      expect(second.ownedCars, contains('ek9'));
      expect(second.records['bedroom:quick'], 63.14);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(GameStore.channel, null);
      first.dispose();
      second.dispose();
    },
  );
  linuxWidgets('Menu animation resumes immediately after backgrounding', (
    tester,
  ) async {
    final store = GameStore()..ready = true;
    await launch(tester, store);
    await tester.pump(const Duration(seconds: 5));
    double phase() =>
        (tester
                    .widgetList<CustomPaint>(find.byType(CustomPaint))
                    .firstWhere((p) => p.painter is TechBackground)
                    .painter
                as TechBackground)
            .phase;
    expect(phase(), greaterThan(4));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final first = phase();
    await tester.pump(const Duration(milliseconds: 50));
    expect(phase(), greaterThan(first));
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
