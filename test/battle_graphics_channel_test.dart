import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/renderer.dart';
import 'package:carwece/ui/gpu_view.dart';

void main() {
  testWidgets(
    'Battle GPU uploads all 44 weapon models, life bars and active projectile',
    (tester) async {
      const channel = MethodChannel('com.hirumisu.carwece/graphics');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            calls.add(c);
            return c.method == 'create' ? 511 : null;
          });
      final e = BattleEngine(
        arena: createBattleArenas().first,
        car: cars.first,
        freeRoam: true,
      )..countdown = 0;
      e.giveWeapon(e.player, BattlePower.doomDisks);
      e.useItem();
      final repaint = ValueNotifier(0);
      await tester.pumpWidget(
        MaterialApp(
          home: GpuRaceView(
            race: e,
            fallbackScene: () => TrackScene(e.track),
            repaint: repaint,
            quality: 'medium',
            cameraDistance: 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 200 && !calls.any((c) => c.method == 'create'); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      final create = calls.firstWhere((c) => c.method == 'create'),
          args = create.arguments as Map;
      expect((args['objects'] as List).length, 174);
      final frame = args['frame'] as List;
      expect(frame[14], lessThanOrEqualTo(128));
      final meshes = [
        for (var i = 0; i < (frame[14] as num).toInt(); i++)
          frame[15 + i * 17] as num,
      ];
      expect(meshes.any((n) => n == 121), isTrue);
      expect(meshes.any((n) => n == 146), isTrue);
      if (const bool.fromEnvironment('EXPORT_GRAPHICS_WIRE')) {
        final p = File('build/graphics_bridge/battle.bin');
        p.parent.createSync(recursive: true);
        final data = const StandardMethodCodec().encodeMethodCall(create);
        final tmp = File('${p.path}.tmp');
        tmp.writeAsBytesSync(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        tmp.renameSync(p.path);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      repaint.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
