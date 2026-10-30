import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';

// Append all race grids and garage bodies to export_battle.dart's 121 scenes.
void main(List<String> args) {
  final root = Directory(args.first);
  final frames =
      jsonDecode(File('${root.path}/frames.json').readAsStringSync()) as List;
  void binary(String name, Float32List data) =>
      File('${root.path}/$name.bin').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  for (final t in createTracks()) {
    binary(t.id, GpuResources.world(t));
    final e = RaceEngine(track: t, car: cars.first);
    frames.add({
      'name': 'race_${t.id}',
      'world': t.id,
      'showroom': false,
      'night': t.night,
      'frame': raceGpuFrame(e).toList(),
    });
  }
  binary('showroom', GpuResources.showroom);
  for (final c in cars)
    frames.add({
      'name': 'garage_${c.id}',
      'world': 'showroom',
      'showroom': true,
      'night': false,
      'frame': garageGpuFrame(c, -.65).toList(),
    });
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(frames));
  stdout.writeln(
    'Exported ${frames.length} scenes, all race grids, arenas, and garage cars',
  );
}
