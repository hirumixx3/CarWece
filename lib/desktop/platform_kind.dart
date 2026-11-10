import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// True only on the Windows desktop build.
///
/// Every desktop replacement for an Android platform channel is gated on
/// this flag, so Android behavior — and the headless test environment,
/// which runs on a non-Windows VM — stays exactly as before.
final bool isWindowsDesktop = !kIsWeb && _detectWindows();

bool _detectWindows() {
  try {
    return Platform.isWindows;
  } catch (_) {
    return false;
  }
}
