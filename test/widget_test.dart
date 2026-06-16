import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  Widget buildTestApp() {
    return const OjFloatApp(
      enablePlatformIntegration: false,
      autoInitializeController: false,
    );
  }

  testWidgets('app starts in compact floating mode', (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('compact-refresh-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-dashboard-button')), findsOneWidget);
    expect(find.text('OJ Float'), findsNothing);
    expect(find.text('Codeforces'), findsNothing);
  });

  testWidgets('compact mode opens and closes the dashboard', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();

    expect(find.text('OJ Float'), findsOneWidget);
    expect(find.text('Codeforces'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-mode-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compact-mode-button')));
    await tester.pumpAndSettle();

    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('OJ Float'), findsNothing);
    expect(find.text('Codeforces'), findsNothing);
  });

  testWidgets('compact mode keeps a manual refresh entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(
        find.byKey(const ValueKey('compact-refresh-button')), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('dashboard shows a heatmap entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();

    expect(find.text('Heatmap'), findsOneWidget);
    expect(find.byKey(const ValueKey('heatmap-entry-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-data-button')), findsOneWidget);
  });

  testWidgets('heatmap entry opens the heatmap dialog', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('heatmap-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('heatmap-dialog')), findsOneWidget);
    expect(
        find.text(
            'No snapshot data yet. Refresh after configuring accounts to build your heatmap.'),
        findsOneWidget);
  });
}
