import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app/oj_float_app.dart';
import 'services/local_store.dart';
import 'ui/app_theme.dart';

export 'app/app_display_mode.dart';
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
export 'platform/startup_service.dart';
export 'providers/atcoder_provider.dart';
export 'providers/codeforces_provider.dart';
export 'providers/leetcode_provider.dart';
export 'providers/luogu_provider.dart';
export 'providers/nowcoder_provider.dart';
export 'providers/oj_provider.dart';
export 'services/backup_service.dart';
export 'services/contest_record_service.dart';
export 'services/daily_summary_service.dart';
export 'services/heatmap_service.dart';
export 'services/local_store.dart';
export 'services/oj_controller.dart';
export 'services/problem_book_service.dart';
export 'services/refresh_service.dart';
export 'services/sync_secret_store.dart';
export 'services/sync_service.dart';
export 'services/teammate_service.dart';
export 'ui/dashboard/oj_float_home.dart';
export 'ui/contests/contest_editor.dart';
export 'ui/contests/contests_page.dart';
export 'ui/heatmap/heatmap_dialog.dart';
export 'ui/heatmap/heatmap_page.dart';
export 'ui/problems/problem_editor.dart';
export 'ui/problems/problems_page.dart';
export 'ui/settings/settings_dialog.dart';
export 'ui/teammates/teammate_editor.dart';
export 'ui/teammates/teammates_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final initialConfig = await LocalStore().loadConfig();
    final options = WindowOptions(
      size: compactWindowSize,
      minimumSize: compactMinimumWindowSize,
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
