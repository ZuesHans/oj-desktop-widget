part of '../main.dart';

enum AppDisplayMode { compact, dashboard, heatmap, problems }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final initialConfig = await LocalStore().loadConfig();
    final options = WindowOptions(
      size: _compactWindowSize,
      minimumSize: _compactMinimumWindowSize,
      center: true,
      title: 'OJ Float',
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: initialConfig.alwaysOnTop,
      backgroundColor: Colors.transparent,
      skipTaskbar: !initialConfig.showInTaskbar,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const OjFloatApp());
}
