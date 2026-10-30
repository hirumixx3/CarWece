import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import '../game/content.dart';
import '../game/engine.dart';
import '../game/math3d.dart';
import 'protocol.dart';
import 'invite.dart';
import 'phone_host.dart';

Uri onlineEndpoint(String value) {
  final u = Uri.parse(value.trim());
  if (u.host.isEmpty ||
      u.userInfo.isNotEmpty ||
      u.hasQuery ||
      u.hasFragment ||
      (u.path.isNotEmpty && u.path != '/'))
    throw const FormatException('Informe somente o endereço do servidor.');
  final h = u.host.toLowerCase(),
      parts = h.split('.').map(int.tryParse).toList();
  final ipv4 =
      parts.length == 4 && parts.every((p) => p != null && p >= 0 && p <= 255);
  final local =
      h == 'localhost' ||
      h == '::1' ||
      (ipv4 &&
          (parts[0] == 127 ||
              parts[0] == 10 ||
              (parts[0] == 192 && parts[1] == 168) ||
              (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31)));
  if (u.scheme != 'https' && !(u.scheme == 'http' && local))
    throw const FormatException(
      'Use HTTPS na internet. HTTP só é permitido em rede local.',
    );
  return u.replace(path: '');
}

class OnlineFailure implements Exception {
  final String message;
  OnlineFailure(this.message);
  @override
  String toString() => message;
}

class _Pose {
  final V3 p, forward, up;
  _Pose(Driver d) : p = d.position!, forward = d.forward!, up = d.normal!;
}

/// Authenticated WebSocket transport. Account passwords and session tokens are
/// intentionally kept out of the local game save. One unacknowledged snapshot
/// per peer bounds server queues when a device or network is slow.
class OnlineClient {
  final List<TrackSpec> tracks;
  final List<ArenaSpec> arenas;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  Uri? endpoint;
  String? _token;
  Map<String, dynamic>? profile, room;
  List<Map<String, dynamic>> rooms = [];
  RaceEngine? match;
  RaceResult? result;
  String status = 'Escolha seu nome e crie uma sala ou cole um convite.',
      error = '';
  bool connected = false, busy = false, closed = false;
  int pingMs = 0, _inputSeq = 0, _retry = 0;
  DateTime _lastPacketAt = DateTime.now();
  String? _game;
  bool _ready = false;
  bool _leaving = false;
  WebSocket? _socket;
  Timer? _inputs, _ping, _reconnect;
  StreamSubscription<dynamic>? _subscription;
  final Map<Driver, _Pose> _targets = {};
  PhoneHost? phoneHost;
  FriendInvite? friendInvite;
  bool get friendMode => friendInvite != null;
  String? get shareCode => friendInvite?.code;
  final Future<Map<String, String>> Function()? createHostIdentity;
  final Future<void> Function(bool)? hostService;
  final PhoneHost Function(void Function(String) onLost)? hostFactory;
  final Uri Function(FriendInvite invite)? friendEndpoint;
  OnlineClient({
    required this.tracks,
    required this.arenas,
    this.createHostIdentity,
    this.hostService,
    this.hostFactory,
    this.friendEndpoint,
  });
  void _emit() {
    if (!closed) _changes.add(null);
  }

  String get name => '${profile?['name'] ?? ''}';
  bool get host => room?['host'] == name.toLowerCase();

  void _pin(String fingerprint) {
    _http.close(force: true);
    _http = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = const Duration(seconds: 20)
      ..badCertificateCallback = (certificate, host, port) =>
          base64UrlEncode(
            sha256.convert(certificate.der).bytes,
          ).replaceAll('=', '') ==
          fingerprint;
  }

  Future<void> _guest(String username, List<String> garage) async {
    final health = await _request('/health', authenticated: false);
    if (health['protocol'] != onlineProtocol ||
        health['content'] != onlineContent)
      throw OnlineFailure(
        'Todos os amigos precisam usar a mesma versão do CarWece.',
      );
    final data = await _request(
      '/api/v1/guest',
      authenticated: false,
      body: {'name': username, 'garage': garage, 'invite': friendInvite!.room},
    );
    _token = data['token'];
    profile = Map<String, dynamic>.from(data['profile']);
    await _open();
  }

  Future<void> createWithFriends({
    required String username,
    required List<String> garage,
    required String kind,
    required String map,
    required int car,
    bool localNetwork = false,
  }) async {
    if (busy || closed) return;
    busy = true;
    error = '';
    status = localNetwork
        ? 'Abrindo sala no Wi-Fi…'
        : 'Abrindo sua sala na internet…';
    _emit();
    try {
      if (createHostIdentity == null)
        throw StateError("A hospedagem precisa do aplicativo Android.");
      void onLost(String message) {
        error = message;
        status = 'Sala desconectada';
        _emit();
      }

      final phone =
          hostFactory?.call(onLost) ??
          PhoneHost(
            keepAlive: hostService,
            onStatus: (message) {
              status = message;
              _emit();
            },
            onLost: (message) {
              error = message;
              status = 'Sala desconectada';
              _emit();
            },
          );
      phoneHost = phone;
      await phone.start(
        await createHostIdentity!(),
        localNetwork: localNetwork,
      );
      if (closed) {
        await phone.close();
        return;
      }
      friendInvite = phone.invite;
      endpoint = phone.endpoint;
      _pin(phone.fingerprint);
      await _guest(username, garage);
      send({
        'type': 'create',
        'kind': kind,
        'map': map,
        'car': car,
        'public': false,
      });
    } catch (e) {
      error = e is StateError ? '${e.message}' : _friendly(e);
      status = 'Sala não criada.';
      await phoneHost?.close();
      phoneHost = null;
      friendInvite = null;
      profile = null;
      _token = null;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> joinWithFriends({
    required String username,
    required List<String> garage,
    required String invitation,
    required int car,
  }) async {
    if (busy || closed) return;
    busy = true;
    error = '';
    status = 'Entrando na sala do seu amigo…';
    _emit();
    try {
      friendInvite = FriendInvite.parse(invitation);
      endpoint = friendEndpoint?.call(friendInvite!) ?? friendInvite!.endpoint;
      _pin(friendInvite!.fingerprint);
      await _guest(username, garage);
      send({'type': 'join', 'code': friendInvite!.room, 'car': car});
    } catch (e) {
      error =
          friendInvite?.isLocal == true &&
              e is! OnlineFailure &&
              e is! FormatException
          ? 'Não foi possível entrar na sala Wi-Fi. Conecte os dois celulares à mesma rede, mantenha a sala aberta e copie um convite novo. Algumas redes de convidados bloqueiam a comunicação entre aparelhos.'
          : _friendly(e);
      status = 'Não conectado.';
      friendInvite = null;
      profile = null;
      _token = null;
    } finally {
      busy = false;
      _emit();
    }
  }

  void send(Map<String, dynamic> m) {
    try {
      if (connected && _socket?.readyState == WebSocket.open)
        _socket!.add(jsonEncode(m));
    } on StateError {
      _lost();
    } on SocketException {
      _lost();
    }
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final u = endpoint;
    if (u == null) throw OnlineFailure('Configure o endereço do servidor.');
    final request = await _http
        .openUrl(body == null ? 'GET' : 'POST', u.replace(path: path))
        .timeout(const Duration(seconds: 20));
    if (authenticated && _token != null)
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    request.headers.contentType = ContentType.json;
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 45));
    final bytes = <int>[];
    await for (final b in response.timeout(const Duration(seconds: 20))) {
      bytes.addAll(b);
      if (bytes.length > 2 * 1024 * 1024)
        throw OnlineFailure('Resposta do servidor muito grande.');
    }
    Map<String, dynamic> m;
    try {
      m = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw OnlineFailure('O endereço não respondeu como um servidor CarWece.');
    }
    if (response.statusCode != 200)
      throw OnlineFailure('${m['error'] ?? 'Falha na conexão.'}');
    return m;
  }

  Future<void> login(
    String address,
    String username,
    String password, {
    bool register = false,
  }) async {
    if (busy || closed) return;
    busy = true;
    error = '';
    status = 'Conectando…';
    _emit();
    try {
      endpoint = onlineEndpoint(address);
      _http.close(force: true);
      _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final health = await _request('/health', authenticated: false);
      if (health['protocol'] != onlineProtocol ||
          health['content'] != onlineContent)
        throw OnlineFailure(
          'O servidor e o APK precisam estar na mesma versão.',
        );
      final data = await _request(
        '/api/v1/${register ? 'register' : 'login'}',
        body: {'name': username, 'password': password},
        authenticated: false,
      );
      _token = data['token'];
      profile = Map<String, dynamic>.from(data['profile']);
      await _open();
      await refreshRooms();
    } catch (e) {
      error = _friendly(e);
      status = 'Não conectado.';
    } finally {
      busy = false;
      _emit();
    }
  }

  String _friendly(Object e) => e is OnlineFailure
      ? e.message
      : e is FormatException
      ? e.message
      : 'Não foi possível conectar. Confira o endereço, a internet e se o servidor está ligado.';
  Future<void> _open() async {
    if (closed || _token == null || endpoint == null) return;
    final u = endpoint!.replace(
      scheme: endpoint!.scheme == 'https' ? 'wss' : 'ws',
      path: '/socket',
      queryParameters: {
        'protocol': '$onlineProtocol',
        'content': onlineContent,
      },
    );
    final socket = await WebSocket.connect(
      u.toString(),
      customClient: _http,
      headers: {HttpHeaders.authorizationHeader: 'Bearer $_token'},
    ).timeout(const Duration(seconds: 20));
    if (closed) {
      await socket.close();
      return;
    }
    _socket = socket;
    connected = true;
    _lastPacketAt = DateTime.now();
    _retry = 0;
    _ready = false;
    error = '';
    status = 'Conectado';
    socket.pingInterval = const Duration(seconds: 10);
    _subscription = socket.listen(
      _message,
      onDone: _lost,
      onError: (Object _) => _lost(),
    );
    _inputs?.cancel();
    _inputs = Timer.periodic(const Duration(milliseconds: 40), (_) => _input());
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 2), (_) => _heartbeat());
    _emit();
  }

  void _heartbeat() {
    if (closed || !connected) return;
    final now = DateTime.now();
    if (now.difference(_lastPacketAt) >= const Duration(seconds: 8)) {
      // A broken reverse tunnel can leave the guest's TCP connection open
      // without forwarding data. WebSocket onDone/pong alone can take much
      // longer to notice. Require responses from the actual game server.
      final socket = _socket;
      _lost();
      if (socket != null) {
        unawaited(
          socket
              .close(1001, 'Sala sem resposta')
              .timeout(const Duration(seconds: 2))
              .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
        );
      }
      return;
    }
    send({'type': 'ping', 'at': now.millisecondsSinceEpoch});
  }

  void _lost() {
    if (!connected || closed) return;
    if (friendMode && _socket?.closeReason == 'Servidor encerrado') {
      connected = false;
      _inputs?.cancel();
      _ping?.cancel();
      _reconnect?.cancel();
      _token = null;
      profile = null;
      room = null;
      match = null;
      result = null;
      friendInvite = null;
      status =
          'O anfitrião encerrou a sala. Cole outro convite para jogar novamente.';
      _emit();
      return;
    }
    if (_socket?.closeReason == 'Conectado em outra sessão') {
      connected = false;
      _inputs?.cancel();
      _ping?.cancel();
      _token = null;
      profile = null;
      room = null;
      match = null;
      result = null;
      status = 'Sua conta foi aberta em outro aparelho.';
      _emit();
      return;
    }
    connected = false;
    _inputs?.cancel();
    _ping?.cancel();
    match?.clearControls();
    status = 'Reconectando… O carro está freando.';
    _emit();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (closed || connected || _token == null) return;
    _reconnect?.cancel();
    final token = _token, address = endpoint;
    final seconds = math.min(10, 1 << math.min(_retry++, 4));
    _reconnect = Timer(Duration(seconds: seconds), () async {
      bool stale() =>
          closed || connected || _token != token || endpoint != address;
      if (stale()) return;
      try {
        await _request('/api/v1/me');
        if (stale()) return;
        await _subscription?.cancel();
        await _open();
      } catch (e) {
        if (stale()) return;
        if (e is OnlineFailure && e.message.contains('Entre na sua conta')) {
          _token = null;
          profile = null;
          room = null;
          match = null;
          status = 'Sessão expirada. Entre novamente.';
          _emit();
        } else {
          _scheduleReconnect();
        }
      }
    });
  }

  void _input({bool idle = false}) {
    final e = match;
    if (e == null || e.finished) return;
    final enabled = !idle && !e.paused;
    final input = NetworkInput(
      steer: enabled ? e.steering * e.sensitivity : 0,
      gas: enabled && e.accelerating,
      brake: !enabled || e.brake,
      boost: enabled && e.boosting,
      drift: enabled && e.driftPressed,
      fire: enabled && e is BattleEngine && e.triggerHeld,
    );
    send({'type': 'input', 'seq': ++_inputSeq, ...input.toJson()});
  }

  void _action(String action) {
    if (action == 'idle' || action == 'controls') {
      _input(idle: action == 'idle');
      return;
    }
    send({'type': 'action', 'action': action});
  }

  void _message(dynamic raw) {
    if (closed) return;
    try {
      if (raw is! String || raw.length > 2 * 1024 * 1024)
        throw const FormatException();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _lastPacketAt = DateTime.now();
      switch (m['type']) {
        case 'hello':
          profile = Map<String, dynamic>.from(m['profile']);
          if (_leaving) send({'type': 'leave'});
          break;
        case 'pong':
          pingMs =
              (DateTime.now().millisecondsSinceEpoch - (m['at'] as num).toInt())
                  .clamp(0, 9999);
          break;
        case 'room':
          if (_leaving) break;
          room = Map<String, dynamic>.from(m['room']);
          if (room!['phase'] == 'lobby') {
            _game = null;
            match = null;
            result = null;
            _targets.clear();
          }
          status = room!['phase'] == 'loading'
              ? 'Carregando os carros de todos os jogadores…'
              : 'Conectado';
          break;
        case 'launch':
          if (!_leaving) _launch(m);
          break;
        case 'left':
          _leaving = false;
          room = null;
          match = null;
          result = null;
          _game = null;
          _targets.clear();
          break;
        case 'error':
          error = '${m['message']}';
          break;
        case 'state':
          final e = match;
          if (e != null) {
            final old = {for (final d in e.networkDrivers) d: _Pose(d)};
            NetworkSnapshot.apply(e, Map<String, dynamic>.from(m['state']));
            for (final d in e.networkDrivers) {
              _targets[d] = _Pose(d);
              if ((d.position! - old[d]!.p).length < 60) {
                d.position = old[d]!.p;
                d.forward = old[d]!.forward;
                d.normal = old[d]!.up;
              }
            }
          }
          send({'type': 'ack', 'seq': m['seq']});
          return;
        case 'result':
          profile = Map<String, dynamic>.from(m['profile']);
          result = RaceResult(
            m['position'],
            (m['time'] as num).toDouble(),
            0,
            m['coins'],
            0,
            0,
            standings: [
              for (final s in m['standings'])
                RaceStanding(
                  s['position'],
                  s['name'],
                  cars[s['car']],
                  s['time'] == null ? null : (s['time'] as num).toDouble(),
                  (s['remaining'] as num).toDouble(),
                ),
            ],
          );
          match?.result = result;
          match?.finished = true;
          status = 'Partida concluída';
          break;
      }
      _emit();
    } catch (_) {
      error =
          'O servidor enviou dados incompatíveis. Atualize o jogo e o servidor.';
      _emit();
    }
  }

  void _launch(Map<String, dynamic> m) {
    final game = '${m['id']}:${m['seed']}';
    if (_game == game && match != null) {
      _ready = false;
      return;
    }
    final players = [
      for (final p in m['players']) NetworkParticipant(p['name'], p['car']),
    ];
    final local = players.indexWhere(
      (p) => p.name.toLowerCase() == name.toLowerCase(),
    );
    if (local < 0) throw const FormatException();
    final e = m['kind'] == 'battle'
        ? BattleEngine(
            arena: arenas.firstWhere((a) => a.track.id == m['map']),
            car: cars[players[local].car],
            seed: m['seed'],
          )
        : RaceEngine(
            track: tracks.firstWhere((t) => t.id == m['map']),
            car: cars[players[local].car],
            seed: m['seed'],
          );
    e.configureNetwork(players, local: local);
    e.remoteAction = _action;
    e.remoteUpdate = (dt) {
      if (!_ready && connected) {
        _ready = true;
        send({'type': 'ready'});
      }
      final amount = 1 - math.exp(-20 * dt.clamp(0, .1));
      for (final d in e.networkDrivers) {
        final target = _targets[d];
        if (target == null) continue;
        d.position = d.position!.lerp(target.p, amount);
        final up = d.normal!.lerp(target.up, amount),
            forward = d.forward!.lerp(target.forward, amount);
        d.normal = up.length > .01 ? up.unit : target.up;
        final planar = forward - d.normal! * forward.dot(d.normal!);
        d.forward = planar.length > .01 ? planar.unit : target.forward;
      }
      for (final fx in e.effects)
        fx.age = math.min(fx.duration, fx.age + dt.clamp(0, .1));
      e.drifting =
          e.driftPressed && e.player.speed.abs() > 18 && e.steering.abs() > .12;
    };
    _game = game;
    match = e;
    result = null;
    _ready = false;
    _targets.clear();
    _inputSeq = 0;
  }

  Future<void> refreshRooms() async {
    try {
      final m = await _request('/api/v1/rooms');
      rooms = [for (final r in m['rooms']) Map<String, dynamic>.from(r)];
      error = '';
    } catch (e) {
      error = _friendly(e);
    }
    _emit();
  }

  void leaveRoom() {
    if (friendMode) {
      unawaited(signOut());
      return;
    }
    _leaving = true;
    _input(idle: true);
    send({'type': 'leave'});
    room = null;
    match = null;
    result = null;
    _game = null;
    _targets.clear();
    _emit();
  }

  Future<void> buy(String id) async {
    if (busy) return;
    busy = true;
    _emit();
    try {
      profile = await _request('/api/v1/buy', body: {'car': id});
      error = '';
    } catch (e) {
      error = _friendly(e);
    }
    busy = false;
    _emit();
  }

  Future<void> signOut() async {
    if (busy) return;
    busy = true;
    _reconnect?.cancel();
    _inputs?.cancel();
    _ping?.cancel();
    send({'type': 'leave'});
    connected = false;
    try {
      await _request(
        '/api/v1/logout',
        body: {},
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
    await _socket?.close();
    await phoneHost?.close();
    phoneHost = null;
    friendInvite = null;
    _token = null;
    profile = null;
    room = null;
    match = null;
    result = null;
    _game = null;
    _leaving = false;
    rooms.clear();
    _targets.clear();
    busy = false;
    status = 'Escolha seu nome e crie uma sala ou cole um convite.';
    _emit();
  }

  void dispose() {
    if (closed) return;
    send({'type': 'leave'});
    closed = true;
    _reconnect?.cancel();
    _inputs?.cancel();
    _ping?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_socket?.close());
    _http.close(force: true);
    unawaited(phoneHost?.close());
    unawaited(_changes.close());
  }
}
