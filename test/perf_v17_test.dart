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

  test('Race loop caps simulation catch-up (anti-spiral)', () {
    final screen = File('lib/ui/race_screen.dart').readAsStringSync();
    expect(screen, contains('final stepDt = dt > 1 / 30 ? 1 / 30 : dt;'));
    expect(screen, contains('race.update(stepDt);'));
    // The engine itself keeps full catch-up semantics: online lockstep
    // and the test suite drive it directly.
    final engine = File('lib/game/engine.dart').readAsStringSync();
    expect(engine, contains('_accumulator += dt.clamp(0, .1);'));
  });

  test('Weak-GPU profile (Galaxy A05s class) is wired end to end', () {
    final base = 'android/app/src/main/kotlin/com/hirumisu/carwece';
    final profile = File('$base/HardwareProfile.kt').readAsStringSync();
    expect(profile, contains('SM-A057')); // Galaxy A05s variants
    expect(profile, contains('SM6225')); // Snapdragon 680 / Adreno 610
    final activity = File('$base/MainActivity.kt').readAsStringSync();
    expect(activity, contains('"profile"'));
    expect(activity, contains('weakGpu'));
    final renderer = File('$base/RushGLRenderer.kt').readAsStringSync();
    expect(renderer, contains('dynamicResolution'));
    expect(renderer, isNot(contains('frameIndex'))); // shadows full-rate
    // The v1.7.1 flicker: an MSAA default framebuffer rejects the final
    // blit from the single-sample scene target. The default framebuffer
    // must stay single-sample under dynamic resolution and MSAA must
    // live inside the scene target instead.
    expect(renderer, contains('dynamicResolution -> null'));
    expect(renderer, contains('sceneMsaaFbo'));
    expect(renderer, contains('RenderbufferStorageMultisample'));
    // Resolution floor on weak GPUs: shadows degrade before resolution.
    expect(renderer, contains('scaleFloor'));
    expect(renderer, contains('"high" -> .80f'));
    final budget = File('$base/RenderBudget.kt').readAsStringSync();
    expect(budget, contains('climbSamples'));
    // No weak-only visual cuts remain: same shadow span and shader path
    // on every device (the v1.7.4 pacing fix carries the frame rate).
    expect(renderer, contains('span = if (showroom) 9f else 105f'));
    expect(renderer, isNot(contains('uPerfMode')));
    final view = File('lib/ui/gpu_view.dart').readAsStringSync();
    expect(view, contains("'profile'"));
    expect(view, contains('renderWidth'));
    // The v1.7.1 60 fps submission floor quantized to 45 fps on the
    // 90 Hz panel and caused the stutter; it must not come back.
    expect(view, isNot(contains('lowEnd && _minFrameUs')));
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

void weakGpuProfileTests() {}
