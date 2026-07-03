import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app/app_display_mode.dart';
import '../models/app_config.dart';
import '../ui/app_labels.dart';
import '../ui/app_theme.dart';

class WindowShellService {
  WindowShellService({
    TrayManager? tray,
    WindowManager? window,
    AssetBundle? assets,
  })  : tray = tray ?? trayManager,
        window = window ?? windowManager,
        assets = assets ?? rootBundle;

  final TrayManager tray;
  final WindowManager window;
  final AssetBundle assets;

  Future<void> setupTray() async {
    if (!isDesktopPlatform) {
      return;
    }
    if (Platform.isWindows) {
      final iconFile = await _extractTrayIcon();
      await tray.setIcon(iconFile.path);
    }
    await tray.setToolTip(AppLabels.appTitle);
    await setupTrayMenu();
  }

  Future<void> setupTrayMenu() async {
    await tray.setContextMenu(
      Menu(
        items: [
          MenuItem(
              key: WindowShellTrayCommand.show.key,
              label: AppLabels.trayShowWindow),
          MenuItem(
              key: WindowShellTrayCommand.hide.key,
              label: AppLabels.trayHideWindow),
          MenuItem(
            key: WindowShellTrayCommand.toggleOnTop.key,
            label: AppLabels.trayToggleOnTop,
          ),
          MenuItem.separator(),
          MenuItem(
              key: WindowShellTrayCommand.refresh.key,
              label: AppLabels.trayRefreshNow),
          MenuItem.separator(),
          MenuItem(
              key: WindowShellTrayCommand.exit.key, label: AppLabels.trayExit),
        ],
      ),
    );
  }

  Future<void> showAndFocus() async {
    await window.show();
    await window.focus();
  }

  Future<void> hide() => window.hide();

  Future<void> minimize() => window.minimize();

  Future<void> startDragging() => window.startDragging();

  Future<void> syncMode(AppDisplayMode mode) async {
    try {
      final spec = windowSpecForMode(mode);
      await window.setResizable(spec.resizable);
      await window.setMinimumSize(spec.minimumSize);
      await window.setSize(spec.size, animate: true);
    } on MissingPluginException {
      // Widget tests do not load the desktop window plugin.
    }
  }

  Future<void> applyPreferences(AppConfig config) async {
    try {
      await window.setAlwaysOnTop(config.alwaysOnTop);
      await window.setSkipTaskbar(!config.showInTaskbar);
    } on MissingPluginException {
      // Widget tests do not load the desktop window plugin.
    }
  }

  Future<void> exitApp() async {
    try {
      await window.setPreventClose(false);
      await tray.destroy();
      await window.destroy();
    } on MissingPluginException {
      // Widget tests do not load the desktop window or tray plugins.
    }
  }

  Future<File> _extractTrayIcon() async {
    final bytes = await assets.load('assets/app_icon.ico');
    final directory = await getTemporaryDirectory();
    final iconFile =
        File('${directory.path}${Platform.pathSeparator}oj_float_app_icon.ico');
    await iconFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return iconFile;
  }
}

enum WindowShellTrayCommand {
  show('show'),
  hide('hide'),
  toggleOnTop('toggle_on_top'),
  refresh('refresh'),
  exit('exit');

  const WindowShellTrayCommand(this.key);

  final String key;

  static WindowShellTrayCommand? fromKey(String? key) {
    for (final command in values) {
      if (command.key == key) {
        return command;
      }
    }
    return null;
  }
}

class WindowModeSpec {
  const WindowModeSpec({
    required this.size,
    required this.minimumSize,
    required this.resizable,
  });

  final Size size;
  final Size minimumSize;
  final bool resizable;
}

WindowModeSpec windowSpecForMode(AppDisplayMode mode) {
  return switch (mode) {
    AppDisplayMode.compact => const WindowModeSpec(
        size: compactWindowSize,
        minimumSize: compactMinimumWindowSize,
        resizable: false,
      ),
    AppDisplayMode.largeFloat => const WindowModeSpec(
        size: largeFloatWindowSize,
        minimumSize: largeFloatMinimumWindowSize,
        resizable: true,
      ),
    AppDisplayMode.dashboard => const WindowModeSpec(
        size: dashboardWindowSize,
        minimumSize: dashboardMinimumWindowSize,
        resizable: true,
      ),
    AppDisplayMode.heatmap => const WindowModeSpec(
        size: heatmapWindowSize,
        minimumSize: heatmapMinimumWindowSize,
        resizable: true,
      ),
    AppDisplayMode.problems ||
    AppDisplayMode.refreshLogs ||
    AppDisplayMode.contests ||
    AppDisplayMode.teammates =>
      const WindowModeSpec(
        size: Size(760, 620),
        minimumSize: heatmapMinimumWindowSize,
        resizable: true,
      ),
  };
}

bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
