import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../../game/content.dart';
import '../../game/engine.dart';
import '../protocol.dart';
import 'auth.dart';

class OnlinePeer {
  final Account account;
  final WebSocket socket;
  final String token;
  int inputSeq = -1, lastSent = 0, acked = 0;
  DateTime inputAt = DateTime.now();
  OnlinePeer(this.account, this.socket, this.token);
  String get key => account.name.toLowerCase();
  void send(Map<String, dynamic> m) {
    try {
      if (socket.readyState == WebSocket.open) socket.add(jsonEncode(m));
    } on StateError {
      /* A disconnect can race a broadcast. */
    } on SocketException {
      /* The stream's close handler releases the peer. */
    }
  }
}

class RoomMember {
  final Account account;
  int car;
  bool ready = false, left = false;
  DateTime? disconnectedAt;
  RoomMember(this.account, this.car);
  String get key => account.name.toLowerCase();
}

class OnlineRoom {
  final String code, id, kind, map;
  final bool public;
  String host, phase = 'lobby';
  final List<RoomMember> members = [];
  final Set<String> forfeits = {};
  final Map<String, Map<String, dynamic>> results = {};
  RaceEngine? engine;
  List<RoomMember> grid = [];
  DateTime changed = DateTime.now();
  double firstFinish = -1;
  int sequence = 0, seed = 0;
  bool finalizing = false;
  OnlineRoom(this.code, this.id, this.kind, this.map, this.host, this.public);
  Map<String, dynamic> info(Map<String, OnlinePeer> peers) => {
    'code': code,
    'kind': kind,
    'map': map,
    'host': host,
    'phase': phase,
    'public': public,
    'players': [
      for (final m in members.where((m) => !m.left))
        {
          'name': m.account.name,
          'car': m.car,
          'connected': peers.containsKey(m.key),
          'ready': m.ready,
        },
    ],
  };
  Map<String, dynamic> launch() => {
    'type': 'launch',
    'id': id,
    'kind': kind,
    'map': map,
    'seed': seed,
    'players': [
      for (final m in grid) {'name': m.account.name, 'car': m.car},
    ],
  };
}

class CarWeceServer {
  final AuthStore auth;
  final bool trustProxy;
  final int maxRooms;
  final String? friendCode;
  final tracks = createTracks(), arenas = createBattleArenas();
  final Map<String, OnlinePeer> peers = {};
  final Map<String, OnlineRoom> rooms = {}, membership = {};
  final RequestLimiter limiter = RequestLimiter();
  HttpServer? http;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  double _previous = 0, _snapshotAt = 0, _maintenanceAt = 0;
  CarWeceServer(
    this.auth, {
    this.trustProxy = false,
    this.maxRooms = 4,
    this.friendCode,
  });
  Future<int> start({
    int port = 8080,
    String address = '0.0.0.0',
    bool ticking = true,
    SecurityContext? tls,
  }) async {
    await auth.load();
    http = tls == null
        ? await HttpServer.bind(address, port)
        : await HttpServer.bindSecure(address, port, tls);
    http!.idleTimeout = const Duration(seconds: 30);
    http!.listen(
      (request) => unawaited(_request(request)),
      onError: (Object _) {
        /* A rejected TLS handshake must not kill the host. */
      },
    );
    _clock.start();
    if (ticking)
      _timer = Timer.periodic(const Duration(milliseconds: 8), (_) => tick());
    return http!.port;
  }

  Future<void> close() async {
    _timer?.cancel();
    await Future.wait(
      peers.values.toList().map((p) async {
        try {
          await p.socket
              .close(1001, 'Servidor encerrado')
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
      }),
    );
    await http?.close(force: true);
    await auth.save();
  }

  String _token(HttpRequest r) =>
      (r.headers.value(HttpHeaders.authorizationHeader) ?? '').replaceFirst(
        RegExp(r'^Bearer '),
        '',
      );
  String _ip(HttpRequest r) => trustProxy
      ? (r.headers.value('x-real-ip') ??
            r.connectionInfo?.remoteAddress.address ??
            'unknown')
      : r.connectionInfo?.remoteAddress.address ?? 'unknown';
  Future<Map<String, dynamic>> _body(HttpRequest r) async {
    final bytes = <int>[];
    await for (final b in r.timeout(const Duration(seconds: 10))) {
      bytes.addAll(b);
      if (bytes.length > 4096) throw AuthFailure('Pedido muito grande.', 413);
    }
    final m = jsonDecode(utf8.decode(bytes));
    if (m is! Map<String, dynamic>) throw AuthFailure('Pedido inválido.');
    return m;
  }

  Future<void> _json(HttpRequest r, int status, Map<String, dynamic> m) async {
    r.response.statusCode = status;
    r.response.headers.contentType = ContentType.json;
    r.response.headers.set('cache-control', 'no-store');
    r.response.headers.set('x-content-type-options', 'nosniff');
    r.response.write(jsonEncode(m));
    await r.response.close();
  }

  Future<void> _request(HttpRequest r) async {
    try {
      final path = r.uri.path;
      if (path == '/health') {
        await _json(r, 200, {
          'ok': true,
          'protocol': onlineProtocol,
          'content': onlineContent,
        });
        return;
      }
      if (!limiter.allow('http:${_ip(r)}', 120, 60))
        throw AuthFailure('Muitos pedidos. Aguarde um minuto.', 429);
      if (path == '/api/v1/guest' && auth is GuestAuthStore) {
        if (r.method != 'POST') throw AuthFailure('Use POST.', 405);
        if (!limiter.allow('guest:${_ip(r)}', 24, 60))
          throw AuthFailure('Muitas tentativas. Aguarde.', 429);
        final m = await _body(r);
        if (m['invite'] != friendCode || friendCode == null)
          throw AuthFailure('Convite inválido.', 403);
        await _json(
          r,
          200,
          (auth as GuestAuthStore).guest(
            '${m['name'] ?? ''}',
            (m['garage'] as List? ?? []).whereType<String>().toList(),
          ),
        );
        return;
      }
      if (path == '/api/v1/login' || path == '/api/v1/register') {
        if (auth is GuestAuthStore)
          throw AuthFailure('Use seu nome e o convite da sala.', 403);
        if (r.method != 'POST') throw AuthFailure('Use POST.', 405);
        final register = path.endsWith('register');
        if (!limiter.allow('auth:${_ip(r)}', 12, 60) ||
            (register && !limiter.allow('register:${_ip(r)}', 10, 3600)))
          throw AuthFailure('Muitas tentativas de login. Aguarde.', 429);
        final m = await _body(r);
        if (m['name'] is! String || m['password'] is! String)
          throw AuthFailure('Informe usuário e senha.');
        if (!limiter.allow(
          'name:${(m['name'] as String).toLowerCase()}',
          8,
          60,
        ))
          throw AuthFailure('Muitas tentativas. Aguarde.', 429);
        await _json(
          r,
          200,
          await auth.login(m['name'], m['password'], register: register),
        );
        return;
      }
      final token = _token(r), account = auth.authenticate(token);
      if (account == null) throw AuthFailure('Entre na sua conta.', 401);
      if (path == '/api/v1/me' && r.method == 'GET') {
        await _json(r, 200, account.profile);
        return;
      }
      if (path == '/api/v1/logout' && r.method == 'POST') {
        await auth.logout(token);
        _leave(account.name.toLowerCase());
        await peers[account.name.toLowerCase()]?.socket.close(
          1000,
          'Conta desconectada',
        );
        await _json(r, 200, {'ok': true});
        return;
      }
      if (path == '/api/v1/buy' && r.method == 'POST') {
        final m = await _body(r);
        await auth.buy(account, '${m['car']}');
        await _json(r, 200, account.profile);
        return;
      }
      if (path == '/api/v1/rooms' && r.method == 'GET') {
        await _json(r, 200, {
          'rooms': [
            for (final x in rooms.values.where(
              (x) => x.public && x.phase == 'lobby',
            ))
              x.info(peers),
          ],
        });
        return;
      }
      if (path == '/api/v1/catalog' && r.method == 'GET') {
        await _json(r, 200, {
          'protocol': onlineProtocol,
          'content': onlineContent,
          'tracks': [
            for (final t in tracks)
              {'id': t.id, 'name': t.name, 'room': t.room},
          ],
          'arenas': [
            for (final a in arenas)
              {'id': a.track.id, 'name': a.track.name, 'room': a.track.room},
          ],
          'cars': [
            for (final c in cars)
              {
                'id': c.id,
                'name': c.name,
                'cost': c.cost,
                'stars': c.requiredStars,
              },
          ],
        });
        return;
      }
      if (path == '/socket' && WebSocketTransformer.isUpgradeRequest(r)) {
        if (r.uri.queryParameters['protocol'] != '$onlineProtocol' ||
            r.uri.queryParameters['content'] != onlineContent)
          throw AuthFailure('Atualize o jogo para entrar nesse servidor.', 409);
        final key = account.name.toLowerCase();
        if (!limiter.allow('socket:$key', 15, 60))
          throw AuthFailure('Reconexões muito frequentes.', 429);
        final ws = await WebSocketTransformer.upgrade(r);
        ws.pingInterval = const Duration(seconds: 10);
        final peer = OnlinePeer(account, ws, token), old = peers[key];
        peers[key] = peer;
        unawaited(
          old?.socket.close(1000, 'Conectado em outra sessão') ??
              Future.value(),
        );
        peer.send({'type': 'hello', 'profile': account.profile});
        final room = membership[key];
        if (room != null) {
          final member = room.members.firstWhere((m) => m.key == key);
          member.disconnectedAt = null;
          _broadcastRoom(room);
          if (room.engine != null) {
            peer.send(room.launch());
            _state(room, force: peer);
            if (room.results[key] != null) peer.send(room.results[key]!);
          }
        }
        ws.listen(
          (raw) => _message(peer, raw),
          onDone: () => _disconnected(peer),
          onError: (Object _) => _disconnected(peer),
        );
        return;
      }
      throw AuthFailure('Endereço não encontrado.', 404);
    } on AuthFailure catch (e) {
      await _json(r, e.status, {'error': e.message});
    } catch (_) {
      try {
        await _json(r, 500, {
          'error': 'Não foi possível concluir. Tente novamente.',
        });
      } catch (_) {}
    }
  }

  void _disconnected(OnlinePeer p) {
    if (peers[p.key] != p) return;
    peers.remove(p.key);
    final room = membership[p.key];
    if (room == null) return;
    room.members.firstWhere((m) => m.key == p.key).disconnectedAt =
        DateTime.now();
    final i = room.grid.indexWhere((m) => m.key == p.key);
    if (i >= 0)
      room.engine?.networkInputs[room.engine!.networkDrivers[i]] =
          const NetworkInput(brake: true);
    _broadcastRoom(room);
  }

  void _broadcastRoom(OnlineRoom r) {
    final m = {'type': 'room', 'room': r.info(peers)};
    for (final member in r.members.where((m) => !m.left))
      peers[member.key]?.send(m);
  }

  void _error(OnlinePeer p, String message) =>
      p.send({'type': 'error', 'message': message});
  void _message(OnlinePeer p, dynamic raw) {
    if (peers[p.key] != p) return;
    try {
      if (raw is! String || raw.length > 4096) {
        unawaited(p.socket.close(1009, 'Mensagem muito grande'));
        return;
      }
      if (!limiter.allow('ws:${p.key}', 100, 1)) {
        unawaited(p.socket.close(1008, 'Muitas mensagens'));
        return;
      }
      final m = jsonDecode(raw) as Map<String, dynamic>, type = m['type'];
      var room = membership[p.key];
      if (type == 'ping') {
        p.send({'type': 'pong', 'at': m['at']});
        return;
      }
      if (type == 'ack') {
        if (m['seq'] == p.lastSent) p.acked = p.lastSent;
        return;
      }
      if (type == 'create') {
        if (room != null) throw AuthFailure('Saia da sala atual primeiro.');
        if (rooms.length >= maxRooms)
          throw AuthFailure('Servidor cheio. Tente novamente mais tarde.');
        _car(p.account, m['car']);
        final kind = m['kind'], map = m['map'];
        if (kind != 'race' && kind != 'battle')
          throw AuthFailure('Modo inválido.');
        if (!(kind == 'race'
                ? tracks.map((t) => t.id)
                : arenas.map((a) => a.track.id))
            .contains(map))
          throw AuthFailure('Mapa inválido.');
        var code = '';
        do {
          code = randomToken(6)
              .replaceAll(RegExp('[^A-Za-z0-9]'), '')
              .toUpperCase()
              .padRight(6, 'X')
              .substring(0, 6);
        } while (rooms.containsKey(code));
        if (friendCode != null) code = friendCode!;
        room = OnlineRoom(
          code,
          randomToken(18),
          kind,
          map,
          p.key,
          friendCode == null && m['public'] == true,
        );
        rooms[code] = room;
        _join(p, room, m['car']);
        return;
      }
      if (type == 'join') {
        if (room != null) throw AuthFailure('Saia da sala atual primeiro.');
        final target = rooms['${m['code']}'.trim().toUpperCase()];
        if (target == null) throw AuthFailure('Sala não encontrada.');
        _join(p, target, m['car']);
        return;
      }
      if (type == 'leave') {
        _leave(p.key);
        p.send({'type': 'left'});
        return;
      }
      if (room == null) throw AuthFailure('Entre em uma sala.');
      if (type == 'car') {
        if (room.phase != 'lobby')
          throw AuthFailure('Espere a próxima partida.');
        room.members.firstWhere((a) => a.key == p.key).car = _car(
          p.account,
          m['car'],
        );
        _broadcastRoom(room);
        return;
      }
      if (type == 'lobby') {
        if (room.host != p.key || room.phase != 'finished')
          throw AuthFailure(
            'Somente o anfitrião pode preparar a próxima partida.',
          );
        room.engine = null;
        room.phase = 'lobby';
        room.members.removeWhere((m) => m.left);
        room.results.clear();
        room.forfeits.clear();
        room.grid = [];
        room.finalizing = false;
        room.firstFinish = -1;
        for (final m in room.members) m.ready = false;
        _broadcastRoom(room);
        return;
      }
      if (type == 'start') {
        if (room.host != p.key || room.phase != 'lobby')
          throw AuthFailure('Somente o anfitrião inicia a sala.');
        if (room.members.length < 2 ||
            room.members.any((m) => !peers.containsKey(m.key)))
          throw AuthFailure(
            'São necessários pelo menos dois jogadores conectados.',
          );
        _launch(room);
        return;
      }
      final engine = room.engine,
          i = room.grid.indexWhere((m) => m.key == p.key);
      if (engine == null || i < 0 || room.forfeits.contains(p.key)) return;
      if (type == 'ready') {
        room.grid[i].ready = true;
        if (room.phase == 'loading' &&
            room.grid.every((m) => m.ready && peers.containsKey(m.key))) {
          room.phase = 'playing';
          room.changed = DateTime.now();
          _broadcastRoom(room);
        }
        return;
      }
      if (type == 'input' && room.phase == 'playing') {
        final seq = m['seq'];
        if (seq is! int || seq <= p.inputSeq) return;
        p.inputSeq = seq;
        p.inputAt = DateTime.now();
        engine.networkInputs[engine.networkDrivers[i]] = NetworkInput.read(m);
        return;
      }
      if (type == 'action' && room.phase == 'playing') {
        if (!limiter.allow('action:${p.key}', 15, 1)) return;
        final command = '${m['action']}';
        if (command == 'reset' && !limiter.allow('reset:${p.key}', 1, 2))
          return;
        engine.networkCommand(engine.networkDrivers[i], command);
      }
    } on AuthFailure catch (e) {
      _error(p, e.message);
    } catch (_) {
      _error(p, 'Pedido inválido.');
    }
  }

  int _car(Account a, dynamic index) {
    if (index is! int ||
        index < 0 ||
        index >= cars.length ||
        !a.owned.contains(cars[index].id))
      throw AuthFailure('Selecione um carro da sua garagem online.');
    return index;
  }

  void _join(OnlinePeer p, OnlineRoom r, dynamic car) {
    if (r.phase != 'lobby' || r.members.length >= onlineMaxPlayers)
      throw AuthFailure('A sala está cheia ou já começou.');
    final index = _car(p.account, car);
    r.members.add(RoomMember(p.account, index));
    membership[p.key] = r;
    r.changed = DateTime.now();
    _broadcastRoom(r);
  }

  void _launch(OnlineRoom r) {
    r.seed = Random.secure().nextInt(1 << 30);
    r.grid = [...r.members]..shuffle(Random(r.seed));
    for (final m in r.grid) {
      m.ready = false;
      final p = peers[m.key];
      if (p != null) {
        p.inputSeq = -1;
        p.lastSent = 0;
        p.acked = 0;
      }
    }
    r.forfeits.clear();
    r.results.clear();
    r.finalizing = false;
    r.firstFinish = -1;
    final e = r.kind == 'battle'
        ? BattleEngine(
            arena: arenas.firstWhere((a) => a.track.id == r.map),
            car: cars[r.grid.first.car],
            seed: r.seed,
          )
        : RaceEngine(
            track: tracks.firstWhere((t) => t.id == r.map),
            car: cars[r.grid.first.car],
            seed: r.seed,
          );
    e.configureNetwork([
      for (final p in r.grid) NetworkParticipant(p.account.name, p.car),
    ]);
    r.engine = e;
    r.phase = 'loading';
    r.changed = DateTime.now();
    _broadcastRoom(r);
    for (final member in r.grid) peers[member.key]?.send(r.launch());
  }

  void _leave(String key) {
    final r = membership.remove(key);
    if (r == null) return;
    final m = r.members.firstWhere((m) => m.key == key);
    m.left = true;
    if (r.engine != null) {
      r.forfeits.add(key);
      final i = r.grid.indexOf(m);
      if (i >= 0) {
        final d = r.engine!.networkDrivers[i];
        r.engine!.networkInputs[d] = const NetworkInput(brake: true);
        if (r.engine is BattleEngine) {
          final b = r.engine! as BattleEngine;
          b.applyDamage(d, 10000);
        } else {
          d.finishTime = 1e9 + r.engine!.time;
          d.velocity = d.velocity * 0;
        }
      }
    }
    if (r.phase == 'lobby') r.members.remove(m);
    final available = r.members.where((m) => !m.left).toList();
    if (available.isEmpty) {
      rooms.remove(r.code);
      return;
    }
    if (r.host == key) r.host = available.first.key;
    _broadcastRoom(r);
  }

  void _state(OnlineRoom r, {OnlinePeer? force}) {
    final seq = ++r.sequence, state = NetworkSnapshot.capture(r.engine!);
    final packet = {'type': 'state', 'seq': seq, 'state': state};
    for (final m in r.grid) {
      final p = peers[m.key];
      if (p == null || m.left || (force != null && p != force)) continue;
      if (force == null && p.lastSent > p.acked) continue;
      p.lastSent = seq;
      p.send(packet);
    }
  }

  void tick() {
    final now = _clock.elapsedMicroseconds / 1e6,
        dt = (now - _previous).clamp(0.0, .1);
    _previous = now;
    for (final r in rooms.values.toList()) {
      if (r.phase != 'playing' || r.engine == null) continue;
      final e = r.engine!;
      for (var i = 0; i < r.grid.length; i++) {
        final p = peers[r.grid[i].key];
        if (p == null ||
            DateTime.now().difference(p.inputAt).inMilliseconds > 350)
          e.networkInputs[e.networkDrivers[i]] = const NetworkInput(
            brake: true,
          );
      }
      e.update(dt);
      if (e is! BattleEngine) {
        if (r.firstFinish < 0 &&
            e.drivers.any((d) => d.finishTime != null && d.finishTime! < 1e9))
          r.firstFinish = e.time;
        if (e.drivers.every((d) => d.finishTime != null) ||
            e.time >= 600 ||
            (r.firstFinish >= 0 && e.time - r.firstFinish >= 45))
          e.finished = true;
      }
      if (e.finished && !r.finalizing) {
        r.finalizing = true;
        unawaited(_finish(r));
      }
    }
    if (now - _snapshotAt >= .05) {
      _snapshotAt = now;
      for (final r in rooms.values.toList())
        if (r.engine != null && r.phase == 'playing') _state(r);
    }
    if (now - _maintenanceAt >= 1) {
      _maintenanceAt = now;
      _maintain();
    }
  }

  void _maintain() {
    final now = DateTime.now();
    for (final p in peers.values.toList())
      if (auth.authenticate(p.token) == null)
        unawaited(p.socket.close(1008, 'Sessão expirada'));
    for (final r in rooms.values.toList()) {
      for (final m in r.members.toList()) {
        if (!m.left &&
            m.disconnectedAt != null &&
            now.difference(m.disconnectedAt!).inSeconds >= 20)
          _leave(m.key);
      }
      if (r.phase == 'loading' && now.difference(r.changed).inSeconds >= 60) {
        r.engine = null;
        r.phase = 'lobby';
        _broadcastRoom(r);
        for (final m in r.members.where((m) => !m.left))
          _errorIfConnected(
            m.key,
            'O carregamento de um jogador demorou demais. Inicie novamente.',
          );
      }
    }
  }

  void _errorIfConnected(String key, String message) {
    final p = peers[key];
    if (p != null) _error(p, message);
  }

  Future<void> _finish(OnlineRoom r) async {
    final e = r.engine!, order = e.standings;
    final original = {for (var i = 0; i < order.length; i++) order[i]: i};
    order.sort((a, b) {
      final x = r.forfeits.contains(r.grid[e.networkDrivers.indexOf(a)].key);
      final y = r.forfeits.contains(r.grid[e.networkDrivers.indexOf(b)].key);
      return x == y
          ? original[a]!.compareTo(original[b]!)
          : x
          ? 1
          : -1;
    });
    final match = '${r.id}:${r.seed}';
    for (var i = 0; i < r.grid.length; i++) {
      final m = r.grid[i], d = e.networkDrivers[i], pos = order.indexOf(d) + 1;
      final eligible = !r.forfeits.contains(m.key);
      auth.reward(
        m.account,
        match,
        pos,
        r.map,
        battle: e is BattleEngine,
        eligible: eligible,
      );
      r.results[m.key] = {
        'type': 'result',
        'position': pos,
        'time': e.time,
        'coins': eligible ? podiumCoins(pos) : 0,
        'profile': m.account.profile,
        'standings': [
          for (var j = 0; j < order.length; j++)
            {
              'position': j + 1,
              'name': order[j].name,
              'car': cars.indexOf(order[j].car),
              'time': order[j].finishTime != null && order[j].finishTime! < 1e9
                  ? order[j].finishTime
                  : null,
              'remaining': e is BattleEngine
                  ? 100 - e.fighters[order[j]]!.health
                  : max(0, e.laps * e.track.length - order[j].distance),
            },
        ],
      };
    }
    try {
      await auth.save();
    } catch (_) {
      for (final m in r.grid)
        _errorIfConnected(m.key, 'Falha ao salvar o resultado no servidor.');
      // Retry durable write without granting twice or publishing unsaved wins.
      Timer(const Duration(seconds: 2), () {
        r.finalizing = false;
      });
      return;
    }
    r.phase = 'finished';
    r.changed = DateTime.now();
    for (final m in r.grid) {
      final p = peers[m.key];
      if (p == null || m.left) continue;
      _state(r, force: p);
      p.send(r.results[m.key]!);
    }
    _broadcastRoom(r);
  }
}
