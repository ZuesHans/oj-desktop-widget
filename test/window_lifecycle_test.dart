import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<_FakeWindowShell> pumpClient(
    WidgetTester tester, {
    required AppConfig config,
  }) async {
    final shell = _FakeWindowShell();
    await tester.pumpWidget(
      OjFloatApp(
        initialConfig: config,
        windowShell: shell,
        enablePlatformIntegration: true,
        autoInitializeController: false,
      ),
    );
    await tester.pumpAndSettle();
    return shell;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('dashboard-nav-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('default native close exits the client', (tester) async {
    final shell = await pumpClient(
      tester,
      config: AppConfig.defaults(),
    );

    shell.windowListener!.onWindowClose();
    await tester.pumpAndSettle();

    expect(shell.exitCalls, 1);
    expect(shell.hideCalls, 0);
  });

  testWidgets('tray close confirms dirty settings before hiding',
      (tester) async {
    final shell = await pumpClient(
      tester,
      config: AppConfig.defaults().copyWith(closeToTray: true),
    );
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('close-to-tray-switch')));
    await tester.pumpAndSettle();

    shell.windowListener!.onWindowClose();
    await tester.pumpAndSettle();

    expect(find.text('放弃未保存的更改？'), findsOneWidget);
    expect(shell.hideCalls, 0);
    expect(shell.exitCalls, 0);

    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(shell.hideCalls, 0);

    shell.windowListener!.onWindowClose();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();

    final traySwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('close-to-tray-switch')),
    );
    expect(traySwitch.value, isTrue);
    expect(shell.hideCalls, 1);
    expect(shell.exitCalls, 0);
  });

  testWidgets('tray exit also protects unsaved settings', (tester) async {
    final shell = await pumpClient(
      tester,
      config: AppConfig.defaults().copyWith(closeToTray: true),
    );
    await openSettings(tester);
    await tester.enterText(
      find.byKey(const ValueKey('refresh-interval-field')),
      '90',
    );
    await tester.pumpAndSettle();

    shell.trayListener!.onTrayMenuItemClick(
      MenuItem(key: WindowShellTrayCommand.exit.key, label: '退出'),
    );
    await tester.pumpAndSettle();

    expect(find.text('放弃未保存的更改？'), findsOneWidget);
    expect(shell.exitCalls, 0);

    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();
    expect(shell.exitCalls, 1);
  });

  test('tray command surface is limited to show, refresh and exit', () {
    expect(
      WindowShellTrayCommand.values.map((command) => command.key),
      ['show', 'refresh', 'exit'],
    );
  });
}

class _FakeWindowShell implements WindowShell {
  TrayListener? trayListener;
  WindowListener? windowListener;
  int hideCalls = 0;
  int exitCalls = 0;
  int showAndFocusCalls = 0;
  bool trayEnabled = false;
  bool closeInterceptionEnabled = false;

  @override
  void addTrayListener(TrayListener listener) {
    trayListener = listener;
  }

  @override
  void removeTrayListener(TrayListener listener) {
    if (identical(trayListener, listener)) {
      trayListener = null;
    }
  }

  @override
  void addWindowListener(WindowListener listener) {
    windowListener = listener;
  }

  @override
  void removeWindowListener(WindowListener listener) {
    if (identical(windowListener, listener)) {
      windowListener = null;
    }
  }

  @override
  Future<void> setTrayEnabled(bool enabled) async {
    trayEnabled = enabled;
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
  Future<void> hide() async {
    hideCalls++;
  }

  @override
  Future<void> exitApp() async {
    exitCalls++;
  }
}
