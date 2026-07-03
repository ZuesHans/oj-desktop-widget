import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('import cancel returns no feedback', () async {
    final service = HomeActionService(pickBackupFile: () async => null);

    final feedback = await service.importData(_FakeOjController());

    expect(feedback, isNull);
  });

  test('open problem rejects invalid URLs', () async {
    final service = HomeActionService();

    expect(
      () => service.openProblemUrl(
        ProblemRecord.create(
          id: 'p1',
          title: 'Broken',
          url: 'not a url',
          platform: ProblemPlatform.other,
        ),
      ),
      throwsA(isA<FetchException>()),
    );
  });

  test('open problem reports launcher failure', () async {
    final service = HomeActionService(launchProblemUrl: (_) async => false);

    expect(
      () => service.openProblemUrl(
        ProblemRecord.create(
          id: 'p1',
          title: 'Problem',
          url: 'https://example.com/problem',
          platform: ProblemPlatform.other,
        ),
      ),
      throwsA(isA<FetchException>()),
    );
  });

  test('sync feedback uses a user-facing message', () {
    final feedback = ActionFeedback.fromSyncResult(
      const SyncResult(
        status: SyncStatus.failure,
        endpointLabel: 'example.com',
        message: 'HTTP 500',
      ),
    );

    expect(feedback.isSuccess, isFalse);
    expect(feedback.message, 'example.com 同步失败：HTTP 500');
  });

  test('window mode specs keep desktop sizing in one place', () {
    expect(windowSpecForMode(AppDisplayMode.compact).resizable, isFalse);
    expect(windowSpecForMode(AppDisplayMode.dashboard).size.width, 960);
    expect(windowSpecForMode(AppDisplayMode.problems).size.height, 620);
  });
}

class _FakeOjController implements OjController {
  @override
  Future<ImportResult> importPortableBackup(
    File backupFile, {
    Directory? safetyBackupDirectory,
  }) async {
    throw UnimplementedError('Should not import when picker is cancelled.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
