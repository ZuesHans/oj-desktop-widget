import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

part 'app/app_display_mode.dart';
part 'app/oj_float_app.dart';
part 'ui/dashboard/oj_float_home.dart';
part 'ui/compact/compact_widget.dart';
part 'ui/dashboard/window_header.dart';
part 'ui/dashboard/summary_panel.dart';
part 'ui/heatmap/heatmap_entry_panel.dart';
part 'ui/heatmap/heatmap_page.dart';
part 'ui/heatmap/heatmap_dialog.dart';
part 'ui/heatmap/heatmap_formatters.dart';
part 'ui/problems/problems_entry_panel.dart';
part 'ui/problems/problems_page.dart';
part 'ui/problems/problem_editor.dart';
part 'ui/dashboard/oj_tile.dart';
part 'ui/dashboard/daily_panel.dart';
part 'ui/shared/pill.dart';
part 'ui/settings/settings_dialog.dart';
part 'services/oj_controller.dart';
part 'services/refresh_service.dart';
part 'platform/startup_service.dart';
part 'providers/oj_provider.dart';
part 'providers/codeforces_provider.dart';
part 'providers/leetcode_provider.dart';
part 'providers/atcoder_provider.dart';
part 'providers/luogu_provider.dart';
part 'providers/nowcoder_provider.dart';
part 'services/local_store.dart';
part 'services/backup_service.dart';
part 'models/oj_meta.dart';
part 'models/app_config.dart';
part 'models/fetch_result.dart';
part 'models/solved_snapshot.dart';
part 'models/problem_record.dart';
part 'services/daily_summary_service.dart';
part 'services/heatmap_service.dart';
part 'services/problem_book_service.dart';
part 'models/oj_state.dart';
part 'core/errors.dart';
part 'core/http_client.dart';
part 'core/solved_totals.dart';
part 'core/time.dart';

const supportedOjs = <OjMeta>[
  OjMeta(
    id: 'codeforces',
    name: 'Codeforces',
    hint: 'handle',
    profileBaseUrl: 'https://codeforces.com/profile/',
  ),
  OjMeta(
    id: 'leetcode',
    name: 'LeetCode',
    hint: 'username',
    profileBaseUrl: 'https://leetcode.com/',
  ),
  OjMeta(
    id: 'atcoder',
    name: 'AtCoder',
    hint: 'username',
    profileBaseUrl: 'https://atcoder.jp/users/',
  ),
  OjMeta(
    id: 'luogu',
    name: '洛谷',
    hint: '数字 UID',
    profileBaseUrl: 'https://www.luogu.com.cn/user/',
  ),
  OjMeta(
    id: 'nowcoder',
    name: '牛客',
    hint: '数字用户 ID',
    profileBaseUrl: 'https://www.nowcoder.com/users/',
  ),
];

const _compactWindowSize = Size(220, 148);
const _compactMinimumWindowSize = Size(200, 132);
const _dashboardWindowSize = Size(360, 520);
const _dashboardMinimumWindowSize = Size(320, 420);
const _heatmapWindowSize = Size(560, 560);
const _heatmapMinimumWindowSize = Size(440, 420);
const _appSurfaceColor = Color(0xFFF6F7F4);
const _cardColor = Color(0xFFFFFFFF);
const _cardMutedColor = Color(0xFFF4F6F3);
const _borderColor = Color(0xFFE1E4DE);
const _textPrimaryColor = Color(0xFF17211D);
const _textSecondaryColor = Color(0xFF64706A);
const _accentColor = Color(0xFF2F6F4E);
const _dangerColor = Color(0xFFB3261E);
final _heatmapDefaultStartDate = DateTime(2026, 6, 1);
const _heatmapLevelColors = <Color>[
  Color(0xFFEFF3EF),
  Color(0xFF9BE9A8),
  Color(0xFF40C463),
  Color(0xFF30A14E),
  Color(0xFF216E39),
];
