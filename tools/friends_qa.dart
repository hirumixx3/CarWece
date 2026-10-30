import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/online/client.dart';
import 'package:carwece/online/invite.dart';
import 'package:carwece/online/phone_host.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> until(bool Function() predicate, String what) async {
  final end = DateTime.now().add(const Duration(seconds: 15));
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timeout: $what');
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

/// Local bore protocol oracle with real TCP streams, a public listener per
/// Hello, control messages split across packets, and separate Accept streams.
class TestRelay {
  final int disconnectFirst;
  int helloCount = 0;
  TestRelay({this.disconnectFirst = 0});
  late final ServerSocket control;
  final listeners = <ServerSocket>[];
  final sockets = <Socket>{};
  final pending = <String, Socket>{};
  int serial = 0;
  Future<void> start() async {
    control = await ServerSocket.bind('127.0.0.1', 0);
    control.listen(_control);
  }

  void _control(Socket connection) {
    sockets.add(connection);
    unawaited(
      connection.done.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
    final bytes = <int>[];
    var accepted = false;
    final remainder = StreamController<List<int>>();
    connection.listen(
      (chunk) async {
        if (accepted) {
          remainder.add(chunk);
          return;
        }
        final separator = chunk.indexOf(0);
        if (separator < 0) {
          bytes.addAll(chunk);
          return;
        }
        bytes.addAll(chunk.take(separator));
        final m = jsonDecode(utf8.decode(bytes)) as Map;
        accepted = true;
        if (m.containsKey('Hello')) {
          if (++helloCount <= disconnectFirst) {
            connection.destroy();
            return;
          }
          final listener = await ServerSocket.bind('127.0.0.1', 0);
          listeners.add(listener);
          final greeting = utf8.encode(jsonEncode({'Hello': listener.port}));
          connection.add(greeting.take(4).toList());
          await connection.flush();
          connection.add([...greeting.skip(4), 0]);
          listener.listen((guest) {
            sockets.add(guest);
            unawaited(
              guest.done.then<void>(
                (_) {},
                onError: (Object _, StackTrace __) {},
              ),
            );
            final id =
                '00000000-0000-4000-8000-${(++serial).toString().padLeft(12, '0')}';
            pending[id] = guest;
            connection.add([
              ...utf8.encode(jsonEncode({'Connection': id})),
              0,
            ]);
          });
          unawaited(remainder.stream.drain<void>());
        } else if (m['Accept'] is String) {
          final guest = pending.remove(m['Accept']);
          if (guest == null) {
            connection.destroy();
            return;
          }
          final extra = chunk.skip(separator + 1).toList();
          if (extra.isNotEmpty) remainder.add(extra);
          unawaited(
            guest
                .addStream(remainder.stream)
                .then((_) => guest.close())
                .catchError((Object _) {
                  guest.destroy();
                }),
          );
          unawaited(
            connection
                .addStream(guest)
                .then((_) => connection.close())
                .catchError((Object _) {
                  connection.destroy();
                }),
          );
        }
      },
      onDone: () {
        unawaited(remainder.close());
      },
      onError: (Object _) {
        unawaited(remainder.close());
      },
    );
  }

  Future<void> close() async {
    for (final s in sockets) {
      s.destroy();
    }
    for (final s in listeners) {
      await s.close();
    }
    await control.close();
  }
}

Future<void> main(List<String> args) async {
  final localNetwork = args.contains("--lan");
  final sshMode = args.contains("--ssh");
  final rawSSH = args.contains('--raw');
  Map<String, dynamic> sshState() =>
      jsonDecode(
            File(
              (Platform.environment['CARWECE_RELAY_FIXTURE'] ??
                      'build/pinggy_fixture') +
                  '/connection.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final directory = Directory('build/host_identity');
  check(
    await directory.exists(),
    'Execute o teste Kotlin HostIdentityTest antes.',
  );
  final identity = {
    'certificate': await File(
      '${directory.path}/certificate.pem',
    ).readAsString(),
    'key': await File('${directory.path}/key.pem').readAsString(),
    // The sandbox has no Wi-Fi interface. Exercise the direct listener using a
    // private invitation address supplied by the test and loopback connections.
    if (localNetwork) 'localAddress': '192.168.77.1',
  };
  final relay = TestRelay(disconnectFirst: 2);
  await relay.start();
  final tracks = createTracks(), arenas = createBattleArenas();
  final host = OnlineClient(
    tracks: tracks,
    arenas: arenas,
    createHostIdentity: () async => identity,
    hostFactory: (lost) => PhoneHost(
      onLost: lost,
      relayHost: sshMode ? null : '127.0.0.1',
      pinggyOptions: sshMode
          ? {
              for (final key in ['host', 'port', 'tlsPin', 'probeLoopback'])
                if (key != 'tlsPin' || !rawSSH) key: sshState()[key],
            }
          : null,
      relayControlPort: relay.control.port,
    ),
  );
  final guests = List.generate(
    6,
    (_) => OnlineClient(
      tracks: tracks,
      arenas: arenas,
      friendEndpoint: (invite) => Uri(
        scheme: 'https',
        host: '127.0.0.1',
        port: sshMode
            ? (sshState()['forwards'] as Map)[invite.endpoint.host] as int
            : invite.port,
      ),
    ),
  );
  Timer? render;
  final report = <String, dynamic>{
    'transport': sshMode
        ? '${rawSSH ? "direct SSH" : "SSH inside TLS"}, remote TCP forwarding, native game TLS and WebSocket; independent local Paramiko server; public DNS/SNI not emulated'
        : localNetwork
        ? 'real direct TCP + pinned TLS + WebSocket on loopback; listener binds all IPv4; LAN address injected; no relay'
        : 'real TCP + pinned TLS + WebSocket; local bore protocol oracle',
    'nativeIdentity': 'HostIdentity Kotlin output',
    'publicInternetVerified': false,
    if (localNetwork) 'wifiInterfaceDiscoveryVerified': false,
    if (localNetwork) 'twoAndroidPhonesVerified': false,
  };
  try {
    if (!localNetwork && !sshMode) {
      final deadRelay = TestRelay(disconnectFirst: 99);
      await deadRelay.start();
      final lost = <String>[];
      final failed = PhoneHost(
        onLost: lost.add,
        relayHost: '127.0.0.1',
        relayControlPort: deadRelay.control.port,
      );
      try {
        Object? error;
        try {
          await failed.start(identity);
        } catch (e) {
          error = e;
        }
        check(
          error is StateError && error.message.toString().contains('encerrou'),
          'Original startup error is preserved: $error',
        );
        check(
          deadRelay.helloCount == 3 && lost.isEmpty,
          'Three failed attempts are not an established-room disconnect',
        );
        report['startupErrorPreserved'] = true;
      } finally {
        await failed.close();
        await deadRelay.close();
      }
    }
    await host.createWithFriends(
      username: 'Higor',
      localNetwork: localNetwork,
      garage: ['rx7'],
      kind: 'battle',
      map: arenas.first.track.id,
      car: 0,
    );
    check(host.error.isEmpty && host.connected, 'Host: ${host.error}');
    check(
      sshMode
          ? host.shareCode!.startsWith('CW2-') && host.friendInvite!.port == 443
          : localNetwork
          ? relay.helloCount == 0
          : relay.helloCount == 3,
      'LAN bypasses relay; internet retries initial disconnects',
    );
    report[sshMode
            ? 'sshTransportAndPublicProbe'
            : localNetwork
            ? 'relayBypassed'
            : 'startupRecoveredAfterTwoDisconnects'] =
        true;
    await until(() => host.room != null, 'host room');
    stdout.writeln('QA: host room ready');
    final invitation = host.shareCode!;
    final parsed = FriendInvite.parse(invitation);
    check(
      parsed.code == invitation && parsed.room == host.room!['code'],
      'Invite round-trip',
    );
    FriendInvite changedInvite(String room, String pin) => parsed.isLocal
        ? FriendInvite.lan(parsed.localAddress, parsed.port, room, pin)
        : parsed.relayAddress != null
        ? FriendInvite.internet(parsed.relayAddress, room, pin)
        : FriendInvite(parsed.port, room, pin);
    final wrongPin = changedInvite(
      parsed.room,
      List.filled(43, 'A').join(),
    ).code;
    await guests.last.joinWithFriends(
      username: 'Espiao',
      garage: ['rx7'],
      invitation: wrongPin,
      car: 0,
    );
    check(
      !guests.last.connected && guests.last.profile == null,
      'Wrong TLS pin must be rejected',
    );
    stdout.writeln('QA: wrong certificate rejected');
    report['wrongCertificateRejected'] = true;
    await guests.last.joinWithFriends(
      username: 'Outro',
      garage: ['rx7'],
      invitation: changedInvite('WRONG1', parsed.fingerprint).code,
      car: 0,
    );
    check(
      !guests.last.connected && guests.last.error.contains('Convite'),
      'Wrong room secret rejected',
    );
    stdout.writeln('QA: wrong invitation rejected');
    report['wrongInviteRejected'] = true;
    for (var i = 0; i < 5; i++) {
      await guests[i].joinWithFriends(
        username: 'Amigo ${i + 1}',
        garage: ['rx7'],
        invitation: invitation,
        car: 0,
      );
      check(
        guests[i].connected && guests[i].error.isEmpty,
        'Guest $i: ${guests[i].error}',
      );
    }
    await until(
      () => (host.room!['players'] as List).length == 6,
      'six players',
    );
    stdout.writeln('QA: six players connected');
    report['sixPlayers'] = true;
    await guests.last.joinWithFriends(
      username: 'Higor',
      garage: ['rx7'],
      invitation: invitation,
      car: 0,
    );
    check(guests.last.error.contains('nome'), 'Duplicate nick rejected');
    report['duplicateNameRejected'] = true;
    await guests.last.joinWithFriends(
      username: 'Setimo',
      garage: ['rx7'],
      invitation: invitation,
      car: 0,
    );
    await until(() => guests.last.error.isNotEmpty, 'full room refusal');
    check(guests.last.room == null, 'Seventh player cannot join');
    await guests.last.signOut();
    report['seventhPlayerRejected'] = true;
    final players = [host, ...guests.take(5)];
    render = Timer.periodic(const Duration(milliseconds: 16), (_) {
      for (final p in players) {
        p.match?.update(.016);
      }
    });
    stdout.writeln('QA: starting match');
    host.send({'type': 'start'});
    await until(
      () => players.every((p) => p.match is BattleEngine),
      'battle launched',
    );
    await until(
      () => players.every((p) => p.match!.countdown <= 0),
      'synchronized start',
    );
    for (final p in players) {
      final b = p.match as BattleEngine;
      b.cycleTarget();
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    check(
      players.every((p) => (p.match as BattleEngine).selectedTarget != null),
      'Server validated target for every player',
    );
    report['battleTargetsSynchronized'] = true;
    final b = guests.first.match as BattleEngine;
    final previous = b.selectedTarget;
    b.cycleTarget();
    await until(
      () => b.selectedTarget != previous,
      'cycle target server round-trip',
    );
    report['cycleTargetReplicated'] = true;
    await host.signOut();
    stdout.writeln(
      'QA: host signOut completed; host busy=' +
          host.busy.toString() +
          ' phone=' +
          (host.phoneHost != null).toString() +
          '; peers: ' +
          guests
              .take(5)
              .map((g) => g.connected.toString() + ':' + g.status)
              .join(' | '),
    );
    await until(
      () => guests.take(5).every((guest) => !guest.connected),
      'host closes room for everyone',
    );
    report['hostShutdownDisconnectsPeers'] = true;
    render.cancel();
    render = null;
    // Exercise the race mode through the same on-phone isolate and relay path.
    await host.createWithFriends(
      username: 'Higor',
      localNetwork: localNetwork,
      garage: ['rx7'],
      kind: 'race',
      map: tracks.last.id,
      car: 0,
    );
    check(
      host.connected && host.error.isEmpty,
      'Recreate race host: ${host.error}',
    );
    await until(() => host.room != null, 'race room');
    await guests.first.signOut();
    await guests.first.joinWithFriends(
      username: 'Amigo',
      garage: ['rx7'],
      invitation: host.shareCode!,
      car: 0,
    );
    await until(
      () => (host.room!['players'] as List).length == 2,
      'race guest',
    );
    stdout.writeln('QA: starting match');
    host.send({'type': 'start'});
    await until(
      () => host.match != null && guests.first.match != null,
      'race launch',
    );
    check(
      host.match is! BattleEngine && host.match!.track.id == tracks.last.id,
      'Race map preserved',
    );
    report['raceAndBattle'] = true;
    report['result'] = 'PASS';
    await File(
      localNetwork
          ? 'verification/friends_lan_v0143.json'
          : sshMode
          ? 'verification/friends_ssh_${rawSSH ? "raw" : "tls"}_v0143.json'
          : 'verification/friends_transport_v0143.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } finally {
    render?.cancel();
    host.dispose();
    for (final g in guests) {
      g.dispose();
    }
    await relay.close();
    stdout.writeln('QA: clients disposed and fixture listeners closed');
  }
}
