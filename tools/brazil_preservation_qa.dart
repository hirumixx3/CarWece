import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../lib/game/content.dart';
import '../lib/game/gpu_mesh.dart';
import 'track_revision_qa.dart' as tracks;

void main(List<String> args) {
  String hash(List<int> bytes) => sha256.convert(bytes).toString();
  final oldTracks = createTracks().take(51).toList();
  final result = <String, Object>{
    'tracks': [for (final t in oldTracks) tracks.signature(t)],
    'arenas': [for (final a in createBattleArenas()) tracks.signature(a.track)],
    'cars': [
      for (final c in cars.take(56))
        {
          'id': c.id,
          'name': c.name,
          'tag': c.tag,
          'description': c.description,
          'spec': [
            c.color,
            c.accent,
            c.speed,
            c.acceleration,
            c.handling,
            c.cost,
            c.body,
            c.drive.name,
            c.requiredStars,
            c.tier,
          ],
          'design': [
            c.design.halfLength,
            c.design.halfWidth,
            c.design.belt,
            c.design.roof,
            c.design.roofFront,
            c.design.roofRear,
            c.design.glassFront,
            c.design.glassRear,
            c.design.frontAxle,
            c.design.rearAxle,
            c.design.wheelRadius,
            c.design.spokes,
            c.design.rimColor,
            c.design.sedan,
            c.design.hatch,
          ],
          'body': hash(buildCarMesh(c).buffer.buffer.asUint8List()),
          'wheel': hash(buildWheelMesh(c).buffer.buffer.asUint8List()),
        },
    ],
  };
  final out = File(args.first)..parent.createSync(recursive: true);
  out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  if (args.length > 1) {
    final baseline = jsonDecode(File(args[1]).readAsStringSync());
    final nowTracks = result['tracks'] as List,
        beforeTracks = baseline['tracks'] as List;
    for (var i = 0; i < 51; i++) {
      if (nowTracks[i]['content'] != beforeTracks[i]['content'])
        throw StateError('Old track physics changed: ${oldTracks[i].id}');
      if (i < 26 && nowTracks[i]['mesh'] != beforeTracks[i]['mesh'])
        throw StateError('Original track mesh changed: ${oldTracks[i].id}');
    }
    if (jsonEncode(result['arenas']) != jsonEncode(baseline['arenas']))
      throw StateError('Arena changed');
    if (jsonEncode(result['cars']) != jsonEncode(baseline['cars']))
      throw StateError('Previous car changed');
    stdout.writeln(
      'PASS: all 51 previous physical routes, all 11 arenas, all 56 previous cars preserved.',
    );
    stdout.writeln(
      'PASS: original 26 room meshes preserved; only the requested outdoor floor overlay was removed.',
    );
  } else {
    stdout.writeln(
      'Recorded baseline: 51 tracks, 11 arenas, 56 cars with chassis and wheel hashes.',
    );
  }
}
