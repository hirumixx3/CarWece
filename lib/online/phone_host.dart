import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'host/auth.dart';
import 'host/server.dart';
import 'bore_tunnel.dart';
import 'pinggy_tunnel.dart';
import 'invite.dart';

class PhoneHost {
  final ReceivePort _messages = ReceivePort();
  final void Function(String)? onLost;
  final void Function(String)? onStatus;
  SendPort? _commands;
  Isolate? _isolate;
  final Completer<void> _stopped = Completer<void>();
  Completer<void>? _starting;
  bool _closed = false;
  late final String room, fingerprint;
  late final Uri endpoint;
  late final FriendInvite invite;
  final Future<void> Function(bool)? keepAlive;
  final String? relayHost;
  final int relayControlPort;
  final Map<String, dynamic>? pinggyOptions;
  PhoneHost({
    this.onLost,
    this.onStatus,
    this.keepAlive,
    this.relayHost,
    this.relayControlPort = 7835,
    this.pinggyOptions,
  });

  Future<void> start(
    Map<String, String> identity, {
    bool localNetwork = false,
  }) async {
    if (_closed) throw StateError('Sala encerrada.');
    final pem = identity['certificate']!, key = identity['key']!;
    fingerprint = base64UrlEncode(
      sha256
          .convert(
            base64Decode(pem.replaceAll(RegExp(r'-----[^-]+-----|\s'), '')),
          )
          .bytes,
    ).replaceAll('=', '');
    room = randomToken(9)
        .replaceAll(RegExp('[^A-Za-z0-9]'), '')
        .toUpperCase()
        .padRight(6, 'X')
        .substring(0, 6);
    final ready = Completer<void>();
    _starting = ready;
    _messages.listen((dynamic m) {
      if (m == null) {
        if (!_stopped.isCompleted) _stopped.complete();
        if (!ready.isCompleted && !_closed) {
          ready.completeError(
            StateError(
              'A hospedagem foi interrompida antes de abrir a sala. Tente novamente.',
            ),
          );
        }
        return;
      }
      if (m is SendPort) {
        _commands = m;
        return;
      }
      if (m is! Map) return;
      if (m['type'] == 'stopped') {
        if (!_stopped.isCompleted) _stopped.complete();
      } else if (m['type'] == 'ready') {
        endpoint = Uri(scheme: 'https', host: '127.0.0.1', port: m['local']);
        invite = m['lan'] is String
            ? FriendInvite.lan(m['lan'], m['local'], room, fingerprint)
            : m['host'] is String
            ? FriendInvite.internet(m['host'], room, fingerprint)
            : FriendInvite(m['public'], room, fingerprint);
        if (!ready.isCompleted) ready.complete();
      } else if (m['type'] == 'progress') {
        onStatus?.call('${m['message']}');
      } else if (m['type'] == 'error') {
        if (!ready.isCompleted) {
          ready.completeError(StateError('${m['message']}'));
        } else if (!_closed) {
          onLost?.call(
            '${m['message']} Crie uma nova sala para gerar outro convite.',
          );
        }
      }
    });
    try {
      await keepAlive?.call(true);
      _isolate = await Isolate.spawn(
        _hostMain,
        [
          _messages.sendPort,
          pem,
          key,
          room,
          relayHost,
          relayControlPort,
          localNetwork,
          identity['localAddress'],
          pinggyOptions,
          fingerprint,
        ],
        debugName: 'CarWece friend host',
        onExit: _messages.sendPort,
      );
      await ready.future.timeout(const Duration(seconds: 95));
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (_starting != null && !_starting!.isCompleted) {
      _starting!.completeError(StateError('Criação da sala cancelada.'));
    }
    _commands?.send('stop');
    // Let the isolate destroy tunnel sockets and finish WebSocket close frames.
    // Killing it immediately can leave native IO resources alive in the VM.
    if (_commands != null) {
      try {
        await _stopped.future.timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    _isolate?.kill(priority: Isolate.immediate);
    _messages.close();
    try {
      await keepAlive?.call(false);
    } catch (_) {}
  }
}

Future<void> _hostMain(List<dynamic> args) async {
  final output = args[0] as SendPort, commands = ReceivePort();
  output.send(commands.sendPort);
  final server = CarWeceServer(
    GuestAuthStore(),
    maxRooms: 1,
    friendCode: args[3],
  );
  BoreTunnel? tunnel;
  PinggyTunnel? internet;
  var stopping = false;
  Future<void> stop() async {
    if (stopping) return;
    stopping = true;
    if (const bool.fromEnvironment('CARWECE_NETWORK_QA'))
      stderr.writeln('Host stop: closing game server');
    try {
      await server.close().timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (const bool.fromEnvironment('CARWECE_NETWORK_QA'))
      stderr.writeln('Host stop: closing internet transport');
    tunnel?.close();
    await internet?.close();
    if (const bool.fromEnvironment('CARWECE_NETWORK_QA'))
      stderr.writeln('Host stop: transport closed');
    commands.close();
    output.send({'type': 'stopped'});
  }

  commands.listen((m) {
    if (m == 'stop') unawaited(stop());
  });
  try {
    final tls = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(args[1]))
      ..usePrivateKeyBytes(utf8.encode(args[2]));
    final localNetwork = args[6] as bool;
    final lan = localNetwork ? await _lanAddress(args[7] as String?) : null;
    final local = await server.start(
      address: localNetwork ? '0.0.0.0' : '127.0.0.1',
      port: 0,
      tls: tls,
    );
    if (stopping) {
      await server.close();
      return;
    }
    if (localNetwork) {
      output.send({'type': 'ready', 'local': local, 'lan': lan});
      return;
    }
    if (args[4] == null) {
      final options = args[8] as Map<String, dynamic>? ?? const {};
      internet = PinggyTunnel(
        localPort: local,
        gameCertificatePin: args[9] as String,
        serverHost: options['host'] as String? ?? 'free.pinggy.io',
        serverPort: options['port'] as int? ?? 443,
        pinnedTransportCertificate: options['tlsPin'] as String?,
        probeLoopback: options['probeLoopback'] == true,
        routes: (options['routes'] as List?)
            ?.map(
              (dynamic route) => PinggyRoute(
                route['host'] as String,
                port: route['port'] as int? ?? 443,
                tls: route['tls'] == true,
                certificatePin: route['tlsPin'] as String?,
              ),
            )
            .toList(),
        onStatus: (message) {
          if (!stopping) output.send({'type': 'progress', 'message': message});
        },
        onClosed: (message) {
          if (!stopping) {
            output.send({'type': 'error', 'message': message});
            unawaited(stop());
          }
        },
      );
      final endpoint = await internet.start();
      if (!stopping)
        output.send({'type': 'ready', 'local': local, 'host': endpoint.host});
      return;
    }
    // Explicit legacy relay injection is retained for protocol regression tests.
    tunnel = BoreTunnel(
      localPort: local,
      relayHost: args[4],
      controlPort: args[5],
      onRetry: (attempt, count) {
        if (!stopping)
          output.send({
            'type': 'progress',
            'message':
                'Reconectando ao retransmissor… tentativa $attempt de $count',
          });
      },
      onClosed: (reason) {
        if (!stopping) {
          output.send({'type': 'error', 'message': reason});
          unawaited(stop());
        }
      },
    );
    final public = await tunnel.start();
    output.send({'type': 'ready', 'local': local, 'public': public});
  } catch (e) {
    output.send({
      'type': 'error',
      'message': e is RelayFailure
          ? e.message
          : e is StateError
          ? e.message
          : 'Não foi possível preparar a sala. Confira a rede e tente novamente.',
    });
    await stop();
  }
}

Future<String> _lanAddress(String? provided) async {
  // Embedded callers/tests can supply an address; only private IPv4 is valid.
  if (provided != null) {
    if (FriendInvite.privateIPv4(provided)) return provided;
    throw StateError(
      'O endereço da sala Wi-Fi precisa pertencer à rede local.',
    );
  }
  final List<NetworkInterface> interfaces;
  try {
    interfaces = (await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ).timeout(const Duration(seconds: 5))).toList();
  } catch (_) {
    throw StateError(
      'Não foi possível identificar a rede Wi-Fi. Conecte o celular ao Wi-Fi ou a um ponto de acesso e tente novamente.',
    );
  }
  int priority(NetworkInterface i) =>
      RegExp(r'wlan|wifi|ap\d').hasMatch(i.name.toLowerCase()) ? 0 : 1;
  interfaces.sort((a, b) => priority(a).compareTo(priority(b)));
  for (final i in interfaces) {
    if (RegExp(
      r'^(rmnet|ccmni|pdp|tun|lo|dummy)',
    ).hasMatch(i.name.toLowerCase()))
      continue;
    for (final address in i.addresses) {
      if (FriendInvite.privateIPv4(address.address)) return address.address;
    }
  }
  throw StateError(
    'Conecte o celular ao mesmo Wi-Fi dos amigos ou a um ponto de acesso e tente novamente.',
  );
}
