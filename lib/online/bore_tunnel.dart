import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RelayFailure implements Exception {
  final String message;
  final bool retryable;
  const RelayFailure(this.message, {this.retryable = true});
  @override
  String toString() => message;
}

/// bore 0.6 control protocol: NUL-separated JSON, maximum 256 bytes per frame.
/// Retry only before publishing an invitation: changing a public port would
/// invalidate invitations already shared with guests.
class BoreTunnel {
  final String relayHost, localHost;
  final int controlPort, localPort, attempts;
  final Duration connectTimeout, handshakeTimeout, retryDelay;
  final void Function(String)? onClosed;
  final void Function(int, int)? onRetry;
  Socket? _control;
  Completer<int>? _ready;
  final _sockets = <Socket>{};
  bool _closed = false, _started = false, _active = false;
  int remotePort = 0;
  BoreTunnel({
    required this.localPort,
    this.localHost = '127.0.0.1',
    this.relayHost = 'bore.pub',
    this.controlPort = 7835,
    this.attempts = 3,
    this.connectTimeout = const Duration(seconds: 8),
    this.handshakeTimeout = const Duration(seconds: 6),
    this.retryDelay = const Duration(milliseconds: 400),
    this.onClosed,
    this.onRetry,
  });

  Future<int> start() async {
    if (_started || _closed) throw StateError('Sala já iniciada ou encerrada.');
    _started = true;
    final count = attempts.clamp(1, 3);
    for (var attempt = 1; attempt <= count; attempt++) {
      try {
        final port = await _attempt();
        _active = true;
        return port;
      } catch (e) {
        _dropControl();
        if (_closed) rethrow;
        final failure = _failure(e);
        if (!failure.retryable || attempt == count) {
          close();
          throw failure;
        }
        onRetry?.call(attempt + 1, count);
        await Future<void>.delayed(retryDelay * attempt);
        if (_closed)
          throw const RelayFailure(
            'Criação da sala cancelada.',
            retryable: false,
          );
      }
    }
    throw StateError('Tentativas esgotadas.');
  }

  static RelayFailure _failure(Object e) {
    if (e is RelayFailure) return e;
    if (e is TimeoutException) {
      return const RelayFailure(
        'O retransmissor não respondeu a tempo. Tente outra rede ou use MESMO WI-FI se todos estiverem juntos.',
      );
    }
    if (e is SocketException) {
      return const RelayFailure(
        'Não foi possível alcançar o retransmissor. Confira a internet; a rede pode bloquear a conexão ou o serviço estar fora do ar.',
      );
    }
    return const RelayFailure(
      'O retransmissor enviou uma resposta inválida. Tente novamente mais tarde.',
      retryable: false,
    );
  }

  Future<int> _attempt() async {
    final socket = await Socket.connect(
      relayHost,
      controlPort,
      timeout: connectTimeout,
    );
    if (_closed) {
      socket.destroy();
      throw const RelayFailure('Criação da sala cancelada.', retryable: false);
    }
    _control = socket;
    final ready = Completer<int>();
    _ready = ready;
    _ignoreDone(socket);
    socket.setOption(SocketOption.tcpNoDelay, true);
    final bytes = <int>[];
    Object? startupFailure;
    void fail(Object error) {
      if (_control != socket || _closed) return;
      if (!_active) {
        startupFailure = error;
        _dropControl();
        if (!ready.isCompleted) ready.completeError(error);
      } else {
        // A deliberate close or failed startup must never fire onClosed.
        final message = _failure(error).message;
        close();
        onClosed?.call(message);
      }
    }

    socket.listen(
      (chunk) {
        if (_control != socket || _closed) return;
        try {
          for (final b in chunk) {
            if (b != 0) {
              bytes.add(b);
              if (bytes.length > 256)
                throw const FormatException('Frame excedido');
              continue;
            }
            final message = jsonDecode(utf8.decode(bytes));
            bytes.clear();
            if (message == 'Heartbeat') continue;
            if (message is! Map || message.length != 1)
              throw const FormatException('Frame inválido');
            if (message['Hello'] is int && !ready.isCompleted) {
              final port = message['Hello'] as int;
              if (port < 1024 || port > 65535)
                throw const FormatException('Porta inválida');
              remotePort = port;
              ready.complete(port);
            } else if (message['Connection'] is String && remotePort != 0) {
              final id = message['Connection'] as String;
              if (!RegExp(
                r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
              ).hasMatch(id)) {
                throw const FormatException('Conexão inválida');
              }
              unawaited(_forward(id));
            } else if (message.containsKey('Challenge')) {
              throw const RelayFailure(
                'O retransmissor está exigindo autenticação. A sala pela internet está indisponível neste serviço.',
                retryable: false,
              );
            } else if (message.containsKey('Error')) {
              // Do not expose untrusted server text in the UI.
              throw const RelayFailure(
                'O retransmissor recusou a abertura da sala. Aguarde e tente novamente, ou use MESMO WI-FI se todos estiverem juntos.',
              );
            } else {
              throw const FormatException('Mensagem inesperada');
            }
          }
        } catch (e) {
          fail(e);
        }
      },
      onError: (Object e) => fail(e),
      onDone: () {
        fail(
          const RelayFailure(
            'O retransmissor encerrou a conexão. O serviço pode estar indisponível ou bloqueado nesta rede. Tente outra rede ou MESMO WI-FI.',
          ),
        );
      },
    );
    socket.add([
      ...utf8.encode(jsonEncode({'Hello': 0})),
      0,
    ]);
    try {
      final port = await ready.future.timeout(handshakeTimeout);
      if (startupFailure != null) throw startupFailure!;
      if (_closed || _control != socket) {
        throw const RelayFailure(
          'Criação da sala cancelada.',
          retryable: false,
        );
      }
      return port;
    } finally {
      if (_ready == ready) _ready = null;
    }
  }

  void _ignoreDone(Socket socket) {
    unawaited(
      socket.done.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
  }

  Future<void> _forward(String id) async {
    if (_closed || _sockets.length >= 48) return;
    Socket? remote, local;
    try {
      remote = await Socket.connect(
        relayHost,
        controlPort,
        timeout: connectTimeout,
      );
      if (_closed) return;
      _sockets.add(remote);
      _ignoreDone(remote);
      local = await Socket.connect(
        localHost,
        localPort,
        timeout: const Duration(seconds: 5),
      );
      if (_closed) return;
      _sockets.add(local);
      _ignoreDone(local);
      remote.setOption(SocketOption.tcpNoDelay, true);
      local.setOption(SocketOption.tcpNoDelay, true);
      remote.add([
        ...utf8.encode(jsonEncode({'Accept': id})),
        0,
      ]);
      final upstream = local.addStream(remote).then((_) => local!.close());
      final downstream = remote.addStream(local).then((_) => remote!.close());
      await Future.wait([upstream, downstream], eagerError: true);
    } catch (_) {
      // A failed peer must not disconnect the other players.
    } finally {
      remote?.destroy();
      local?.destroy();
      _sockets.remove(remote);
      _sockets.remove(local);
    }
  }

  void _dropControl() {
    final socket = _control;
    _control = null;
    remotePort = 0;
    socket?.destroy();
  }

  void close() {
    if (_closed) return;
    _closed = true;
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(
        const RelayFailure('Criação da sala cancelada.', retryable: false),
      );
    }
    _dropControl();
    for (final socket in _sockets) {
      socket.destroy();
    }
    _sockets.clear();
  }
}
