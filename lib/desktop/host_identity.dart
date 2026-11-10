import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Windows replacement for the Kotlin `HostIdentity`: an ephemeral,
/// self-signed RSA-2048 X.509 certificate for the friend-room TLS server,
/// generated fresh per room with no bundled secrets. The DER layout below
/// mirrors the Android implementation field for field.
class DesktopHostIdentity {
  static Future<Map<String, String>> create() async {
    final secureRandom = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List.generate(32, (_) => math.Random.secure().nextInt(256)),
          ),
        ),
      );
    final generator = KeyGenerator('RSA')
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          secureRandom,
        ),
      );
    final pair = generator.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    // sha256WithRSAEncryption 1.2.840.113549.1.1.11, NULL parameters.
    final signatureAlgorithm = _seq([
      _oid([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0b]),
      _der(0x05, const []),
    ]);
    // rsaEncryption 1.2.840.113549.1.1.1, NULL parameters.
    final keyAlgorithm = _seq([
      _oid([0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]),
      _der(0x05, const []),
    ]);
    final name = _seq([
      _der(0x31, [
        ..._seq([
          _oid([0x55, 0x04, 0x03]),
          _der(0x0c, utf8.encode('CarWece friend room')),
        ]),
      ]),
    ]);
    final now = DateTime.now().toUtc();
    final validity = _seq([
      _utcTime(now.subtract(const Duration(days: 1))),
      _utcTime(now.add(const Duration(days: 7))),
    ]);
    final serialBytes = List.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    );
    serialBytes[0] |= 0x80;
    final serial = _bytesToBigInt(serialBytes);
    final publicKeyInfo = _seq([
      keyAlgorithm,
      _der(0x03, [
        0,
        ..._seq([
          _integer(publicKey.modulus!),
          _integer(publicKey.publicExponent!),
        ]),
      ]),
    ]);
    final tbs = _seq([
      _der(0xa0, [..._integer(BigInt.two)]),
      _integer(serial),
      signatureAlgorithm,
      name,
      validity,
      name,
      publicKeyInfo,
    ]);
    final signer = Signer('SHA-256/RSA')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final signature = (signer.generateSignature(tbs) as RSASignature).bytes;
    final certificate = _seq([
      tbs,
      signatureAlgorithm,
      _der(0x03, [0, ...signature]),
    ]);

    final p = privateKey.p!, q = privateKey.q!;
    final d = privateKey.privateExponent!;
    final rsaPrivateKey = _seq([
      _integer(BigInt.zero),
      _integer(privateKey.modulus!),
      _integer(publicKey.publicExponent!),
      _integer(d),
      _integer(p),
      _integer(q),
      _integer(d % (p - BigInt.one)),
      _integer(d % (q - BigInt.one)),
      _integer(q.modInverse(p)),
    ]);
    final pkcs8 = _seq([
      _integer(BigInt.zero),
      keyAlgorithm,
      _der(0x04, [...rsaPrivateKey]),
    ]);
    return {
      'certificate': _pem('CERTIFICATE', certificate),
      'key': _pem('PRIVATE KEY', pkcs8),
    };
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }

  static Uint8List _der(int tag, List<int> content) {
    final size = content.length;
    final List<int> length;
    if (size < 128) {
      length = [size];
    } else {
      final raw = <int>[];
      var rest = size;
      while (rest > 0) {
        raw.insert(0, rest & 0xff);
        rest >>= 8;
      }
      length = [0x80 | raw.length, ...raw];
    }
    return Uint8List.fromList([tag, ...length, ...content]);
  }

  static Uint8List _seq(List<Uint8List> fields) =>
      _der(0x30, fields.expand((field) => field).toList());

  static Uint8List _oid(List<int> encoded) => _der(0x06, encoded);

  static Uint8List _integer(BigInt value) {
    final raw = <int>[];
    var rest = value;
    while (rest > BigInt.zero) {
      raw.insert(0, (rest & BigInt.from(0xff)).toInt());
      rest >>= 8;
    }
    if (raw.isEmpty) raw.add(0);
    if (raw.first & 0x80 != 0) raw.insert(0, 0);
    return _der(0x02, raw);
  }

  static Uint8List _utcTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    final text =
        '${two(time.year % 100)}${two(time.month)}${two(time.day)}'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}Z';
    return _der(0x17, text.codeUnits);
  }

  static String _pem(String label, List<int> der) {
    final base64 = base64Encode(der);
    final lines = <String>[
      for (var i = 0; i < base64.length; i += 64)
        base64.substring(i, math.min(i + 64, base64.length)),
    ];
    return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
  }
}

/// The two `host` channel operations from `online_screen.dart`, on
/// Windows: identity generation is pure Dart (above), and the Android
/// foreground service has no desktop equivalent — the process hosts the
/// room for as long as the app is open.
class DesktopHost {
  static Future<Map<String, String>> identity() =>
      DesktopHostIdentity.create();

  static Future<void> service(bool active) async {}
}
