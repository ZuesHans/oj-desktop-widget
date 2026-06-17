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

  test('config saves launchAtStartup state', () async {
    final store = LocalStore();
    final config = _config(
      launchAtStartup: true,
      alwaysOnTop: false,
      showInTaskbar: false,
      closeToTray: false,
    );

    await store.saveConfig(config);
    final loaded = await store.loadConfig();

    expect(loaded.launchAtStartup, isTrue);
    expect(loaded.alwaysOnTop, isFalse);
    expect(loaded.showInTaskbar, isFalse);
    expect(loaded.closeToTray, isFalse);
  });

  testWidgets('settings page shows start at login switch', (tester) async {
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
    expect(find.text('窗口置顶'), findsOneWidget);
    expect(find.text('在任务栏显示'), findsOneWidget);
    expect(find.text('关闭时最小化到托盘'), findsOneWidget);
  });

  test('startup plugin failure does not block saving other settings', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final startupService = _FailingStartupService();
    final store = LocalStore(supportDirectory: directory);
    final controller = OjController(
      storage: store,
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: startupService,
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
}) {
  return AppConfig(
    refreshIntervalMinutes: 45,
    launchAtStartup: launchAtStartup,
    alwaysOnTop: alwaysOnTop,
    showInTaskbar: showInTaskbar,
    closeToTray: closeToTray,
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
