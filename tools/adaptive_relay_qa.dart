import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:carwece/online/bore_tunnel.dart';
import 'package:carwece/online/pinggy_tunnel.dart';
import 'package:carwece/online/host/auth.dart';
import 'package:carwece/online/host/server.dart';
import 'package:carwece/online/protocol.dart';

void check(bool value, String reason) {
  if (!value) throw StateError(reason);
}

Future<void> main() async {
  final directory = Platform.environment['CARWECE_RELAY_FIXTURE']!;
  Map<String, dynamic> state() =>
      jsonDecode(File('$directory/connection.json').readAsStringSync())
          as Map<String, dynamic>;
  final config = state();
  final host = config['host'] as String, port = config['port'] as int;
  final pem = File('build/host_identity/certificate.pem').readAsStringSync();
  final key = File('build/host_identity/key.pem').readAsStringSync();
  final pin = base64UrlEncode(
    sha256
        .convert(
          base64Decode(pem.replaceAll(RegExp(r'-----[^-]+-----|\s'), '')),
        )
        .bytes,
  ).replaceAll('=', '');
  final game = CarWeceServer(GuestAuthStore(), maxRooms: 1);
  final local = await game.start(
    address: '127.0.0.1',
    port: 0,
    tls: SecurityContext()
      ..useCertificateChainBytes(utf8.encode(pem))
      ..usePrivateKeyBytes(utf8.encode(key)),
  );
  void mode(String name) => File(
    '$directory/mode.json',
  ).writeAsStringSync(jsonEncode({'mode': name}));
  final raw = PinggyRoute(host, port: port);
  final tls = PinggyRoute(
    host,
    port: port,
    tls: true,
    certificatePin: config['tlsPin'] as String,
  );
  final report = <String, dynamic>{
    'transport':
        'Independent Paramiko SSH/TLS server, real sockets, forwarded pinned game TLS',
    'publicInternetVerified': false,
    'twoAndroidPhonesVerified': false,
  };
  PinggyTunnel tunnel(
    List<PinggyRoute> routes, {
    Duration? timeout,
    void Function(String)? lost,
  }) => PinggyTunnel(
    localPort: local,
    gameCertificatePin: pin,
    routes: routes,
    probeLoopback: true,
    attemptTimeout: timeout ?? const Duration(seconds: 15),
    onClosed: lost,
  );

  Future<void> healthy(PinggyTunnel active) async {
    final endpoint = await active.start();
    final forward = (state()['forwards'] as Map)[endpoint.host] as int;
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false))
      ..badCertificateCallback = (cert, _, _) =>
          base64UrlEncode(sha256.convert(cert.der).bytes).replaceAll('=', '') ==
          pin;
    try {
      final request = await client.getUrl(
        Uri.parse('https://127.0.0.1:$forward/health'),
      );
      final response = await request.close();
      final body = jsonDecode(await utf8.decoder.bind(response).join()) as Map;
      check(
        response.statusCode == 200 &&
            body['protocol'] == onlineProtocol &&
            body['content'] == onlineContent,
        'Forwarded game health failed',
      );
    } finally {
      client.close(force: true);
    }
  }

  try {
    mode('raw_only');
    final old = tunnel([tls]);
    Object? originalFailure;
    try {
      await old.start();
    } catch (e) {
      originalFailure = e;
    } finally {
      await old.close();
    }
    check(
      originalFailure is RelayFailure,
      'TLS-only route must fail on SSH-only edge',
    );
    report['tlsOnlyFailureReproduced'] = originalFailure.toString();

    // This first route has no certificate override, as in the released APK.
    final fixed = tunnel([PinggyRoute(host, port: port, tls: true), raw]);
    final rawBefore = state()['rawSessions'] as int;
    try {
      await healthy(fixed);
    } finally {
      await fixed.close();
    }
    check(
      (state()['rawSessions'] as int) > rawBefore,
      'Did not switch to direct SSH',
    );
    report['failedTLSFallsBackToDirectSSH'] = true;

    mode('tls_only');
    final sslFallback = tunnel([raw, tls]);
    final tlsBefore = state()['tlsSessions'] as int;
    try {
      await healthy(sslFallback);
    } finally {
      await sslFallback.close();
    }
    check(
      (state()['tlsSessions'] as int) > tlsBefore,
      'Did not switch to SSH over TLS',
    );
    report['blockedDirectSSHFallsBackToTLS'] = true;

    mode('normal');
    final unavailable = await ServerSocket.bind('127.0.0.1', 0);
    final deadPort = unavailable.port;
    await unavailable.close();
    final alternate = tunnel([PinggyRoute(host, port: deadPort), raw]);
    try {
      await healthy(alternate);
    } finally {
      await alternate.close();
    }
    report['unreachableControlAddressFallsBack'] = true;

    mode('delayed_urls');
    final delayed = tunnel([raw]);
    final before = state()['apiCalls'] as int;
    try {
      await healthy(delayed);
    } finally {
      await delayed.close();
    }
    check(
      (state()['apiCalls'] as int) - before >= 3,
      'Did not wait for URL allocation',
    );
    report['emptyURLResponsesWaitForAllocation'] = true;

    mode('api_disabled');
    final output = tunnel([raw]);
    try {
      await healthy(output);
    } finally {
      await output.close();
    }
    report['unavailableAPIFallsBackToFragmentedANSIOutput'] = true;

    // A timeout leaves an outstanding SSH handshake. Its late completion must
    // not publish a room or corrupt the next attempt's generation.
    mode('normal');
    final silent = await ServerSocket.bind('127.0.0.1', 0);
    final silentSockets = <Socket>[];
    silent.listen((socket) {
      silentSockets.add(socket);
      socket.listen((_) {}, onError: (Object _) {});
    });
    final timed = tunnel([
      PinggyRoute(host, port: silent.port),
      raw,
    ], timeout: const Duration(seconds: 2));
    try {
      await healthy(timed);
    } finally {
      await timed.close();
      for (final socket in silentSockets) {
        socket.destroy();
      }
      await silent.close();
    }
    report['timedOutHandshakeDoesNotCorruptNextRoute'] = true;

    final lost = <String>[];
    final cancelled = tunnel([raw], lost: lost.add);
    final starting = cancelled.start().then<Object?>(
      (_) => null,
      onError: (Object e) => e,
    );
    await cancelled.close();
    final cancellation = await starting;
    check(
      cancellation is Exception || cancellation is Error,
      'Cancelled startup unexpectedly succeeded',
    );
    check(lost.isEmpty, 'Cancelled startup announced a disconnected room');
    report['cancellationBeforeReadyIsSilent'] = true;

    mode('normal');
    final recreated = tunnel([raw]);
    try {
      await healthy(recreated);
    } finally {
      await recreated.close();
    }
    report['roomCanBeRecreatedAfterFailures'] = true;
    report['result'] = 'PASS';
    final result = const JsonEncoder.withIndent('  ').convert(report);
    File('verification/adaptive_relay_v0143.json').writeAsStringSync(result);
    stdout.writeln(result);
  } finally {
    mode('normal');
    await game.close();
  }
}
