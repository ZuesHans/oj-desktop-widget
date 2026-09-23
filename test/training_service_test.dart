import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  const service = TrainingService();

  test('training day switches at 04:00', () {
    expect(trainingDateFor(DateTime(2026, 7, 27, 3, 59)), '2026-07-26');
    expect(trainingDateFor(DateTime(2026, 7, 27, 4)), '2026-07-27');
    expect(
      trainingDayEndFromKey('2026-07-27'),
      DateTime(2026, 7, 28, 4),
    );
  });

  test('active attempt keeps task id, pause time, and schema v2 roundtrip', () {
    final started = DateTime(2026, 7, 27, 8);
    var data = service.addTask(
      const TrainingStoreData(),
      'p1',
      now: started,
    );
    final taskId = data.tasks.single.id;
    data = service.startAttempt(
      data,
      'p1',
      taskId: taskId,
      now: started,
    );
    data = service.pauseAttempt(
      data,
      now: started.add(const Duration(minutes: 10)),
    );
    expect(
      data.activeAttempt!.elapsedSeconds(
        started.add(const Duration(minutes: 30)),
      ),
      600,
    );

    final restored = TrainingStoreData.tryFromJson(data.toJson())!;
    expect(restored.schemaVersion, 2);
    expect(restored.activeAttempt?.taskId, taskId);
    data = service.resumeAttempt(
      restored,
      now: started.add(const Duration(minutes: 30)),
    );
    expect(
      data.activeAttempt!.elapsedSeconds(
        started.add(const Duration(minutes: 35)),
      ),
      900,
    );
  });

  test('only one active attempt is allowed', () {
    final data = service.startAttempt(
      const TrainingStoreData(),
      'p1',
      now: DateTime(2026, 7, 27, 8),
    );
    expect(
      () => service.startAttempt(data, 'p2'),
      throwsA(isA<FetchException>()),
    );
  });

  test('finish uses automatic elapsed time and never schedules a review', () {
    final start = DateTime(2026, 7, 27, 8);
    var data = service.startAttempt(
      const TrainingStoreData(),
      'p1',
      now: start,
    );
    final accepted = service.finishAttempt(
      data: data,
      problem: _problem(),
      result: AttemptResult.ac,
      assistance: AssistanceLevel.hint,
      mistakes: const [MistakeCategory.idea],
      reflection: 'Use prefix sums.',
      now: start.add(const Duration(minutes: 25)),
    );

    expect(accepted.attempt.durationSeconds, 1500);
    expect(accepted.attempt.reflection, 'Use prefix sums.');
    expect(accepted.problem.workflowStatus, ProblemWorkflowStatus.mastered);
    expect(accepted.problem.nextReviewAt, isNull);
    expect(accepted.problem.reviewStage, 0);
    expect(accepted.data.tasks, isEmpty);
    expect(accepted.attempt.toJson(), isNot(contains('language')));
    expect(accepted.attempt.toJson(), isNot(contains('solutionFilePath')));
    expect(accepted.attempt.toJson(), isNot(contains('gitCommit')));

    data = service.startAttempt(
      accepted.data,
      'p1',
      now: start.add(const Duration(hours: 1)),
    );
    final failed = service.finishAttempt(
      data: data,
      problem: accepted.problem,
      result: AttemptResult.wa,
      now: start.add(const Duration(hours: 1, minutes: 5)),
    );
    expect(failed.problem.workflowStatus, ProblemWorkflowStatus.active);
    expect(failed.problem.nextReviewAt, isNull);
    expect(failed.data.tasks, isEmpty);
  });

  test('legacy attempt metadata is accepted but omitted when saved as v2', () {
    final restored = TrainingStoreData.tryFromJson({
      'schemaVersion': 1,
      'attempts': [
        {
          'id': 'a1',
          'problemId': 'p1',
          'origin': 'manual',
          'startedAt': '2026-07-27T08:00:00.000',
          'endedAt': '2026-07-27T08:10:00.000',
          'durationSeconds': 600,
          'result': 'ac',
          'assistance': 'none',
          'mistakes': <String>[],
          'reflection': 'ok',
          'language': 'C++20',
          'solutionFilePath': r'C:\code\p1.cpp',
          'gitCommit': 'abc123',
        },
      ],
      'lists': <Object?>[],
      'tasks': <Object?>[],
      'activeAttempt': null,
    })!;

    expect(restored.schemaVersion, 2);
    expect(restored.attempts.single.reflection, 'ok');
    expect(restored.toJson()['schemaVersion'], 2);
    final attemptJson =
        (restored.toJson()['attempts'] as List).single as Map<String, dynamic>;
    expect(attemptJson, isNot(contains('language')));
    expect(attemptJson, isNot(contains('solutionFilePath')));
    expect(attemptJson, isNot(contains('gitCommit')));
  });

  test('legacy failed status creates one latest-result attempt', () {
    final problem = ProblemRecord.create(
      id: 'legacy',
      title: 'Legacy',
      url: 'https://example.com/problem/legacy',
      platform: ProblemPlatform.other,
      status: ProblemStatus.TLE,
      now: DateTime(2026, 7, 1, 8),
    );

    final migrated = service.migrateLegacyAttempts(
      [problem],
      const TrainingStoreData(),
    );
    final repeated = service.migrateLegacyAttempts([problem], migrated);
    expect(migrated.attempts, hasLength(1));
    expect(migrated.attempts.single.result, AttemptResult.tle);
    expect(migrated.attempts.single.durationSeconds, isNull);
    expect(repeated.attempts, hasLength(1));
  });

  test('legacy review state and automatic tasks are removed on migration', () {
    final now = DateTime(2026, 7, 27, 8);
    final reviewProblem = _problem().copyWith(
      workflowStatus: ProblemWorkflowStatus.review,
      reviewStage: 3,
      nextReviewAt: now,
    );
    final automatic = DailyTrainingTask.create(
      id: 'auto',
      problemId: 'p1',
      trainingDate: '2026-07-27',
      source: DailyTaskSource.reviewDue,
      now: now,
    );
    final manual = DailyTrainingTask.create(
      id: 'manual',
      problemId: 'p2',
      trainingDate: '2026-08-01',
      now: now,
    );

    final problems = service.normalizeLegacyProblems([reviewProblem], now: now);
    var data = service.normalizeTrainingData(
      TrainingStoreData(tasks: [automatic, manual]),
      now: now,
    );
    data = service.normalizeTrainingData(data, now: now);

    expect(problems.single.workflowStatus, ProblemWorkflowStatus.active);
    expect(problems.single.reviewStage, 0);
    expect(problems.single.nextReviewAt, isNull);
    expect(problems.single.toJson(), isNot(contains('reviewStage')));
    expect(problems.single.toJson(), isNot(contains('nextReviewAt')));
    expect(data.tasks.map((item) => item.id), ['manual']);
    expect(data.lists.where((item) => item.isDefault), hasLength(1));
    expect(data.lists.single.title, '默认收藏夹');
  });

  test('manual schedule supports batch add, dedupe, move, and remove', () {
    final now = DateTime(2026, 7, 27, 8);
    var data = service.addTasks(
      const TrainingStoreData(),
      ['p1', 'p2', 'p1'],
      trainingDate: '2026-08-02',
      now: now,
    );
    expect(data.tasks, hasLength(2));
    expect(data.tasks.map((item) => item.sortOrder), [0, 1]);

    data = service.moveTask(data, data.tasks.first.id, '2026-08-03');
    expect(data.tasks.first.trainingDate, '2026-08-03');
    expect(data.tasks.first.status, DailyTaskStatus.planned);

    data = service.addTask(
      data,
      'p1',
      trainingDate: '2026-08-02',
      now: now,
    );
    expect(data.tasks.where((item) => item.problemId == 'p1'), hasLength(2));
    final movedId = data.tasks.first.id;
    data = service.moveTask(data, movedId, '2026-08-02');
    expect(data.tasks.where((item) => item.problemId == 'p1'), hasLength(1));

    final removeId = data.tasks.first.id;
    data = service.removeTask(data, removeId);
    expect(data.tasks.any((item) => item.id == removeId), isFalse);
  });

  test('cross-date attempt completes only its bound schedule task', () {
    final now = DateTime(2026, 7, 27, 8);
    var data = service.addTask(
      const TrainingStoreData(),
      'p1',
      trainingDate: '2026-08-01',
      now: now,
    );
    data = service.addTask(
      data,
      'p1',
      trainingDate: '2026-08-02',
      now: now,
    );
    final futureTask = data.tasks.last;
    data = service.startAttempt(
      data,
      'p1',
      taskId: futureTask.id,
      now: now,
    );
    expect(data.tasks.first.status, DailyTaskStatus.planned);
    expect(data.tasks.last.status, DailyTaskStatus.inProgress);

    final finished = service.finishAttempt(
      data: data,
      problem: _problem(),
      result: AttemptResult.wa,
      now: now.add(const Duration(minutes: 10)),
    );
    expect(finished.data.tasks.first.status, DailyTaskStatus.planned);
    expect(finished.data.tasks.last.status, DailyTaskStatus.done);
    expect(finished.data.tasks.last.completedAt, isNotNull);
  });

  test('cancel restores only the bound task', () {
    final now = DateTime(2026, 7, 27, 8);
    var data = service.addTask(
      const TrainingStoreData(),
      'p1',
      trainingDate: '2026-08-01',
      now: now,
    );
    final taskId = data.tasks.single.id;
    data = service.startAttempt(data, 'p1', taskId: taskId, now: now);
    expect(
      () => service.removeTask(data, taskId),
      throwsA(isA<FetchException>()),
    );
    data = service.cancelAttempt(data);
    expect(data.activeAttempt, isNull);
    expect(data.tasks.single.status, DailyTaskStatus.planned);
  });

  test('default favorites can be renamed, populated once, but not deleted', () {
    final now = DateTime(2026, 7, 27, 8);
    var data = service.normalizeTrainingData(
      const TrainingStoreData(),
      now: now,
    );
    final favorites = data.lists.single;
    data = service.upsertList(
      data,
      favorites.copyWith(title: '想再做一次', updatedAt: now),
    );
    data = service.addProblemToList(data, favorites.id, 'p1', now: now);
    data = service.addProblemToList(data, favorites.id, 'p1', now: now);

    expect(data.lists.single.title, '想再做一次');
    expect(data.lists.single.problemIds, ['p1']);
    expect(
      () => service.removeList(data, favorites.id),
      throwsA(isA<FetchException>()),
    );
  });

  test('latest result uses ended time rather than stored list order', () {
    final older = _attempt(
      id: 'old',
      result: AttemptResult.wa,
      endedAt: DateTime(2026, 7, 27, 9),
    );
    final newer = _attempt(
      id: 'new',
      result: AttemptResult.ac,
      endedAt: DateTime(2026, 7, 27, 10),
    );
    final data = TrainingStoreData(attempts: [older, newer]);
    expect(service.latestAttemptFor(data, 'p1')?.result, AttemptResult.ac);
  });

  test('analytics keeps focus, independent AC rate, and failure details', () {
    final now = DateTime(2026, 7, 27, 20);
    final analytics = service.analytics(
      TrainingStoreData(attempts: [
        _attempt(id: 'a1', result: AttemptResult.ac, endedAt: now),
        _attempt(
          id: 'a2',
          result: AttemptResult.ac,
          endedAt: now,
          assistance: AssistanceLevel.hint,
          seconds: null,
        ),
        _attempt(
          id: 'a3',
          result: AttemptResult.wa,
          endedAt: now,
          mistakes: const [MistakeCategory.idea],
        ),
        _attempt(id: 'a4', result: AttemptResult.tle, endedAt: now),
      ]),
      [_problem()],
      now: now,
    );

    expect(analytics.focusSecondsToday, 1800);
    expect(analytics.attemptsToday, 4);
    expect(analytics.independentAcRate, 0.5);
    expect(analytics.repeatedFailureProblemIds, ['p1']);
    expect(analytics.mistakeCounts[MistakeCategory.idea], 1);
  });

  test('removing a problem clears attempts, tasks, lists, and active timer',
      () {
    final now = DateTime(2026, 7, 27, 8);
    var data = service.normalizeTrainingData(
      TrainingStoreData(
        attempts: [
          _attempt(id: 'a1', result: AttemptResult.wa, endedAt: now),
        ],
      ),
      now: now,
    );
    data = service.addTask(data, 'p1', now: now);
    data = service.addProblemToList(data, data.lists.single.id, 'p1', now: now);
    data = service.startAttempt(
      data,
      'p1',
      taskId: data.tasks.single.id,
      now: now,
    );

    final cleaned = service.removeProblemReferences(data, 'p1');
    expect(cleaned.attempts, isEmpty);
    expect(cleaned.tasks, isEmpty);
    expect(cleaned.lists.single.problemIds, isEmpty);
    expect(cleaned.activeAttempt, isNull);
  });
}

TrainingAttempt _attempt({
  required String id,
  required AttemptResult result,
  required DateTime endedAt,
  AssistanceLevel assistance = AssistanceLevel.none,
  List<MistakeCategory> mistakes = const [],
  int? seconds = 600,
}) {
  return TrainingAttempt.create(
    id: id,
    problemId: 'p1',
    origin: TrainingAttemptOrigin.manual,
    startedAt: endedAt.subtract(const Duration(minutes: 30)),
    endedAt: endedAt,
    durationSeconds: seconds,
    result: result,
    assistance: assistance,
    mistakes: mistakes,
  );
}

ProblemRecord _problem() {
  return ProblemRecord.create(
    id: 'p1',
    title: 'Problem 1',
    url: 'https://example.com/problem/1',
    platform: ProblemPlatform.other,
    workflowStatus: ProblemWorkflowStatus.backlog,
    now: DateTime(2026, 7, 1, 8),
  );
}
