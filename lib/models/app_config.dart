import 'package:flutter/foundation.dart';

import '../core/oj_catalog.dart';

class AppConfig {
  const AppConfig({
    required this.refreshIntervalMinutes,
    required this.accounts,
    this.launchAtStartup = false,
    this.alwaysOnTop = true,
    this.showInTaskbar = true,
    this.closeToTray = true,
  });

  factory AppConfig.defaults() {
    return AppConfig(
      refreshIntervalMinutes: 60,
      launchAtStartup: false,
      alwaysOnTop: true,
      showInTaskbar: true,
      closeToTray: true,
      accounts: {
        for (final meta in supportedOjs)
          meta.id: const OjAccountConfig(usernames: [], enabled: false),
      },
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    return AppConfig(
      refreshIntervalMinutes: _parseRefreshInterval(
        json['refreshIntervalMinutes'],
      ),
      launchAtStartup: json['launchAtStartup'] is bool
          ? json['launchAtStartup'] as bool
          : false,
      alwaysOnTop:
          json['alwaysOnTop'] is bool ? json['alwaysOnTop'] as bool : true,
      showInTaskbar:
          json['showInTaskbar'] is bool ? json['showInTaskbar'] as bool : true,
      closeToTray:
          json['closeToTray'] is bool ? json['closeToTray'] as bool : true,
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
      throw const FormatException('Backup config.accounts must be an array.');
    }
    final accounts = {
      for (final meta in supportedOjs)
        meta.id: const OjAccountConfig(usernames: [], enabled: false),
    };
    for (final item in rawAccounts) {
      if (item is! Map) {
        throw const FormatException('Backup account entry must be an object.');
      }
      final accountJson = Map<String, dynamic>.from(item);
      final ojId = accountJson['ojId'];
      if (ojId is! String || ojId.isEmpty) {
        throw const FormatException('Backup account ojId is invalid.');
      }
      if (!accounts.containsKey(ojId)) {
        continue;
      }
      accounts[ojId] = OjAccountConfig.fromJson(accountJson);
    }
    return AppConfig(
      refreshIntervalMinutes: _parseRefreshInterval(
        json['refreshIntervalMinutes'],
      ),
      launchAtStartup: json['launchAtStartup'] is bool
          ? json['launchAtStartup'] as bool
          : false,
      alwaysOnTop:
          json['alwaysOnTop'] is bool ? json['alwaysOnTop'] as bool : true,
      showInTaskbar:
          json['showInTaskbar'] is bool ? json['showInTaskbar'] as bool : true,
      closeToTray:
          json['closeToTray'] is bool ? json['closeToTray'] as bool : true,
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
      debugPrint('Failed to parse OJ account config. Using defaults.');
      return const OjAccountConfig(usernames: [], enabled: false);
    }
  }

  final int refreshIntervalMinutes;
  final Map<String, OjAccountConfig> accounts;
  final bool launchAtStartup;
  final bool alwaysOnTop;
  final bool showInTaskbar;
  final bool closeToTray;

  AppConfig copyWith({
    int? refreshIntervalMinutes,
    Map<String, OjAccountConfig>? accounts,
    bool? launchAtStartup,
    bool? alwaysOnTop,
    bool? showInTaskbar,
    bool? closeToTray,
  }) {
    return AppConfig(
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      accounts: accounts ?? this.accounts,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      showInTaskbar: showInTaskbar ?? this.showInTaskbar,
      closeToTray: closeToTray ?? this.closeToTray,
    );
  }

  Map<String, dynamic> toJson() => {
        'refreshIntervalMinutes': refreshIntervalMinutes,
        'launchAtStartup': launchAtStartup,
        'alwaysOnTop': alwaysOnTop,
        'showInTaskbar': showInTaskbar,
        'closeToTray': closeToTray,
        'accounts': {
          for (final entry in accounts.entries) entry.key: entry.value.toJson(),
        },
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
