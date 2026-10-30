import 'dart:io';
import '../lib/game/content.dart';

void main() {
  for (final t in createTracks()) {
    stdout.writeln(
      '${t.id}: barriers=${t.barriers.length} shortcuts=${t.shortcuts.length} ${t.shortcuts.map((s) => '${s.entryCheckpoint}->${s.exitCheckpoint}: ${s.length.toStringAsFixed(0)}/${(s.exitS - s.entryS).toStringAsFixed(0)}').join(',')}',
    );
  }
}
