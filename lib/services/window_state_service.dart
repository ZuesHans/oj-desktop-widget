import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../ui/app_theme.dart';
import 'app_data_directory.dart';

class DesktopWindowState {
  const DesktopWindowState({
    this.bounds,
    this.maximized = false,
    this.section = 'summary',
  });

  final Rect? bounds;
  final bool maximized;
  final String section;

  factory DesktopWindowState.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) return const DesktopWindowState();
    final raw = json['bounds'];
    Rect? bounds;
    if (raw is Map &&
        ['x', 'y', 'width', 'height'].every((key) => raw[key] is num)) {
      final candidate = Rect.fromLTWH(
        (raw['x'] as num).toDouble(),
        (raw['y'] as num).toDouble(),
        (raw['width'] as num).toDouble(),
        (raw['height'] as num).toDouble(),
      );
      if (candidate.isFinite && !candidate.isEmpty) bounds = candidate;
    }
    return DesktopWindowState(
      bounds: bounds,
      maximized: json['maximized'] == true,
      section:
          json['section'] is String ? json['section'] as String : 'summary',
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        if (bounds != null)
          'bounds': {
            'x': bounds!.left,
            'y': bounds!.top,
            'width': bounds!.width,
            'height': bounds!.height,
          },
        'maximized': maximized,
        'section': section,
      };
}

/// Coordinates and display work areas are both in logical pixels. The first
/// area is the primary display; negative coordinates on other screens are valid.
Rect fitWindowToDisplays(Rect? saved, List<Rect> workAreas) {
  final areas =
      workAreas.where((area) => area.isFinite && !area.isEmpty).toList();
  if (areas.isEmpty) throw StateError('No display work area is available.');
  if (saved != null && saved.isFinite && !saved.isEmpty) {
    for (final area in areas) {
      if (saved.left >= area.left &&
          saved.top >= area.top &&
          saved.right <= area.right &&
          saved.bottom <= area.bottom &&
          saved.width >= math.min(appMinimumWindowSize.width, area.width) &&
          saved.height >= math.min(appMinimumWindowSize.height, area.height)) {
        return saved;
      }
    }
  }
  final area = areas.first;
  final size = saved != null && saved.isFinite && !saved.isEmpty
      ? saved.size
      : appWindowSize;
  final width = size.width
      .clamp(
        math.min(appMinimumWindowSize.width, area.width),
        area.width,
      )
      .toDouble();
  final height = size.height
      .clamp(
        math.min(appMinimumWindowSize.height, area.height),
        area.height,
      )
      .toDouble();
  return Rect.fromLTWH(area.left + (area.width - width) / 2,
      area.top + (area.height - height) / 2, width, height);
}

/// Optional, machine-local UI preferences. Failures must never prevent startup
/// or exit. All reads/captures/writes are serialized so older events cannot win.
class WindowStateService with WindowListener, ScreenListener {
  WindowStateService({
    this.supportDirectory,
    WindowManager? window,
    this.loadWorkAreas,
  }) : window = window ?? windowManager;

  final Future<Directory> Function()? supportDirectory;
  final WindowManager window;
  final Future<List<Rect>> Function()? loadWorkAreas;
  DesktopWindowState state = const DesktopWindowState();
  Future<void> _pending = Future.value();
  Timer? _saveTimer;
  bool _started = false;
  bool _suspended = false;
  bool _maximizeOnShow = false;
  int _generation = 0;

  Future<File> _file() async {
    final directory = await (supportDirectory ?? applicationDataDirectory)();
    return File('${directory.path}/window_state.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        state = DesktopWindowState.fromJson(Map<String, dynamic>.from(
            jsonDecode(await file.readAsString()) as Map));
      }
    } catch (error) {
      debugPrint(
          'Window preferences could not be loaded (${error.runtimeType}).');
    }
  }

  Future<List<Rect>> _workAreas() async {
    if (loadWorkAreas != null) return loadWorkAreas!();
    final primary = await screenRetriever.getPrimaryDisplay();
    final displays = await screenRetriever.getAllDisplays();
    return [
      for (final display in [
        primary,
        ...displays.where((d) => d.id != primary.id)
      ])
        (display.visiblePosition ?? Offset.zero) &
            (display.visibleSize ?? display.size),
    ];
  }

  Future<void> restore({bool startHidden = false}) async {
    try {
      final bounds = fitWindowToDisplays(state.bounds, await _workAreas());
      await _applyBounds(bounds);
      state = DesktopWindowState(
          bounds: bounds, maximized: state.maximized, section: state.section);
      // Native maximize can show a hidden window. Defer it until the user
      // brings the main window back, without losing the saved preference.
      _maximizeOnShow = startHidden && state.maximized;
      if (state.maximized && !startHidden) await window.maximize();
    } catch (error) {
      debugPrint(
          'Window placement could not be restored (${error.runtimeType}).');
      await window.center();
    }
  }

  Future<void> _applyBounds(Rect bounds) async {
    await window.setMinimumSize(Size(
      math.min(appMinimumWindowSize.width, bounds.width),
      math.min(appMinimumWindowSize.height, bounds.height),
    ));
    await window.setBounds(bounds);
  }

  void start() {
    if (_started) return;
    _started = true;
    window.addListener(this);
    screenRetriever.addListener(this);
  }

  void dispose() {
    _saveTimer?.cancel();
    if (!_started) return;
    _started = false;
    window.removeListener(this);
    screenRetriever.removeListener(this);
  }

  /// Quick entry temporarily resizes the same native window. Its bounds must
  /// never replace the main window, including captures already awaiting I/O.
  set geometrySuspended(bool value) {
    _suspended = value;
    _generation++;
    _saveTimer?.cancel();
  }

  void selectSection(String section) {
    if (state.section == section) return;
    state = DesktopWindowState(
        bounds: state.bounds, maximized: state.maximized, section: section);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer =
        Timer(const Duration(milliseconds: 350), () => unawaited(flush()));
  }

  void _rememberMaximized(bool value) {
    if (_suspended) return;
    state = DesktopWindowState(
        bounds: state.bounds, maximized: value, section: state.section);
    _scheduleSave();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    return _pending = _pending.then((_) => action()).catchError((Object error) {
      debugPrint(
          'Window preferences could not be updated (${error.runtimeType}).');
    });
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    return _enqueue(() async {
      final generation = _generation;
      if (!_suspended && !await window.isMinimized()) {
        final maximized = _maximizeOnShow || await window.isMaximized();
        final bounds = maximized ? state.bounds : await window.getBounds();
        if (!_suspended && generation == _generation) {
          state = DesktopWindowState(
              bounds: bounds, maximized: maximized, section: state.section);
        }
      }
      final contents = jsonEncode(state.toJson());
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(file.path);
    });
  }

  /// Recheck after display hotplug and when a hidden window is brought back.
  Future<void> ensureVisible() => _enqueue(() async {
        final generation = _generation;
        if (_suspended || await window.isMinimized()) return;
        final deferredMaximize = _maximizeOnShow;
        if (deferredMaximize && await window.isVisible()) {
          _maximizeOnShow = false;
          await window.maximize();
        }
        final maximized = deferredMaximize || await window.isMaximized();
        final bounds = maximized ? state.bounds : await window.getBounds();
        final fitted = fitWindowToDisplays(bounds, await _workAreas());
        if (_suspended || generation != _generation || fitted == bounds) return;
        if (maximized && !_maximizeOnShow) await window.unmaximize();
        await _applyBounds(fitted);
        state = DesktopWindowState(
            bounds: fitted, maximized: maximized, section: state.section);
        if (maximized && !_maximizeOnShow) await window.maximize();
        _scheduleSave();
      });

  @override
  void onScreenEvent(String eventName) => unawaited(ensureVisible());
  @override
  void onWindowFocus() => unawaited(ensureVisible());
  @override
  void onWindowMove() => _scheduleSave();
  @override
  void onWindowResize() => _scheduleSave();
  @override
  void onWindowMaximize() => _rememberMaximized(true);
  @override
  void onWindowUnmaximize() => _rememberMaximized(false);
  @override
  void onWindowMinimize() => _scheduleSave();
  @override
  void onWindowRestore() => _scheduleSave();
}
