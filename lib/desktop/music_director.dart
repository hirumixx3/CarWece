import 'dart:math' as math;

import '../music.dart';

/// Decoder operations behind the desktop music director — the Dart mirror
/// of the Kotlin `MusicBackend` interface, so playlist and lifecycle rules
/// are identical on Android and Windows.
abstract class MusicBackend {
  void load(
    Song track, {
    required int startMs,
    required void Function() ready,
    required void Function() completed,
    required void Function() failed,
  });
  void play();
  void pause();
  void volume(double value);
  int position();
  void release();
}

/// Shuffle-bag / sequential picker for one scene — a direct port of the
/// Kotlin `MusicDeck`.
class MusicDeck {
  MusicDeck(this.ids, this._random);

  final List<String> ids;
  final math.Random _random;
  final List<String> _bag = [];

  void clear() => _bag.clear();

  void selected(String id) => _bag.remove(id);

  String? next(String? current, bool shuffle, Set<String> failed) {
    final available = ids.where((id) => !failed.contains(id)).toList();
    if (available.isEmpty) return null;
    if (!shuffle) {
      final start = current == null ? -1 : ids.indexOf(current);
      for (var offset = 1; offset <= ids.length; offset++) {
        final id = ids[(start + offset) % ids.length];
        if (!failed.contains(id)) return id;
      }
    }
    _bag.removeWhere(failed.contains);
    if (_bag.isEmpty) _bag.addAll(available..shuffle(_random));
    if (_bag.length > 1 && _bag.first == current) _bag.add(_bag.removeAt(0));
    if (_bag.length == 1 && _bag.first == current && available.length > 1) {
      _bag.clear();
      _bag.addAll(available.where((id) => id != current).toList()..shuffle(_random));
    }
    return _bag.removeAt(0);
  }
}

/// Scene playlists, shuffle, failure skipping and play/pause reconciliation
/// — a direct port of the Kotlin `MusicDirector`, emitting the same state
/// maps the Android music channel produces.
class MusicDirector {
  MusicDirector({
    required List<Song> tracks,
    required List<String> menuIds,
    required List<String> raceIds,
    required List<String> battleIds,
    required MusicBackend backend,
    math.Random? random,
    void Function(Map<String, dynamic> state)? changed,
  }) : _backend = backend,
       _changed = changed ?? _noop {
    final rng = random ?? math.Random();
    _catalog = {for (final track in tracks) track.id: track};
    _playlists = {'menu': menuIds, 'race': raceIds, 'battle': battleIds};
    _decks = {
      for (final entry in _playlists.entries) entry.key: MusicDeck(entry.value, rng),
    };
    assert(_catalog.length == tracks.length);
    assert(
      _playlists.values.every((ids) => ids.isNotEmpty && ids.length == ids.toSet().length),
    );
    assert(_playlists.values.expand((ids) => ids).toSet().length == tracks.length);
    assert(_playlists.values.expand((ids) => ids).every(_catalog.containsKey));
  }

  static void _noop(Map<String, dynamic> _) {}

  final MusicBackend _backend;
  final void Function(Map<String, dynamic> state) _changed;
  late final Map<String, Song> _catalog;
  late final Map<String, List<String>> _playlists;
  late final Map<String, MusicDeck> _decks;
  final Map<String, String> _lastPlayed = {};
  final Set<String> _failed = {};

  int _generation = 0;
  bool _ready = false, _loaded = false, _active = false, _focused = false;
  bool _closed = false, _playing = false;
  double _gain = .35, _duck = 1;
  int _startMs = 0;
  String? _error;

  String scene = 'menu';
  String? currentId;
  bool shuffle = true;
  bool userPaused = false;

  List<String> get _activeIds => _playlists[scene]!;
  MusicDeck get _deck => _decks[scene]!;

  /// Menu music is always shuffled, independently of the race/battle setting.
  bool get _sceneShuffle => scene == 'menu' || shuffle;

  String? _chooseNext() => _deck.next(_lastPlayed[scene], _sceneShuffle, _failed);

  Map<String, dynamic> state() => {
    'trackId': currentId,
    'scene': scene,
    'shuffle': shuffle,
    'userPaused': userPaused,
    'error': _error,
    'status': _error != null
        ? 'error'
        : (!_active || !_focused)
        ? 'waiting'
        : !_ready
        ? (_loaded ? 'loading' : 'idle')
        : _playing
        ? 'playing'
        : 'paused',
  };

  void _emit() {
    if (!_closed) _changed(state());
  }

  void setScene(String value) {
    if (_closed) return;
    final next = _playlists.containsKey(value) ? value : 'menu';
    if (scene == next) {
      _ensureLoaded();
      return;
    }
    scene = next;
    userPaused = false;
    _failed.clear();
    _error = null;
    _choose(_chooseNext());
  }

  /// One explicit return to the main menu, never a periodic audio update.
  void enterMenu() {
    if (_closed) return;
    if (scene != 'menu') {
      setScene('menu');
      return;
    }
    userPaused = false;
    _failed.clear();
    _error = null;
    _choose(_chooseNext());
  }

  void setVolume(double value) {
    if (_closed) return;
    final next = value.isFinite ? value.clamp(0.0, 1.0) : .35;
    if (_gain == next) return;
    _gain = next;
    _reconcile();
  }

  void setDuck(double value) {
    _duck = value.clamp(0.0, 1.0);
    _reconcile();
  }

  void setFocus(bool value) {
    if (_closed || _focused == value) return;
    _focused = value;
    _reconcile();
  }

  void setActive(bool value) {
    if (_closed) return;
    final returningToMenu = value && !_active && scene == 'menu' && currentId != null;
    _active = value;
    if (returningToMenu) {
      // Opening the app again while in a menu starts a fresh draw.
      _failed.clear();
      _error = null;
      _choose(_chooseNext());
    } else if (value) {
      _ensureLoaded();
    }
    _reconcile();
  }

  void setShuffle(bool value) {
    if (_closed || shuffle == value) return;
    shuffle = value;
    // Do not reset the independent menu shuffle bag.
    for (final entry in _decks.entries) {
      if (entry.key != 'menu') entry.value.clear();
    }
    _emit();
  }

  void select(String id) {
    if (_closed || !_activeIds.contains(id)) return;
    userPaused = false;
    _failed.remove(id);
    _deck.selected(id);
    _choose(id);
  }

  void next() {
    if (_closed) return;
    userPaused = false;
    if (_failed.containsAll(_activeIds)) _failed.clear();
    _choose(_deck.next(currentId, _sceneShuffle, _failed));
  }

  void setUserPaused(bool value) {
    if (_closed) return;
    userPaused = value;
    if (!userPaused && _error != null) {
      _failed.clear();
      _choose(currentId ?? _activeIds.first);
    } else {
      _ensureLoaded();
      _reconcile();
    }
  }

  void toggle() => setUserPaused(!userPaused);

  void _choose(String? id) {
    _generation++;
    _backend.release();
    _ready = false;
    _loaded = false;
    _playing = false;
    currentId = id;
    _startMs = 0;
    _error = null;
    if (id != null) _lastPlayed[scene] = id;
    if (id == null) {
      _error = 'Não foi possível iniciar a trilha. Toque em PULAR FAIXA para tentar novamente.';
      _emit();
      return;
    }
    _ensureLoaded();
    _emit();
  }

  void _ensureLoaded() {
    if (_closed || !_active || _loaded || _error != null) return;
    currentId ??= _chooseNext();
    final track = _catalog[currentId];
    if (track == null) return;
    _lastPlayed[scene] = track.id;
    _loaded = true;
    _ready = false;
    final token = ++_generation;
    try {
      _backend.load(
        track,
        startMs: _startMs,
        ready: () {
          if (!_closed && token == _generation) {
            _ready = true;
            _startMs = 0;
            _reconcile();
          }
        },
        completed: () {
          if (!_closed && token == _generation) {
            _choose(_deck.next(currentId, _sceneShuffle, _failed));
          }
        },
        failed: () => _fail(token),
      );
    } catch (_) {
      _fail(token);
    }
  }

  void _fail(int token) {
    if (_closed || token != _generation) return;
    final current = currentId;
    if (current != null) _failed.add(current);
    final next = _deck.next(currentId, _sceneShuffle, _failed);
    if (next != null) {
      _choose(next);
      return;
    }
    _generation++;
    _backend.release();
    _loaded = false;
    _ready = false;
    _playing = false;
    _error = 'Não foi possível iniciar a trilha. Toque em PULAR FAIXA para tentar novamente.';
    _emit();
  }

  void _reconcile() {
    if (_closed) return;
    try {
      if (_ready) _backend.volume(_gain * _duck);
      final shouldPlay = _active && _focused && _ready && _gain > 0 && !userPaused;
      if (shouldPlay && !_playing) {
        _playing = true;
        _backend.play();
      } else if (!shouldPlay && _playing) {
        _playing = false;
        _backend.pause();
      }
    } catch (_) {
      _fail(_generation);
      return;
    }
    _emit();
  }

  /// Release the decoder, retaining the track and its seek position —
  /// the same contract as the Kotlin `suspend` used from `onStop`.
  void suspend() {
    if (_closed) return;
    _active = false;
    if (_loaded) {
      if (_ready) {
        try {
          final position = _backend.position();
          _startMs = position < 0 ? 0 : position;
        } catch (_) {
          _startMs = 0;
        }
      }
      _generation++;
      _backend.release();
      _loaded = false;
      _ready = false;
      _playing = false;
    }
    _emit();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _generation++;
    _backend.release();
    _loaded = false;
    _ready = false;
    _playing = false;
  }
}
