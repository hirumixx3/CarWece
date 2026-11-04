import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// v1.5.1: the v1.6.0 graphics BUG FIXES ported onto the v1.5.0 base,
// without the changes that cost performance (forced Vulkan backend,
// 5x5 PCF tier, MSAA on medium). These tests pin both halves of that.
void main() {
  test('Shader fixes are in', () async {
    final vert = await File('assets/shaders/scene.vert').readAsString();
    final frag = await File('assets/shaders/scene.frag').readAsString();
    // Correct normals under non-uniform instance scales.
    expect(vert, contains('transpose(inverse(mat3(uModel)))'));
    expect(vert, contains('vLocalPosition'));
    expect(frag, contains('vLocalPosition'));
    // Object-space detail noise (no crawling across moving paint).
    expect(frag, contains('noise(localPlane*70.0)'));
    // Grade runs in display space; the HDR S-curve is gone.
    expect(frag, isNot(contains('vec3 curved=color*color')));
    expect(frag, contains('vec3 curved=display*display'));
    // Shadow fades at the light-frustum edge; glass respects shadow.
    expect(frag, contains('float edge=smoothstep(0.0,0.045'));
    expect(frag, contains('*(.38+.62*vis)'));
  });

  test('Renderer fixes are in, performance traps stay out', () {
    final renderer = File(
      'android/app/src/main/kotlin/com/hirumisu/carwece/RushGLRenderer.kt',
    ).readAsStringSync();
    // Transparent world chunks stay out of the shadow pass.
    expect(renderer, contains('forShadow: Boolean = false'));
    expect(renderer, contains('mesh.castsShadow'));
    // Transparent instances blend far-to-near.
    expect(renderer, contains('sortedByDescending'));
    // The v1.6 cost increases are NOT ported.
    expect(renderer, isNot(contains('config(2)')));
    expect(renderer, contains('if(quality=="high")2f else 1f'));
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, isNot(contains('ImpellerBackend')));
  });
}
