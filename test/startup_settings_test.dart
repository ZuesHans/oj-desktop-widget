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
      alwaysOnTop: false,
      showInTaskbar: false,
      closeToTray: false,
      sync: const SyncConfig(
        enabled: true,
        endpointUrl: 'https://example.com/api/oj-sync',
      ),
    );

    await store.saveConfig(config);
    final loaded = await store.loadConfig();

    expect(loaded.launchAtStartup, isTrue);
    expect(loaded.alwaysOnTop, isFalse);
    expect(loaded.showInTaskbar, isFalse);
    expect(loaded.closeToTray, isFalse);
    expect(loaded.sync.enabled, isTrue);
    expect(loaded.sync.endpointUrl, 'https://example.com/api/oj-sync');
    expect(loaded.toJson().toString(), isNot(contains('secret-token')));
  });

  testWidgets('settings page shows startup and sync switches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsDialog(config: _config(launchAtStartup: true)),
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('launch-at-startup-switch')), findsOneWidget);
    expect(find.text('Start at login'), findsOneWidget);
    expect(find.byKey(const ValueKey('always-on-top-switch')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('show-in-taskbar-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('close-to-tray-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-enabled-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-endpoint-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-token-field')), findsOneWidget);
    expect(find.text('Webhook sync'), findsOneWidget);
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
}

AppConfig _config({
  bool launchAtStartup = false,
  bool alwaysOnTop = true,
  bool showInTaskbar = true,
  bool closeToTray = true,
  String username = 'alice',
  bool enabled = true,
  SyncConfig sync = const SyncConfig(),
}) {
  return AppConfig(
    refreshIntervalMinutes: 45,
    launchAtStartup: launchAtStartup,
    alwaysOnTop: alwaysOnTop,
    showInTaskbar: showInTaskbar,
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
