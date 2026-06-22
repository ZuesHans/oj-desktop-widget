import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _configKey = 'app_config_v1';
const _snapshotsFile = 'snapshots_v1.json';
const _refreshLogsFile = 'refresh_logs_v1.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('config storage hardening', () {
    test('damaged config JSON falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({_configKey: '{not-json'});

      final config = await LocalStore().loadConfig();

      expect(config.refreshIntervalMinutes, 60);
      expect(config.accounts.length, supportedOjs.length);
      expect(
          config.accounts.values.every((account) => !account.enabled), isTrue);
    });

    test('missing refreshIntervalMinutes falls back to 60', () {
      final config = AppConfig.fromJson({'accounts': <String, dynamic>{}});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('refreshIntervalMinutes of zero falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': 0});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('negative refreshIntervalMinutes falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': -1});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('refreshIntervalMinutes above 1440 falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': 1441});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('wrong refreshIntervalMinutes type falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': '60'});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('old username field is read as a single username', () {
      final config = AppConfig.fromJson({
        'accounts': {
          'codeforces': {'username': 'abc', 'enabled': true},
        },
      });

      expect(config.accounts['codeforces']!.usernames, ['abc']);
      expect(config.accounts['codeforces']!.enabled, isTrue);
    });

    test('new usernames field is read as multiple usernames', () {
      final config = AppConfig.fromJson({
        'accounts': {
          'codeforces': {
            'usernames': ['a', 'b'],
            'enabled': true,
          },
        },
      });

      expect(config.accounts['codeforces']!.usernames, ['a', 'b']);
      expect(config.accounts['codeforces']!.enabled, isTrue);
    });

    test('comma-separated usernames are normalized', () {
      final usernames = OjAccountConfig.normalizeUsernames(['a, b,,a']);

      expect(usernames, ['a', 'b']);
    });
  });

  group('snapshot storage hardening', () {
    test('damaged snapshot file falls back to an empty list', () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      try {
        await File('${directory.path}${Platform.pathSeparator}$_snapshotsFile')
            .writeAsString('{not-json');

        final snapshots =
            await LocalStore(supportDirectory: directory).loadSnapshots();

        expect(snapshots, isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('damaged snapshot entry is skipped while valid entries are kept',
        () async {
      final snapshots = await _loadSnapshotsFromJson([
        _validSnapshot(),
        {
          'date': '2026-06-15',
          'fetchedAt': 123,
          'ojId': 'codeforces',
          'status': 'success',
        },
        {
          'date': '2026-06-15',
          'fetchedAt': '2026-06-15T09:00:00.000',
          'status': 'success',
        },
      ]);

      expect(snapshots, hasLength(1));
      expect(snapshots.single.ojId, 'codeforces');
      expect(snapshots.single.solvedCount, 42);
    });

    test('snapshot with unknown status is skipped', () async {
      final snapshots = await _loadSnapshotsFromJson([
        _validSnapshot(status: 'mystery'),
      ]);

      expect(snapshots, isEmpty);
    });

    test('snapshot with invalid date is skipped', () async {
      final snapshots = await _loadSnapshotsFromJson([
        _validSnapshot(date: '2026-02-31'),
        _validSnapshot(ojId: 'leetcode'),
      ]);

      expect(snapshots, hasLength(1));
      expect(snapshots.single.ojId, 'leetcode');
    });

    test('snapshot missing username is kept with an empty username', () async {
      final snapshot = _validSnapshot()..remove('username');

      final snapshots = await _loadSnapshotsFromJson([snapshot]);

      expect(snapshots, hasLength(1));
      expect(snapshots.single.username, '');
    });
  });

  group('refresh log storage hardening', () {
    test('damaged refresh log file falls back to an empty list', () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      try {
        await File(
          '${directory.path}${Platform.pathSeparator}$_refreshLogsFile',
        ).writeAsString('{not-json');

        final logs =
            await LocalStore(supportDirectory: directory).loadRefreshLogs();

        expect(logs, isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('refresh logs keep only the latest 200 entries', () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      try {
        final store = LocalStore(supportDirectory: directory);
        final base = DateTime.parse('2026-06-15T08:00:00');
        await store.saveRefreshLogs([
          for (var i = 0; i < 205; i++)
            RefreshLogEntry.create(
              fetchedAt: base.add(Duration(minutes: i)),
              ojId: 'codeforces',
              username: 'alice',
              status: RefreshLogStatus.success,
              source: 'primary',
              message: 'ok $i',
              solvedCount: i,
            ),
        ]);

        final logs = await store.loadRefreshLogs();

        expect(logs, hasLength(200));
        expect(logs.first.solvedCount, 204);
        expect(logs.last.solvedCount, 5);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  test('parse failure logs do not include raw sensitive JSON content',
      () async {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        logs.add(message);
      }
    };

    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    try {
      const damagedConfig =
          '{"accounts":{"codeforces":{"username":"secret_user_123"}}';
      const damagedSnapshots =
          '[{"username":"secret_user_123","error":"private failure text"';
      SharedPreferences.setMockInitialValues({_configKey: damagedConfig});
      await File('${directory.path}${Platform.pathSeparator}$_snapshotsFile')
          .writeAsString(damagedSnapshots);

      await LocalStore().loadConfig();
      await LocalStore(supportDirectory: directory).loadSnapshots();

      final joinedLogs = logs.join('\n');
      expect(joinedLogs, isNot(contains('secret_user_123')));
      expect(joinedLogs, isNot(contains(damagedConfig)));
      expect(joinedLogs, isNot(contains(damagedSnapshots)));
      expect(joinedLogs, isNot(contains('private failure text')));
    } finally {
      debugPrint = originalDebugPrint;
      await directory.delete(recursive: true);
    }
  });
}

Future<List<SolvedSnapshot>> _loadSnapshotsFromJson(
    List<Object?> entries) async {
  final directory = await Directory.systemTemp.createTemp('oj_float_test_');
  try {
    await File('${directory.path}${Platform.pathSeparator}$_snapshotsFile')
        .writeAsString(jsonEncode(entries));

    return await LocalStore(supportDirectory: directory).loadSnapshots();
  } finally {
    await directory.delete(recursive: true);
  }
}

Map<String, Object?> _validSnapshot({
  String date = '2026-06-15',
  String status = 'success',
  String ojId = 'codeforces',
}) {
  return {
    'date': date,
    'fetchedAt': '2026-06-15T08:00:00.000',
    'ojId': ojId,
    'username': 'alice',
    'status': status,
    'solvedCount': 42,
    'error': null,
  };
}
