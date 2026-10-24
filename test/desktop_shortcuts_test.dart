import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/services/window_state_service.dart';

void main() {
  Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key,
      {bool settle = true}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    AppConfig? config,
    LocalStore? store,
    WindowStateService? windowState,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1120, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: OjFloatHome(
      initialConfig: config,
      storage: store,
      windowState: windowState,
      enablePlatformIntegration: false,
      autoInitializeController: false,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+F navigates and focuses search, including repeated use',
      (tester) async {
    await pumpHome(tester);
    await shortcut(tester, LogicalKeyboardKey.keyF);
    final finder = find.byKey(const ValueKey('problem-search-field'));
    expect(tester.widget<TextField>(finder).focusNode!.hasFocus, isTrue);
    await tester.enterText(finder, 'dynamic programming');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await shortcut(tester, LogicalKeyboardKey.keyF);
    expect(tester.widget<TextField>(finder).focusNode!.hasFocus, isTrue);
    expect(tester.widget<TextField>(finder).controller!.text,
        'dynamic programming');
  });

  testWidgets(
      'Ctrl+, opens settings; search and Esc preserve dirty-settings guard',
      (tester) async {
    final store = _RefreshStore();
    await pumpHome(tester, store: store);
    await shortcut(tester, LogicalKeyboardKey.comma);
    expect(find.byKey(const ValueKey('dashboard-section-settings')),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('refresh-interval-field')), '90');
    await shortcut(tester, LogicalKeyboardKey.keyF);
    expect(find.text('放弃未保存的更改？'), findsOneWidget);
    // A modal owns keyboard focus, so application shortcuts cannot refresh behind it.
    await shortcut(tester, LogicalKeyboardKey.keyR);
    expect(store.saves, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的更改？'), findsNothing);
    expect(find.byKey(const ValueKey('dashboard-section-settings')),
        findsOneWidget);
    await shortcut(tester, LogicalKeyboardKey.keyF);
    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(
                find.byKey(const ValueKey('problem-search-field')))
            .focusNode!
            .hasFocus,
        isTrue);
  });

  testWidgets('Ctrl+R refreshes once and ignores repeats while busy',
      (tester) async {
    final store = _RefreshStore()..pending = Completer<void>();
    await pumpHome(tester, store: store);
    await shortcut(tester, LogicalKeyboardKey.keyR, settle: false);
    expect(store.saves, 1);
    await shortcut(tester, LogicalKeyboardKey.keyR, settle: false);
    expect(store.saves, 1);
    store.pending!.complete();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('toolbar-refresh-button')))
            .onPressed,
        isNotNull);
  });

  testWidgets('disabled problem and account modules ignore their shortcuts',
      (tester) async {
    final store = _RefreshStore();
    await pumpHome(tester,
        config: AppConfig.defaults()
            .copyWith(dashboardModules: [DashboardModule.summary]),
        store: store);
    await shortcut(tester, LogicalKeyboardKey.keyF);
    await shortcut(tester, LogicalKeyboardKey.keyR);
    expect(store.saves, 0);
    expect(find.byKey(const ValueKey('dashboard-section-summary')),
        findsOneWidget);
    await shortcut(tester, LogicalKeyboardKey.comma);
    expect(find.byKey(const ValueKey('dashboard-section-settings')),
        findsOneWidget);
  });

  testWidgets('Esc closes a problem dialog while a text field has focus',
      (tester) async {
    await pumpHome(tester);
    await shortcut(tester, LogicalKeyboardKey.keyF);
    await tester.tap(find.byKey(const ValueKey('add-problem-button')));
    await tester.pumpAndSettle();
    final dialog = find.byKey(const ValueKey('problem-editor-dialog'));
    final field =
        find.descendant(of: dialog, matching: find.byType(TextField)).first;
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.byKey(const ValueKey('problems-page')), findsOneWidget);
  });

  testWidgets('last page restores and disabled or unknown pages fall back',
      (tester) async {
    final state = _MemoryWindowState('problems');
    await pumpHome(tester, windowState: state);
    expect(find.byKey(const ValueKey('problems-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-nav-training')));
    await tester.pumpAndSettle();
    expect(state.state.section, 'training');
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester,
        windowState: _MemoryWindowState('problems'),
        config: AppConfig.defaults()
            .copyWith(dashboardModules: [DashboardModule.summary]));
    expect(find.byKey(const ValueKey('dashboard-section-summary')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester, windowState: _MemoryWindowState('obsolete-page'));
    expect(find.byKey(const ValueKey('dashboard-section-summary')),
        findsOneWidget);
  });
}

class _RefreshStore extends LocalStore {
  int saves = 0;
  Completer<void>? pending;
  @override
  Future<void> saveSnapshots(List<SolvedSnapshot> snapshots) async {
    saves++;
    await pending?.future;
  }

  @override
  Future<void> saveRefreshLogs(List<RefreshLogEntry> logs) async {}
}

class _MemoryWindowState extends WindowStateService {
  _MemoryWindowState(String section) {
    state = DesktopWindowState(section: section);
  }
  @override
  void selectSection(String section) {
    state = DesktopWindowState(section: section);
  }
}
