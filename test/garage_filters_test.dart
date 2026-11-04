import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/main.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/music.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(
      GameStore.channel,
      (c) async => c.method == 'save' ? true : null,
    );
    messenger.setMockMethodCallHandler(
      SoundtrackController.channel,
      (c) async => null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(GameStore.channel, null);
    messenger.setMockMethodCallHandler(SoundtrackController.channel, null);
  });
  setUpAll(() async {
    for (final p in [
      ['RushDisplay', 'Display.ttf'],
      ['RushBody', 'Body.ttf'],
    ]) {
      await (FontLoader(
        p[0],
      )..addFont(rootBundle.load('assets/fonts/${p[1]}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [const Size(1280, 720), const Size(800, 360)]) {
    testWidgets(
      'Garage combines filters, buys Fusca and preserves master index at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()..coins = 1000;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: CarWeceApp(store: store, showIntro: false),
          ),
        );
        await tester.pump(const Duration(milliseconds: 30));
        await tester.tap(find.text('GARAGEM').last);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('106 / 106 CARROS'), findsOneWidget);
        Future<void> choose(String key, String option) async {
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pump(const Duration(milliseconds: 250));
          await tester.scrollUntilVisible(
            find.text(option),
            100,
            scrollable: find.byType(Scrollable).last,
            maxScrolls: 30,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text(option).last),
            alignment: .5,
          );
          await tester.pump(const Duration(milliseconds: 250));
          await tester.tap(find.text(option).last);
          await tester.pump(const Duration(milliseconds: 250));
        }

        await choose('garage-class-filter', 'CLASSE S');
        await tester.tap(find.byKey(const ValueKey('garage-brazil-filter')));
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.text('NENHUM CARRO NESTA COMBINAÇÃO'), findsOneWidget);
        expect(store.selectedCar, 0);
        await choose('garage-category-filter', 'PICAPE');
        expect(find.text('0 / 106 CARROS'), findsOneWidget);
        await tester.tap(find.byTooltip('Limpar filtros'));
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.text('106 / 106 CARROS'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('garage-brazil-filter')));
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.text('50 / 106 CARROS'), findsOneWidget);
        await choose('garage-class-filter', 'CLASSE D');
        await choose('garage-category-filter', 'CLÁSSICO');
        await tester.scrollUntilVisible(
          find.text('VOLKSWAGEN FUSCA 1600'),
          120,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('garage-car-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.ensureVisible(find.text('VOLKSWAGEN FUSCA 1600'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('VOLKSWAGEN FUSCA 1600').first);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('COMPRAR • 650'), findsOneWidget);
        await tester.tap(find.text('COMPRAR • 650'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(store.selectedCar, 56);
        expect(store.coins, 350);
        expect(store.ownedCars, contains('br_fusca'));
        expect(find.text('SELECIONADO'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_BR')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'previews/brasil_loops/garagem_${size.width.toInt()}.png',
            )..parent.createSync(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
