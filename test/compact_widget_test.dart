import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/ui/app_theme.dart';
import 'package:oj_float/ui/compact/compact_widget.dart';

void main() {
  testWidgets('compact widget fits the configured compact window height',
      (tester) async {
    final state = OjState.initial().copyWith(
      latest: {
        'codeforces': [
          FetchResult.success(
            ojId: 'codeforces',
            username: 'tourist',
            solvedCount: 539,
            fetchedAt: DateTime(2026, 7, 10),
          ),
        ],
      },
    );

    await tester.binding.setSurfaceSize(compactWindowSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: CompactWidget(
            state: state,
            refreshing: false,
            onRefresh: () {},
            onOpenDashboard: () {},
            onExit: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('总通过'), findsOneWidget);
    expect(find.text('539'), findsOneWidget);
    expect(find.text('今日 +0'), findsOneWidget);
  });
}
