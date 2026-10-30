import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/main.dart';
import 'package:carwece/music.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/intro_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, dynamic> state;
  final calls = <String>[];
  const graphics = MethodChannel('com.hirumisu.carwece/graphics');
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
  setUp(() {
    calls.clear();
    state = {
      'status': 'playing',
      'textureId': 71,
      'width': 1280,
      'height': 720,
      'durationMs': 10027,
    };
    messenger.setMockMethodCallHandler(IntroController.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'pause' && state['status'] != 'completed')
        state['status'] = 'paused';
      if (call.method == 'resume' && state['status'] != 'completed')
        state['status'] = 'playing';
      if (call.method == 'open' && state['status'] == 'error')
        state['status'] = 'playing';
      return Map<String, dynamic>.from(state);
    });
    messenger.setMockMethodCallHandler(GameStore.channel, (call) async => null);
    messenger.setMockMethodCallHandler(
      SoundtrackController.channel,
      (call) async => {
        'trackId': 'menu_01',
        'scene': 'menu',
        'status': 'playing',
        'shuffle': true,
      },
    );
    messenger.setMockMethodCallHandler(
      graphics,
      (call) async => call.method == 'create' ? 11 : null,
    );
  });
  tearDown(() {
    for (final c in [
      IntroController.channel,
      GameStore.channel,
      SoundtrackController.channel,
      graphics,
    ])
      messenger.setMockMethodCallHandler(c, null);
    IntroController.channel.setMethodCallHandler(null);
    SoundtrackController.channel.setMethodCallHandler(null);
  });
  Future<void> event(String status) async {
    state['status'] = status;
    await messenger.handlePlatformMessage(
      IntroController.channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('state', Map<String, dynamic>.from(state)),
      ),
      (_) {},
    );
  }

  testWidgets(
    'Production launch waits beyond video duration and enters menu only on decoder completion',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = GameStore()..ready = true;
      await tester.pumpWidget(CarWeceApp(store: store));
      await tester.pump();
      expect(find.byKey(const ValueKey('intro-screen')), findsOneWidget);
      expect(find.byType(RushShell), findsNothing);
      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(RushShell), findsNothing);
      expect(calls.where((c) => c == 'open').length, 1);
      await event('completed');
      await tester.pump();
      await tester.pump();
      expect(find.byType(RushShell), findsOneWidget);
      expect(find.byKey(const ValueKey('intro-screen')), findsNothing);
      expect(calls, contains('dispose'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      store.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Background pauses and resumes intro without reopening or skipping it',
    (tester) async {
      var completed = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(home: IntroScreen(onCompleted: () => completed++)),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(calls, contains('pause'));
      expect(completed, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, contains('resume'));
      expect(calls.where((c) => c == 'open').length, 1);
      await tester.pump(const Duration(seconds: 12));
      expect(completed, 0);
      await event('completed');
      await tester.pump();
      expect(completed, 1);
      await event('paused');
      await tester.pump();
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'A decoding error offers retry and does not advance to the menu',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(home: IntroScreen(onCompleted: () => completed++)),
      );
      await tester.pump();
      await event('error');
      await tester.pump();
      expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
      expect(completed, 0);
      await tester.tap(find.text('TENTAR NOVAMENTE'));
      await tester.pump();
      expect(calls.where((c) => c == 'open').length, 2);
      expect(completed, 0);
      await event('completed');
      await tester.pump();
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  testWidgets(
    'Widescreen phones preserve the complete 16:9 video without cropping',
    (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: IntroScreen(onCompleted: () {})),
      );
      await tester.pump();
      final texture = find.byType(Texture);
      expect(tester.getSize(texture), const Size(640, 360));
      expect(tester.getTopLeft(texture).dx, 80);
      expect(find.textContaining('PULAR'), findsNothing);
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
  test(
    'Completion is terminal even if an older platform response arrives later',
    () async {
      final controller = IntroController();
      await controller.open();
      await event('completed');
      await event('playing');
      expect(controller.status, 'completed');
      controller.dispose();
    },
  );
}
