import 'dart:io';

import 'package:carwece/desktop/save_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save de ida e volta pelo arquivo em Documentos/CarWece', () async {
    final temp = await Directory.systemTemp.createTemp('carwece_save_test');
    addTearDown(() => temp.delete(recursive: true));
    final store = DesktopSaveStore(documents: temp);

    expect(await store.read(), isNull);
    expect(await store.write('{"coins":10}'), isTrue);
    expect(await store.read(), '{"coins":10}');

    final file = File(
      '${temp.path}${Platform.pathSeparator}CarWece'
      '${Platform.pathSeparator}save.json',
    );
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), '{"coins":10}');

    expect(await store.write('{"coins":20}'), isTrue);
    expect(await store.read(), '{"coins":20}');

    // Payloads above the native 256000-character limit are refused,
    // exactly like the Android save slot.
    expect(await store.write('x' * 256001), isFalse);
    expect(await store.read(), '{"coins":20}');
  });
}
