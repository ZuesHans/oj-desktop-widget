import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  testWidgets('problem archive offers undo', (tester) async {
    var archived = 0;
    var restored = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProblemsPage(
          problems: [_problem()],
          onBack: () {},
          onParseLink: (_) async => throw UnimplementedError(),
          onSave: (_) async {},
          onDelete: (_) async => archived += 1,
          onRestore: (_) async => restored += 1,
          onOpenProblem: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('delete-problem-p1')));
    await tester.pumpAndSettle();
    expect(archived, 1);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(restored, 1);
  });

  testWidgets('permanent delete requires details confirmation', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProblemsPage(
          problems: [_problem()],
          onBack: () {},
          onParseLink: (_) async => throw UnimplementedError(),
          onSave: (_) async {},
          onDelete: (_) async {},
          onPermanentDelete: (_) async => deleted += 1,
          onOpenProblem: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('view-problem-p1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('permanent-delete-problem-p1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('永久删除题目？'), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.text('永久删除').last);
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });
}

ProblemRecord _problem() {
  return ProblemRecord.create(
    id: 'p1',
    title: 'Problem 1',
    url: 'https://example.com/problem/1',
    platform: ProblemPlatform.other,
    workflowStatus: ProblemWorkflowStatus.backlog,
    now: DateTime(2026, 7, 27, 8),
  );
}
