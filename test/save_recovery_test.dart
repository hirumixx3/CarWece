import 'dart:async';
import 'dart:convert';
import 'package:carwece/game/content.dart';
import 'package:carwece/platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = GameStore.channel;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'Malformed optional fields do not discard valid garage and records',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'load'
            ? jsonEncode({
                'progressionVersion': 2,
                'coins': 'broken',
                'races': -12,
                'wins': [],
                'car': {},
                'settings': [],
                'battle': 'broken',
                'owned': ['rx7', 'ek9', 45, null],
                'carId': 'ek9',
                'records': {'valid': 60, 'negative': -1, 'text': 'oops'},
                'medals': {'bedroom': 99, 'garage': -3, 'bad': []},
              })
            : null,
      );
      final store = GameStore();
      await store.load();
      expect(store.ownedCars, contains('ek9'));
      expect(cars[store.selectedCar].id, 'ek9');
      expect(store.records, {'valid': 60.0});
      expect(store.medals['bedroom'], 3);
      expect(store.medals['garage'], 0);
      expect(store.coins, 0);
      expect(store.races, 0);
      expect(store.wins, 0);
      expect(store.saveError, isNull);
      store.dispose();
    },
  );

  test('Non-finite settings fall back instead of becoming maximum values', () {
    final settings = GameSettings()
      ..restore({
        'music': double.nan,
        'effects': double.infinity,
        'sensitivity': double.negativeInfinity,
        'camera': double.nan,
      });
    expect(settings.music, .35);
    expect(settings.effects, .7);
    expect(settings.sensitivity, 1);
    expect(settings.cameraDistance, 1);
  });

  test(
    'Lifecycle save waits for pending load and never writes empty progress',
    () async {
      final pending = Completer<String>();
      final writes = <Map<String, dynamic>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'load') return pending.future;
        if (call.method == 'save')
          writes.add(jsonDecode(call.arguments as String));
        return null;
      });
      final store = GameStore();
      final loading = store.load();
      final saving = store.save();
      await Future<void>.delayed(Duration.zero);
      expect(writes, isEmpty);
      pending.complete(jsonEncode({'progressionVersion': 2, 'coins': 999}));
      await loading;
      await saving;
      expect(writes.single['coins'], 999);
      store.dispose();
    },
  );

  test('Concurrent load calls share one platform request', () async {
    var loads = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'load') {
        loads++;
        return '{}';
      }
      return null;
    });
    final store = GameStore();
    await Future.wait([store.load(), store.load()]);
    expect(loads, 1);
    store.dispose();
  });

  test(
    'Pending load can finish after store disposal without notifying',
    () async {
      final pending = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (_) => pending.future);
      final store = GameStore();
      final loading = store.load();
      store.dispose();
      pending.complete('{}');
      await expectLater(loading, completes);
    },
  );
}
