import 'dart:convert';
import 'dart:io';
import 'package:carwece/online/host/auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('carwece-auth-'),
  );
  tearDown(() async => directory.delete(recursive: true));

  Map<String, dynamic> snapshot() => {
    'accounts': [Account('Piloto', 'salt', 'hash').toJson()],
    'sessions': <String, dynamic>{},
  };

  test('Recover valid backup when accounts.json is absent', () async {
    await File(
      '${directory.path}/accounts.json.bak',
    ).writeAsString(jsonEncode(snapshot()));
    final auth = AuthStore(directory);
    await auth.load();
    expect(auth.accounts.keys, contains('piloto'));
  });

  test(
    'Recover backup when primary is valid JSON but has invalid structure',
    () async {
      await File(
        '${directory.path}/accounts.json',
      ).writeAsString('{"accounts":null}');
      await File(
        '${directory.path}/accounts.json.bak',
      ).writeAsString(jsonEncode(snapshot()));
      final auth = AuthStore(directory);
      await auth.load();
      expect(auth.accounts.keys, contains('piloto'));
    },
  );

  test(
    'Saving recovery must not replace good backup with broken primary',
    () async {
      await File('${directory.path}/accounts.json').writeAsString('broken');
      final backup = File('${directory.path}/accounts.json.bak');
      final valid = jsonEncode(snapshot());
      await backup.writeAsString(valid);
      final auth = AuthStore(directory);
      await auth.load();
      await auth.save();
      expect(jsonDecode(await backup.readAsString())['accounts'], isNotEmpty);
    },
  );
}
