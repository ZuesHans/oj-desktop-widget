import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/services/window_state_service.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late WindowStateService service;
  var bounds = const Rect.fromLTWH(100, 80, 1120, 760);
  var maximized = false;
  var minimized = false;
  var visible = true;
  var areas = [const Rect.fromLTWH(0, 0, 1920, 1040)];
  final calls = <MethodCall>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('oj_window_state_');
    bounds = const Rect.fromLTWH(100, 80, 1120, 760);
    maximized = minimized = false;
    visible = true;
    areas = [const Rect.fromLTWH(0, 0, 1920, 1040)];
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isMinimized':
          return minimized;
        case 'isMaximized':
          return maximized;
        case 'isVisible':
          return visible;
        case 'getBounds':
          return {
            'x': bounds.left,
            'y': bounds.top,
            'width': bounds.width,
            'height': bounds.height,
          };
        case 'setBounds':
          final args = call.arguments as Map;
          bounds = Rect.fromLTWH(args['x'] as double, args['y'] as double,
              args['width'] as double, args['height'] as double);
          return null;
        case 'maximize':
          maximized = true;
          return null;
        case 'unmaximize':
          maximized = false;
          return null;
        default:
          return null;
      }
    });
    service = WindowStateService(
        supportDirectory: () async => directory,
        loadWorkAreas: () async => areas);
  });

  tearDown(() async {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    await deleteTestDirectory(directory);
  });

  test('normal bounds, maximized state and page survive a disk round trip',
      () async {
    await service.load();
    await service.restore();
    bounds = const Rect.fromLTWH(220, 100, 1300, 850);
    service.selectSection('problems');
    await service.flush();
    maximized = true;
    bounds = areas.first;
    await service.flush();
    final reloaded = WindowStateService(
        supportDirectory: () async => directory,
        loadWorkAreas: () async => areas);
    await reloaded.load();
    await reloaded.restore();
    expect(reloaded.state.section, 'problems');
    expect(reloaded.state.bounds, const Rect.fromLTWH(220, 100, 1300, 850));
    expect(reloaded.state.maximized, isTrue);
    expect(bounds, reloaded.state.bounds);
    expect(calls.last.method, 'maximize');
    reloaded.dispose();
  });

  test(
      'temporary quick-entry and minimized geometry never overwrite main bounds',
      () async {
    await service.flush();
    final normal = bounds;
    service.geometrySuspended = true;
    bounds = const Rect.fromLTWH(0, 0, 520, 640);
    service.onWindowResize();
    service.selectSection('training');
    await service.flush();
    expect(service.state.bounds, normal);
    service.geometrySuspended = false;
    minimized = true;
    bounds = const Rect.fromLTWH(-32000, -32000, 1120, 760);
    await service.flush();
    await service.load();
    expect(service.state.bounds, normal);
    expect(service.state.section, 'training');
    expect(service.state.maximized, isFalse);
  });

  test('suspending invalidates a capture already waiting for native bounds',
      () async {
    await service.flush();
    final normal = service.state.bounds;
    final pending = Completer<Object?>();
    final requested = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isMinimized' || call.method == 'isMaximized') {
        return false;
      }
      if (call.method == 'getBounds') {
        requested.complete();
        return pending.future;
      }
      return null;
    });
    final saving = service.flush();
    await requested.future;
    service.geometrySuspended = true;
    pending.complete({'x': 0.0, 'y': 0.0, 'width': 520.0, 'height': 640.0});
    await saving;
    expect(service.state.bounds, normal);
  });

  test('unplugged display recenters bounds and retains maximized preference',
      () async {
    bounds = const Rect.fromLTWH(-1500, 120, 1200, 800);
    areas = [areas.first, const Rect.fromLTWH(-1920, 0, 1920, 1040)];
    await service.flush();
    await service.ensureVisible();
    expect(bounds.left, -1500);
    maximized = true;
    areas = [areas.first];
    await service.ensureVisible();
    expect(bounds, const Rect.fromLTWH(360, 120, 1200, 800));
    expect(maximized, isTrue);
    await service.flush();
    expect(service.state.maximized, isTrue);
    expect(calls.map((call) => call.method), contains('unmaximize'));
  });

  test(
      'corrupt or future window preferences fall back without blocking startup',
      () async {
    final file = File('${directory.path}/window_state.json');
    await file.writeAsString('{broken');
    await service.load();
    expect(service.state.bounds, isNull);
    await service.restore();
    expect(bounds, const Rect.fromLTWH(400, 140, 1120, 760));
    await file
        .writeAsString(jsonEncode({'version': 99, 'section': 'problems'}));
    await service.load();
    expect(service.state.section, 'summary');
    expect(
        DesktopWindowState.fromJson({
          'version': 1,
          'bounds': {'x': 0, 'y': 0, 'width': -10, 'height': 10},
          'section': 42,
        }).bounds,
        isNull);
  });

  test(
      'silent startup defers maximize and preserves it until the main window is shown',
      () async {
    final normal = bounds;
    service.state = DesktopWindowState(bounds: normal, maximized: true);
    visible = false;
    await service.restore(startHidden: true);
    await service.flush();
    expect(calls.map((call) => call.method), isNot(contains('maximize')));
    expect(service.state.maximized, isTrue);
    await service.ensureVisible();
    expect(maximized, isFalse);
    // Quick entry is allowed to become visible without applying the main
    // window's deferred maximize.
    service.geometrySuspended = true;
    visible = true;
    await service.ensureVisible();
    expect(maximized, isFalse);
    visible = false;
    service.geometrySuspended = false;
    await service.flush();
    expect(service.state.maximized, isTrue);
    visible = true;
    await service.ensureVisible();
    expect(maximized, isTrue);
    expect(service.state.bounds, normal);
    service.onWindowMaximize();
    minimized = true;
    await service.flush();
    expect(service.state.maximized, isTrue);
  });

  test('small work areas and offscreen bounds remain reachable at current DPI',
      () {
    const area = Rect.fromLTWH(0, 24, 800, 576);
    expect(
        fitWindowToDisplays(const Rect.fromLTWH(5000, 0, 1800, 1200), [area]),
        area);
    expect(fitWindowToDisplays(null, [area]), area);
    expect(() => fitWindowToDisplays(null, []), throwsStateError);
  });
}
