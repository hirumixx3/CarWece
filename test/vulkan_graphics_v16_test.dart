import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/gpu_mesh.dart';

// v1.6: Vulkan-first presentation (Impeller), renderer bug fixes and the
// next visual pass. These tests pin the contracts that do not need a GPU.
void main() {
  test('Android shell renders through Impeller with the Vulkan backend', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains(
        'io.flutter.embedding.android.EnableImpeller" android:value="true"',
      ),
    );
    expect(
      manifest,
      contains(
        'io.flutter.embedding.android.ImpellerBackend" android:value="vulkan"',
      ),
    );
    // Vulkan is preferred, never a hard requirement: GLES-only devices
    // must still install and run the game.
    expect(manifest, contains('android.hardware.vulkan.version'));
    expect(manifest, contains('android.hardware.vulkan.level'));
    expect(manifest, isNot(contains('EnableImpeller" android:value="false"')));
  });

  test('Shaders use correct normals and object-space detail', () async {
    final vert = await File('assets/shaders/scene.vert').readAsString();
    final frag = await File('assets/shaders/scene.frag').readAsString();
    // Inverse-transpose normal matrix for non-uniform instance scales.
    expect(vert, contains('transpose(inverse(mat3(uModel)))'));
    expect(vert, contains('vLocalPosition'));
    expect(frag, contains('localPlane'));
    // The HDR-unsafe S-curve is gone; the grade runs in display space.
    expect(frag, isNot(contains('vec3 curved=color*color')));
    expect(frag, contains('display*display*(3.0-2.0*display)'));
    // Shadow frustum edges fade instead of cutting off in a hard square.
    expect(frag, contains('smoothstep(0.0,0.045'));
    // The project's no-fog contract still holds.
    expect(frag, isNot(contains('float fog=')));
    expect(frag, isNot(contains('color=mix(color,uSky')));
  });

  test('Circuits gained a rubbered racing line and edge lines', () {
    final mesh = buildWorldMesh(createTracks().first).buffer;
    var racingLine = false, edgeLine = false;
    for (var i = 0; i < mesh.length; i += 12) {
      final r = mesh[i + 6], g = mesh[i + 7], b = mesh[i + 8];
      if ((r - 0x34 / 255).abs() < .01 &&
          (g - 0x38 / 255).abs() < .01 &&
          (b - 0x3e / 255).abs() < .01) {
        racingLine = true;
      }
      if ((r - 0xf3 / 255).abs() < .01 &&
          (g - 0xea / 255).abs() < .01 &&
          (b - 0xd2 / 255).abs() < .01 &&
          mesh[i + 11] == 8) {
        edgeLine = true;
      }
    }
    expect(racingLine, isTrue);
    expect(edgeLine, isTrue);
  });

  test('Showroom turntable gained steel inlay rings', () {
    final mesh = buildShowroom().buffer;
    var found = false;
    for (var i = 0; i < mesh.length; i += 12) {
      if ((mesh[i + 6] - 0x8f / 255).abs() < .01 &&
          (mesh[i + 7] - 0xa3 / 255).abs() < .01 &&
          (mesh[i + 8] - 0xb8 / 255).abs() < .01) {
        found = true;
      }
    }
    expect(found, isTrue);
  });
}
