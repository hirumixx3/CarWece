import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../game/content.dart';

String randomToken([int length = 32]) {
  final r = Random.secure();
  return base64UrlEncode(
    List.generate(length, (_) => r.nextInt(256)),
  ).replaceAll('=', '');
}

String tokenHash(String token) => sha256.convert(utf8.encode(token)).toString();

/// PBKDF2-HMAC-SHA256, 600,000 iterations. Runs in a worker isolate so login
/// cannot pause active matches. Passwords never enter the save file or logs.
String passwordKey(String password, String salt, int iterations) {
  final mac = Hmac(sha256, utf8.encode(password));
  var block = mac.convert([...base64Decode(salt), 0, 0, 0, 1]).bytes;
  final result = Uint8List.fromList(block);
  for (var i = 1; i < iterations; i++) {
    block = mac.convert(block).bytes;
    for (var j = 0; j < 32; j++) result[j] ^= block[j];
  }
  return base64Encode(result);
}

bool sameKey(String a, String b) {
  if (a.length != b.length) return false;
  var delta = 0;
  for (var i = 0; i < a.length; i++) delta |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  return delta == 0;
}

class Account {
  final String name, salt, hash;
  final int iterations;
  int coins = 0, played = 0, wins = 0;
  final Set<String> owned = {'rx7'};
  final Map<String, int> medals = {};
  final List<String> paid = [];
  Account(this.name, this.salt, this.hash, {this.iterations = 600000});
  int get stars => medals.values.fold(0, (a, b) => a + b);
  Map<String, dynamic> get profile => {
    'name': name,
    'coins': coins,
    'played': played,
    'wins': wins,
    'owned': owned.toList(),
    'stars': stars,
    'medals': medals,
  };
  Map<String, dynamic> toJson() => {
    ...profile,
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
    'paid': paid,
  };
  factory Account.read(Map<String, dynamic> m) {
    final a = Account(
      m['name'],
      m['salt'],
      m['hash'],
      iterations: m['iterations'],
    );
    a.coins = m['coins'];
    a.played = m['played'];
    a.wins = m['wins'];
    a.owned.addAll(List<String>.from(m['owned']));
    a.medals.addAll(Map<String, int>.from(m['medals']));
    a.paid.addAll(List<String>.from(m['paid'] ?? []));
    return a;
  }
}

class AuthFailure implements Exception {
  final String message;
  final int status;
  AuthFailure(this.message, [this.status = 400]);
}

class AuthStore {
  final Directory directory;
  final Map<String, Account> accounts = {};
  final Map<String, Map<String, dynamic>> sessions = {};
  final Set<String> _pendingNames = {};
  int _hashing = 0;
  bool _preserveBackup = false;
  Future<void> _writes = Future.value();
  AuthStore(this.directory);
  Future<void> load() async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/accounts.json');
    final backup = File('${file.path}.bak');
    if (!await file.exists() && !await backup.exists()) return;
    try {
      _restore(jsonDecode(await file.readAsString()));
      _preserveBackup = false;
    } catch (_) {
      // Includes missing files and schema/type failures, not just invalid JSON.
      _restore(jsonDecode(await backup.readAsString()));
      _preserveBackup = true;
    }
    _prune();
  }

  void _restore(dynamic m) {
    if (m is! Map || m['accounts'] is! List || m['sessions'] is! Map) {
      throw const FormatException('Banco de contas inválido.');
    }
    final restoredAccounts = <String, Account>{};
    for (final raw in m['accounts']) {
      final account = Account.read(Map<String, dynamic>.from(raw));
      restoredAccounts[account.name.toLowerCase()] = account;
    }
    final restoredSessions = <String, Map<String, dynamic>>{};
    (m['sessions'] as Map).forEach((key, raw) {
      final session = Map<String, dynamic>.from(raw);
      if (key is! String ||
          session['expires'] is! int ||
          session['user'] is! String) {
        throw const FormatException('Sessão inválida.');
      }
      restoredSessions[key] = session;
    });
    // Commit only after the entire snapshot has validated.
    accounts
      ..clear()
      ..addAll(restoredAccounts);
    sessions
      ..clear()
      ..addAll(restoredSessions);
  }

  void _prune() {
    final now = DateTime.now().millisecondsSinceEpoch;
    sessions.removeWhere((k, v) => v['expires'] < now);
  }

  Future<void> save() {
    _prune();
    final json = jsonEncode({
      'accounts': accounts.values.map((a) => a.toJson()).toList(),
      'sessions': sessions,
    });
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final file = File('${directory.path}/accounts.json'),
          tmp = File('${directory.path}/accounts.json.tmp');
      await tmp.writeAsString(json, flush: true);
      if (!_preserveBackup && await file.exists()) {
        await file.copy('${file.path}.bak');
      }
      await tmp.rename(file.path);
      _preserveBackup = false;
    });
    _writes = operation;
    return operation;
  }

  Future<Map<String, dynamic>> login(
    String name,
    String password, {
    bool register = false,
  }) async {
    name = name.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(name))
      throw AuthFailure('Use 3–20 letras, números ou _.');
    if (password.length < 8 || password.length > 128)
      throw AuthFailure('A senha precisa ter de 8 a 128 caracteres.');
    if (_hashing >= 2)
      throw AuthFailure(
        'Servidor ocupado. Tente novamente em alguns segundos.',
        429,
      );
    final key = name.toLowerCase();
    var a = accounts[key];
    if (register && (a != null || _pendingNames.contains(key)))
      throw AuthFailure('Esse nome já está em uso.', 409);
    if (register && accounts.length >= 5000)
      throw AuthFailure('Cadastro temporariamente indisponível.', 503);
    if (register) _pendingNames.add(key);
    _hashing++;
    try {
      final salt =
          a?.salt ?? base64Encode(base64Url.decode('${randomToken(24)}'));
      final iterations = a?.iterations ?? 600000;
      final hash = await Isolate.run(
        () => passwordKey(password, salt, iterations),
      );
      if (register) {
        a = Account(name, salt, hash);
        accounts[key] = a;
      } else if (a == null || !sameKey(a.hash, hash)) {
        throw AuthFailure('Usuário ou senha incorretos.', 401);
      }
      _prune();
      final old = sessions.entries
          .where((e) => e.value['user'] == key)
          .toList();
      while (old.length >= 5) sessions.remove(old.removeAt(0).key);
      final token = randomToken();
      sessions[tokenHash(token)] = {
        'user': key,
        'expires': DateTime.now()
            .add(const Duration(days: 7))
            .millisecondsSinceEpoch,
      };
      await save();
      return {'token': token, 'profile': a.profile};
    } finally {
      _hashing--;
      _pendingNames.remove(key);
    }
  }

  Account? authenticate(String token) {
    if (token.length > 100 || token.length < 32) return null;
    final s = sessions[tokenHash(token)];
    if (s == null || s['expires'] < DateTime.now().millisecondsSinceEpoch)
      return null;
    return accounts[s['user']];
  }

  Future<void> logout(String token) async {
    sessions.remove(tokenHash(token));
    await save();
  }

  Future<void> buy(Account a, String id) async {
    final matches = cars.where((c) => c.id == id);
    if (matches.isEmpty) throw AuthFailure('Carro desconhecido.');
    final c = matches.first;
    if (a.owned.contains(id)) return;
    if (a.coins < c.cost || a.stars < c.requiredStars)
      throw AuthFailure('Moedas ou estrelas insuficientes.');
    a.coins -= c.cost;
    a.owned.add(id);
    await save();
  }

  void reward(
    Account a,
    String match,
    int position,
    String map, {
    required bool battle,
    required bool eligible,
  }) {
    if (a.paid.contains(match)) return;
    a.paid.add(match);
    if (a.paid.length > 128) a.paid.removeAt(0);
    a.played++;
    if (eligible) {
      a.coins += switch (position) {
        1 => 1000,
        2 => 500,
        3 => 250,
        _ => 0,
      };
      if (position == 1) a.wins++;
      // Race stars follow the existing car requirements. Battle victories also
      // earn up to three stars per arena in this separate online career.
      final key = '${battle ? 'battle:' : ''}$map';
      a.medals[key] = max(a.medals[key] ?? 0, (4 - position).clamp(0, 3));
    }
  }
}

/// One private phone-hosted session. No passwords or persistent accounts.
class GuestAuthStore extends AuthStore {
  GuestAuthStore() : super(Directory.systemTemp);
  @override
  Future<void> load() async {}
  @override
  Future<void> save() async {}

  Map<String, dynamic> guest(String name, List<String> garage) {
    name = name.trim();
    if (name.length < 2 ||
        name.length > 20 ||
        RegExp(r'[\x00-\x1f\x7f<>]').hasMatch(name)) {
      throw AuthFailure('Escolha um nome de 2 a 20 caracteres.');
    }
    final key = name.toLowerCase();
    if (accounts.containsKey(key)) {
      throw AuthFailure('Já existe um piloto com esse nome nesta sessão.', 409);
    }
    if (accounts.length >= 24)
      throw AuthFailure('Sessão cheia. Crie outra sala.');
    final account = Account(name, '', '', iterations: 0);
    account.owned.addAll(garage.where((id) => cars.any((c) => c.id == id)));
    accounts[key] = account;
    final token = randomToken();
    sessions[tokenHash(token)] = {
      'user': key,
      'expires': DateTime.now()
          .add(const Duration(hours: 8))
          .millisecondsSinceEpoch,
    };
    return {
      'token': token,
      'profile': {...account.profile, 'guest': true},
    };
  }
}

class RequestLimiter {
  final Map<String, List<int>> _events = {};
  bool allow(String key, int limit, int seconds) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_events.length > 4096)
      _events.removeWhere((k, v) => v.isEmpty || v.last < now - 3600000);
    if (_events.length > 8192 && !_events.containsKey(key)) return false;
    final events = _events.putIfAbsent(key, () => []);
    events.removeWhere((n) => n < now - seconds * 1000);
    if (events.length >= limit) return false;
    events.add(now);
    return true;
  }
}
