import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'game/content.dart';
import 'game/engine.dart';
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
        data[key] is num
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
  String _audioScene = 'menu';
  SoundtrackController get soundtrack => _soundtrack ??= SoundtrackController();
  @override
  void dispose() {
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

  Future<void> load() async {
    try {
      final raw = await channel.invokeMethod<String>('load');
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        settings.restore(Map<String, dynamic>.from(data['settings'] ?? {}));
        coins = (data['coins'] as num?)?.toInt() ?? 0;
        races = (data['races'] as num?)?.toInt() ?? 0;
        wins = (data['wins'] as num?)?.toInt() ?? 0;
        final battleData = data['battle'] as Map? ?? {};
        battles = (battleData['played'] as num?)?.toInt() ?? 0;
        battleWins = (battleData['wins'] as num?)?.toInt() ?? 0;
        eliminations = (battleData['kills'] as num?)?.toInt() ?? 0;
        (battleData['records'] as Map? ?? {}).forEach((k, v) {
          if (v is num) battleRecords['$k'] = v.toInt();
        });
        selectedCar = ((data['car'] as num?)?.toInt() ?? 0).clamp(
          0,
          cars.length - 1,
        );
        ownedCars.addAll(List<String>.from(data['owned'] ?? []));
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
        (data['records'] as Map? ?? {}).forEach((k, v) {
          if (v is num) records['$k'] = v.toDouble();
        });
        (data['medals'] as Map? ?? {}).forEach((k, v) {
          if (v is num) medals['$k'] = v.toInt();
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
        await channel.invokeMethod('save', payload);
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
    final nextScene = enterMenu ? 'menu' : (scene ?? (racing ? 'race' : 'menu'));
    _audioScene = nextScene;
    try {
      _soundtrack ??= SoundtrackController();
      await channel.invokeMethod('audio', {
        'music': settings.music,
        'scene': nextScene,
        if (enterMenu) 'enterMenu': true,
        'shuffle': settings.musicShuffle,
        'effects': settings.effects,
        'speed': speed,
        'racing': racing,
        'turbo': turbo,
        if (event != null) 'event': event,
      });
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
