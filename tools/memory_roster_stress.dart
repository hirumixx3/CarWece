import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../lib/game/content.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/gpu_mesh.dart';

Future<void> main() async {
  final raw = Directory('build/memory_tracks_qa');
  final stress = Directory('build/memory_roster_stress')
    ..createSync(recursive: true);
  final sizes = <(int, int)>[];
  for (var body = 0; body < cars.length; body++) {
    final id = body;
    final bytes = await Isolate.run(
      () =>
          2 * buildCarMesh(cars[id]).buffer.lengthInBytes +
          buildWheelMesh(cars[id]).buffer.lengthInBytes,
    );
    sizes.add((bytes, body));
  }
  sizes.sort((a, b) => b.$1.compareTo(a.$1));
  final largest = sizes.take(6).map((r) => r.$2).toSet();
  final meshes = await Isolate.run(() => GpuResources.objectsFor(largest));
  for (var i = 0; i < meshes.length; i++) {
    final data = meshes[i];
    File('${stress.path}/object_$i.bin').writeAsBytesSync(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }
  for (final file in raw.listSync().whereType<File>()) {
    if (file.path.endsWith('.bin') &&
        !file.uri.pathSegments.last.startsWith('object_')) {
      final link = Link('${stress.path}/${file.uri.pathSegments.last}');
      if (link.existsSync()) link.deleteSync();
      link.createSync(file.absolute.path);
    }
  }
  final result = {
    'scope':
        'Synthetic worst six-car geometry inventory, not a gameplay opponent selection',
    'cars': [
      for (final id in largest) {'id': cars[id].id, 'body': id},
    ],
    'objectsBytes': meshes.fold<int>(0, (n, d) => n + d.lengthInBytes),
  };
  File(
    'verification/correcao_memoria_25/pior_inventario.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(jsonEncode(result));
}
