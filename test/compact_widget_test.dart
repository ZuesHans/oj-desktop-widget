import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/ui/app_theme.dart';

void main() {
  test('desktop window uses the client size contract', () {
    expect(appWindowSize, const Size(1120, 760));
    expect(appMinimumWindowSize, const Size(900, 620));
  });

  testWidgets('dashboard fits the minimum supported client size',
      (tester) async {
    await tester.binding.setSurfaceSize(appMinimumWindowSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const OjFloatApp(
        enablePlatformIntegration: false,
        autoInitializeController: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('dashboard-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-widget')), findsNothing);
  });
}
