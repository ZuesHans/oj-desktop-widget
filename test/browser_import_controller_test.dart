import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('browser imports return created then existing with one local record',
      () async {
    final directory = await Directory.systemTemp.createTemp('browser_import_');
    final controller = OjController(
      storage: LocalStore(supportDirectory: directory),
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: NoopStartupService(),
      syncSecretStore: MemorySyncSecretStore(),
    );
    addTearDown(() async {
      controller.dispose();
      await directory.delete(recursive: true);
    });
    await controller.init();

    final created = await controller.importBrowserProblem(
      const BrowserProblemImport(
        url: 'https://codeforces.com/contest/1799/problem/A',
        title: 'Original',
        platform: 'cf',
        externalId: '1799:A',
        tags: ['greedy'],
        difficulty: '800',
      ),
    );
    final existing = await controller.importBrowserProblem(
      const BrowserProblemImport(
        url: 'https://codeforces.com/problemset/problem/1799/A?locale=en',
        title: 'Updated',
        platform: 'codeforces',
        externalId: '',
        tags: ['implementation'],
        difficulty: '',
      ),
    );

    expect(created.created, isTrue);
    expect(existing.created, isFalse);
    expect(existing.problemId, created.problemId);
    expect(controller.state.problems, hasLength(1));
    expect(controller.state.problems.single.title, 'Updated');
    expect(
      controller.state.problems.single.tags,
      containsAll(['greedy', 'implementation']),
    );
    expect(controller.state.problems.single.difficulty, '800');
  });
}
