import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/online/bore_tunnel.dart';
import 'package:carwece/online/invite.dart';

class RelayFixture {
  final Future<void> Function(Socket, int) reply;
  late final ServerSocket listener;
  final sockets = <Socket>[];
  final greetings = <Object?>[];
  RelayFixture(this.reply);
  Future<void> start() async {
    listener = await ServerSocket.bind('127.0.0.1', 0);
    listener.listen((socket) {
      sockets.add(socket);
      final number = sockets.length;
      final bytes = <int>[];
      var first = true;
      socket.listen((chunk) {
        if (!first) return;
        bytes.addAll(chunk);
        final end = bytes.indexOf(0);
        if (end < 0) return;
        first = false;
        greetings.add(jsonDecode(utf8.decode(bytes.take(end).toList())));
        unawaited(reply(socket, number));
      }, onError: (Object _) {});
    });
  }

  BoreTunnel tunnel({
    void Function(String)? lost,
    void Function(int, int)? retry,
  }) => BoreTunnel(
    localPort: 43210,
    relayHost: '127.0.0.1',
    controlPort: listener.port,
    connectTimeout: const Duration(milliseconds: 300),
    handshakeTimeout: const Duration(milliseconds: 100),
    retryDelay: const Duration(milliseconds: 1),
    onClosed: lost,
    onRetry: retry,
  );
  Future<void> close() async {
    for (final socket in sockets) {
      socket.destroy();
    }
    await listener.close();
  }
}

void frame(Socket socket, Object message) =>
    socket.add([...utf8.encode(jsonEncode(message)), 0]);

void main() {
  test(
    'transient EOF retries up to three times without announcing a lost room',
    () async {
      final fixture = RelayFixture((s, n) async {
        if (n < 3) {
          await s.close();
        } else {
          frame(s, {'Hello': 32123});
        }
      });
      await fixture.start();
      addTearDown(fixture.close);
      final lost = <String>[], retries = <int>[];
      final tunnel = fixture.tunnel(
        lost: lost.add,
        retry: (n, _) => retries.add(n),
      );
      addTearDown(tunnel.close);
      expect(await tunnel.start(), 32123);
      expect(fixture.greetings, List.filled(3, {'Hello': 0}));
      expect(retries, [2, 3]);
      expect(lost, isEmpty);
      tunnel.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(lost, isEmpty);
    },
  );

  test(
    'persistent EOF preserves startup error instead of generic onClosed',
    () async {
      final fixture = RelayFixture((s, n) async {
        await s.close();
      });
      await fixture.start();
      addTearDown(fixture.close);
      final lost = <String>[];
      final tunnel = fixture.tunnel(lost: lost.add);
      addTearDown(tunnel.close);
      await expectLater(
        tunnel.start(),
        throwsA(
          isA<RelayFailure>().having(
            (e) => e.message,
            'reason',
            contains('encerrou'),
          ),
        ),
      );
      expect(fixture.sockets.length, 3);
      expect(lost, isEmpty);
    },
  );

  test(
    'authentication requirement fails immediately, with its actual reason',
    () async {
      final fixture = RelayFixture((s, n) async {
        frame(s, {'Challenge': '00000000-0000-4000-8000-000000000001'});
      });
      await fixture.start();
      addTearDown(fixture.close);
      final tunnel = fixture.tunnel();
      addTearDown(tunnel.close);
      await expectLater(
        tunnel.start(),
        throwsA(
          isA<RelayFailure>().having(
            (e) => e.message,
            'reason',
            contains('autenticação'),
          ),
        ),
      );
      expect(fixture.sockets.length, 1);
    },
  );

  test(
    'relay rejection is bounded and does not render arbitrary remote text',
    () async {
      final fixture = RelayFixture((s, n) async {
        frame(s, {'Error': 'UNTRUSTED_TEXT'});
      });
      await fixture.start();
      addTearDown(fixture.close);
      final tunnel = fixture.tunnel();
      addTearDown(tunnel.close);
      await expectLater(
        tunnel.start(),
        throwsA(
          isA<RelayFailure>().having(
            (e) => e.message,
            'reason',
            allOf(contains('recusou'), isNot(contains('UNTRUSTED'))),
          ),
        ),
      );
      expect(fixture.sockets.length, 3);
    },
  );

  test(
    'silent relay times out, releases attempts, and never announces a room',
    () async {
      final fixture = RelayFixture((s, n) async {});
      await fixture.start();
      addTearDown(fixture.close);
      final lost = <String>[];
      final tunnel = fixture.tunnel(lost: lost.add);
      addTearDown(tunnel.close);
      await expectLater(
        tunnel.start(),
        throwsA(
          isA<RelayFailure>().having(
            (e) => e.message,
            'reason',
            contains('tempo'),
          ),
        ),
      );
      expect(fixture.sockets.length, 3);
      expect(tunnel.remotePort, 0);
      expect(lost, isEmpty);
    },
  );

  test(
    'cancelling a silent startup stops retries and completes promptly',
    () async {
      final fixture = RelayFixture((s, n) async {});
      await fixture.start();
      addTearDown(fixture.close);
      final tunnel = fixture.tunnel();
      final startup = tunnel.start();
      final checked = expectLater(startup, throwsA(isA<RelayFailure>()));
      while (fixture.greetings.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      tunnel.close();
      await checked;
      expect(fixture.sockets.length, 1);
    },
  );

  test(
    'fragmented frames and heartbeats coexist; established EOF reports once',
    () async {
      final fixture = RelayFixture((s, n) async {
        s.add(utf8.encode('{"Hel'));
        await s.flush();
        await Future<void>.delayed(const Duration(milliseconds: 2));
        s.add(
          utf8.encode('lo":32001}\u0000"Heartbeat"\u0000"Heartbeat"\u0000'),
        );
      });
      await fixture.start();
      addTearDown(fixture.close);
      final lost = Completer<String>();
      var calls = 0;
      final tunnel = fixture.tunnel(
        lost: (message) {
          calls++;
          if (!lost.isCompleted) lost.complete(message);
        },
      );
      addTearDown(tunnel.close);
      expect(await tunnel.start(), 32001);
      await fixture.sockets.first.close();
      expect(
        await lost.future.timeout(const Duration(seconds: 1)),
        contains('encerrou'),
      );
      expect(calls, 1);
    },
  );

  test(
    'invalid public port and oversized frames are refused without retry loops',
    () async {
      for (final payload in [
        jsonEncode({'Hello': 0}),
        List.filled(257, 'x').join(),
      ]) {
        final fixture = RelayFixture((s, n) async {
          s.add([...utf8.encode(payload), 0]);
        });
        await fixture.start();
        final tunnel = fixture.tunnel();
        try {
          await expectLater(tunnel.start(), throwsA(isA<RelayFailure>()));
          expect(fixture.sockets.length, 1);
        } finally {
          tunnel.close();
          await fixture.close();
        }
      }
    },
  );

  test(
    'internet invitations remain compatible; LAN invites preserve only private IPv4',
    () {
      final fingerprint = base64UrlEncode(
        List.generate(32, (i) => i),
      ).replaceAll('=', '');
      final internet = FriendInvite(45321, 'ABC123', fingerprint);
      expect(FriendInvite.parse(internet.code).endpoint, internet.endpoint);
      expect(internet.code.startsWith('CW1-'), isTrue);
      for (final address in [
        '192.168.0.12',
        '10.0.0.1',
        '172.16.5.8',
        '172.31.255.10',
      ]) {
        final lan = FriendInvite.lan(address, 45321, 'ABC123', fingerprint);
        final parsed = FriendInvite.parse(lan.code);
        expect(parsed.isLocal, isTrue);
        expect(parsed.endpoint.host, address);
        expect(parsed.fingerprint, fingerprint);
      }
      for (final address in [
        '8.8.8.8',
        '127.0.0.1',
        '169.254.1.2',
        '172.32.0.1',
        '255.255.255.255',
      ]) {
        final code = FriendInvite.lan(
          address,
          45321,
          'ABC123',
          fingerprint,
        ).code;
        expect(() => FriendInvite.parse(code), throwsFormatException);
      }
      expect(
        () => FriendInvite.parse('CW1-c0a80001-1ABC-ABC123-' + fingerprint),
        throwsFormatException,
      );
    },
  );
}
