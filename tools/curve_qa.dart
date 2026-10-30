import 'dart:io';
import '../lib/game/content.dart';

void main() {
  for (final t in createTracks()) {
    var min = 1e9, atS = 0.0;
    for (var s = 0.0; s < t.length; s += 2) {
      final k = (t.at(s + 1).forward - t.at(s).forward).length;
      if (k > 1e-6 && 1 / k < min) {
        min = 1 / k;
        atS = s;
      }
    }
    stdout.writeln('${t.id}: radius=$min s=$atS floor=${t.isFloor(atS)}');
  }
}
