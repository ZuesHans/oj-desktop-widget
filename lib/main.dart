import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/oj_float_app.dart';
import 'models/app_config.dart';
import 'services/local_store.dart';
import 'ui/app_labels.dart';
import 'ui/app_theme.dart';

export 'app/oj_float_app.dart';
export 'core/errors.dart';
export 'core/http_client.dart';
export 'core/oj_catalog.dart';
export 'core/solved_totals.dart';
export 'core/time.dart';
export 'models/app_config.dart';
export 'models/contest_record.dart';
export 'models/fetch_result.dart';
export 'models/oj_meta.dart';
export 'models/oj_state.dart';
export 'models/problem_record.dart';
export 'models/refresh_log_entry.dart';
export 'models/solved_snapshot.dart';
export 'models/teammate.dart';
export 'models/training.dart';
export 'platform/startup_service.dart';
export 'providers/atcoder_provider.dart';
export 'providers/codeforces_provider.dart';
export 'providers/leetcode_provider.dart';
export 'providers/luogu_provider.dart';
export 'providers/nowcoder_provider.dart';
export 'providers/oj_provider.dart';
export 'services/backup_service.dart';
export 'services/automatic_backup_service.dart';
export 'services/browser_import_service.dart';
export 'services/contest_record_service.dart';
export 'services/daily_summary_service.dart';
export 'services/heatmap_service.dart';
export 'services/home_action_service.dart';
export 'services/local_store.dart';
export 'services/oj_controller.dart';
export 'services/problem_database.dart';
export 'services/problem_book_service.dart';
export 'services/refresh_service.dart';
export 'services/sync_secret_store.dart';
export 'services/sync_service.dart';
export 'services/teammate_service.dart';
export 'services/training_service.dart';
export 'services/window_shell_service.dart';
export 'ui/dashboard/oj_float_home.dart';
export 'ui/dashboard/oj_tile.dart';
export 'ui/dashboard/home_summary_view_model.dart';
export 'ui/contests/contest_editor.dart';
export 'ui/contests/contests_page.dart';
export 'ui/heatmap/heatmap_dialog.dart';
export 'ui/heatmap/heatmap_page.dart';
export 'ui/problems/problem_editor.dart';
export 'ui/problems/problems_page.dart';
export 'ui/settings/settings_page.dart';
export 'ui/teammates/teammate_editor.dart';
export 'ui/teammates/teammates_page.dart';
export 'ui/training/training_page.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig? initialConfig;
  var startHidden = false;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    initialConfig = await LocalStore().loadConfig();
    startHidden = shouldStartHidden(arguments, initialConfig);
    final options = WindowOptions(
      size: appWindowSize,
      minimumSize: appMinimumWindowSize,
      center: true,
      title: AppLabels.appTitle,
      titleBarStyle: TitleBarStyle.normal,
      backgroundColor: appPaletteFor(initialConfig.colorTheme).surface,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      // All close requests are routed through the app so unsaved settings can
      // be confirmed before the window exits or hides to the tray.
      await windowManager.setPreventClose(true);
      if (!startHidden) {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  runApp(OjFloatApp(
    initialConfig: initialConfig,
    startHidden: startHidden,
  ));
}

bool shouldStartHidden(List<String> arguments, AppConfig config) {
  return arguments.contains('--startup') &&
      config.closeToTray &&
      config.launchAtStartup;
}
