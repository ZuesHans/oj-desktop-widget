import '../core/time.dart';

enum AttemptResult { ac, wa, tle, re, gaveUp, skipped }

enum AssistanceLevel { none, hint, editorial }

enum TrainingAttemptOrigin { manual, contest, review, browserImport, legacy }

enum MistakeCategory {
  idea,
  implementation,
  complexity,
  edgeCase,
  math,
  reading,
  template,
  timeManagement,
  other,
}

enum TrainingListType { custom, topic, contest }

enum DailyTaskSource { manual, reviewDue, contestUpsolve }

enum DailyTaskStatus { planned, inProgress, done, skipped }

class TrainingAttempt {
  const TrainingAttempt({
    required this.id,
    required this.problemId,
    required this.origin,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.result,
    required this.assistance,
    required this.mistakes,
    required this.reflection,
  });

  factory TrainingAttempt.create({
    String? id,
    required String problemId,
    required TrainingAttemptOrigin origin,
    required DateTime startedAt,
    required DateTime endedAt,
    required int? durationSeconds,
    required AttemptResult result,
    AssistanceLevel assistance = AssistanceLevel.none,
    List<MistakeCategory> mistakes = const [],
    String reflection = '',
  }) {
    return TrainingAttempt(
      id: id ?? buildTrainingId('a', endedAt),
      problemId: problemId.trim(),
      origin: origin,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds?.clamp(0, 86400 * 7).toInt(),
      result: result,
      assistance: assistance,
      mistakes: List.unmodifiable(mistakes.toSet()),
      reflection: reflection.trim(),
    );
  }

  static TrainingAttempt? tryFromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id']);
    final problemId = _requiredString(json['problemId']);
    final startedAt = _dateTime(json['startedAt']);
    final endedAt = _dateTime(json['endedAt']);
    final origin = _enumValue(TrainingAttemptOrigin.values, json['origin']);
    final result = _enumValue(AttemptResult.values, json['result']);
    final assistance = _enumValue(AssistanceLevel.values, json['assistance']) ??
        AssistanceLevel.none;
    final duration = json['durationSeconds'];
    if (id == null ||
        problemId == null ||
        startedAt == null ||
        endedAt == null ||
        origin == null ||
        result == null ||
        endedAt.isBefore(startedAt) ||
        (duration != null && (duration is! int || duration < 0))) {
      return null;
    }
    final mistakes = <MistakeCategory>[];
    final rawMistakes = json['mistakes'];
    if (rawMistakes is List) {
      for (final value in rawMistakes) {
        final parsed = _enumValue(MistakeCategory.values, value);
        if (parsed != null && !mistakes.contains(parsed)) {
          mistakes.add(parsed);
        }
      }
    }
    return TrainingAttempt(
      id: id,
      problemId: problemId,
      origin: origin,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: duration as int?,
      result: result,
      assistance: assistance,
      mistakes: List.unmodifiable(mistakes),
      reflection: _optionalString(json['reflection']),
    );
  }

  final String id;
  final String problemId;
  final TrainingAttemptOrigin origin;
  final DateTime startedAt;
  final DateTime endedAt;
  final int? durationSeconds;
  final AttemptResult result;
  final AssistanceLevel assistance;
  final List<MistakeCategory> mistakes;
  final String reflection;

  Map<String, dynamic> toJson() => {
        'id': id,
        'problemId': problemId,
        'origin': origin.name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'result': result.name,
        'assistance': assistance.name,
        'mistakes': mistakes.map((item) => item.name).toList(),
        'reflection': reflection,
      };
}

class ActiveTrainingAttempt {
  const ActiveTrainingAttempt({
    required this.id,
    required this.problemId,
    required this.taskId,
    required this.origin,
    required this.startedAt,
    required this.pausedAt,
    required this.pausedSeconds,
  });

  factory ActiveTrainingAttempt.create({
    required String problemId,
    String? taskId,
    required TrainingAttemptOrigin origin,
    DateTime? now,
  }) {
    final startedAt = now ?? DateTime.now();
    return ActiveTrainingAttempt(
      id: buildTrainingId('active', startedAt),
      problemId: problemId,
      taskId: taskId?.trim(),
      origin: origin,
      startedAt: startedAt,
      pausedAt: null,
      pausedSeconds: 0,
    );
  }

  static ActiveTrainingAttempt? tryFromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id']);
    final problemId = _requiredString(json['problemId']);
    final taskId = _nullableString(json['taskId']);
    final origin = _enumValue(TrainingAttemptOrigin.values, json['origin']);
    final startedAt = _dateTime(json['startedAt']);
    final pausedAt =
        json['pausedAt'] == null ? null : _dateTime(json['pausedAt']);
    final pausedSeconds = json['pausedSeconds'];
    if (id == null ||
        problemId == null ||
        origin == null ||
        startedAt == null ||
        (json['pausedAt'] != null && pausedAt == null) ||
        pausedSeconds is! int ||
        pausedSeconds < 0) {
      return null;
    }
    return ActiveTrainingAttempt(
      id: id,
      problemId: problemId,
      taskId: taskId,
      origin: origin,
      startedAt: startedAt,
      pausedAt: pausedAt,
      pausedSeconds: pausedSeconds,
    );
  }

  final String id;
  final String problemId;
  final String? taskId;
  final TrainingAttemptOrigin origin;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final int pausedSeconds;

  bool get isPaused => pausedAt != null;

  int elapsedSeconds(DateTime now) {
    final stoppedAt = pausedAt ?? now;
    return (stoppedAt.difference(startedAt).inSeconds - pausedSeconds)
        .clamp(0, 86400 * 7)
        .toInt();
  }

  ActiveTrainingAttempt pause(DateTime now) {
    return isPaused
        ? this
        : ActiveTrainingAttempt(
            id: id,
            problemId: problemId,
            taskId: taskId,
            origin: origin,
            startedAt: startedAt,
            pausedAt: now,
            pausedSeconds: pausedSeconds,
          );
  }

  ActiveTrainingAttempt resume(DateTime now) {
    if (pausedAt == null) {
      return this;
    }
    return ActiveTrainingAttempt(
      id: id,
      problemId: problemId,
      taskId: taskId,
      origin: origin,
      startedAt: startedAt,
      pausedAt: null,
      pausedSeconds: pausedSeconds + now.difference(pausedAt!).inSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'problemId': problemId,
        'taskId': taskId,
        'origin': origin.name,
        'startedAt': startedAt.toIso8601String(),
        'pausedAt': pausedAt?.toIso8601String(),
        'pausedSeconds': pausedSeconds,
      };
}

class TrainingList {
  const TrainingList({
    required this.id,
    required this.title,
    required this.type,
    required this.problemIds,
    required this.contestId,
    required this.createdAt,
    required this.updatedAt,
    required this.archived,
    required this.isDefault,
  });

  factory TrainingList.create({
    String? id,
    required String title,
    TrainingListType type = TrainingListType.custom,
    List<String> problemIds = const [],
    String? contestId,
    bool isDefault = false,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return TrainingList(
      id: id ?? buildTrainingId('list', timestamp),
      title: title.trim(),
      type: type,
      problemIds: List.unmodifiable(problemIds.toSet()),
      contestId: contestId?.trim(),
      createdAt: timestamp,
      updatedAt: timestamp,
      archived: false,
      isDefault: isDefault,
    );
  }

  static TrainingList? tryFromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id']);
    final title = _requiredString(json['title']);
    final type = _enumValue(TrainingListType.values, json['type']);
    final createdAt = _dateTime(json['createdAt']);
    final updatedAt = _dateTime(json['updatedAt']);
    final problemIds = json['problemIds'];
    if (id == null ||
        title == null ||
        type == null ||
        createdAt == null ||
        updatedAt == null ||
        problemIds is! List) {
      return null;
    }
    return TrainingList(
      id: id,
      title: title,
      type: type,
      problemIds: List.unmodifiable(
        problemIds
            .whereType<String>()
            .map((item) => item.trim())
            .where(
              (item) => item.isNotEmpty,
            )
            .toSet(),
      ),
      contestId: _nullableString(json['contestId']),
      createdAt: createdAt,
      updatedAt: updatedAt,
      archived: json['archived'] is bool ? json['archived'] as bool : false,
      isDefault: json['isDefault'] is bool ? json['isDefault'] as bool : false,
    );
  }

  final String id;
  final String title;
  final TrainingListType type;
  final List<String> problemIds;
  final String? contestId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final bool isDefault;

  TrainingList copyWith({
    String? title,
    TrainingListType? type,
    List<String>? problemIds,
    String? contestId,
    bool clearContestId = false,
    DateTime? updatedAt,
    bool? archived,
    bool? isDefault,
  }) {
    return TrainingList(
      id: id,
      title: title?.trim() ?? this.title,
      type: type ?? this.type,
      problemIds: problemIds == null
          ? this.problemIds
          : List.unmodifiable(problemIds.toSet()),
      contestId: clearContestId ? null : contestId ?? this.contestId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      archived: archived ?? this.archived,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'problemIds': problemIds,
        'contestId': contestId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'archived': archived,
        'isDefault': isDefault,
      };
}

class DailyTrainingTask {
  const DailyTrainingTask({
    required this.id,
    required this.problemId,
    required this.trainingDate,
    required this.source,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    required this.completedAt,
  });

  factory DailyTrainingTask.create({
    String? id,
    required String problemId,
    required String trainingDate,
    DailyTaskSource source = DailyTaskSource.manual,
    int sortOrder = 0,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return DailyTrainingTask(
      id: id ?? buildTrainingId('task', timestamp),
      problemId: problemId,
      trainingDate: trainingDate,
      source: source,
      status: DailyTaskStatus.planned,
      sortOrder: sortOrder,
      createdAt: timestamp,
      completedAt: null,
    );
  }

  static DailyTrainingTask? tryFromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id']);
    final problemId = _requiredString(json['problemId']);
    final trainingDate = _requiredString(json['trainingDate']);
    final source = _enumValue(DailyTaskSource.values, json['source']);
    final status = _enumValue(DailyTaskStatus.values, json['status']);
    final createdAt = _dateTime(json['createdAt']);
    final completedAt =
        json['completedAt'] == null ? null : _dateTime(json['completedAt']);
    final sortOrder = json['sortOrder'];
    if (id == null ||
        problemId == null ||
        trainingDate == null ||
        !isValidDateKey(trainingDate) ||
        source == null ||
        status == null ||
        createdAt == null ||
        sortOrder is! int ||
        (json['completedAt'] != null && completedAt == null)) {
      return null;
    }
    return DailyTrainingTask(
      id: id,
      problemId: problemId,
      trainingDate: trainingDate,
      source: source,
      status: status,
      sortOrder: sortOrder,
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }

  final String id;
  final String problemId;
  final String trainingDate;
  final DailyTaskSource source;
  final DailyTaskStatus status;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? completedAt;

  DailyTrainingTask copyWith({
    String? trainingDate,
    DailyTaskStatus? status,
    int? sortOrder,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return DailyTrainingTask(
      id: id,
      problemId: problemId,
      trainingDate: trainingDate ?? this.trainingDate,
      source: source,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'problemId': problemId,
        'trainingDate': trainingDate,
        'source': source.name,
        'status': status.name,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };
}

class TrainingStoreData {
  const TrainingStoreData({
    this.schemaVersion = 2,
    this.attempts = const [],
    this.lists = const [],
    this.tasks = const [],
    this.activeAttempt,
  });

  static TrainingStoreData? tryFromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != null && version != 1 && version != 2) {
      return null;
    }
    final attempts = <TrainingAttempt>[];
    final rawAttempts = json['attempts'];
    if (rawAttempts != null && rawAttempts is! List) {
      return null;
    }
    for (final item in rawAttempts ?? const []) {
      if (item is Map) {
        final attempt = TrainingAttempt.tryFromJson(
          Map<String, dynamic>.from(item),
        );
        if (attempt != null) {
          attempts.add(attempt);
        }
      }
    }
    final lists = <TrainingList>[];
    final rawLists = json['lists'];
    if (rawLists != null && rawLists is! List) {
      return null;
    }
    for (final item in rawLists ?? const []) {
      if (item is Map) {
        final list = TrainingList.tryFromJson(Map<String, dynamic>.from(item));
        if (list != null) {
          lists.add(list);
        }
      }
    }
    final tasks = <DailyTrainingTask>[];
    final rawTasks = json['tasks'];
    if (rawTasks != null && rawTasks is! List) {
      return null;
    }
    for (final item in rawTasks ?? const []) {
      if (item is Map) {
        final task = DailyTrainingTask.tryFromJson(
          Map<String, dynamic>.from(item),
        );
        if (task != null) {
          tasks.add(task);
        }
      }
    }
    final rawActive = json['activeAttempt'];
    final active = rawActive is Map
        ? ActiveTrainingAttempt.tryFromJson(
            Map<String, dynamic>.from(rawActive),
          )
        : null;
    return TrainingStoreData(
      schemaVersion: 2,
      attempts: List.unmodifiable(attempts),
      lists: List.unmodifiable(lists),
      tasks: List.unmodifiable(tasks),
      activeAttempt: active,
    );
  }

  final int schemaVersion;
  final List<TrainingAttempt> attempts;
  final List<TrainingList> lists;
  final List<DailyTrainingTask> tasks;
  final ActiveTrainingAttempt? activeAttempt;

  TrainingStoreData copyWith({
    List<TrainingAttempt>? attempts,
    List<TrainingList>? lists,
    List<DailyTrainingTask>? tasks,
    ActiveTrainingAttempt? activeAttempt,
    bool clearActiveAttempt = false,
  }) {
    return TrainingStoreData(
      schemaVersion: 2,
      attempts: attempts ?? this.attempts,
      lists: lists ?? this.lists,
      tasks: tasks ?? this.tasks,
      activeAttempt:
          clearActiveAttempt ? null : activeAttempt ?? this.activeAttempt,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 2,
        'attempts': attempts.map((item) => item.toJson()).toList(),
        'lists': lists.map((item) => item.toJson()).toList(),
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'activeAttempt': activeAttempt?.toJson(),
      };
}

String buildTrainingId(String prefix, DateTime time) {
  return '$prefix${time.microsecondsSinceEpoch.toRadixString(36)}';
}

T? _enumValue<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  return null;
}

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}

String? _requiredString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

String _optionalString(Object? value) {
  return value is String ? value.trim() : '';
}

String? _nullableString(Object? value) {
  final text = _optionalString(value);
  return text.isEmpty ? null : text;
}
