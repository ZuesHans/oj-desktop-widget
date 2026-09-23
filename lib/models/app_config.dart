import 'package:flutter/foundation.dart';

import '../core/oj_catalog.dart';
import 'quick_entry_shortcut.dart';

const defaultDashboardModules = <DashboardModule>[
  DashboardModule.summary,
  DashboardModule.training,
  DashboardModule.heatmap,
  DashboardModule.problems,
  DashboardModule.refreshLogs,
  DashboardModule.contests,
  DashboardModule.teammates,
  DashboardModule.ojAccounts,
  DashboardModule.daily,
];

const currentAppConfigVersion = 3;

enum DashboardModule {
  summary('summary'),
  training('training'),
  heatmap('heatmap'),
  problems('problems'),
  refreshLogs('refreshLogs'),
  contests('contests'),
  teammates('teammates'),
  ojAccounts('ojAccounts'),
  daily('daily');

  const DashboardModule(this.id);

  final String id;
}

enum AppColorTheme {
  githubLight('githubLight'),
  terminalDark('terminalDark'),
  classic('classic'),
  dark('dark'),
  candy('candy');

  const AppColorTheme(this.id);

  final String id;
}

class AppConfig {
  const AppConfig({
    required this.refreshIntervalMinutes,
    required this.accounts,
    this.configVersion = currentAppConfigVersion,
    this.dashboardModules = defaultDashboardModules,
    this.colorTheme = AppColorTheme.classic,
    this.sync = const SyncConfig(),
    this.automaticBackup = const AutomaticBackupConfig(),
    this.launchAtStartup = false,
    this.closeToTray = false,
    this.quickEntryHotkey = 'Ctrl+Shift+O',
  });

  factory AppConfig.defaults() {
    return AppConfig(
      refreshIntervalMinutes: 60,
      launchAtStartup: false,
      closeToTray: false,
      sync: const SyncConfig(),
      automaticBackup: const AutomaticBackupConfig(),
      dashboardModules: defaultDashboardModules,
      colorTheme: AppColorTheme.classic,
      accounts: {
        for (final meta in supportedOjs)
          meta.id: const OjAccountConfig(usernames: [], enabled: false),
      },
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    final storedVersion =
        json['configVersion'] is int ? json['configVersion'] as int : 1;
    final isLegacyFloatingConfig = storedVersion < 2;
    return AppConfig(
      configVersion: currentAppConfigVersion,
      refreshIntervalMinutes: _parseRefreshInterval(
        json['refreshIntervalMinutes'],
      ),
      launchAtStartup:
          !isLegacyFloatingConfig && json['launchAtStartup'] is bool
              ? json['launchAtStartup'] as bool
              : false,
      closeToTray: !isLegacyFloatingConfig && json['closeToTray'] is bool
          ? json['closeToTray'] as bool
          : false,
      sync: SyncConfig.fromJson(json['sync']),
      automaticBackup: AutomaticBackupConfig.fromJson(
        json['automaticBackup'],
      ),
      dashboardModules: _parseDashboardModules(json['dashboardModules']),
      colorTheme: _parseColorTheme(json['colorTheme']),
      quickEntryHotkey: _parseQuickEntryHotkey(json['quickEntryHotkey']),
      accounts: {
        for (final meta in supportedOjs)
          meta.id: _parseAccountConfig(
            rawAccounts is Map ? rawAccounts[meta.id] : null,
          ),
      },
    );
  }

  factory AppConfig.fromPortableJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    if (rawAccounts is! List) {
      throw const FormatException('备份配置中的账号必须是数组。');
    }
    final accounts = {
      for (final meta in supportedOjs)
        meta.id: const OjAccountConfig(usernames: [], enabled: false),
    };
    for (final item in rawAccounts) {
      if (item is! Map) {
        throw const FormatException('备份账号条目必须是对象。');
      }
      final accountJson = Map<String, dynamic>.from(item);
      final ojId = accountJson['ojId'];
      if (ojId is! String || ojId.isEmpty) {
        throw const FormatException('备份账号的 OJ ID 无效。');
      }
      if (!accounts.containsKey(ojId)) {
        continue;
      }
      accounts[ojId] = OjAccountConfig.fromJson(accountJson);
    }
    return AppConfig(
      configVersion: currentAppConfigVersion,
      refreshIntervalMinutes: _parseRefreshInterval(
        json['refreshIntervalMinutes'],
      ),
      launchAtStartup: false,
      closeToTray: false,
      sync: const SyncConfig(),
      automaticBackup: const AutomaticBackupConfig(),
      dashboardModules: _parseDashboardModules(json['dashboardModules']),
      colorTheme: _parseColorTheme(json['colorTheme']),
      quickEntryHotkey: _parseQuickEntryHotkey(json['quickEntryHotkey']),
      accounts: accounts,
    );
  }

  static int _parseRefreshInterval(Object? value) {
    if (value is! int || value < 15 || value > 1440) {
      return 60;
    }
    return value;
  }

  static OjAccountConfig _parseAccountConfig(Object? value) {
    if (value is! Map) {
      return const OjAccountConfig(usernames: [], enabled: false);
    }
    try {
      return OjAccountConfig.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      debugPrint('解析 OJ 账号配置失败，已使用默认值。');
      return const OjAccountConfig(usernames: [], enabled: false);
    }
  }

  static List<DashboardModule> _parseDashboardModules(Object? value) {
    if (value == null) {
      return List.unmodifiable(defaultDashboardModules);
    }
    final parsed = <DashboardModule>[];
    if (value is List) {
      for (final item in value) {
        if (item is! String) {
          continue;
        }
        final module = _dashboardModuleFromId(item);
        if (module != null && !parsed.contains(module)) {
          parsed.add(module);
        }
      }
    }
    return List.unmodifiable(parsed);
  }

  static DashboardModule? _dashboardModuleFromId(String id) {
    for (final module in DashboardModule.values) {
      if (module.id == id) {
        return module;
      }
    }
    return null;
  }

  static String _parseQuickEntryHotkey(Object? value) => value is String
      ? QuickEntryShortcut.parse(value)?.label ??
          QuickEntryShortcut.defaultLabel
      : QuickEntryShortcut.defaultLabel;

  static AppColorTheme _parseColorTheme(Object? value) {
    if (value == 'ocean' || value == 'rose') return AppColorTheme.githubLight;
    if (value is String) {
      for (final theme in AppColorTheme.values) {
        if (theme.id == value) {
          return theme;
        }
      }
    }
    return AppColorTheme.classic;
  }

  final int configVersion;
  final int refreshIntervalMinutes;
  final Map<String, OjAccountConfig> accounts;
  final List<DashboardModule> dashboardModules;
  final AppColorTheme colorTheme;
  final bool launchAtStartup;
  final bool closeToTray;
  final String quickEntryHotkey;
  final SyncConfig sync;
  final AutomaticBackupConfig automaticBackup;

  AppConfig copyWith({
    int? configVersion,
    int? refreshIntervalMinutes,
    Map<String, OjAccountConfig>? accounts,
    List<DashboardModule>? dashboardModules,
    AppColorTheme? colorTheme,
    bool? launchAtStartup,
    bool? closeToTray,
    String? quickEntryHotkey,
    SyncConfig? sync,
    AutomaticBackupConfig? automaticBackup,
  }) {
    return AppConfig(
      configVersion: configVersion ?? this.configVersion,
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      accounts: accounts ?? this.accounts,
      dashboardModules: dashboardModules ?? this.dashboardModules,
      colorTheme: colorTheme ?? this.colorTheme,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      closeToTray: closeToTray ?? this.closeToTray,
      quickEntryHotkey: quickEntryHotkey ?? this.quickEntryHotkey,
      sync: sync ?? this.sync,
      automaticBackup: automaticBackup ?? this.automaticBackup,
    );
  }

  Map<String, dynamic> toJson() => {
        'configVersion': currentAppConfigVersion,
        'refreshIntervalMinutes': refreshIntervalMinutes,
        'launchAtStartup': launchAtStartup,
        'closeToTray': closeToTray,
        'quickEntryHotkey': quickEntryHotkey,
        'dashboardModules':
            dashboardModules.map((module) => module.id).toList(),
        'colorTheme': colorTheme.id,
        'sync': sync.toJson(),
        'automaticBackup': automaticBackup.toJson(),
        'accounts': {
          for (final entry in accounts.entries) entry.key: entry.value.toJson(),
        },
      };
}

class AutomaticBackupConfig {
  const AutomaticBackupConfig({
    this.enabled = false,
    this.timeMinutes = 22 * 60,
    this.directoryPath = '',
  });

  factory AutomaticBackupConfig.fromJson(Object? value) {
    if (value is! Map) {
      return const AutomaticBackupConfig();
    }
    final json = Map<String, dynamic>.from(value);
    final rawTime = json['timeMinutes'];
    final timeMinutes =
        rawTime is int && rawTime >= 0 && rawTime < 24 * 60 ? rawTime : 22 * 60;
    return AutomaticBackupConfig(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      timeMinutes: timeMinutes,
      directoryPath: json['directoryPath'] is String
          ? (json['directoryPath'] as String).trim()
          : '',
    );
  }

  final bool enabled;
  final int timeMinutes;
  final String directoryPath;

  AutomaticBackupConfig copyWith({
    bool? enabled,
    int? timeMinutes,
    String? directoryPath,
  }) {
    return AutomaticBackupConfig(
      enabled: enabled ?? this.enabled,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      directoryPath: directoryPath?.trim() ?? this.directoryPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'timeMinutes': timeMinutes,
        'directoryPath': directoryPath,
      };
}

class SyncConfig {
  const SyncConfig({
    this.enabled = false,
    this.endpointUrl = '',
    this.syncDailyStats = true,
    this.syncProblems = true,
    this.includeProblemNote = false,
    this.includeProblemAnalysis = false,
    this.autoSyncAfterRefresh = true,
  });

  factory SyncConfig.fromJson(Object? value) {
    if (value is! Map) {
      return const SyncConfig();
    }
    final json = Map<String, dynamic>.from(value);
    return SyncConfig(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      endpointUrl:
          json['endpointUrl'] is String ? json['endpointUrl'] as String : '',
      syncDailyStats: json['syncDailyStats'] is bool
          ? json['syncDailyStats'] as bool
          : true,
      syncProblems:
          json['syncProblems'] is bool ? json['syncProblems'] as bool : true,
      includeProblemNote: json['includeProblemNote'] is bool
          ? json['includeProblemNote'] as bool
          : false,
      includeProblemAnalysis: json['includeProblemAnalysis'] is bool
          ? json['includeProblemAnalysis'] as bool
          : false,
      autoSyncAfterRefresh: json['autoSyncAfterRefresh'] is bool
          ? json['autoSyncAfterRefresh'] as bool
          : true,
    );
  }

  final bool enabled;
  final String endpointUrl;
  final bool syncDailyStats;
  final bool syncProblems;
  final bool includeProblemNote;
  final bool includeProblemAnalysis;
  final bool autoSyncAfterRefresh;

  SyncConfig copyWith({
    bool? enabled,
    String? endpointUrl,
    bool? syncDailyStats,
    bool? syncProblems,
    bool? includeProblemNote,
    bool? includeProblemAnalysis,
    bool? autoSyncAfterRefresh,
  }) {
    return SyncConfig(
      enabled: enabled ?? this.enabled,
      endpointUrl: endpointUrl?.trim() ?? this.endpointUrl,
      syncDailyStats: syncDailyStats ?? this.syncDailyStats,
      syncProblems: syncProblems ?? this.syncProblems,
      includeProblemNote: includeProblemNote ?? this.includeProblemNote,
      includeProblemAnalysis:
          includeProblemAnalysis ?? this.includeProblemAnalysis,
      autoSyncAfterRefresh: autoSyncAfterRefresh ?? this.autoSyncAfterRefresh,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'endpointUrl': endpointUrl,
        'syncDailyStats': syncDailyStats,
        'syncProblems': syncProblems,
        'includeProblemNote': includeProblemNote,
        'includeProblemAnalysis': includeProblemAnalysis,
        'autoSyncAfterRefresh': autoSyncAfterRefresh,
      };
}

class OjAccountConfig {
  const OjAccountConfig({required this.usernames, required this.enabled});

  factory OjAccountConfig.fromJson(Map<String, dynamic> json) {
    final rawUsernames =
        json.containsKey('usernames') ? json['usernames'] : json['username'];
    return OjAccountConfig(
      usernames: _parseUsernames(rawUsernames),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
    );
  }

  static List<String> normalizeUsernames(Iterable<Object?> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      if (value is! String) {
        continue;
      }
      for (final item in value.split(',')) {
        final username = item.trim();
        if (username.isNotEmpty && seen.add(username)) {
          normalized.add(username);
        }
      }
    }
    return List.unmodifiable(normalized);
  }

  static List<String> _parseUsernames(Object? value) {
    if (value is List) {
      return normalizeUsernames(value);
    }
    if (value is String) {
      return normalizeUsernames([value]);
    }
    return const [];
  }

  final List<String> usernames;
  final bool enabled;

  Map<String, dynamic> toJson() => {
        'usernames': usernames,
        'enabled': enabled,
      };
}
