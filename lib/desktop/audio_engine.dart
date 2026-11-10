import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import '../music.dart';
import 'music_director.dart';

/// media_kit-backed decoder for the desktop music director — the Windows
/// counterpart of the Kotlin `AndroidMusicBackend` (one MediaPlayer there,
/// one mpv instance here).
class MediaKitMusicBackend implements MusicBackend {
  final Player _player = Player();
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<Duration>? _durationSub;
  bool _prepared = false;
  double _level = .35;

  @override
  void load(
    Song track, {
    required int startMs,
    required void Function() ready,
    required void Function() completed,
    required void Function() failed,
  }) {
    release();
    var readySent = false;
    _durationSub = _player.stream.duration.listen((duration) {
      if (duration <= Duration.zero || readySent) return;
      readySent = true;
      _prepared = true;
      _player.setVolume(_level * 100);
      if (startMs > 0) {
        unawaited(
          _player.seek(Duration(milliseconds: startMs)).then((_) => ready()),
        );
      } else {
        ready();
      }
    });
    _completedSub = _player.stream.completed.listen((done) {
      if (done) completed();
    });
    _errorSub = _player.stream.error.listen((_) => failed());
    unawaited(
      _player
          .open(Media('asset:///assets/music/${track.id}.m4a'), play: false)
          .catchError((_) => failed()),
    );
  }

  @override
  void play() {
    if (_prepared) unawaited(_player.play());
  }

  @override
  void pause() {
    if (_prepared) unawaited(_player.pause());
  }

  @override
  void volume(double value) {
    _level = value.clamp(0.0, 1.0);
    unawaited(_player.setVolume(_level * 100));
  }

  @override
  int position() => _prepared ? _player.state.position.inMilliseconds : 0;

  @override
  void release() {
    unawaited(_durationSub?.cancel());
    unawaited(_completedSub?.cancel());
    unawaited(_errorSub?.cancel());
    _durationSub = null;
    _completedSub = null;
    _errorSub = null;
    _prepared = false;
    unawaited(_player.stop());
  }

  void dispose() {
    release();
    unawaited(_player.dispose());
  }
}

/// Engine hum and gameplay effects for Windows — mirrors `RushSynth`.
///
/// The Android synth renders PCM in real time; here the same formulas were
/// rendered ahead of time into `assets/sfx/` (see the generator values in
/// `RushSynth.render`): one loopable engine tone whose playback rate tracks
/// the car's speed, plus one-shot samples for each effect type.
class DesktopSynth {
  static const _eventTypes = <String, int>{
    'tap': 1,
    'pickup': 2,
    'lap': 2,
    'go': 2,
    'bump': 3,
    'land': 3,
    'boost': 4,
    'jump': 4,
    'item': 4,
    'shield': 4,
    'repair': 4,
    'missile': 4,
    'hit': 5,
    'explosion': 5,
    'finish': 6,
    'gun': 7,
    'laser': 8,
    'electric': 9,
  };

  /// Fundamental of `engine_loop.wav`; the Kotlin engine tone runs at
  /// `45 + speed * 125 (+ 30 turbo)` Hz, reproduced here via playback rate.
  static const _engineBaseHz = 85.0;

  Player? _engine;
  bool _engineOpened = false, _enginePlaying = false;
  final List<Player> _sfxPool = [];
  int _sfxNext = 0;

  bool _active = false;
  double _effects = .7, _speed = 0;
  bool _racing = false, _turbo = false;

  void setActive(bool value) {
    _active = value;
    _reconcileEngine();
  }

  void update(Map<String, dynamic> args) {
    final effects = args['effects'];
    if (effects is num) _effects = effects.toDouble().clamp(0.0, 1.0);
    final speed = args['speed'];
    _speed = speed is num ? speed.toDouble().clamp(0.0, 1.6) : 0;
    _racing = args['racing'] == true;
    _turbo = args['turbo'] == true;
    final event = args['event'];
    if (event is String) _playEvent(event);
    _reconcileEngine();
  }

  void _playEvent(String name) {
    final type = _eventTypes[name];
    if (type == null || !_active || _effects <= 0) return;
    if (_sfxPool.isEmpty) {
      _sfxPool.addAll(List.generate(4, (_) => Player()));
    }
    final player = _sfxPool[_sfxNext];
    _sfxNext = (_sfxNext + 1) % _sfxPool.length;
    unawaited(player.setVolume(_effects * 100));
    unawaited(player.open(Media('asset:///assets/sfx/sfx_$type.wav')));
  }

  void _reconcileEngine() {
    final shouldPlay = _active && _racing && _effects > 0;
    if (!shouldPlay) {
      if (_enginePlaying) {
        _enginePlaying = false;
        unawaited(_engine?.pause());
      }
      return;
    }
    final engine = _engine ??= Player();
    if (!_engineOpened) {
      _engineOpened = true;
      unawaited(engine.setPlaylistMode(PlaylistMode.loop));
      unawaited(
        engine.open(Media('asset:///assets/sfx/engine_loop.wav'), play: false),
      );
    }
    final frequency = 45 + _speed * 125 + (_turbo ? 30 : 0);
    unawaited(engine.setRate((frequency / _engineBaseHz).clamp(0.5, 3.0)));
    unawaited(engine.setVolume(_effects * 100));
    if (!_enginePlaying) {
      _enginePlaying = true;
      unawaited(engine.play());
    }
  }

  void close() {
    _enginePlaying = false;
    unawaited(_engine?.dispose());
    _engine = null;
    for (final player in _sfxPool) {
      unawaited(player.dispose());
    }
    _sfxPool.clear();
  }
}

/// The Windows audio hub: owns the music director and the synth, applies
/// the same lifecycle and intro gating `MainActivity` applies on Android,
/// and exposes the two entry points the Dart side already uses —
/// `GameStore.audio()` updates and `SoundtrackController` commands.
class DesktopAudio with WidgetsBindingObserver {
  DesktopAudio._();

  static final DesktopAudio instance = DesktopAudio._();

  MediaKitMusicBackend? _musicBackend;
  MusicDirector? _director;
  DesktopSynth? _synth;
  bool _foreground = true;
  bool _introPending = true;
  void Function(Map<String, dynamic> state)? _stateListener;

  MusicDirector get _music => _director!;
  DesktopSynth get _effects => _synth!;

  void _ensureInit() {
    if (_director != null) return;
    MediaKit.ensureInitialized();
    _musicBackend = MediaKitMusicBackend();
    _director = MusicDirector(
      tracks: songs,
      menuIds: [for (final song in menuSongs) song.id],
      raceIds: [for (final song in raceSongs) song.id],
      battleIds: [for (final song in battleSongs) song.id],
      backend: _musicBackend!,
      changed: (state) => _stateListener?.call(state),
    );
    _synth = DesktopSynth();
    WidgetsBinding.instance.addObserver(this);
    // Like MainActivity, nothing plays until the intro finishes and the
    // app is in the foreground; endIntro()/lifecycle drive activation.
  }

  // -- Lifecycle (mirrors MainActivity onResume/onPause/onStop) ----------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (!_introPending) _resumeAudio();
    } else {
      _foreground = false;
      _music.setActive(false);
      _music.setFocus(false);
      _effects.setActive(false);
      if (state == AppLifecycleState.detached) _music.suspend();
    }
  }

  void _resumeAudio() {
    _music.setActive(true);
    _music.setFocus(true);
    _effects.setActive(true);
  }

  // -- Intro gate (mirrors MainActivity's introPending flag) -------------

  bool get introPending => _introPending;

  void beginIntro() {
    _ensureInit();
    _introPending = true;
    _music.setActive(false);
    _music.setFocus(false);
    _effects.setActive(false);
  }

  void endIntro() {
    _ensureInit();
    _introPending = false;
    if (_foreground) _resumeAudio();
  }

  // -- SoundtrackController plumbing --------------------------------------

  void bindSoundtrack(void Function(Map<String, dynamic> state) listener) {
    _ensureInit();
    _stateListener = listener;
  }

  void unbindSoundtrack() {
    _stateListener = null;
  }

  /// Mirrors `RushMusic.command`, including the intro gate: while the
  /// intro is pending every command degrades to a plain status read.
  Map<String, dynamic> musicCommand(
    String action,
    Map<String, dynamic> args,
  ) {
    _ensureInit();
    if (_introPending || action == 'status') return _music.state();
    final sceneArg = args['scene'];
    if (sceneArg == 'race' || sceneArg == 'battle') {
      _music.setScene(sceneArg as String);
    }
    switch (action) {
      case 'select':
        final id = args['id'];
        if (id is String) _music.select(id);
      case 'next':
        _music.next();
      case 'toggle':
        _music.toggle();
      case 'play':
        _music.setUserPaused(false);
      case 'pause':
        _music.setUserPaused(true);
      case 'shuffle':
        _music.setShuffle(args['enabled'] != false);
    }
    return _music.state();
  }

  /// Mirrors the native `audio` method: synth + soundtrack updates,
  /// dropped entirely while the intro is pending.
  void updateAudio(Map<String, dynamic> args) {
    _ensureInit();
    if (_introPending) return;
    _effects.update(args);
    final music = args['music'];
    _music.setVolume(music is num ? music.toDouble() : .35);
    _music.setShuffle(args['shuffle'] != false);
    if (args['enterMenu'] == true) {
      _music.enterMenu();
    } else {
      final scene = args['scene'];
      _music.setScene(scene is String ? scene : 'menu');
    }
  }
}
