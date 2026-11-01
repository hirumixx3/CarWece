import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../lib/game/content.dart';
import '../lib/game/gpu_mesh.dart';

List<double> vec(dynamic p) => <double>[
  p.x as double,
  p.y as double,
  p.z as double,
];
Map<String, Object> signature(TrackSpec t) {
  final data = <String, Object>{
    'id': t.id,
    'name': t.name,
    'room': t.room,
    'colors': [t.accent, t.floor, t.wall],
    'width': t.width,
    'controls': t.controls.map(vec).toList(),
    'frames': t.frames
        .map(
          (f) => [
            vec(f.p),
            vec(f.right),
            vec(f.up),
            vec(f.forward),
            f.s,
            t.widthAt(f.s),
          ],
        )
        .toList(),
    'obstacles': t.obstacles
        .map(
          (o) => [
            vec(o.center),
            vec(o.size),
            o.color,
            o.visible,
            vec(o.right),
            vec(o.forward),
          ],
        )
        .toList(),
    'details': t.details
        .map((p) => [p.kind, vec(p.center), vec(p.size), p.color, p.solid])
        .toList(),
    'ramps': t.ramps
        .map((r) => [vec(r.frame.p), r.width, r.length, r.height])
        .toList(),
    'barriers': t.barriers
        .map(
          (b) => [
            vec(b.frame.p),
            vec(b.frame.right),
            b.kind,
            b.length,
            b.height,
          ],
        )
        .toList(),
    'shortcuts': t.shortcuts
        .map(
          (s) => [
            s.id,
            s.entryCheckpoint,
            s.exitCheckpoint,
            s.width,
            s.frames.map((f) => vec(f.p)).toList(),
          ],
        )
        .toList(),
  };
  final mesh = buildWorldMesh(t).buffer;
  return {
    'id': t.id,
    'content': sha256.convert(utf8.encode(jsonEncode(data))).toString(),
    'mesh': sha256.convert(mesh.buffer.asUint8List()).toString(),
  };
}

void main(List<String> args) {
  final records = <Map<String, Object>>[];
  for (final t in createTracks().take(26)) records.add(signature(t));
  for (final a in createBattleArenas()) records.add(signature(a.track));
  final output = File(args.first)..parent.createSync(recursive: true);
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(records));
  stdout.writeln(
    'Recorded ${records.length} unmodified track/arena content and mesh signatures.',
  );
  if (args.length > 1) {
    final baseline = jsonDecode(File(args[1]).readAsStringSync());
    if (jsonEncode(records) != jsonEncode(baseline)) {
      for (var i = 0; i < records.length; i++) {
        if (jsonEncode(records[i]) != jsonEncode(baseline[i]))
          stdout.writeln('CHANGED ${records[i]['id']}');
      }
      exitCode = 1;
    } else {
      stdout.writeln(
        'PASS: all 26 original circuits and all 11 arenas are byte-identical in geometry and content.',
      );
    }
  }
}
