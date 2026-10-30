import 'dart:io';
import '../lib/game/content.dart';

void main() {
  for (final t in createTracks()) {
    var minRadius = double.infinity, minGap = double.infinity;
    var description = '', radiusAt = '';
    for (var s = 0.0; s < t.length; s += 2) {
      final a = t.at(s), b = t.at(s + 1);
      final curvature = (a.forward - b.forward).length;
      if (curvature > 1e-7 && 1 / curvature < minRadius) {
        minRadius = 1 / curvature;
        radiusAt = '$s';
      }
      for (var q = s + t.width * 2; q < t.length; q += 2) {
        if (t.length - q + s < t.width * 2) continue;
        final c = t.at(q), delta = c.p - a.p;
        // Road ribbons on crossing paths need 5+ units vertical clearance.
        if (delta.length < minGap) {
          minGap = delta.length;
          description = '$s / $q';
        }
      }
    }
    stdout.writeln(
      '${t.id}: length=${t.length} minRadius=$minRadius at $radiusAt minSeparatedCenterGap=$minGap at $description',
    );
    if (t.loopStart != null) {
      final a = t.at(t.loopStart!), b = t.at(t.loopEnd!);
      stdout.writeln(
        'loop ${t.loopStart}..${t.loopEnd}, bottom gap=${(a.p - b.p).length} dot=${a.forward.dot(b.forward)}',
      );
    }
  }
}
