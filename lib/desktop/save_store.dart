import 'dart:io';

/// Windows replacement for the Android SharedPreferences save slot.
///
/// The native side stores one JSON payload (at most 256000 characters)
/// under the key `save`. On Windows the same payload lives in a single
/// file: `<Documents>\CarWece\save.json`.
class DesktopSaveStore {
  DesktopSaveStore({Directory? documents}) : _documents = documents;

  static final DesktopSaveStore instance = DesktopSaveStore();

  final Directory? _documents;
  Future<File>? _fileFuture;

  /// The user's Documents folder, resolved the standard Windows way.
  static Directory resolveDocuments() {
    final profile = Platform.environment['USERPROFILE'];
    if (profile != null && profile.isNotEmpty) {
      return Directory(
        '$profile${Platform.pathSeparator}Documents',
      );
    }
    return Directory.current;
  }

  Future<File> _file() => _fileFuture ??= () async {
    final docs = _documents ?? resolveDocuments();
    final dir = Directory('${docs.path}${Platform.pathSeparator}CarWece');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}save.json');
  }();

  /// The stored payload, or null when no save exists yet — the same
  /// contract as the Android `load` method.
  Future<String?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// Persists [payload]. Returns false (and writes nothing) for payloads
  /// above the native 256000-character limit, mirroring the Android side.
  /// The write goes through a temporary file so a crash mid-write cannot
  /// truncate the previous save.
  Future<bool> write(String payload) async {
    if (payload.length > 256000) return false;
    try {
      final file = await _file();
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(payload, flush: true);
      await temp.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }
}
