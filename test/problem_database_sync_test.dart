import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('row upserts preserve external rows and direct SQL advances revision',
      () async {
    final directory = await Directory.systemTemp.createTemp('problem_sync_');
    try {
      final flutterStore = LocalStore(supportDirectory: directory);
      final companionStore = LocalStore(supportDirectory: directory);
      final first = _problem('flutter', 'Flutter problem');
      final external = _problem('cpp', 'C++ problem');

      await flutterStore.saveProblem(first);
      await companionStore.saveProblem(external);
      final revisionBeforeDirectWrite = await flutterStore.problemRevision();

      await flutterStore.saveProblem(
        first.copyWith(note: 'edited in Flutter'),
      );
      final afterUpsert = await flutterStore.loadProblems();
      expect(afterUpsert.map((problem) => problem.id),
          containsAll(['flutter', 'cpp']));

      final database = sqlite3.open(
        '${directory.path}${Platform.pathSeparator}$problemDatabaseFileName',
      );
      try {
        database.execute(
          'UPDATE problems SET title = ?, updated_at = ? WHERE id = ?',
          [
            'Edited by native companion',
            DateTime(2026, 9, 22, 18).toIso8601String(),
            external.id,
          ],
        );
      } finally {
        database.close();
      }

      final snapshot = await flutterStore.loadProblemSnapshot();
      expect(snapshot.revision, greaterThan(revisionBeforeDirectWrite));
      expect(
        snapshot.problems
            .singleWhere((problem) => problem.id == external.id)
            .title,
        'Edited by native companion',
      );
    } finally {
      await deleteTestDirectory(directory);
    }
  });

  test('schema v1 databases upgrade in place to revision tracking', () async {
    final directory = await Directory.systemTemp.createTemp('problem_sync_');
    try {
      final store = LocalStore(supportDirectory: directory);
      await store.saveProblem(_problem('existing', 'Existing problem'));
      final path =
          '${directory.path}${Platform.pathSeparator}$problemDatabaseFileName';
      final database = sqlite3.open(path);
      try {
        database.execute('DROP TRIGGER problems_revision_after_insert');
        database.execute('DROP TRIGGER problems_revision_after_update');
        database.execute('DROP TRIGGER problems_revision_after_delete');
        database.execute('DROP TABLE problem_change_state');
        database.execute('PRAGMA user_version = 1');
      } finally {
        database.close();
      }

      final upgraded = LocalStore(supportDirectory: directory);
      expect((await upgraded.loadProblems()).single.id, 'existing');
      expect(await upgraded.problemRevision(), 0);

      final verified = sqlite3.open(path);
      try {
        expect(
          verified.select('PRAGMA user_version').single['user_version'],
          ProblemDatabase.schemaVersion,
        );
      } finally {
        verified.close();
      }
    } finally {
      await deleteTestDirectory(directory);
    }
  });

  test('controller reloads changes committed by another process', () async {
    final directory = await Directory.systemTemp.createTemp('problem_sync_');
    final store = LocalStore(supportDirectory: directory);
    final controller = OjController(
      storage: store,
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: NoopStartupService(),
      syncSecretStore: MemorySyncSecretStore(),
      problemRefreshInterval: Duration.zero,
    );
    try {
      await controller.init();
      expect(controller.state.problems, isEmpty);

      await LocalStore(supportDirectory: directory).saveProblem(
        _problem('external', 'Added by C++'),
      );

      expect(await controller.refreshProblemsIfChanged(), isTrue);
      expect(controller.state.problems.single.id, 'external');
      expect(await controller.refreshProblemsIfChanged(), isFalse);
    } finally {
      controller.dispose();
      await deleteTestDirectory(directory);
    }
  });
}

ProblemRecord _problem(String id, String title) {
  return ProblemRecord.create(
    id: id,
    title: title,
    url: 'https://example.com/problems/$id',
    platform: ProblemPlatform.other,
    date: '2026-09-22',
    now: DateTime(2026, 9, 22, 17),
  );
}
