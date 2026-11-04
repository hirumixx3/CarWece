import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/math3d.dart';

// v1.7 performance pass: the frame packet is now filled directly into its
// buffer. These tests pin the exact wire layout so the rewrite cannot
// drift from what the Kotlin renderer expects.
void main() {
  test('framePacket layout is byte-identical to the original construction', () {
    final model = Float32List.fromList(List.generate(16, (i) => i * .5));
    final packet = framePacket(
      const V3(1, 2, 3),
      const V3(4, 5, 6),
      const V3(0, 1, 0),
      const V3(7, 8, 9),
      2.5,
      [GpuInstance(3, model), GpuInstance(9, model)],
      boost: true,
    );
    expect(packet.length, 15 + 2 * 17);
    expect(packet.sublist(0, 15), [
      1,
      2,
      3,
      4,
      5,
      6,
      0,
      1,
      0,
      2.5,
      7,
      8,
      9,
      1,
      2,
    ]);
    expect(packet[15], 3);
    expect(packet.sublist(16, 32), model);
    expect(packet[32], 9);
    expect(packet.sublist(33, 49), model);
  });

  test('framePacket caps the instance count at 128', () {
    final model = Float32List(16);
    final packet = framePacket(
      V3.zero,
      V3.zero,
      const V3(0, 1, 0),
      V3.zero,
      0,
      List.generate(300, (i) => GpuInstance(i, model)),
    );
    expect(packet[14], 128);
    expect(packet.length, 15 + 128 * 17);
  });

  test(
    'Shader carries the distance shadow LOD and rough-surface GGX gate',
    () async {
      final frag = await File('assets/shaders/scene.frag').readAsString();
      expect(frag, contains('fragDist>110.0'));
      expect(frag, contains('fragDist>60.0'));
      expect(frag, contains('if(rough<.85)'));
      expect(frag, contains('0.1031')); // sin-free hash
      expect(frag, isNot(contains('float fog=')));
      expect(frag, isNot(contains('color=mix(color,uSky')));
    },
  );
}
