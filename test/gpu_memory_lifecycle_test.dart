import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/ui/gpu_view.dart';

void main() {
  const channel = MethodChannel('com.hirumisu.carwece/graphics');
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final triangle = Float32List(36);
  final frame = Float32List(15);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Widget surface({
    Future<(Float32List, List<Float32List>)> Function()? prepare,
    VoidCallback? onReady,
    VoidCallback? onUnavailable,
    Listenable? repaint,
  }) => MaterialApp(
    home: GpuSurface(
      prepare: prepare ?? () async => (triangle, [triangle]),
      world: () => triangle,
      frame: () => frame,
      fallback: const SizedBox(),
      onReady: onReady,
      onUnavailable: onUnavailable,
      repaint: repaint,
    ),
  );

  testWidgets(
    'Repeated retry taps cannot upload the same world concurrently',
    (tester) async {
      var creates = 0;
      final retryReady = Completer<int>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') {
          creates++;
          if (creates == 1)
            throw PlatformException(code: 'oom', message: 'memory');
          return retryReady.future;
        }
        return null;
      });
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      final button = find.text('TENTAR NOVAMENTE');
      expect(button, findsOneWidget);
      // No intervening paint: both taps reach the same error button.
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();
      expect(creates, 2);
      retryReady.complete(88);
      await tester.pumpAndSettle();
      expect(find.byType(Texture), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Failed GPU frame notifies race once and stops further packets',
    (tester) async {
      var unavailable = 0, frames = 0;
      var fail = false;
      final repaint = ValueNotifier(0);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') return 89;
        if (call.method == 'frame') {
          frames++;
          return fail ? 'memory' : null;
        }
        return null;
      });
      await tester.pumpWidget(
        surface(repaint: repaint, onUnavailable: () => unavailable++),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      fail = true;
      repaint.value++;
      await tester.pumpAndSettle();
      expect(unavailable, 1);
      final sent = frames;
      for (var i = 0; i < 4; i++) {
        repaint.value++;
        await tester.pump();
      }
      expect(frames, sent);
      await tester.pumpWidget(const SizedBox());
      repaint.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Leaving while geometry is building never creates an orphan GPU world',
    (tester) async {
      var creates = 0;
      final prepared = Completer<(Float32List, List<Float32List>)>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'create') creates++;
        return 90;
      });
      await tester.pumpWidget(surface(prepare: () => prepared.future));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      prepared.complete((triangle, [triangle]));
      await tester.pump();
      expect(creates, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
