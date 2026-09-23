import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  group('automatic core backup', () {
    late Directory directory;
    late DateTime now;
    late AutomaticBackupService service;
    late AutomaticBackupConfig config;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('oj_auto_backup_');
      now = DateTime(2026, 8, 1, 22);
      service = AutomaticBackupService(
        defaultDirectoryProvider: () async => directory,
        now: () => now,
      );
      config = AutomaticBackupConfig(
        enabled: true,
        timeMinutes: 22 * 60,
        directoryPath: directory.path,
      );
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('contains only user-authored core data and restores every field',
        () async {
      final data = _coreData('initial');
      final result = await service.createBackup(
        config: config,
        problems: data.problems,
        training: data.training,
        contests: data.contests,
      );

      expect(result.outcome, AutomaticBackupOutcome.created);
      final file = File(result.filePath!);
      final json = jsonDecode(await file.readAsString()) as Map;
      expect(json['schemaVersion'], automaticBackupSchemaVersion);
      expect(json['backupScope'], automaticBackupScope);
      expect(json, isNot(contains('config')));
      expect(json, isNot(contains('snapshots')));
      expect(json, isNot(contains('refreshLogs')));
      expect(json, isNot(contains('teammates')));

      final restored = parseCoreTrainingBackupJson(await file.readAsString());
      expect(restored.problems.single.title, 'Problem initial');
      expect(restored.training.lists.single.isDefault, isTrue);
      expect(restored.training.tasks.single.trainingDate, '2026-08-02');
      expect(
          restored.training.attempts.single.reflection, 'Reflection initial');
      expect(restored.training.attempts.single.assistance,
          AssistanceLevel.editorial);
      expect(restored.training.attempts.single.mistakes,
          [MistakeCategory.edgeCase]);
      expect(restored.training.activeAttempt?.problemId, 'p-initial');
      expect(restored.contests.single.note, 'Contest review initial');
    });

    test('rejects silently modified content', () async {
      final data = _coreData('safe');
      final result = await service.createBackup(
        config: config,
        problems: data.problems,
        training: data.training,
        contests: data.contests,
      );
      final file = File(result.filePath!);
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final backupData = json['data'] as Map<String, dynamic>;
      final training = backupData['training'] as Map<String, dynamic>;
      final attempts = training['attempts'] as List<dynamic>;
      (attempts.single as Map<String, dynamic>)['reflection'] = 'tampered';
      await file.writeAsString(jsonEncode(json), flush: true);

      expect(
        () => parseCoreTrainingBackupJson(file.readAsStringSync()),
        throwsFormatException,
      );
    });

    test('refuses internally inconsistent core relationships', () async {
      final data = _coreData('consistent');
      final orphaned = data.training.copyWith(
        attempts: [
          TrainingAttempt.create(
            id: 'orphan-attempt',
            problemId: 'missing-problem',
            origin: TrainingAttemptOrigin.manual,
            startedAt: DateTime(2026, 8, 1, 20),
            endedAt: DateTime(2026, 8, 1, 20, 5),
            durationSeconds: 300,
            result: AttemptResult.wa,
          ),
        ],
      );

      await expectLater(
        service.createBackup(
          config: config,
          problems: data.problems,
          training: orphaned,
          contests: data.contests,
        ),
        throwsFormatException,
      );
      expect(await _automaticFiles(directory), isEmpty);
      expect(
        directory.listSync().whereType<File>().where(
              (file) => file.path.endsWith('.tmp'),
            ),
        isEmpty,
      );
    });

    test('writes at most once per day and skips unchanged data', () async {
      final initial = _coreData('same');
      final first = await service.createBackup(
        config: config,
        problems: initial.problems,
        training: initial.training,
        contests: initial.contests,
      );
      now = DateTime(2026, 8, 1, 23);
      final sameDay = await service.createBackup(
        config: config,
        problems: _coreData('changed-today').problems,
        training: _coreData('changed-today').training,
        contests: _coreData('changed-today').contests,
      );
      now = DateTime(2026, 8, 2, 22);
      final unchanged = await service.createBackup(
        config: config,
        problems: initial.problems,
        training: initial.training,
        contests: initial.contests,
      );
      final changed = _coreData('changed-next-day');
      final second = await service.createBackup(
        config: config,
        problems: changed.problems,
        training: changed.training,
        contests: changed.contests,
      );

      expect(first.outcome, AutomaticBackupOutcome.created);
      expect(sameDay.outcome, AutomaticBackupOutcome.alreadyCreatedToday);
      expect(unchanged.outcome, AutomaticBackupOutcome.unchanged);
      expect(second.outcome, AutomaticBackupOutcome.created);
      expect(await _automaticFiles(directory), hasLength(2));
    });

    test('retains seven recent days plus four older weekly points', () async {
      final start = DateTime(2026, 1, 1, 22);
      for (var index = 0; index < 50; index++) {
        now = start.add(Duration(days: index));
        final data = _coreData('day-$index');
        await service.createBackup(
          config: config,
          problems: data.problems,
          training: data.training,
          contests: data.contests,
        );
      }

      final files = await _automaticFiles(directory);
      expect(files, hasLength(11));
      final backups = <CoreTrainingBackup>[];
      for (final file in files) {
        backups.add(parseCoreTrainingBackupJson(await file.readAsString()));
      }
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(
        backups.take(7).map((item) => item.createdAt.day),
        [19, 18, 17, 16, 15, 14, 13],
      );
      expect(
        backups.skip(7).every(
              (item) => item.createdAt.isBefore(DateTime(2026, 2, 13)),
            ),
        isTrue,
      );
    });

    test('preserves corrupt automatic files and reports them', () async {
      final corrupt = File(
        '${directory.path}${Platform.pathSeparator}'
        'oj_float_auto_backup_corrupt.json',
      );
      await corrupt.writeAsString('{broken', flush: true);
      final data = _coreData('valid');
      final result = await service.createBackup(
        config: config,
        problems: data.problems,
        training: data.training,
        contests: data.contests,
      );
      final overview = await service.inspect(config);

      expect(result.invalidBackupCount, 1);
      expect(overview.invalidBackupCount, 1);
      expect(await corrupt.exists(), isTrue);
    });

    test('validates and reports the exact selected directory', () async {
      await service.validateDirectory(config);
      final overview = await service.inspect(config);

      expect(overview.directoryPath, directory.absolute.path);
      expect(
        directory.listSync().whereType<File>().where(
              (file) => file.path.contains('write_test'),
            ),
        isEmpty,
      );
    });

    test('core snapshot waits for queued writes before reading', () async {
      final storeDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}store',
      );
      final store = LocalStore(supportDirectory: storeDirectory);
      final oldData = _coreData('old');
      await store.saveProblems(oldData.problems);
      await store.saveTraining(oldData.training);
      await store.saveContests(oldData.contests);

      final current = _coreData('current');
      final write = store.saveProblemsAndTraining(
        current.problems,
        current.training,
      );
      final snapshotFuture = store.loadCoreBackupSnapshot();
      await write;
      final snapshot = await snapshotFuture;

      expect(snapshot.problems.single.id, 'p-current');
      expect(snapshot.training.attempts.single.id, 'attempt-current');
      expect(snapshot.contests.single.id, 'contest-old');
    });

    test('legacy migration recovers a semantically damaged primary from .bak',
        () async {
      final storeDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}semantic_recovery_store',
      );
      final previous = _coreData('previous');
      await storeDirectory.create(recursive: true);
      final primary = File(
        '${storeDirectory.path}${Platform.pathSeparator}problems_v1.json',
      );
      await File('${primary.path}.bak').writeAsString(
        jsonEncode(
          previous.problems.map((item) => item.toStorageJson()).toList(),
        ),
        flush: true,
      );
      await primary.writeAsString(
        jsonEncode([
          {'id': 'silently-damaged'},
        ]),
        flush: true,
      );

      final store = LocalStore(supportDirectory: storeDirectory);
      final snapshot = await store.loadCoreBackupSnapshot();

      expect(snapshot.problems.single.id, 'p-previous');
      final repaired = jsonDecode(await primary.readAsString()) as List;
      expect((repaired.single as Map)['id'], 'p-previous');
    });

    test('core snapshot rejects damaged source instead of dropping entries',
        () async {
      final storeDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}strict_source_store',
      );
      await storeDirectory.create(recursive: true);
      await File(
        '${storeDirectory.path}${Platform.pathSeparator}problems_v1.json',
      ).writeAsString(
        jsonEncode([
          _coreData('valid').problems.single.toStorageJson(),
          {'id': 'silently-damaged'},
        ]),
        flush: true,
      );
      final store = LocalStore(supportDirectory: storeDirectory);

      await expectLater(
        store.loadCoreBackupSnapshot(),
        throwsFormatException,
      );
    });
  });
}

Future<List<File>> _automaticFiles(Directory directory) async {
  return directory
      .listSync()
      .whereType<File>()
      .where(
        (file) =>
            file.path.split(Platform.pathSeparator).last.startsWith(
                  'oj_float_auto_backup_',
                ) &&
            file.path.endsWith('.json'),
      )
      .toList();
}

_CoreData _coreData(String suffix) {
  final problemId = 'p-$suffix';
  final startedAt = DateTime(2026, 8, 1, 20);
  final endedAt = DateTime(2026, 8, 1, 20, 35);
  final problem = ProblemRecord.create(
    id: problemId,
    title: 'Problem $suffix',
    url: 'https://example.com/problems/$suffix',
    platform: ProblemPlatform.other,
    tags: ['dp', suffix],
    date: '2026-08-01',
    note: 'Note $suffix',
    analysis: 'Analysis $suffix',
    now: startedAt,
  );
  final attempt = TrainingAttempt.create(
    id: 'attempt-$suffix',
    problemId: problemId,
    origin: TrainingAttemptOrigin.manual,
    startedAt: startedAt,
    endedAt: endedAt,
    durationSeconds: 1800,
    result: AttemptResult.wa,
    assistance: AssistanceLevel.editorial,
    mistakes: const [MistakeCategory.edgeCase],
    reflection: 'Reflection $suffix',
  );
  final list = TrainingList.create(
    id: 'list-$suffix',
    title: 'Default $suffix',
    problemIds: [problemId],
    isDefault: true,
    now: startedAt,
  );
  final task = DailyTrainingTask.create(
    id: 'task-$suffix',
    problemId: problemId,
    trainingDate: '2026-08-02',
    now: startedAt,
  ).copyWith(status: DailyTaskStatus.inProgress);
  final active = ActiveTrainingAttempt.create(
    problemId: problemId,
    taskId: task.id,
    origin: TrainingAttemptOrigin.manual,
    now: endedAt,
  );
  final contest = ContestRecord.create(
    id: 'contest-$suffix',
    title: 'Contest $suffix',
    date: '2026-08-01',
    rank: 10,
    note: 'Contest review $suffix',
    now: endedAt,
  );
  return _CoreData(
    problems: [problem],
    training: TrainingStoreData(
      attempts: [attempt],
      lists: [list],
      tasks: [task],
      activeAttempt: active,
    ),
    contests: [contest],
  );
}

class _CoreData {
  const _CoreData({
    required this.problems,
    required this.training,
    required this.contests,
  });

  final List<ProblemRecord> problems;
  final TrainingStoreData training;
  final List<ContestRecord> contests;
}
