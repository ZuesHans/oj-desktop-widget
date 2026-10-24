import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';

void main() {
  test('import cancel returns no feedback', () async {
    final service = HomeActionService(pickBackupFile: () async => null);

    final feedback = await service.importData(_FakeOjController());

    expect(feedback, isNull);
  });

  test('portable import feedback describes the replaced data', () async {
    final service = HomeActionService(
      pickBackupFile: () async => File('portable.json'),
    );

    final feedback = await service.importData(
      _ImportingFakeOjController(BackupImportScope.portable),
    );

    expect(feedback?.isSuccess, isTrue);
    expect(feedback?.message, contains('完整便携备份导入完成'));
    expect(feedback?.message, contains('抓取快照'));
    expect(feedback?.message, contains('safety.json'));
  });

  test('core import feedback says OJ data is preserved', () async {
    final service = HomeActionService(
      pickBackupFile: () async => File('core.json'),
    );

    final feedback = await service.importData(
      _ImportingFakeOjController(BackupImportScope.coreTraining),
    );

    expect(feedback?.isSuccess, isTrue);
    expect(feedback?.message, contains('核心训练备份导入完成'));
    expect(feedback?.message, contains('OJ 配置和抓取数据保持不变'));
    expect(feedback?.message, contains('safety.json'));
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

  test('open problem rejects non-web schemes without launching', () async {
    var launched = false;
    final service = HomeActionService(
      launchProblemUrl: (_) async {
        launched = true;
        return true;
      },
    );

    expect(
      () => service.openProblemUrl(
        ProblemRecord.create(
          id: 'p1',
          title: 'Unsafe',
          url: 'file:///C:/Windows/System32/calc.exe',
          platform: ProblemPlatform.other,
        ),
      ),
      throwsA(isA<FetchException>()),
    );
    expect(launched, isFalse);
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

  test('saving non-account settings does not refresh', () async {
    final controller = _RecordingOjController();
    addTearDown(controller.dispose);
    final service = HomeActionService();

    await service.saveSettings(
      controller: controller,
      shell: _FakeWindowShell(),
      config: controller.state.config.copyWith(refreshIntervalMinutes: 90),
      syncToken: '',
      syncNow: false,
      enablePlatformIntegration: false,
    );

    expect(controller.refreshCalls, 0);
  });

  test('changing OJ accounts triggers exactly one asynchronous refresh',
      () async {
    final controller = _RecordingOjController();
    addTearDown(controller.dispose);
    final service = HomeActionService();
    final accounts = Map<String, OjAccountConfig>.from(
      controller.state.config.accounts,
    )..['codeforces'] = const OjAccountConfig(
        usernames: ['tourist'],
        enabled: true,
      );

    await service.saveSettings(
      controller: controller,
      shell: _FakeWindowShell(),
      config: controller.state.config.copyWith(accounts: accounts),
      syncToken: '',
      syncNow: false,
      enablePlatformIntegration: false,
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.refreshCalls, 1);
  });

  test('tray initialization failure restores an accessible client config',
      () async {
    final controller = _RecordingOjController();
    addTearDown(controller.dispose);
    final shell = _FakeWindowShell(failEnablingTray: true);
    final service = HomeActionService();

    await expectLater(
      service.saveSettings(
        controller: controller,
        shell: shell,
        config: controller.state.config.copyWith(
          closeToTray: true,
          launchAtStartup: true,
        ),
        syncToken: '',
        syncNow: false,
        enablePlatformIntegration: true,
      ),
      throwsA(isA<FetchException>()),
    );

    expect(controller.state.config.closeToTray, isFalse);
    expect(controller.state.config.launchAtStartup, isFalse);
    expect(shell.showAndFocusCalls, 1);
    expect(shell.closeInterceptionEnabled, isTrue);
  });
}

class _RecordingOjController extends OjController {
  _RecordingOjController()
      : super(
          storage: LocalStore(),
          service: RefreshService(client: http.Client(), providers: const {}),
          startupService: NoopStartupService(),
          syncSecretStore: MemorySyncSecretStore(),
        );

  int refreshCalls = 0;

  @override
  Future<void> saveConfig(AppConfig config) async {
    final normalized =
        config.closeToTray ? config : config.copyWith(launchAtStartup: false);
    state = state.copyWith(config: normalized);
  }

  @override
  Future<void> saveSyncToken(String token) async {}

  @override
  Future<void> refresh({bool syncAfterRefresh = true}) async {
    refreshCalls++;
  }
}

class _FakeWindowShell implements WindowShell {
  _FakeWindowShell({this.failEnablingTray = false});

  final bool failEnablingTray;
  int showAndFocusCalls = 0;
  bool closeInterceptionEnabled = false;

  @override
  Future<void> setTrayEnabled(bool enabled) async {
    if (enabled && failEnablingTray) {
      throw StateError('tray unavailable');
    }
  }

  @override
  Future<void> setCloseInterceptionEnabled(bool enabled) async {
    closeInterceptionEnabled = enabled;
  }

  @override
  Future<void> showAndFocus() async {
    showAndFocusCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _ImportingFakeOjController implements OjController {
  _ImportingFakeOjController(this.scope);

  final BackupImportScope scope;

  @override
  Future<ImportResult> importPortableBackup(
    File backupFile, {
    Directory? safetyBackupDirectory,
  }) async {
    return ImportResult(
      safetyBackupFile: File('safety.json'),
      scope: scope,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
