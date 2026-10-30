import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Real isolate work does not advance with the widget test's simulated clock.
Future<void> waitForGpu(WidgetTester tester) async {
  for (var i = 0; i < 300 && find.byType(Texture).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    find.byType(Texture),
    findsOneWidget,
    reason: 'GPU preparation must finish before interaction assertions',
  );
}
