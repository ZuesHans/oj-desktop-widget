import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(loaded.toJson().toString(), isNot(contains('secret-token')));
  });

  testWidgets('settings page shows startup and sync switches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(
            config: _config(launchAtStartup: true),
            initialSyncToken: '',
            onSave: (_) async {},
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
      await directory.delete(recursive: true);
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
      await directory.delete(recursive: true);
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
      await directory.delete(recursive: true);
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
