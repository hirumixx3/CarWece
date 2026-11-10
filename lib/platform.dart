import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'game/content.dart';
import 'game/engine.dart';
import 'desktop/audio_engine.dart';
import 'desktop/platform_kind.dart';
import 'desktop/save_store.dart';
import 'hud_layout.dart';
import 'music.dart';

class GameSettings {
  bool autoAccelerate = false, vibration = true, showFps = false;
  String difficulty = 'normal', quality = 'auto';
  String battleDifficulty = 'normal';
  String onlineEndpoint = '', onlineUsername = '';
  double music = .35, effects = .7, sensitivity = 1, cameraDistance = 1;
  bool musicShuffle = true;
  HudLayout hud = HudLayout();
  Map<String, dynamic> toJson() => {
    'auto': autoAccelerate,
    'controlsVersion': 3,
    'vibration': vibration,
    'fps': showFps,
    'difficulty': difficulty,
    'battleDifficulty': battleDifficulty,
    'onlineEndpoint': onlineEndpoint,
    'onlineUsername': onlineUsername,
    'quality': quality,
    'graphicsVersion': 2,
    'music': music,
    'musicShuffle': musicShuffle,
    'effects': effects,
    'sensitivity': sensitivity,
    'camera': cameraDistance,
    'hud': hud.toJson(),
  };
  void restore(Map<String, dynamic> data) {
    if (data['onlineEndpoint'] is String)
      onlineEndpoint = data['onlineEndpoint'];
    if (data['onlineUsername'] is String)
      onlineUsername = data['onlineUsername'];
    autoAccelerate = data['controlsVersion'] == 3 && data['auto'] == true;
    vibration = data['vibration'] != false;
    showFps = data['fps'] == true;
    if (['easy', 'normal', 'hard'].contains(data['difficulty']))
      difficulty = data['difficulty'];
    if (['easy', 'normal', 'hard'].contains(data['battleDifficulty']))
      battleDifficulty = data['battleDifficulty'];
    if (data['graphicsVersion'] == 2 &&
        ['auto', 'low', 'medium', 'high'].contains(data['quality']))
      quality = data['quality'];
    double number(String key, double fallback, double min, double max) =>
        data[key] is num && (data[key] as num).isFinite
        ? (data[key] as num).toDouble().clamp(min, max)
        : fallback;
    music = number('music', .35, 0, 1);
    musicShuffle = data['musicShuffle'] != false;
    effects = number('effects', .7, 0, 1);
    sensitivity = number('sensitivity', 1, .5, 1.6);
    cameraDistance = number('camera', 1, .8, 1.4);
    hud = HudLayout.restore(data['hud']);
  }
}

class GameStore extends ChangeNotifier {
  static const channel = MethodChannel('com.hirumisu.carwece/native');
  final settings = GameSettings();
  SoundtrackController? _soundtrack;
  Future<void>? _loadFuture;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String _audioScene = 'menu';
  SoundtrackController get soundtrack => _soundtrack ??= SoundtrackController();
  @override
  void dispose() {
    _disposed = true;
    _soundtrack?.dispose();
    super.dispose();
  }

  int coins = 0, races = 0, wins = 0, selectedCar = 0;
  int battles = 0, battleWins = 0, eliminations = 0;
  final Map<String, int> battleRecords = {};
  final Set<String> ownedCars = {'rx7'};
  final Map<String, double> records = {};
  final Map<String, int> medals = {};
  bool ready = false;
  String? saveError;
  Future<void> _saveQueue = Future.value();
  int lastStarsEarned = 0;
  int get stars => medals.values.fold(0, (sum, v) => sum + v.clamp(0, 3));
  bool trackUnlocked(TrackSpec t) => stars >= t.requiredStars;
  bool carEligible(CarSpec car) => stars >= car.requiredStars;
  String trackRequirement(TrackSpec t) =>
      '${t.requiredStars} ★ NA CARREIRA • VOCÊ TEM $stars';
  String carRequirement(CarSpec car) => carEligible(car)
      ? '${car.tier} • ${car.cost} MOEDAS'
      : '${car.tier} • REQUER ${car.requiredStars} ★ (VOCÊ TEM $stars)';

  Future<void> load() => _loadFuture ??= _load();

  // Optional sections are recovered independently: one malformed value must
  // never discard valid purchases, times or the selected car.
  static Map<String, dynamic> _map(Object? value) => value is Map
      ? {
          for (final entry in value.entries)
            if (entry.key is String) entry.key as String: entry.value,
        }
      : {};
  static int _count(Object? value) => value is num && value.isFinite
      ? value.toInt().clamp(0, 0x7fffffffffffffff)
      : 0;

  Future<void> _load() async {
    try {
      final raw = isWindowsDesktop
          ? await DesktopSaveStore.instance.read()
          : await channel.invokeMethod<String>('load');
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        settings.restore(_map(data['settings']));
        coins = _count(data['coins']);
        races = _count(data['races']);
        wins = _count(data['wins']);
        final battleData = _map(data['battle']);
        battles = _count(battleData['played']);
        battleWins = _count(battleData['wins']);
        eliminations = _count(battleData['kills']);
        _map(battleData['records']).forEach((k, v) {
          if (v is num && v.isFinite && v >= 0) battleRecords[k] = _count(v);
        });
        selectedCar = _count(data['car']).clamp(0, cars.length - 1);
        if (data['owned'] is List) {
          ownedCars.addAll((data['owned'] as List).whereType<String>());
        }
        // Previous versions gave four starters. Preserve every existing grant.
        if (data['progressionVersion'] != 2) {
          ownedCars.addAll(['rx7', 'evo9', 'r34', '350z']);
        }
        const legacyCars = {
          'spark': 'rx7',
          'viper': 'evo9',
          'volt': 'r34',
          'phantom': '350z',
        };
        for (final entry in legacyCars.entries) {
          if (ownedCars.contains(entry.key)) ownedCars.add(entry.value);
        }
        if (data['carId'] is String) {
          final index = cars.indexWhere((c) => c.id == data['carId']);
          if (index >= 0) selectedCar = index;
        }
        _map(data['records']).forEach((k, v) {
          if (v is num && v.isFinite && v > 0) records[k] = v.toDouble();
        });
        _map(data['medals']).forEach((k, v) {
          if (v is num && v.isFinite) medals[k] = v.toInt().clamp(0, 3);
        });
        if (!ownedCars.contains(cars[selectedCar].id)) selectedCar = 0;
      }
    } on MissingPluginException {
      /* Headless tests have no Android channel. */
    } catch (_) {
      saveError = 'Não foi possível ler o progresso anterior.';
    }
    ready = true;
    notifyListeners();
  }

  Future<void> save() {
    // Android can pause while its asynchronous initial read is still pending.
    // Wait before capturing the payload, otherwise defaults overwrite progress.
    final loading = _loadFuture;
    if (loading != null && !ready) return loading.then((_) => save());
    final payload = jsonEncode({
      'version': 1,
      'progressionVersion': 2,
      'settings': settings.toJson(),
      'coins': coins,
      'races': races,
      'wins': wins,
      'battle': {
        'played': battles,
        'wins': battleWins,
        'kills': eliminations,
        'records': battleRecords,
      },
      'car': selectedCar,
      'carId': cars[selectedCar].id,
      'owned': ownedCars.toList(),
      'records': records,
      'medals': medals,
    });
    _saveQueue = _saveQueue.then((_) async {
      try {
        if (isWindowsDesktop) {
          if (!await DesktopSaveStore.instance.write(payload)) {
            saveError = 'Não foi possível salvar. Tente novamente.';
            notifyListeners();
            return;
          }
        } else {
          await channel.invokeMethod('save', payload);
        }
        saveError = null;
      } on MissingPluginException {
        /* Test platform. */
      } catch (_) {
        saveError = 'Não foi possível salvar. Tente novamente.';
        notifyListeners();
      }
    });
    return _saveQueue;
  }

  void changed() {
    notifyListeners();
    unawaited(save());
  }

  bool buyCar(CarSpec car) {
    if (ownedCars.contains(car.id)) return true;
    if (!carEligible(car) || coins < car.cost) return false;
    coins -= car.cost;
    ownedCars.add(car.id);
    changed();
    return true;
  }

  String recordKey(TrackSpec track, RaceMode mode) =>
      '${track.id}:${mode.name}:layout7';

  void record(TrackSpec track, RaceResult result, RaceMode mode) {
    final before = stars;
    coins += result.coins;
    races++;
    if (result.position == 1 && mode != RaceMode.timeTrial) wins++;
    final key = recordKey(track, mode);
    if (!records.containsKey(key) || result.time < records[key]!)
      records[key] = result.time;
    if (mode != RaceMode.timeTrial)
      medals[track.id] =
          (medals[track.id] ?? 0) > (4 - result.position).clamp(0, 3)
          ? medals[track.id]!
          : (4 - result.position).clamp(0, 3);
    lastStarsEarned = stars - before;
    changed();
  }

  void recordBattle(BattleEngine battle) {
    if (battle.freeRoam || !battle.finished || battle.rewardRecorded) return;
    battle.rewardRecorded = true;
    battles++;
    coins += battle.reward;
    eliminations += battle.human.kills;
    if (battle.result?.position == 1 && battle.human.alive) battleWins++;
    final id = battle.arena.track.id;
    if (battle.human.kills > (battleRecords[id] ?? 0))
      battleRecords[id] = battle.human.kills;
    lastStarsEarned = 0;
    changed();
  }

  Future<void> audio({
    double speed = 0,
    bool racing = false,
    bool turbo = false,
    String? event,
    String? scene,
    bool enterMenu = false,
  }) async {
    final nextScene = enterMenu
        ? 'menu'
        : (scene ?? (racing ? 'race' : 'menu'));
    _audioScene = nextScene;
    try {
      _soundtrack ??= SoundtrackController();
      final args = <String, dynamic>{
        'music': settings.music,
        'scene': nextScene,
        if (enterMenu) 'enterMenu': true,
        'shuffle': settings.musicShuffle,
        'effects': settings.effects,
        'speed': speed,
        'racing': racing,
        'turbo': turbo,
        if (event != null) 'event': event,
      };
      if (isWindowsDesktop) {
        DesktopAudio.instance.updateAudio(args);
        return;
      }
      await channel.invokeMethod('audio', args);
    } on MissingPluginException {
      /* Not available in widget tests. */
    } catch (_) {
      /* Audio must never interrupt a race. */
    }
  }

  void tap() {
    // Button sound effects must not switch a paused race or battle to menu music.
    unawaited(audio(event: 'tap', scene: _audioScene));
  }

  void haptic() {
    if (settings.vibration) unawaited(HapticFeedback.lightImpact());
  }
}
