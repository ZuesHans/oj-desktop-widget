import '../core/errors.dart';
import '../core/time.dart';
import '../models/problem_record.dart';
import '../models/training.dart';

class TrainingFinishResult {
  const TrainingFinishResult({
    required this.data,
    required this.problem,
    required this.attempt,
  });

  final TrainingStoreData data;
  final ProblemRecord problem;
  final TrainingAttempt attempt;
}

class TrainingAnalytics {
  const TrainingAnalytics({
    required this.focusSecondsToday,
    required this.attemptsToday,
    required this.independentAcRate,
    required this.repeatedFailureProblemIds,
    required this.mistakeCounts,
  });

  final int focusSecondsToday;
  final int attemptsToday;
  final double independentAcRate;
  final List<String> repeatedFailureProblemIds;
  final Map<MistakeCategory, int> mistakeCounts;
}

class TrainingService {
  const TrainingService();

  TrainingStoreData migrateLegacyAttempts(
    List<ProblemRecord> problems,
    TrainingStoreData data,
  ) {
    final attempts = [...data.attempts];
    final existingProblemIds = attempts.map((item) => item.problemId).toSet();
    for (final problem in problems) {
      final legacy = problem.legacyStatusForMigration;
      if (existingProblemIds.contains(problem.id) ||
          (legacy != ProblemStatus.WA &&
              legacy != ProblemStatus.TLE &&
              legacy != ProblemStatus.RE)) {
        continue;
      }
      attempts.add(
        TrainingAttempt.create(
          id: 'legacy-${problem.id}',
          problemId: problem.id,
          origin: TrainingAttemptOrigin.legacy,
          startedAt: problem.updatedAt,
          endedAt: problem.updatedAt,
          durationSeconds: null,
          result: switch (legacy) {
            ProblemStatus.WA => AttemptResult.wa,
            ProblemStatus.TLE => AttemptResult.tle,
            ProblemStatus.RE => AttemptResult.re,
            _ => AttemptResult.skipped,
          },
          reflection: problem.note,
        ),
      );
    }
    attempts.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return data.copyWith(attempts: List.unmodifiable(attempts));
  }

  List<ProblemRecord> normalizeLegacyProblems(
    List<ProblemRecord> problems, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return List.unmodifiable([
      for (final problem in problems)
        if (problem.workflowStatus == ProblemWorkflowStatus.review ||
            problem.nextReviewAt != null ||
            problem.reviewStage != 0)
          problem.copyWith(
            workflowStatus:
                problem.workflowStatus == ProblemWorkflowStatus.review
                    ? ProblemWorkflowStatus.active
                    : problem.workflowStatus,
            reviewStage: 0,
            clearNextReviewAt: true,
            updatedAt: timestamp,
          )
        else
          problem,
    ]);
  }

  TrainingStoreData normalizeTrainingData(
    TrainingStoreData data, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final manualTasks = data.tasks
        .where((task) => task.source != DailyTaskSource.reviewDue)
        .toList();
    final lists = <TrainingList>[];
    TrainingList? defaultList;
    for (final list in data.lists) {
      if (defaultList == null &&
          (list.isDefault || list.id == 'default-favorites')) {
        defaultList = list.copyWith(isDefault: true);
        lists.add(defaultList);
      } else {
        lists.add(list.isDefault ? list.copyWith(isDefault: false) : list);
      }
    }
    if (defaultList == null) {
      lists.add(
        TrainingList.create(
          id: 'default-favorites',
          title: '默认收藏夹',
          isDefault: true,
          now: timestamp,
        ),
      );
    }
    lists.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return data.copyWith(
      tasks: List.unmodifiable(manualTasks),
      lists: List.unmodifiable(lists),
    );
  }

  TrainingStoreData addTask(
    TrainingStoreData data,
    String problemId, {
    String? trainingDate,
    DailyTaskSource source = DailyTaskSource.manual,
    DateTime? now,
  }) {
    return addTasks(
      data,
      [problemId],
      trainingDate: trainingDate,
      source: source,
      now: now,
    );
  }

  TrainingStoreData addTasks(
    TrainingStoreData data,
    Iterable<String> problemIds, {
    String? trainingDate,
    DailyTaskSource source = DailyTaskSource.manual,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final date = trainingDate ?? trainingDateFor(timestamp);
    if (!isValidDateKey(date)) {
      throw FetchException('训练日期无效。');
    }
    final tasks = [...data.tasks];
    var nextOrder = tasks.where((item) => item.trainingDate == date).fold<int>(
              -1,
              (value, item) => item.sortOrder > value ? item.sortOrder : value,
            ) +
        1;
    for (final rawProblemId in problemIds) {
      final problemId = rawProblemId.trim();
      if (problemId.isEmpty ||
          tasks.any(
            (item) =>
                item.problemId == problemId &&
                item.trainingDate == date &&
                item.status != DailyTaskStatus.skipped,
          )) {
        continue;
      }
      final taskOrder = nextOrder++;
      tasks.add(
        DailyTrainingTask.create(
          id: '${buildTrainingId('task', timestamp)}-$date-$taskOrder',
          problemId: problemId,
          trainingDate: date,
          source: source,
          sortOrder: taskOrder,
          now: timestamp,
        ),
      );
    }
    return data.copyWith(tasks: List.unmodifiable(tasks));
  }

  TrainingStoreData moveTask(
    TrainingStoreData data,
    String taskId,
    String trainingDate,
  ) {
    if (!isValidDateKey(trainingDate)) {
      throw FetchException('训练日期无效。');
    }
    final task = data.tasks.where((item) => item.id == taskId).firstOrNull;
    if (task == null || task.status == DailyTaskStatus.inProgress) {
      return data;
    }
    final duplicate = data.tasks.any(
      (item) =>
          item.id != taskId &&
          item.problemId == task.problemId &&
          item.trainingDate == trainingDate &&
          item.status != DailyTaskStatus.skipped,
    );
    if (duplicate) {
      return removeTask(data, taskId);
    }
    final nextOrder =
        data.tasks.where((item) => item.trainingDate == trainingDate).fold<int>(
                  -1,
                  (value, item) =>
                      item.sortOrder > value ? item.sortOrder : value,
                ) +
            1;
    return data.copyWith(
      tasks: List.unmodifiable([
        for (final item in data.tasks)
          if (item.id == taskId)
            item.copyWith(
              trainingDate: trainingDate,
              sortOrder: nextOrder,
              status: DailyTaskStatus.planned,
              clearCompletedAt: true,
            )
          else
            item,
      ]),
    );
  }

  TrainingStoreData removeTask(TrainingStoreData data, String taskId) {
    if (data.activeAttempt?.taskId == taskId) {
      throw FetchException('进行中的安排不能移除。');
    }
    return data.copyWith(
      tasks: List.unmodifiable(data.tasks.where((item) => item.id != taskId)),
    );
  }

  TrainingStoreData updateTaskStatus(
    TrainingStoreData data,
    String taskId,
    DailyTaskStatus status, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return data.copyWith(
      tasks: List.unmodifiable([
        for (final task in data.tasks)
          if (task.id == taskId)
            task.copyWith(
              status: status,
              completedAt: status == DailyTaskStatus.done ? timestamp : null,
              clearCompletedAt: status != DailyTaskStatus.done,
            )
          else
            task,
      ]),
    );
  }

  TrainingStoreData startAttempt(
    TrainingStoreData data,
    String problemId, {
    TrainingAttemptOrigin origin = TrainingAttemptOrigin.manual,
    String? taskId,
    DateTime? now,
  }) {
    if (data.activeAttempt != null) {
      throw FetchException('已有进行中的训练，请先结束或暂停当前题目。');
    }
    if (taskId != null) {
      final task = data.tasks.where((item) => item.id == taskId).firstOrNull;
      if (task == null || task.problemId != problemId) {
        throw FetchException('训练安排与题目不匹配。');
      }
      if (task.status == DailyTaskStatus.done) {
        throw FetchException('已完成的安排不能重复开始，请新建一条安排。');
      }
    }
    final timestamp = now ?? DateTime.now();
    final active = ActiveTrainingAttempt.create(
      problemId: problemId,
      taskId: taskId,
      origin: origin,
      now: timestamp,
    );
    return data.copyWith(
      activeAttempt: active,
      tasks: List.unmodifiable([
        for (final task in data.tasks)
          if (task.id == taskId)
            task.copyWith(status: DailyTaskStatus.inProgress)
          else
            task,
      ]),
    );
  }

  TrainingStoreData pauseAttempt(TrainingStoreData data, {DateTime? now}) {
    final active = data.activeAttempt;
    if (active == null) {
      return data;
    }
    return data.copyWith(activeAttempt: active.pause(now ?? DateTime.now()));
  }

  TrainingStoreData resumeAttempt(TrainingStoreData data, {DateTime? now}) {
    final active = data.activeAttempt;
    if (active == null) {
      return data;
    }
    return data.copyWith(activeAttempt: active.resume(now ?? DateTime.now()));
  }

  TrainingStoreData cancelAttempt(TrainingStoreData data) {
    final taskId = data.activeAttempt?.taskId;
    return data.copyWith(
      clearActiveAttempt: true,
      tasks: List.unmodifiable([
        for (final task in data.tasks)
          if (task.id == taskId && task.status == DailyTaskStatus.inProgress)
            task.copyWith(
              status: DailyTaskStatus.planned,
              clearCompletedAt: true,
            )
          else
            task,
      ]),
    );
  }

  TrainingFinishResult finishAttempt({
    required TrainingStoreData data,
    required ProblemRecord problem,
    required AttemptResult result,
    AssistanceLevel assistance = AssistanceLevel.none,
    List<MistakeCategory> mistakes = const [],
    String reflection = '',
    DateTime? now,
  }) {
    final active = data.activeAttempt;
    if (active == null || active.problemId != problem.id) {
      throw FetchException('没有与该题目匹配的进行中训练。');
    }
    final endedAt = now ?? DateTime.now();
    final attempt = TrainingAttempt.create(
      id: active.id.replaceFirst('active', 'a'),
      problemId: problem.id,
      origin: active.origin,
      startedAt: active.startedAt,
      endedAt: endedAt,
      durationSeconds: active.elapsedSeconds(endedAt),
      result: result,
      assistance: assistance,
      mistakes: mistakes,
      reflection: reflection,
    );
    final updatedProblem = _applyResult(problem, attempt, endedAt);
    final tasks = [
      for (final task in data.tasks)
        if (task.id == active.taskId)
          task.copyWith(
            status: DailyTaskStatus.done,
            completedAt: endedAt,
          )
        else
          task,
    ];
    final next = data.copyWith(
      attempts: List.unmodifiable([attempt, ...data.attempts]),
      tasks: List.unmodifiable(tasks),
      clearActiveAttempt: true,
    );
    return TrainingFinishResult(
      data: next,
      problem: updatedProblem,
      attempt: attempt,
    );
  }

  TrainingStoreData upsertList(TrainingStoreData data, TrainingList list) {
    final existing = data.lists.where((item) => item.id == list.id).firstOrNull;
    final defaultId =
        data.lists.where((item) => item.isDefault).firstOrNull?.id;
    if (list.isDefault && defaultId != null && defaultId != list.id) {
      throw FetchException('默认收藏夹已经存在。');
    }
    final normalized = existing?.isDefault == true
        ? list.copyWith(isDefault: true, archived: false)
        : list;
    var replaced = false;
    final lists = [
      for (final item in data.lists)
        if (item.id == list.id) ...[
          normalized,
        ] else
          item,
    ];
    replaced = data.lists.any((item) => item.id == list.id);
    if (!replaced) {
      lists.add(normalized);
    }
    lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return data.copyWith(lists: List.unmodifiable(lists));
  }

  TrainingStoreData removeList(TrainingStoreData data, String id) {
    if (data.lists.any((item) => item.id == id && item.isDefault)) {
      throw FetchException('默认收藏夹不能删除。');
    }
    return data.copyWith(
      lists: List.unmodifiable(data.lists.where((item) => item.id != id)),
    );
  }

  TrainingStoreData addProblemToList(
    TrainingStoreData data,
    String listId,
    String problemId, {
    DateTime? now,
  }) {
    final list = data.lists.where((item) => item.id == listId).firstOrNull;
    if (list == null) {
      throw FetchException('收藏夹不存在。');
    }
    if (list.problemIds.contains(problemId)) {
      return data;
    }
    return upsertList(
      data,
      list.copyWith(
        problemIds: [...list.problemIds, problemId],
        updatedAt: now ?? DateTime.now(),
      ),
    );
  }

  TrainingAttempt? latestAttemptFor(
    TrainingStoreData data,
    String problemId,
  ) {
    TrainingAttempt? latest;
    for (final attempt in data.attempts) {
      if (attempt.problemId == problemId &&
          (latest == null || attempt.endedAt.isAfter(latest.endedAt))) {
        latest = attempt;
      }
    }
    return latest;
  }

  TrainingStoreData removeProblemReferences(
    TrainingStoreData data,
    String problemId,
  ) {
    return TrainingStoreData(
      attempts: List.unmodifiable(
        data.attempts.where((item) => item.problemId != problemId),
      ),
      tasks: List.unmodifiable(
        data.tasks.where((item) => item.problemId != problemId),
      ),
      lists: List.unmodifiable([
        for (final list in data.lists)
          list.copyWith(
            problemIds:
                list.problemIds.where((item) => item != problemId).toList(),
          ),
      ]),
      activeAttempt: data.activeAttempt?.problemId == problemId
          ? null
          : data.activeAttempt,
    );
  }

  TrainingAnalytics analytics(
    TrainingStoreData data,
    List<ProblemRecord> problems, {
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final today = trainingDateFor(timestamp);
    final todayAttempts = data.attempts
        .where((item) => trainingDateFor(item.endedAt) == today)
        .toList();
    final acAttempts =
        todayAttempts.where((item) => item.result == AttemptResult.ac).toList();
    final independent = acAttempts
        .where((item) => item.assistance == AssistanceLevel.none)
        .length;
    final failuresByProblem = <String, int>{};
    final mistakes = <MistakeCategory, int>{};
    for (final attempt in data.attempts) {
      if (attempt.result != AttemptResult.ac) {
        failuresByProblem[attempt.problemId] =
            (failuresByProblem[attempt.problemId] ?? 0) + 1;
      }
      for (final mistake in attempt.mistakes) {
        mistakes[mistake] = (mistakes[mistake] ?? 0) + 1;
      }
    }
    return TrainingAnalytics(
      focusSecondsToday: todayAttempts.fold(
        0,
        (sum, item) => sum + (item.durationSeconds ?? 0),
      ),
      attemptsToday: todayAttempts.length,
      independentAcRate:
          acAttempts.isEmpty ? 0 : independent / acAttempts.length,
      repeatedFailureProblemIds: List.unmodifiable(
        failuresByProblem.entries
            .where((entry) => entry.value >= 2)
            .map((entry) => entry.key),
      ),
      mistakeCounts: Map.unmodifiable(mistakes),
    );
  }

  ProblemRecord _applyResult(
    ProblemRecord problem,
    TrainingAttempt attempt,
    DateTime endedAt,
  ) {
    if (attempt.result == AttemptResult.ac) {
      return problem.copyWith(
        workflowStatus: ProblemWorkflowStatus.mastered,
        reviewStage: 0,
        clearNextReviewAt: true,
        clearArchivedAt: true,
        updatedAt: endedAt,
      );
    }
    return problem.copyWith(
      workflowStatus: ProblemWorkflowStatus.active,
      reviewStage: 0,
      clearNextReviewAt: true,
      clearArchivedAt: true,
      updatedAt: endedAt,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
