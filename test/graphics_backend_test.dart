import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/ui/gpu_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void androidWidgets(String description, WidgetTesterCallback callback) =>
      testWidgets(
        description,
        callback,
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
  const channel = MethodChannel('com.hirumisu.carwece/graphics');
  const fallback = Key('software_fallback');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> mount(WidgetTester tester, ValueNotifier<int> repaint) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GpuSurface(
            bodies: {cars.last.body},
            world: () => GpuResources.showroom,
            frame: () => garageGpuFrame(cars.last, -.6),
            repaint: repaint,
            fallback: const ColoredBox(key: fallback, color: Colors.red),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  androidWidgets(
    'Android keeps all 114 slots while uploading just the visible car',
    (tester) async {
      var creates = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'create') {
              creates++;
              final args = call.arguments as Map;
              final meshes = args['objects'] as List;
              expect(meshes.length, cars.length * 3 + 21);
              expect((meshes[0] as List).length, 36);
              expect(
                (meshes[cars.last.body] as List).length,
                greaterThan(1000),
              );
              return 41;
            }
            return null;
          });
      final repaint = ValueNotifier(0);
      await mount(tester, repaint);
      expect(creates, 1);
      expect(find.byType(Texture), findsOneWidget);
      expect(tester.widget<Texture>(find.byType(Texture)).textureId, 41);
      expect(find.byKey(fallback), findsNothing);
      await tester.pumpWidget(const SizedBox());
      repaint.dispose();
    },
  );
  androidWidgets(
    'Native initialization failure never swaps to the old renderer; retry restores GPU',
    (tester) async {
      var creates = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'create') {
              creates++;
              if (creates == 1)
                throw PlatformException(
                  code: 'graphics_unavailable',
                  message: 'Falha de teste',
                );
              return 42;
            }
            return null;
          });
      final repaint = ValueNotifier(0);
      await mount(tester, repaint);
      expect(find.text('NÃO FOI POSSÍVEL INICIAR O 3D'), findsOneWidget);
      expect(find.byKey(fallback), findsNothing);
      await tester.tap(find.text('TENTAR NOVAMENTE'));
      await tester.pumpAndSettle();
      expect(creates, 2);
      expect(find.byType(Texture), findsOneWidget);
      expect(find.byKey(fallback), findsNothing);
      await tester.pumpWidget(const SizedBox());
      repaint.dispose();
    },
  );
  androidWidgets(
    'A later GPU failure releases the previous texture before retrying',
    (tester) async {
      var creates = 0, failFrame = false;
      final disposed = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'create') return 50 + creates++;
            if (call.method == 'frame' && failFrame) return 'Falha no quadro';
            if (call.method == 'dispose')
              disposed.add((call.arguments as Map)['id'] as int);
            return null;
          });
      final repaint = ValueNotifier(0);
      await mount(tester, repaint);
      failFrame = true;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      repaint.value++;
      await tester.pumpAndSettle();
      expect(find.text('NÃO FOI POSSÍVEL INICIAR O 3D'), findsOneWidget);
      expect(find.byKey(fallback), findsNothing);
      failFrame = false;
      await tester.tap(find.text('TENTAR NOVAMENTE'));
      await tester.pumpAndSettle();
      expect(disposed, contains(50));
      expect(tester.widget<Texture>(find.byType(Texture)).textureId, 51);
      await tester.pumpWidget(const SizedBox());
      repaint.dispose();
    },
  );
  androidWidgets(
    'Changing garage cars reloads their own meshes and releases the old texture',
    (tester) async {
      final selected = <int>[], disposed = <int>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map;
            if (call.method == 'create') {
              final frame = args['frame'] as List;
              final id = (frame[15] as num).toInt();
              selected.add(id);
              final models = args['objects'] as List;
              expect((models[id] as List).length, greaterThan(1000));
              expect((models[id == 0 ? 30 : 0] as List).length, 36);
              return 70 + selected.length;
            }
            if (call.method == 'dispose') disposed.add(args['id'] as int);
            return null;
          });
      for (final car in [cars.first, cars.last, cars[16]]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GpuGarageView(car: car, angle: -.6)),
          ),
        );
        await tester.pump();
        for (
          var i = 0;
          i < 200 &&
              selected.length <
                  [cars.first, cars.last, cars[16]].indexOf(car) + 1;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
        }
        await tester.pump();
        expect(find.byType(Texture), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(selected, [0, 30, 16]);
      expect(disposed, containsAll([71, 72]));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
