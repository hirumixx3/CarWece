import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'bore_tunnel.dart' show RelayFailure;
import 'invite.dart';
import 'protocol.dart';

/// A control route is separate from the public, TLS-passthrough game route.
/// Pinggy's standard control protocol is SSH on port 443, not HTTPS. Some
/// networks also support its optional SSH-over-TLS listener.
class PinggyRoute {
  final String host;
  final int port;
  final bool tls;
  final String? certificatePin;
  const PinggyRoute(
    this.host, {
    this.port = 443,
    this.tls = false,
    this.certificatePin,
  });
}

/// No account/password is sent to this untrusted transport. The game's own
/// TLS certificate remains pinned end to end by the invitation on both SSH
/// control routes; accepting a relay's SSH key never trusts it with game data.
class PinggyTunnel {
  final int localPort;
  final String serverHost;
  final int serverPort;
  final String? pinnedTransportCertificate;
  final String gameCertificatePin;
  final bool probeLoopback;
  final List<PinggyRoute>? routes;
  final void Function(String)? onClosed, onStatus;
  final Duration attemptTimeout;
  SSHClient? _client;
  Socket? _transport;
  final _locals = <Socket>{};
  final _channels = <SSHForwardChannel>{};
  final _bridges = <Future<void>>{};
  Timer? _expiry;
  bool _closed = false, _active = false, _started = false;
  int _generation = 0;
  Future<void>? _closing;
  String _stage = 'TCP';
  PinggyTunnel({
    required this.localPort,
    required this.gameCertificatePin,
    this.serverHost = 'free.pinggy.io',
    this.serverPort = 443,
    this.pinnedTransportCertificate,
    this.probeLoopback = false,
    this.routes,
    this.onClosed,
    this.onStatus,
    this.attemptTimeout = const Duration(seconds: 20),
  });

  Future<Uri> start() async {
    if (_started || _closed) throw StateError('Sala já iniciada ou encerrada.');
    _started = true;
    final candidates =
        routes ??
        (pinnedTransportCertificate != null
            ? List.filled(
                2,
                PinggyRoute(
                  serverHost,
                  port: serverPort,
                  tls: true,
                  certificatePin: pinnedTransportCertificate,
                ),
              )
            : [
                PinggyRoute(serverHost, port: serverPort),
                if (serverHost == 'free.pinggy.io')
                  const PinggyRoute('a.pinggy.io'),
                PinggyRoute(serverHost, port: serverPort, tls: true),
                if (serverHost == 'free.pinggy.io')
                  const PinggyRoute('a.pinggy.io', tls: true),
              ]);
    if (candidates.isEmpty || candidates.length > 4) {
      throw ArgumentError('Informe de uma a quatro rotas de controle.');
    }
    final failures = <String>[];
    for (var attempt = 0; attempt < candidates.length; attempt++) {
      final route = candidates[attempt];
      final generation = ++_generation;
      try {
        onStatus?.call(
          'Conectando a sala… tentativa ${attempt + 1} de ${candidates.length}',
        );
        final endpoint = await _open(generation, route).timeout(attemptTimeout);
        _check(generation);
        if (_client!.isClosed) throw const SocketException('Túnel encerrado');
        _active = true;
        _expiry = Timer(const Duration(minutes: 60), () {
          _lost(
            'A sessão gratuita de internet chegou ao limite de 60 minutos.',
          );
        });
        return endpoint;
      } catch (e) {
        failures.add(
          '${route.host}/${route.tls ? 'TLS' : 'SSH'}:${_failureCode(e)}',
        );
        await _cleanup();
        if (_closed) rethrow;
        // A fixture's explicit identity pin is never bypassed by an unpinned
        // route. Production TLS validation also stays enabled on TLS routes.
        if (attempt == candidates.length - 1 ||
            (route.certificatePin != null && e is HandshakeException)) {
          await close();
          final friendly = _friendly(e);
          throw RelayFailure(
            '${friendly.message} Diagnóstico: ${failures.join('; ')}.',
            retryable: friendly.retryable,
          );
        }
        onStatus?.call('Tentando outra conexão para a sala…');
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (_closed) throw StateError('Criação cancelada.');
      }
    }
    throw StateError('Tentativas esgotadas.');
  }

  String _failureCode(Object e) {
    if (e is SocketException &&
        RegExp(
          r'lookup|resolv|name|nodename',
          caseSensitive: false,
        ).hasMatch(e.message))
      return 'DNS';
    if (e is HandshakeException) return 'TLS';
    if (e is TimeoutException) return '$_stage/TEMPO';
    if (e is SocketException) return '$_stage/CONEXAO';
    return _stage;
  }

  RelayFailure _friendly(Object e) {
    if (e is RelayFailure) return e;
    if (e is HandshakeException) {
      return const RelayFailure(
        'Não foi possível validar a conexão segura do retransmissor. Confira a data do celular e a rede.',
        retryable: false,
      );
    }
    if (e is TimeoutException) {
      return const RelayFailure(
        'O túnel de internet demorou a responder na porta 443. Tente novamente ou outra rede.',
      );
    }
    if (e is FormatException) {
      return const RelayFailure(
        'O retransmissor não forneceu um endereço de sala válido. Tente novamente mais tarde.',
        retryable: false,
      );
    }
    if (e is SocketException) {
      return const RelayFailure(
        'Não foi possível alcançar o retransmissor pelas conexões alternativas. Confira a internet e tente novamente.',
      );
    }
    return const RelayFailure(
      'Não foi possível abrir o túnel seguro da sala. O serviço recusou ou encerrou a sessão; tente novamente.',
    );
  }

  void _check(int generation) {
    if (_closed || generation != _generation)
      throw StateError('Criação cancelada.');
  }

  Future<Uri> _open(int generation, PinggyRoute route) async {
    _stage = route.tls ? 'TLS' : 'TCP';
    final pinned = route.certificatePin;
    final socket = route.tls
        ? await SecureSocket.connect(
            route.host,
            route.port,
            context: pinned == null
                ? null
                : SecurityContext(withTrustedRoots: false),
            onBadCertificate: pinned == null
                ? null
                : (cert) =>
                      base64UrlEncode(
                        sha256.convert(cert.der).bytes,
                      ).replaceAll('=', '') ==
                      pinned,
            timeout: const Duration(seconds: 8),
          )
        : await Socket.connect(
            route.host,
            route.port,
            timeout: const Duration(seconds: 8),
          );
    if (_closed || generation != _generation) {
      socket.destroy();
      _check(generation);
    }
    _transport = socket;
    socket.setOption(SocketOption.tcpNoDelay, true);
    final client = SSHClient(
      _ControlSocket(socket),
      username: 'tls',
      onPasswordRequest: () => '',
      // A free relay is an untrusted byte transport, including on the direct
      // SSH route. No credentials are used; the independent game TLS pin
      // authenticates every public /health, HTTP and WebSocket connection.
      onVerifyHostKey: (_, _) => true,
      handshakeTimeout: const Duration(seconds: 8),
      authTimeout: const Duration(seconds: 8),
      keepAliveInterval: const Duration(seconds: 10),
      ident: 'CarWece_0.14.3',
    );
    _client = client;
    unawaited(
      client.done.then<void>(
        (_) {
          if (generation == _generation)
            _lost('O retransmissor encerrou a conexão da sala.');
        },
        onError: (Object _, StackTrace __) {
          if (generation == _generation)
            _lost('A conexão da sala com a internet caiu.');
        },
      ),
    );
    _stage = 'SSH';
    await client.authenticated;
    _check(generation);
    onStatus?.call('Abrindo endereço público da sala…');
    _stage = 'ENCAMINHAMENTO';
    final forward = await client.forwardRemote(host: 'localhost', port: 0);
    _check(generation);
    if (forward == null)
      throw const RelayFailure('O retransmissor recusou a abertura da sala.');
    forward.connections.listen((channel) {
      if (_closed || generation != _generation || _channels.length >= 24) {
        channel.destroy();
      } else {
        _channels.add(channel);
        final bridge = _bridge(channel, generation);
        _bridges.add(bridge);
        unawaited(bridge.then((_) => _bridges.remove(bridge)));
      }
    }, onError: (Object _) => _lost('A conexão da sala com a internet caiu.'));
    final shell = await client.shell(pty: null);
    _check(generation);
    // Keep output flowing, but retain a bounded copy of advertised URLs. Some
    // edges expose them here before /urls is ready (or without that API).
    var output = '';
    void collect(List<int> bytes) {
      output += utf8.decode(bytes, allowMalformed: true);
      if (output.length > 32768)
        output = output.substring(output.length - 16384);
    }

    shell.stdout.listen(collect, onError: (Object _) {});
    shell.stderr.listen(collect, onError: (Object _) {});
    final api = SSHHttpClient(client, idleTimeout: const Duration(seconds: 4));
    _stage = 'ENDERECO';
    for (var poll = 0; poll < 5; poll++) {
      _check(generation);
      final urls = <String>[];
      // Pinggy's /urls API over a direct SSH forwarding channel. Empty or
      // temporarily unavailable responses are startup conditions, not failure.
      try {
        final request = api.get(Uri.parse('http://localhost:4300/urls'))
          ..protocolVersion = SSHHttpProtocolVersion.http10;
        final response = await request.close().timeout(
          const Duration(seconds: 2),
        );
        if (response.statusCode == 200 &&
            (response.body?.length ?? 0) <= 16384) {
          final data = jsonDecode(response.body ?? '');
          if (data is Map && data['urls'] is List)
            urls.addAll((data['urls'] as List).whereType<String>());
        }
      } catch (_) {
        _check(generation);
      }
      final text = output.replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '');
      urls.addAll(
        RegExp(
          r'(?:tls|https)://[a-zA-Z0-9.-]+(?::[0-9]+)?',
        ).allMatches(text).map((m) => m[0]!),
      );
      _check(generation);
      for (final value in urls.toSet()) {
        final u = Uri.tryParse(value);
        if (u == null ||
            !['tls', 'https'].contains(u.scheme) ||
            u.userInfo.isNotEmpty ||
            u.hasQuery ||
            u.hasFragment ||
            (u.path.isNotEmpty && u.path != '/') ||
            (u.hasPort && u.port != 443) ||
            !FriendInvite.validRelayHost(u.host))
          continue;
        final endpoint = Uri(scheme: 'https', host: u.host, port: 443);
        onStatus?.call('Testando a conexão pública da sala…');
        _stage = 'ROTA_PUBLICA';
        // Startup DNS/SNI propagation can lag behind the allocation response.
        for (var probe = 0; probe < 3; probe++) {
          try {
            await _probe(endpoint, forward.port);
            _check(generation);
            return endpoint;
          } on RelayFailure {
            if (probe == 2) rethrow;
            _check(generation);
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
        }
      }
      if (poll < 4)
        await Future<void>.delayed(Duration(milliseconds: 250 * (poll + 1)));
    }
    throw const FormatException('Nenhum endereço TLS válido');
  }

  Future<void> _probe(Uri endpoint, int forwardingPort) async {
    final http = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..connectionTimeout = const Duration(seconds: 6)
      ..badCertificateCallback = (cert, _, _) =>
          base64UrlEncode(sha256.convert(cert.der).bytes).replaceAll('=', '') ==
          gameCertificatePin;
    // The fixture has no public DNS/SNI router. Production always probes the
    // advertised public domain; the local fixture probes its SSH listener.
    final target = probeLoopback
        ? Uri(scheme: 'https', host: '127.0.0.1', port: forwardingPort)
        : endpoint;
    try {
      final request = await http
          .getUrl(target.replace(path: '/health'))
          .timeout(const Duration(seconds: 6));
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 6))) {
        bytes.addAll(chunk);
        if (bytes.length > 4096)
          throw const FormatException('Resposta pública excedida');
      }
      final health = jsonDecode(utf8.decode(bytes));
      if (response.statusCode != 200 ||
          health is! Map ||
          health['protocol'] != onlineProtocol ||
          health['content'] != onlineContent) {
        throw const FormatException(
          'A sala não respondeu pelo endereço público',
        );
      }
    } catch (e, st) {
      if (const bool.fromEnvironment('CARWECE_NETWORK_QA')) {
        stderr.writeln('Public TLS probe failed: $e\n$st');
      }
      throw const RelayFailure(
        'O túnel abriu, mas a sala não respondeu pelo endereço público. O convite não foi liberado. Tente novamente ou outra rede.',
      );
    } finally {
      http.close(force: true);
    }
  }

  Future<void> _bridge(SSHForwardChannel channel, int generation) async {
    Socket? local;
    try {
      local = await Socket.connect(
        '127.0.0.1',
        localPort,
        timeout: const Duration(seconds: 5),
      );
      if (_closed || generation != _generation) return;
      _locals.add(local);
      unawaited(
        local.done.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
      local.setOption(SocketOption.tcpNoDelay, true);
      unawaited(
        channel.done.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
      final toLocal = local
          .addStream(channel.stream)
          .then((_) => local!.close());
      final toRelay = channel.sink
          .addStream(local)
          .then((_) => channel.sink.close());
      await Future.wait([toLocal, toRelay], eagerError: true);
    } catch (_) {
      // A disconnected guest does not interrupt the host or the other guests.
    } finally {
      local?.destroy();
      channel.destroy();
      _locals.remove(local);
      _channels.remove(channel);
    }
  }

  void _lost(String message) {
    if (_closed || !_active) return;
    unawaited(close());
    onClosed?.call(message);
  }

  Future<void> _cleanup() async {
    _generation++;
    _expiry?.cancel();
    _expiry = null;
    // Closing the SSH transport releases the remote listener too. Sending a
    // cancellation after a transport failure could produce an unhandled error.
    for (final socket in _locals) {
      socket.destroy();
    }
    _locals.clear();
    for (final channel in _channels) {
      channel.destroy();
    }
    _channels.clear();
    final client = _client;
    final transport = _transport;
    _client = null;
    // SSHClient.close is asynchronous. Await its actual socket shutdown,
    // rather than its early `done` notification, before the isolate can exit.
    // Always bound a graceful close and force release a stalled transport.
    try {
      await client?.close().timeout(const Duration(seconds: 1));
    } catch (_) {}
    transport?.destroy();
    _transport = null;
    // Finish native IO closure before the phone-host isolate is killed.
    try {
      await Future.wait<void>([
        if (client != null)
          client.done.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
        if (transport != null)
          transport.done.then<void>(
            (_) {},
            onError: (Object _, StackTrace __) {},
          ),
        ..._bridges.toList(),
      ]).timeout(const Duration(seconds: 1));
    } catch (_) {}
    // Let native stream-cancellation callbacks finish before PhoneHost kills
    // its isolate; otherwise a remote peer can retain a stale TCP connection.
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _active = false;
    return _closing = _cleanup();
  }
}

class _ControlSocket implements SSHSocket {
  final Socket socket;
  _ControlSocket(this.socket);
  @override
  Stream<Uint8List> get stream => socket;
  @override
  StreamSink<List<int>> get sink => socket;
  @override
  Future<void> get done => socket.done;
  @override
  Future<void> close() async {
    await socket.close();
  }

  @override
  Future<void> flush() => socket.flush();
  @override
  void destroy() => socket.destroy();
}
