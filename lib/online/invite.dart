import 'dart:convert';

/// Public relay and private LAN invites both pin the session TLS identity.
/// LAN invites carry only private IPv4 addresses, not arbitrary public URLs.
class FriendInvite {
  static const relay = 'bore.pub';
  final int port;
  final String room, fingerprint;
  final String? localAddress;
  final String? relayAddress;
  const FriendInvite(this.port, this.room, this.fingerprint)
    : localAddress = null,
      relayAddress = null;
  const FriendInvite.internet(this.relayAddress, this.room, this.fingerprint)
    : port = 443,
      localAddress = null;
  const FriendInvite.lan(
    this.localAddress,
    this.port,
    this.room,
    this.fingerprint,
  ) : relayAddress = null;
  bool get isLocal => localAddress != null;
  Uri get endpoint => Uri(
    scheme: 'https',
    host: localAddress ?? relayAddress ?? relay,
    port: port,
  );
  static bool validRelayHost(String host) {
    if (host.length > 220 ||
        host != host.toLowerCase() ||
        !host
            .split('.')
            .every(
              (label) =>
                  label.length <= 63 &&
                  RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
            ))
      return false;
    return ['.pinggy.link', '.pinggy-free.link'].any(host.endsWith);
  }

  static bool privateIPv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255))
      return false;
    return parts[0] == 10 ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31) ||
        (parts[0] == 192 && parts[1] == 168);
  }

  String get code {
    if (relayAddress != null)
      return [
        'CW2',
        base64UrlEncode(utf8.encode(relayAddress!)).replaceAll('=', ''),
        room,
        fingerprint,
      ].join('-');
    if (localAddress == null)
      return ['CW1', port.toRadixString(36), room, fingerprint].join('-');
    final address = localAddress!
        .split('.')
        .map((p) => int.parse(p).toRadixString(16).padLeft(2, '0'))
        .join();
    return [
      'CWL1',
      address,
      port.toRadixString(36),
      room,
      fingerprint,
    ].join('-');
  }

  factory FriendInvite.parse(String input) {
    if (input.trim().startsWith('CW2-')) {
      final m = RegExp(
        r'^CW2-([A-Za-z0-9_-]{8,296})-([A-Z0-9]{6})-([A-Za-z0-9_-]{43})$',
      ).firstMatch(input.trim());
      if (m == null)
        throw const FormatException(
          'Cole o convite completo da nova sala de internet. Todos devem usar a versão 0.14.2 ou posterior.',
        );
      final host = utf8.decode(base64Url.decode(base64Url.normalize(m[1]!)));
      if (!validRelayHost(host) ||
          base64Url.decode(base64Url.normalize(m[3]!)).length != 32) {
        throw const FormatException('Convite de internet inválido.');
      }
      return FriendInvite.internet(host, m[2]!, m[3]!);
    }
    final m = RegExp(
      r'^(CW1|CWL1)-(?:(?<address>[0-9a-f]{8})-)?([0-9a-z]{1,4})-([A-Z0-9]{6})-([A-Za-z0-9_-]{43})$',
    ).firstMatch(input.trim());
    if (m == null || (m[1] == 'CWL1') != (m.namedGroup('address') != null)) {
      throw const FormatException(
        'Cole o convite completo que seu amigo copiou na sala.',
      );
    }
    final port = int.parse(m[3]!, radix: 36);
    final fingerprint = m[5]!;
    if (port < 1024 ||
        port > 65535 ||
        base64Url.decode(base64Url.normalize(fingerprint)).length != 32) {
      throw const FormatException('Convite inválido.');
    }
    final encoded = m.namedGroup('address');
    if (encoded == null) return FriendInvite(port, m[4]!, fingerprint);
    final address = List.generate(
      4,
      (i) => int.parse(encoded.substring(i * 2, i * 2 + 2), radix: 16),
    ).join('.');
    if (!privateIPv4(address))
      throw const FormatException(
        'O convite Wi-Fi precisa apontar para uma rede local.',
      );
    return FriendInvite.lan(address, port, m[4]!, fingerprint);
  }
}
