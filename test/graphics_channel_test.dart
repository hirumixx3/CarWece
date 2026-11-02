import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Android graphics payload round-trips all car bodies, effects, damage and animated wheels',
    () async {
      final race = RaceEngine(track: createTracks().first, car: cars.last)
        ..countdown = 0;
      race.player.hitFlash = .5;
      final shaders = await Future.wait(
        [
          'scene.vert',
          'scene.frag',
          'depth.vert',
          'depth.frag',
        ].map((s) => rootBundle.loadString('assets/shaders/$s')),
      );
      final arguments = {
        'width': 1280,
        'height': 720,
        'world': GpuResources.world(race.track),
        // Match the production upload: stable slots, full geometry only for
        // the cars actually present. Exporting all 81 cars consumed 282 MB
        // on the wire and exhausted the native unit-test JVM heap.
        'objects': GpuResources.objectsFor({
          for (final driver in race.drivers) driver.car.body,
        }),
        'shaders': shaders,
        'frame': raceGpuFrame(race),
        'showroom': false,
        'night': false,
        'quality': 'medium',
      };
      const codec = StandardMethodCodec();
      final wire = codec.encodeMethodCall(MethodCall('create', arguments));
      final decoded = codec.decodeMethodCall(wire);
      final args = decoded.arguments as Map;
      final meshes = args['objects'] as List;
      expect(decoded.method, 'create');
      expect(
        meshes.length,
        cars.length * 3 + 21,
        reason: 'The former Android limit of 16 rejected this entire request.',
      );
      expect(meshes.every((v) => v is Float32List && v.isNotEmpty), isTrue);
      final frame = args['frame'] as Float32List;
      expect([
        for (var i = 0; i < frame[14].toInt(); i++) frame[15 + i * 17].toInt(),
      ], contains(GpuMeshId.wheel + cars.length - 1));
      if (const bool.fromEnvironment('EXPORT_GRAPHICS_WIRE')) {
        final path = File('build/graphics_bridge/create.bin');
        await path.parent.create(recursive: true);
        final temporary = File('${path.path}.tmp');
        await temporary.writeAsBytes(
          wire.buffer.asUint8List(wire.offsetInBytes, wire.lengthInBytes),
        );
        await temporary.rename(path.path);
      }
    },
  );
}
