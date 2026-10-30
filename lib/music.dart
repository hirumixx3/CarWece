import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Song {
  final String id, title, artist;
  final int durationMs;
  const Song(this.id, this.title, this.artist, this.durationMs);
  String get durationLabel => '${durationMs ~/ 60000}:${((durationMs ~/ 1000) % 60).toString().padLeft(2, '0')}';
}

const songs = <Song>[
  Song("menu_01", "Burned Track", "CarWece Original", 174720),
  Song("menu_02", "Heroes Departure", "CarWece Original", 201240),
  Song("menu_03", "Let's run", "CarWece Original", 193992),
  Song("menu_04", "Waiting on the road", "CarWece Original", 182808),
  Song("menu_05", "Get ready", "CarWece Original", 187632),
  Song("race_01", "Hot Speed", "CarWece Original", 181200),
  Song("race_02", "Hot Track", "CarWece Original", 151488),
  Song("race_03", "Corridors of Fire", "CarWece Original", 134928),
  Song("race_04", "High Speed", "CarWece Original", 131232),
  Song("race_05", "Running for life", "CarWece Original", 178800),
  Song("race_06", "Dangerous race", "CarWece Original", 163632),
  Song("race_07", "Victory in Speed", "CarWece Original", 152400),
  Song("race_08", "I want to run", "CarWece Original", 176688),
  Song("race_09", "Flying Down the Road", "CarWece Original", 169920),
  Song("race_10", "Long Night", "CarWece Original", 158832),
  Song("race_11", "Endless Dawn", "CarWece Original", 178800),
  Song("race_12", "Fierceness on the Track", "CarWece Original", 188040),
  Song("race_13", "Winding Track", "CarWece Original", 183240),
  Song("race_14", "Running in the Storm", "CarWece Original", 165528),
  Song("race_15", "Crown of the Winners", "CarWece Original", 188040),
  Song("battle_01", "Survivor", "CarWece Original", 188328),
  Song("battle_02", "End Times", "CarWece Original", 183648),
  Song("battle_03", "Final Battle", "CarWece Original", 151560),
  Song("battle_04", "Go get 'em", "CarWece Original", 179040),
  Song("battle_05", "Be the last one", "CarWece Original", 151632),
];
const menuSongId = 'menu_01';
final menuSongs = List<Song>.unmodifiable(songs.where((s) => s.id.startsWith('menu_')));
final raceSongs = List<Song>.unmodifiable(songs.where((s) => s.id.startsWith('race_')));
final battleSongs = List<Song>.unmodifiable(songs.where((s) => s.id.startsWith('battle_')));
Song? songById(String? id) {
  for (final song in songs) { if (song.id == id) return song; }
  return null;
}
/// Native state is authoritative, including completion, focus and backgrounding.
class SoundtrackController extends ChangeNotifier {
  static const channel = MethodChannel('com.hirumisu.carwece/music');
  String? trackId, error;
  String scene = 'menu', status = 'idle';
  bool shuffle = true, userPaused = false, _disposed = false;
  Song? get current => songById(trackId);
  bool get playing => status == 'playing';
  SoundtrackController() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'state') _apply(call.arguments);
    });
    unawaited(refresh());
  }
  void _apply(dynamic raw) {
    if (_disposed || raw is! Map) return;
    final id = raw['trackId'] is String ? raw['trackId'] as String : null;
    final nextId = songById(id)?.id;
    final nextScene = ['race', 'battle'].contains(raw['scene']) ? raw['scene'] as String : 'menu';
    final nextStatus =
        [
          'idle',
          'loading',
          'playing',
          'paused',
          'waiting',
          'error',
        ].contains(raw['status'])
        ? raw['status'] as String
        : 'idle';
    final nextShuffle = raw['shuffle'] != false,
        nextPaused = raw['userPaused'] == true;
    final nextError = raw['error'] is String ? raw['error'] as String : null;
    if (trackId == nextId &&
        scene == nextScene &&
        status == nextStatus &&
        shuffle == nextShuffle &&
        userPaused == nextPaused &&
        error == nextError)
      return;
    trackId = nextId;
    scene = nextScene;
    status = nextStatus;
    shuffle = nextShuffle;
    userPaused = nextPaused;
    error = nextError;
    notifyListeners();
  }

  Future<void> _command(
    String action, [
    Map<String, dynamic> extra = const {},
  ]) async {
    try {
      final state = await channel.invokeMethod<dynamic>(action, extra);
      _apply(state);
    } on MissingPluginException {
      // Desktop widget tests and the compatibility renderer have no audio codec.
    } catch (_) {
      if (!_disposed) {
        error = 'Não foi possível controlar a música. Tente novamente.';
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => _command('status');
  Future<void> select(String id) async {
    if (raceSongs.any((s) => s.id == id) || battleSongs.any((s) => s.id == id))
      await _command('select', {'id': id, 'scene': scene});
  }

  Future<void> next() => _command('next', {'scene': scene});
  Future<void> toggle() =>
      _command(playing ? 'pause' : 'play', {'scene': scene});
  Future<void> setShuffle(bool enabled) =>
      _command('shuffle', {'enabled': enabled, 'scene': scene});
  @override
  void dispose() {
    _disposed = true;
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
