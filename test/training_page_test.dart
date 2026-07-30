import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  testWidgets('finish keeps automatic time, reflection, and optional favorite',
      (tester) async {
    await _setDesktopSize(tester);
    final started = DateTime.now().subtract(const Duration(minutes: 12));
    TrainingFinishInput? saved;
    final favorites = TrainingList.create(
      id: 'default-favorites',
      title: '我的收藏',
      isDefault: true,
    );
    await tester.pumpWidget(
      _app(
        training: TrainingStoreData(
          activeAttempt: ActiveTrainingAttempt.create(
            problemId: 'p1',
            origin: TrainingAttemptOrigin.manual,
            now: started,
          ),
          lists: [favorites],
        ),
        onFinish: (input) async => saved = input,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('finish-training-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('finish-attempt-dialog')), findsOneWidget);
    expect(find.textContaining('自动计时'), findsOneWidget);
    expect(find.text('代码文件'), findsNothing);
    expect(find.textContaining('Git commit'), findsNothing);
    expect(find.text('语言'), findsNothing);
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('favorite-attempt-checkbox')),
    );
    expect(checkbox.value, isFalse);

    await tester.enterText(
      find.byKey(const ValueKey('attempt-reflection-field')),
      '注意边界条件',
    );
    await tester.tap(find.byKey(const ValueKey('favorite-attempt-checkbox')));
    await tester.pumpAndSettle();
    expect(find.text('我的收藏'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-attempt-button')));
    await tester.pumpAndSettle();

    expect(saved?.result, AttemptResult.ac);
    expect(saved?.reflection, '注意边界条件');
    expect(saved?.favoriteListId, 'default-favorites');
  });

  testWidgets('daily schedule adds selected problems for the displayed date',
      (tester) async {
    await _setDesktopSize(tester);
    Iterable<String>? selectedIds;
    String? selectedDate;
    await tester.pumpWidget(
      _app(
        problems: [_problem(), _problem(id: 'p2', title: 'Problem 2')],
        onAddTasks: (ids, date) async {
          selectedIds = ids;
          selectedDate = date;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('previous-training-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-schedule-tasks-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('problem-picker-dialog')), findsOneWidget);

    await tester.tap(find.text('Problem 2'));
    await tester.tap(find.byKey(const ValueKey('confirm-problem-selection')));
    await tester.pumpAndSettle();

    expect(selectedIds, contains('p2'));
    expect(selectedIds, isNot(contains('p1')));
    expect(
      selectedDate,
      dateKey(trainingDayStartFor(DateTime.now())
          .subtract(const Duration(days: 1))),
    );
  });

  testWidgets('training dialogs fit the minimum supported client size',
      (tester) async {
    await _setDesktopSize(tester, size: const Size(900, 620));
    final list = TrainingList.create(
      id: 'list',
      title: '最小窗口题单',
      problemIds: const ['p1'],
    );
    await tester.pumpWidget(
      _app(training: TrainingStoreData(lists: [list])),
    );

    await tester.tap(find.byKey(const ValueKey('add-schedule-tasks-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('problem-picker-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('题单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最小窗口题单'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('training-list-detail-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('contest list uses shared picker and stores selected problems',
      (tester) async {
    await _setDesktopSize(tester);
    TrainingList? saved;
    final contest = ContestRecord.create(
      id: 'c1',
      title: 'Weekly Contest',
      date: '2026-07-27',
      rank: 10,
      now: DateTime(2026, 7, 27, 20),
    );
    await tester.pumpWidget(
      _app(
        contests: [contest],
        onSaveList: (list) async => saved = list,
      ),
    );

    await tester.tap(find.text('题单'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-training-list-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('training-list-title-field')),
      '赛后补题',
    );
    await tester.tap(find.byType(DropdownButtonFormField<TrainingListType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('比赛补题').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('training-list-contest-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Weekly Contest').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choose-list-problems-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Problem 1'));
    await tester.tap(find.byKey(const ValueKey('confirm-problem-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-training-list-button')));
    await tester.pumpAndSettle();

    expect(saved?.type, TrainingListType.contest);
    expect(saved?.contestId, 'c1');
    expect(saved?.problemIds, ['p1']);
  });

  testWidgets('list opens with latest results and can start without a schedule',
      (tester) async {
    await _setDesktopSize(tester);
    String? startedProblemId;
    String? startedTaskId = 'not-called';
    final attempt = TrainingAttempt.create(
      id: 'a1',
      problemId: 'p1',
      origin: TrainingAttemptOrigin.manual,
      startedAt: DateTime(2026, 7, 27, 8),
      endedAt: DateTime(2026, 7, 27, 8, 10),
      durationSeconds: 600,
      result: AttemptResult.wa,
    );
    final list = TrainingList.create(
      id: 'list',
      title: '基础题单',
      problemIds: const ['p1'],
    );
    await tester.pumpWidget(
      _app(
        training: TrainingStoreData(attempts: [attempt], lists: [list]),
        onStart: (problem, taskId) async {
          startedProblemId = problem.id;
          startedTaskId = taskId;
        },
      ),
    );

    await tester.tap(find.text('题单'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/1 已尝试'), findsOneWidget);
    await tester.tap(find.text('基础题单'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('training-list-detail-dialog')),
        findsOneWidget);
    expect(find.textContaining('WA'), findsWidgets);
    await tester.tap(find.byTooltip('开始训练'));
    await tester.pumpAndSettle();

    expect(startedProblemId, 'p1');
    expect(startedTaskId, isNull);
  });

  testWidgets('history exposes full attempt details', (tester) async {
    await _setDesktopSize(tester);
    final now = DateTime(2026, 7, 27, 20);
    final attempts = [
      for (var index = 0; index < 2; index += 1)
        TrainingAttempt.create(
          id: 'a$index',
          problemId: 'p1',
          origin: TrainingAttemptOrigin.manual,
          startedAt: now.subtract(Duration(hours: index + 1)),
          endedAt: now.subtract(Duration(minutes: index * 10)),
          durationSeconds: 600,
          result: AttemptResult.wa,
          assistance: AssistanceLevel.editorial,
          mistakes: const [MistakeCategory.implementation],
          reflection: '检查数组下标',
        ),
    ];
    await tester.pumpWidget(
      _app(
        training: TrainingStoreData(attempts: attempts),
        analytics: const TrainingAnalytics(
          focusSecondsToday: 1200,
          attemptsToday: 2,
          independentAcRate: 0,
          repeatedFailureProblemIds: ['p1'],
          mistakeCounts: {MistakeCategory.implementation: 2},
        ),
      ),
    );

    await tester.tap(find.text('记录与分析'));
    await tester.pumpAndSettle();

    expect(find.text('常见错误'), findsOneWidget);
    expect(find.text('重复失败题'), findsOneWidget);
    expect(find.text('检查数组下标'), findsNWidgets(2));
    expect(find.textContaining('看过题解'), findsNWidgets(2));
    expect(find.text('实现'), findsNWidgets(2));
  });
}

Widget _app({
  List<ProblemRecord>? problems,
  List<ContestRecord> contests = const [],
  TrainingStoreData training = const TrainingStoreData(),
  TrainingAnalytics? analytics,
  Future<void> Function(ProblemRecord, String?)? onStart,
  Future<void> Function(TrainingFinishInput)? onFinish,
  Future<void> Function(Iterable<String>, String)? onAddTasks,
  Future<void> Function(TrainingList)? onSaveList,
}) {
  return MaterialApp(
    home: TrainingPage(
      problems: problems ?? [_problem()],
      contests: contests,
      training: training,
      analytics: analytics ?? _analytics(),
      onStart: onStart ?? (_, __) async {},
      onPause: () async {},
      onResume: () async {},
      onCancel: () async {},
      onFinish: onFinish ?? (_) async {},
      onAddTasks: onAddTasks ?? (_, __) async {},
      onMoveTask: (_, __) async {},
      onRemoveTask: (_) async {},
      onSaveList: onSaveList ?? (_) async {},
      onDeleteList: (_) async {},
      onOpenProblem: (_) async {},
    ),
  );
}

Future<void> _setDesktopSize(
  WidgetTester tester, {
  Size size = const Size(1200, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

ProblemRecord _problem({String id = 'p1', String title = 'Problem 1'}) {
  return ProblemRecord.create(
    id: id,
    title: title,
    url: 'https://example.com/problem/$id',
    platform: ProblemPlatform.other,
    workflowStatus: ProblemWorkflowStatus.backlog,
    tags: const ['DP'],
    now: DateTime(2026, 7, 27, 8),
  );
}

TrainingAnalytics _analytics() {
  return const TrainingAnalytics(
    focusSecondsToday: 0,
    attemptsToday: 0,
    independentAcRate: 0,
    repeatedFailureProblemIds: [],
    mistakeCounts: {},
  );
}
