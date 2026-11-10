import 'dart:convert';
import 'dart:io';

import 'package:carwece/desktop/host_identity.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'identidade do host: certificado autoassinado faz handshake TLS',
    () async {
      final identity = await DesktopHostIdentity.create();
      expect(identity['certificate'], contains('-----BEGIN CERTIFICATE-----'));
      expect(identity['key'], contains('-----BEGIN PRIVATE KEY-----'));

      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(identity['certificate']!))
        ..usePrivateKeyBytes(utf8.encode(identity['key']!));
      final server = await SecureServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      addTearDown(() => server.close());

      String? fingerprint;
      final serverSideFuture = server.first;
      final client = await SecureSocket.connect(
        '127.0.0.1',
        server.port,
        onBadCertificate: (certificate) {
          // The same pin the online client computes for an invite.
          fingerprint = sha256.convert(certificate.der).toString();
          return true;
        },
      );
      addTearDown(() => client.close());
      final serverSide = await serverSideFuture;
      addTearDown(() => serverSide.close());

      expect(fingerprint, isNotNull);
      expect(fingerprint, hasLength(64));

      client.write('oi');
      await client.flush();
      final data = await serverSide.first;
      expect(utf8.decode(data), 'oi');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
