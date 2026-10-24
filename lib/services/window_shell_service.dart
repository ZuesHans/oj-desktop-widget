import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../ui/app_labels.dart';

abstract interface class WindowShell {
  void addTrayListener(TrayListener listener);

  void removeTrayListener(TrayListener listener);

  void addWindowListener(WindowListener listener);

  void removeWindowListener(WindowListener listener);

  Future<void> setTrayEnabled(bool enabled);

  /// Enables app-managed close handling so the UI can confirm unsaved work
  /// before either hiding to the tray or exiting.
  Future<void> setCloseInterceptionEnabled(bool enabled);

  Future<void> showAndFocus();

  Future<void> hide();

  Future<void> exitApp();
}

class WindowShellService implements WindowShell {
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

  bool _trayReady = false;

  @override
  void addTrayListener(TrayListener listener) => tray.addListener(listener);

  @override
  void removeTrayListener(TrayListener listener) =>
      tray.removeListener(listener);

  @override
  void addWindowListener(WindowListener listener) =>
      window.addListener(listener);

  @override
  void removeWindowListener(WindowListener listener) =>
      window.removeListener(listener);

  @override
  Future<void> setTrayEnabled(bool enabled) async {
    if (!enabled) {
      if (_trayReady) {
        await tray.destroy();
        _trayReady = false;
      }
      return;
    }

    if (!_trayReady) {
      final iconPath = Platform.isWindows
          ? (await _extractTrayIcon()).path
          : 'assets/app_icon.png';
      await tray.setIcon(iconPath);
      await tray.setToolTip(AppLabels.appTitle);
      _trayReady = true;
    }
    await tray.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: WindowShellTrayCommand.show.key,
            label: AppLabels.trayShowWindow,
          ),
          MenuItem(
            key: WindowShellTrayCommand.refresh.key,
            label: AppLabels.trayRefreshNow,
          ),
          MenuItem.separator(),
          MenuItem(
            key: WindowShellTrayCommand.exit.key,
            label: AppLabels.trayExit,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> setCloseInterceptionEnabled(bool enabled) =>
      window.setPreventClose(enabled);

  @override
  Future<void> showAndFocus() async {
    if (await window.isMinimized()) {
      await window.restore();
    }
    await window.show();
    await window.focus();
  }

  @override
  Future<void> hide() => window.hide();

  @override
  Future<void> exitApp() async {
    if (_trayReady) {
      await tray.destroy();
      _trayReady = false;
    }
    await window.setPreventClose(false);
    // close() posts a native close request and lets the method call return
    // before the Flutter engine is torn down. destroy() quits the Windows
    // message loop immediately and can crash the engine callback in flight.
    await window.close();
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
