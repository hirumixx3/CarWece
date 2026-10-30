import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/main.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/music.dart';
import 'package:carwece/online/client.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/online_screen.dart';

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
      (c) async => {'scene': 'menu', 'status': 'idle'},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.hirumisu.carwece/graphics'),
      (c) async => null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(GameStore.channel, null);
    messenger.setMockMethodCallHandler(SoundtrackController.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.hirumisu.carwece/graphics'),
      null,
    );
    SoundtrackController.channel.setMethodCallHandler(null);
  });
  setUpAll(() async {
    for (final f in [
      ['RushDisplay', 'Display.ttf'],
      ['RushBody', 'Body.ttf'],
    ])
      await (FontLoader(
        f[0],
      )..addFont(rootBundle.load('assets/fonts/${f[1]}'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(
    WidgetTester tester,
    GlobalKey boundary,
    String name,
  ) async {
    if (!const bool.fromEnvironment('EXPORT_ONLINE_PREVIEW')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File('previews/online_v0144/$name.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [const Size(1280, 720), const Size(800, 360)]) {
    testWidgets(
      'online login and map selection fit $size and preserve offline progress',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()
          ..ready = true
          ..coins = 9876;
        final tracks = createTracks(),
            arenas = createBattleArenas(),
            boundary = GlobalKey();
        final client = OnlineClient(tracks: tracks, arenas: arenas);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                fontFamily: 'RushBody',
              ),
            ),
            home: RepaintBoundary(
              key: boundary,
              child: OnlineScreen(
                store: store,
                tracks: tracks,
                arenas: arenas,
                onBack: () {},
                client: client,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('friend-username')), findsOneWidget);
        expect(find.byKey(const ValueKey('friend-invite')), findsOneWidget);
        expect(find.byKey(const ValueKey('friend-create')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('friend-lan')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.textContaining('Esta opção não usa retransmissor'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, boundary, 'wifi_${size.width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('friend-internet')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('online-password')), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('friend-username')),
          'Higor',
        );
        await tester.tap(find.text('BATALHA'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const ValueKey('friend-map-battle')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, boundary, 'login_${size.width.toInt()}');
        client.profile = {
          'name': 'PilotoTeste',
          'coins': 0,
          'stars': 0,
          'wins': 0,
          'owned': ['rx7'],
        };
        // A harmless failed request emits the same refresh notification as login.
        await client.refreshRooms();
        await tester.pump();
        expect(find.byKey(const ValueKey('friend-map-battle')), findsOneWidget);
        expect(find.byKey(const ValueKey('online-endpoint')), findsNothing);
        expect(find.byKey(const ValueKey('advanced-server')), findsNothing);
        expect(find.text('CRIAR CONTA'), findsNothing);
        expect(store.coins, 9876);
        expect(store.ownedCars, {'rx7'});
        expect(tester.takeException(), isNull);
        await capture(tester, boundary, 'sala_${size.width.toInt()}');
        await tester.pumpWidget(const SizedBox());
        client.dispose();
        await store.save();
        store.dispose();
      },
    );
  }
  testWidgets(
    'home opens online and credits include Marcos Nascimento Sage Corp',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = GameStore()..ready = true, boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: CarWeceApp(store: store, showIntro: false),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('enter-online')), findsOneWidget);
      await capture(tester, boundary, 'home');
      await tester.tap(find.text('CRÉDITOS'));
      await tester.pump();
      expect(find.text('Marcos Nascimento (Sage Corp.)'), findsOneWidget);
      expect(find.text('por hirumisu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'creditos');
      await tester.pumpWidget(const SizedBox());
      await store.save();
      store.dispose();
    },
  );
}
