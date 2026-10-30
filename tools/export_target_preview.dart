import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/math3d.dart';

void main() {
  final out = Directory('gpu_qa_target')..createSync(recursive: true);
  void binary(String name, Float32List data) => File('${out.path}/$name.bin')
    .writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  final b = BattleEngine(arena: createBattleArenas().first, car: cars.first, freeRoam: true)..countdown = 0;
  final origin = b.arena.safeFloor(const V3(-160, .16, -320));
  b.player.position = origin; b.player.forward = const V3(0, 0, 1);
  for (var i = 0; i < b.bots.length; i++) {
    final d = b.bots[i];
    d.position = b.arena.safeFloor(origin + V3((i - 1) * 22.0, 0, 50 + i * 20.0));
    d.forward = const V3(0, 0, -1);
  }
  b.giveWeapon(b.player, BattlePower.homingMissile, 3);
  b.selectTarget(b.bots.first);
  binary(b.track.id, GpuResources.world(b.track));
  final meshes = [...GpuResources.objects, ...BattleGpuMeshes.objects];
  for (var i = 0; i < meshes.length; i++) { binary('object_$i', meshes[i]); }
  for (final shader in ['scene.vert', 'scene.frag', 'depth.vert', 'depth.frag']) {
    File('assets/shaders/$shader').copySync('${out.path}/$shader');
  }
  final frames = <Map<String, dynamic>>[];
  for (var i = 0; i < 2; i++) {
    frames.add({'name': 'mira_verde_${i + 1}', 'world': b.track.id, 'showroom': false,
      'night': b.track.night, 'frame': raceGpuFrame(b).toList()});
    b.cycleTarget();
  }
  File('${out.path}/frames.json').writeAsStringSync(jsonEncode(frames));
}
