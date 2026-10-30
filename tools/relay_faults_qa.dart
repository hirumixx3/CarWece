import 'dart:convert';
import 'dart:io';
import 'package:carwece/online/phone_host.dart';
import 'package:carwece/online/invite.dart';

void check(bool value, String why) {
  if (!value) throw StateError(why);
}

Future<void> main() async {
  final state =
      jsonDecode(
            File(
              (Platform.environment['CARWECE_RELAY_FIXTURE'] ??
                      'build/pinggy_fixture') +
                  '/connection.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final config = {
    for (final key in ['host', 'port', 'tlsPin', 'probeLoopback'])
      key: state[key],
  };
  final identity = {
    'certificate': File(
      'build/host_identity/certificate.pem',
    ).readAsStringSync(),
    'key': File('build/host_identity/key.pem').readAsStringSync(),
  };
  final report = <String, dynamic>{
    'transport': 'actual local SSH inside TLS, with independent Paramiko relay',
    'publicInternetVerified': false,
  };
  for (final test in [
    ['refuse_forward', 'recusou', 'forwardRefusalPreserved'],
    ['bad_urls', 'endereço', 'untrustedAddressRejected'],
    [
      'broken_public',
      'convite não foi liberado',
      'brokenPublicRouteRejectedBeforeInvite',
    ],
    ['wrong_control_pin', 'validar', 'wrongControlTLSRejected'],
  ]) {
    File(
      (Platform.environment['CARWECE_RELAY_FIXTURE'] ??
              'build/pinggy_fixture') +
          '/mode.json',
    ).writeAsStringSync(jsonEncode({'mode': test[0]}));
    final options = Map<String, dynamic>.from(config);
    if (test[0] == 'wrong_control_pin')
      options['tlsPin'] = List.filled(43, 'A').join();
    final lost = <String>[];
    final phone = PhoneHost(pinggyOptions: options, onLost: lost.add);
    try {
      Object? failure;
      try {
        await phone.start(identity);
      } catch (e) {
        failure = e;
      }
      check(
        failure is StateError && failure.message.toString().contains(test[1]),
        'Expected ' +
            test[1] +
            ' for ' +
            test[0] +
            ', got ' +
            failure.toString(),
      );
      check(
        lost.isEmpty,
        'A startup failure must not announce an established-room disconnect',
      );
      report[test[2]] = true;
    } finally {
      await phone.close();
    }
  }
  File(
    (Platform.environment['CARWECE_RELAY_FIXTURE'] ?? 'build/pinggy_fixture') +
        '/mode.json',
  ).writeAsStringSync('{"mode":"normal"}');
  final pin = List.filled(43, 'A').join();
  final valid = FriendInvite.internet(
    'session-test.a.pinggy.link',
    'ABC123',
    pin,
  );
  check(
    FriendInvite.parse(valid.code).endpoint == valid.endpoint,
    'CW2 round trip',
  );
  for (final host in [
    '127.0.0.1',
    'untrusted.invalid',
    'pinggy.link.evil.invalid',
    'a.pinggy.link@evil.invalid',
  ]) {
    var rejected = false;
    try {
      FriendInvite.parse(FriendInvite.internet(host, 'ABC123', pin).code);
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Unsafe invitation host accepted: ' + host);
  }
  report['internetInvitesRestrictedToProviderDomains'] = true;
  report['result'] = 'PASS';
  File(
    'verification/relay_faults_v0143.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
