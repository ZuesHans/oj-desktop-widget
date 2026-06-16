import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('portable backup JSON includes metadata and config accounts', () {
    final jsonText = buildPortableBackupJson(
      config: _config(),
      snapshots: [_snapshot('2026-06-16', 'alice', 42)],
      exportedAt: DateTime.parse('2026-06-18T21:30:00'),
    );

    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    expect(data['schemaVersion'], 1);
    expect(data['app'], 'oj_float');
    expect(data['exportType'], 'portable_backup');
    expect(data['exportedAt'], '2026-06-18T21:30:00.000');

    final config = data['config'] as Map<String, dynamic>;
    expect(config['refreshIntervalMinutes'], 45);
    final accounts = config['accounts'] as List<dynamic>;
    final codeforces = accounts.cast<Map<String, dynamic>>().firstWhere(
          (account) => account['ojId'] == 'codeforces',
        );
    expect(codeforces['enabled'], isTrue);
    expect(codeforces['usernames'], ['alice', 'bob']);
  });

  test('portable backup JSON keeps multiple raw snapshots including failure',
      () {
    final jsonText = buildPortableBackupJson(
      config: _config(),
      snapshots: [
        _snapshot('2026-06-16', 'alice', 10, hour: 8),
        _snapshot('2026-06-16', 'alice', 13, hour: 20),
        _failureSnapshot('2026-06-16', 'bob'),
      ],
      exportedAt: DateTime.parse('2026-06-18T21:30:00'),
    );

    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    final snapshots = data['snapshots'] as List<dynamic>;
    expect(snapshots, hasLength(3));
    expect(
      snapshots.cast<Map<String, dynamic>>().map((item) => item['status']),
      contains('failure'),
    );
  });

  test('portable backup dailyStats are sorted and omit failure details', () {
    final jsonText = buildPortableBackupJson(
      config: _config(),
      snapshots: [
        _snapshot('2026-06-17', 'alice', 20, hour: 8),
        _snapshot('2026-06-17', 'alice', 22, hour: 20),
        _failureSnapshot('2026-06-18', 'alice'),
        _snapshot('2026-06-16', 'alice', 10, hour: 8),
        _snapshot('2026-06-16', 'alice', 13, hour: 20),
      ],
      exportedAt: DateTime.parse('2026-06-18T21:30:00'),
    );

    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    final dailyStats =
        (data['dailyStats'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(dailyStats.map((item) => item['date']), [
      '2026-06-16',
      '2026-06-17',
    ]);
    expect(dailyStats.first['totalDelta'], 3);
    expect(dailyStats.first['active'], isTrue);
    expect(dailyStats.any((item) => item.containsKey('status')), isFalse);
    expect(dailyStats.any((item) => item.containsKey('error')), isFalse);
  });

  test('empty snapshots still export a valid portable backup JSON', () {
    final jsonText = buildPortableBackupJson(
      config: _config(),
      snapshots: const [],
      exportedAt: DateTime.parse('2026-06-18T21:30:00'),
    );

    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    expect(data['snapshots'], isEmpty);
    expect(data['dailyStats'], isEmpty);
    expect(data['config'], isA<Map<String, dynamic>>());
  });

  test('daily summary CSV keeps the auxiliary header and rows', () {
    final csv = buildDailySummaryCsv([
      _snapshot('2026-06-16', 'alice', 10, hour: 8),
      _snapshot('2026-06-16', 'alice', 13, hour: 20),
    ]);

    expect(csv, startsWith('date,totalDelta,active\n'));
    expect(csv, contains('2026-06-16,3,true'));
  });

  test('export file name includes timestamp', () {
    final name = buildExportFileName(
      'oj_float_backup',
      'json',
      DateTime.parse('2026-06-18T21:30:00'),
    );

    expect(name, 'oj_float_backup_20260618_2130.json');
  });

  test('export writes portable backup JSON and daily summary CSV', () async {
    final directory = await Directory.systemTemp.createTemp('oj_export_test_');
    try {
      final result = await exportOjData(
        config: _config(),
        snapshots: [
          _snapshot('2026-06-16', 'alice', 10, hour: 8),
          _snapshot('2026-06-16', 'alice', 13, hour: 20),
        ],
        now: DateTime.parse('2026-06-18T21:30:00'),
        directory: directory,
      );

      expect(await result.backupFile.exists(), isTrue);
      expect(await result.dailySummaryFile.exists(), isTrue);
      expect(
        result.backupFile.path,
        contains('oj_float_backup_20260618_2130.json'),
      );
      expect(
        result.dailySummaryFile.path,
        contains('oj_float_daily_summary_20260618_2130.csv'),
      );
      expect(
        await result.dailySummaryFile.readAsString(),
        contains('2026-06-16,3,true'),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

AppConfig _config() {
  return AppConfig(
    refreshIntervalMinutes: 45,
    accounts: {
      for (final meta in supportedOjs)
        meta.id: meta.id == 'codeforces'
            ? const OjAccountConfig(
                usernames: ['alice', 'bob'],
                enabled: true,
              )
            : const OjAccountConfig(usernames: [], enabled: false),
    },
  );
}

SolvedSnapshot _snapshot(
  String date,
  String username,
  int solvedCount, {
  int hour = 8,
}) {
  return SolvedSnapshot(
    date: date,
    fetchedAt: DateTime.parse(
      '${date}T${hour.toString().padLeft(2, '0')}:00:00',
    ),
    ojId: 'codeforces',
    username: username,
    status: FetchStatus.success,
    solvedCount: solvedCount,
  );
}

SolvedSnapshot _failureSnapshot(String date, String username) {
  return SolvedSnapshot(
    date: date,
    fetchedAt: DateTime.parse('${date}T12:00:00'),
    ojId: 'codeforces',
    username: username,
    status: FetchStatus.failure,
    error: 'network',
  );
}
