import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('config saves launchAtStartup and sync state', () async {
    final store = LocalStore();
    final config = _config(
      launchAtStartup: true,
      closeToTray: true,
      sync: const SyncConfig(
        enabled: true,
        endpointUrl: 'https://example.com/api/oj-sync',
      ),
    );

    await store.saveConfig(config);
    final loaded = await store.loadConfig();

    expect(loaded.launchAtStartup, isTrue);
    expect(loaded.closeToTray, isTrue);
    expect(loaded.sync.enabled, isTrue);
    expect(loaded.sync.endpointUrl, 'https://example.com/api/oj-sync');
    expect(loaded.automaticBackup.enabled, isFalse);
    expect(loaded.toJson().toString(), isNot(contains('secret-token')));
  });

  test('config v2 migration preserves lifecycle and disables backup by default',
      () async {
    SharedPreferences.setMockInitialValues({
      'app_config_v1': jsonEncode({
        'configVersion': 2,
        'refreshIntervalMinutes': 30,
        'launchAtStartup': true,
        'closeToTray': true,
        'accounts': const {},
      }),
    });

    final loaded = await LocalStore().loadConfig();

    expect(loaded.configVersion, currentAppConfigVersion);
    expect(loaded.launchAtStartup, isTrue);
    expect(loaded.closeToTray, isTrue);
    expect(loaded.automaticBackup.enabled, isFalse);
    expect(loaded.automaticBackup.timeMinutes, 22 * 60);
  });

  testWidgets('settings page shows startup and sync switches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            config: _config(launchAtStartup: true),
            initialSyncToken: '',
            onSave: (_) async {},
            onChooseAutomaticBackupDirectory: () async => r'C:\Backups',
          ),
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('launch-at-startup-switch')), findsOneWidget);
    expect(find.text('登录时启动'), findsOneWidget);
    expect(find.byKey(const ValueKey('always-on-top-switch')), findsNothing);
    expect(find.byKey(const ValueKey('show-in-taskbar-switch')), findsNothing);
    expect(find.byKey(const ValueKey('close-to-tray-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-enabled-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-endpoint-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-token-field')), findsOneWidget);
    expect(find.text('网页钩子同步'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('automatic-backup-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('automatic-backup-time-button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('automatic-backup-directory-path')),
        findsOneWidget);
  });

  testWidgets('settings selects and saves automatic backup directory',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SettingsPageResult? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            config: _config().copyWith(
              automaticBackup: const AutomaticBackupConfig(
                timeMinutes: 13 * 60 + 37,
                directoryPath: r'C:\OldBackups',
              ),
            ),
            initialSyncToken: '',
            onChooseAutomaticBackupDirectory: () async => r'D:\OJ Backups',
            onSave: (result) async => saved = result,
          ),
        ),
      ),
    );

    final choose = find.byKey(
      const ValueKey('choose-automatic-backup-directory'),
    );
    await tester.ensureVisible(choose);
    await tester.pumpAndSettle();
    await tester.tap(choose);
    await tester.pumpAndSettle();
    expect(find.text(r'D:\OJ Backups'), findsOneWidget);
    expect(find.text('13:37'), findsOneWidget);

    final backupSwitch = find.byKey(const ValueKey('automatic-backup-switch'));
    await tester.ensureVisible(backupSwitch);
    await tester.pumpAndSettle();
    await tester.tap(backupSwitch);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('settings-save-button'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(saved?.config.automaticBackup.enabled, isTrue);
    expect(saved?.config.automaticBackup.directoryPath, r'D:\OJ Backups');
    expect(saved?.config.automaticBackup.timeMinutes, 13 * 60 + 37);
  });

  test('startup plugin failure does not block saving other settings', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final startupService = _FailingStartupService();
    final store = LocalStore(supportDirectory: directory);
    final controller = OjController(
      storage: store,
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: startupService,
      syncSecretStore: MemorySyncSecretStore(),
    );
    final config = _config(
      launchAtStartup: true,
      closeToTray: true,
      username: 'saved-user',
      enabled: false,
    );

    try {
      await expectLater(
          controller.saveConfig(config), throwsA(isA<FetchException>()));
      final loaded = await store.loadConfig();

      expect(startupService.calls, [true]);
      expect(loaded.launchAtStartup, isTrue);
      expect(loaded.accounts['codeforces']!.usernames, ['saved-user']);
    } finally {
      await deleteTestDirectory(directory);
      controller.dispose();
    }
  });

  test('startup plugin false result is reported after saving config', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final startupService = _FalseStartupService();
    final store = LocalStore(supportDirectory: directory);
    final controller = OjController(
      storage: store,
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: startupService,
      syncSecretStore: MemorySyncSecretStore(),
    );
    final config = _config(
      launchAtStartup: true,
      closeToTray: true,
      username: 'saved-after-false',
      enabled: false,
    );

    try {
      await expectLater(
        controller.saveConfig(config),
        throwsA(isA<FetchException>()),
      );
      final loaded = await store.loadConfig();

      expect(startupService.calls, [true]);
      expect(loaded.launchAtStartup, isTrue);
      expect(loaded.accounts['codeforces']!.usernames, ['saved-after-false']);
    } finally {
      await deleteTestDirectory(directory);
      controller.dispose();
    }
  });

  test('disabling tray mode also disables startup registration', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final startupService = _RecordingStartupService();
    final controller = OjController(
      storage: LocalStore(supportDirectory: directory),
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: startupService,
      syncSecretStore: MemorySyncSecretStore(),
    );

    try {
      await controller.saveConfig(
        _config(launchAtStartup: true, closeToTray: false),
      );

      expect(controller.state.config.launchAtStartup, isFalse);
      expect(startupService.calls, [false]);
    } finally {
      controller.dispose();
      await deleteTestDirectory(directory);
    }
  });

  test('startup argument hides only when both lifecycle switches are enabled',
      () {
    expect(
      shouldStartHidden(
        const ['--startup'],
        _config(launchAtStartup: true, closeToTray: true),
      ),
      isTrue,
    );
    expect(
      shouldStartHidden(
        const ['--startup'],
        _config(launchAtStartup: false, closeToTray: true),
      ),
      isFalse,
    );
    expect(
      shouldStartHidden(
        const ['--startup'],
        _config(launchAtStartup: true, closeToTray: false),
      ),
      isFalse,
    );
    expect(
      shouldStartHidden(
        const [],
        _config(launchAtStartup: true, closeToTray: true),
      ),
      isFalse,
    );
  });

  test('controller creates a due backup in the selected directory', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final backupDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}chosen_backups',
    );
    final store = LocalStore(supportDirectory: directory);
    final config = _config(enabled: false).copyWith(
      automaticBackup: AutomaticBackupConfig(
        enabled: true,
        timeMinutes: 9 * 60,
        directoryPath: backupDirectory.path,
      ),
    );
    await store.saveConfig(config);
    await store.saveProblems([
      ProblemRecord.create(
        id: 'scheduled-problem',
        title: 'Scheduled problem',
        url: 'https://example.com/scheduled',
        platform: ProblemPlatform.other,
        date: '2026-08-01',
        now: DateTime(2026, 8, 1, 8),
      ),
    ]);
    final backupService = AutomaticBackupService(
      defaultDirectoryProvider: () async => backupDirectory,
      now: () => DateTime(2026, 8, 1, 10),
    );
    final controller = OjController(
      storage: store,
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: NoopStartupService(),
      syncSecretStore: MemorySyncSecretStore(),
      automaticBackupService: backupService,
    );

    try {
      await controller.init();

      expect(controller.automaticBackupError, isEmpty);
      expect(controller.automaticBackupOverview?.validBackupCount, 1);
      expect(controller.automaticBackupOverview?.directoryPath,
          backupDirectory.absolute.path);
      expect(
        backupDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.contains('oj_float_auto_backup_')),
        hasLength(1),
      );
    } finally {
      controller.dispose();
      await deleteTestDirectory(directory);
    }
  });

  test('controller does not back up before the selected time', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final backupDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}chosen_backups',
    );
    final store = LocalStore(supportDirectory: directory);
    await store.saveConfig(
      _config(enabled: false).copyWith(
        automaticBackup: AutomaticBackupConfig(
          enabled: true,
          timeMinutes: 23 * 60,
          directoryPath: backupDirectory.path,
        ),
      ),
    );
    final backupService = AutomaticBackupService(
      defaultDirectoryProvider: () async => backupDirectory,
      now: () => DateTime(2026, 8, 1, 10),
    );
    final controller = OjController(
      storage: store,
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: NoopStartupService(),
      syncSecretStore: MemorySyncSecretStore(),
      automaticBackupService: backupService,
    );

    try {
      await controller.init();

      expect(controller.automaticBackupOverview?.validBackupCount, 0);
      expect(
        await backupDirectory.exists()
            ? backupDirectory
                .listSync()
                .whereType<File>()
                .where((file) => file.path.contains('oj_float_auto_backup_'))
            : const <File>[],
        isEmpty,
      );
    } finally {
      controller.dispose();
      await deleteTestDirectory(directory);
    }
  });
}

AppConfig _config({
  bool launchAtStartup = false,
  bool closeToTray = true,
  String username = 'alice',
  bool enabled = true,
  SyncConfig sync = const SyncConfig(),
}) {
  return AppConfig(
    refreshIntervalMinutes: 45,
    launchAtStartup: launchAtStartup,
    closeToTray: closeToTray,
    sync: sync,
    accounts: {
      for (final meta in supportedOjs)
        meta.id: meta.id == 'codeforces'
            ? OjAccountConfig(usernames: [username], enabled: enabled)
            : const OjAccountConfig(usernames: [], enabled: false),
    },
  );
}

class _FailingStartupService implements StartupService {
  final calls = <bool>[];

  @override
  Future<bool> setEnabled(bool enabled) {
    calls.add(enabled);
    return Future<bool>.error(const SocketException('startup denied'));
  }
}

class _FalseStartupService implements StartupService {
  final calls = <bool>[];

  @override
  Future<bool> setEnabled(bool enabled) async {
    calls.add(enabled);
    return false;
  }
}

class _RecordingStartupService implements StartupService {
  final calls = <bool>[];

  @override
  Future<bool> setEnabled(bool enabled) async {
    calls.add(enabled);
    return true;
  }
}
