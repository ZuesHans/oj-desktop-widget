import 'dart:async';
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
    final config = _config(launchAtStartup: true);

    await store.saveConfig(config);
    final loaded = await store.loadConfig();

    expect(loaded.launchAtStartup, isTrue);
  });

  testWidgets('settings page shows start at login switch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsDialog(config: _config(launchAtStartup: true)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('launch-at-startup-switch')), findsOneWidget);
    expect(find.text('Start at login'), findsOneWidget);
  });

  test('startup plugin failure does not block saving other settings', () async {
    final startupService = _FailingStartupService();
    final controller = OjController(
      storage: LocalStore(),
      service: RefreshService(client: http.Client(), providers: const {}),
      startupService: startupService,
    );
    final config = _config(
      launchAtStartup: true,
      username: 'saved-user',
      enabled: false,
    );

    await expectLater(controller.saveConfig(config), throwsA(isA<FetchException>()));
    final loaded = await LocalStore().loadConfig();

    expect(startupService.calls, [true]);
    expect(loaded.launchAtStartup, isTrue);
    expect(loaded.accounts['codeforces']!.usernames, ['saved-user']);
  });
}

AppConfig _config({
  bool launchAtStartup = false,
  String username = 'alice',
  bool enabled = true,
}) {
  return AppConfig(
    refreshIntervalMinutes: 45,
    launchAtStartup: launchAtStartup,
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
  Future<void> setEnabled(bool enabled) {
    calls.add(enabled);
    return Future<void>.error(const SocketException('startup denied'));
  }
}
