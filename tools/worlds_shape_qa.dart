import 'dart:math' as math;
import 'dart:io';
import '../lib/game/content.dart';

void main() {
  final tracks = createTracks();
  var failures = 0;
  var minimum = double.infinity;
  for (var i = 0; i < tracks.length; i++) {
    final t = tracks[i];
    if (t.frames.any(
      (f) => f.p.x.abs() + t.width / 2 > 850 || f.p.z.abs() + t.width / 2 > 850,
    )) {
      stdout.writeln('BOUNDS ${t.id}');
      failures++;
    }
    for (var j = i + 1; j < tracks.length; j++) {
      var d = 0.0;
      for (var k = 0; k < 64; k++)
        d +=
            (t.at(k / 64 * t.length).p -
                    tracks[j].at(k / 64 * tracks[j].length).p)
                .length;
      d /= 64;
      minimum = math.min(d, minimum);
      if (d <= 75) {
        stdout.writeln('SIMILAR ${t.id} ${tracks[j].id}: $d');
        failures++;
      }
    }
  }
  stdout.writeln('Minimum difference: $minimum; failures: $failures');
  if (failures > 0) exitCode = 1;
}
