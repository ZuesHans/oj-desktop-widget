import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';

void main() {
  test('training date switches at 04:00', () {
    expect(
      trainingDateFor(DateTime.parse('2026-07-10T03:59:00')),
      '2026-07-09',
    );
    expect(
      trainingDateFor(DateTime.parse('2026-07-10T04:00:00')),
      '2026-07-10',
    );
    expect(
      isSameTrainingDate(
        DateTime.parse('2026-07-10T03:59:00'),
        DateTime.parse('2026-07-09T22:00:00'),
      ),
      isTrue,
    );
    expect(
      shouldAutoRefreshTeammates(
        DateTime.parse('2026-07-10T04:01:00'),
        '2026-07-09',
      ),
      isTrue,
    );
  });

  test('teammate validation enforces max count and enabled account', () {
    final service = _service(const {});
    final data = TeammateStoreData(
      profiles: [
        _teammate('a', 'Ann'),
        _teammate('b', 'Bob'),
        _teammate('c', 'Cat'),
      ],
    );

    expect(
      () => service.addTeammate(data, _teammate('d', 'Dan')),
      throwsA(isA<FetchException>()),
    );
    expect(
      () => service.addTeammate(
        const TeammateStoreData(),
        TeammateProfile.create(
          id: 'x',
          nickname: 'No Account',
          accounts: const [
            TeammateAccount(
              platform: 'codeforces',
              handle: 'x',
              enabled: false,
            ),
          ],
          now: DateTime.parse('2026-07-10T12:00:00'),
        ),
      ),
      throwsA(isA<FetchException>()),
    );
    service.dispose();
  });

  test('first refresh creates baseline then second refresh computes delta',
      () async {
    final provider = _FakeProvider({
      'alice': [
        const OjProfile(solvedCount: 100, profileUrl: 'https://example.test/a'),
        const OjProfile(solvedCount: 104, profileUrl: 'https://example.test/a'),
      ],
    });
    final service = _service({'codeforces': provider});
    var data = TeammateStoreData(profiles: [_teammate('t1', 'Alice')]);

    data = await service.refreshTeammate(
      data,
      't1',
      now: DateTime.parse('2026-07-10T05:00:00'),
    );
    expect(data.snapshots.single.solvedTotalAtStart, 100);
    expect(data.records.single.totalDelta, 0);

    data = await service.refreshTeammate(
      data,
      't1',
      now: DateTime.parse('2026-07-10T20:00:00'),
    );
    expect(data.snapshots.single.solvedTotalAtStart, 100);
    expect(data.snapshots.single.latestSolvedTotal, 104);
    expect(data.records.single.totalDelta, 4);
    service.dispose();
  });

  test('solved count decrease does not produce negative delta', () async {
    final service = _service({
      'codeforces': _FakeProvider({
        'alice': [
          const OjProfile(solvedCount: 100, profileUrl: ''),
          const OjProfile(solvedCount: 96, profileUrl: ''),
        ],
      }),
    });
    var data = TeammateStoreData(profiles: [_teammate('t1', 'Alice')]);

    data = await service.refreshTeammate(
      data,
      't1',
      now: DateTime.parse('2026-07-10T05:00:00'),
    );
    data = await service.refreshTeammate(
      data,
      't1',
      now: DateTime.parse('2026-07-10T20:00:00'),
    );

    expect(data.records.single.totalDelta, 0);
    service.dispose();
  });

  test('records outside recent 7 training days are trimmed', () {
    final data = trimTeammateStoreData(
      TeammateStoreData(
        profiles: [_teammate('t1', 'Alice')],
        records: [
          _record('t1', '2026-07-10', 3),
          _record('t1', '2026-07-03', 9),
        ],
        snapshots: [
          _snapshot('t1', '2026-07-10'),
          _snapshot('t1', '2026-07-03'),
        ],
      ),
      now: DateTime.parse('2026-07-10T12:00:00'),
    );

    expect(data.records.map((record) => record.trainingDate), ['2026-07-10']);
    expect(data.snapshots.map((snapshot) => snapshot.trainingDate), [
      '2026-07-10',
    ]);
  });

  test('ranking sorts by daily delta descending then nickname', () {
    final service = _service(const {});
    final data = TeammateStoreData(
      profiles: [
        _teammate('a', 'Ann'),
        _teammate('b', 'Bob'),
        _teammate('c', 'Cal'),
      ],
      records: [
        _record('a', '2026-07-10', 5),
        _record('b', '2026-07-10', 7),
        _record('c', '2026-07-10', 7),
      ],
    );

    final ranking = service.rankingForDate(data, '2026-07-10');

    expect(
        ranking.map((entry) => entry.profile.nickname), ['Bob', 'Cal', 'Ann']);
    service.dispose();
  });

  test('single platform failure keeps other platform record', () async {
    final service = _service({
      'codeforces': _FakeProvider({
        'alice': const OjProfile(solvedCount: 10, profileUrl: ''),
      }),
      'leetcode': _FakeProvider({'alice-lc': FetchException('broken')}),
    });
    var data = TeammateStoreData(
      profiles: [
        _teammate(
          't1',
          'Alice',
          accounts: const [
            TeammateAccount(platform: 'codeforces', handle: 'alice'),
            TeammateAccount(platform: 'leetcode', handle: 'alice-lc'),
          ],
        ),
      ],
    );

    data = await service.refreshTeammate(
      data,
      't1',
      now: DateTime.parse('2026-07-10T05:00:00'),
    );

    expect(data.records.single.perPlatformDelta['codeforces'], 0);
    expect(data.records.single.errors['leetcode'], 'broken');
    expect(data.snapshots.map((snapshot) => snapshot.platform), ['codeforces']);
    service.dispose();
  });

  test('backup export includes teammates and old backup import is compatible',
      () {
    final exported = buildPortableBackupJson(
      config: _config(),
      snapshots: const [],
      teammates: TeammateStoreData(
        profiles: [_teammate('t1', 'Alice')],
        records: [_record('t1', '2026-07-10', 2)],
        snapshots: [_snapshot('t1', '2026-07-10')],
      ),
      exportedAt: DateTime.parse('2026-07-10T12:00:00'),
    );
    final data = jsonDecode(exported) as Map<String, dynamic>;
    expect(data['teammates'], isA<Map<String, dynamic>>());
    expect(
        (data['teammates'] as Map<String, dynamic>)['profiles'], hasLength(1));

    data.remove('teammates');
    final parsed = parsePortableBackupJson(jsonEncode(data));
    expect(parsed.teammates.profiles, isEmpty);
  });

  test('backup import trims teammates by exportedAt instead of restore date',
      () {
    final exported = buildPortableBackupJson(
      config: _config(),
      snapshots: const [],
      teammates: TeammateStoreData(
        profiles: [_teammate('t1', 'Alice')],
        records: [
          _record('t1', '2026-07-10', 2),
          _record('t1', '2026-07-03', 9),
        ],
        snapshots: [
          _snapshot('t1', '2026-07-10'),
          _snapshot('t1', '2026-07-03'),
        ],
      ),
      exportedAt: DateTime.parse('2026-07-10T12:00:00'),
    );

    final parsed = parsePortableBackupJson(exported);

    expect(parsed.teammates.records.map((record) => record.trainingDate), [
      '2026-07-10',
    ]);
    expect(
        parsed.teammates.snapshots.map((snapshot) => snapshot.trainingDate), [
      '2026-07-10',
    ]);
  });
}

TeammateService _service(Map<String, OjProvider> providers) {
  return TeammateService(client: http.Client(), providers: providers);
}

TeammateProfile _teammate(
  String id,
  String nickname, {
  List<TeammateAccount> accounts = const [
    TeammateAccount(platform: 'codeforces', handle: 'alice'),
  ],
}) {
  return TeammateProfile.create(
    id: id,
    nickname: nickname,
    accounts: accounts,
    now: DateTime.parse('2026-07-10T12:00:00'),
  );
}

TeammateDailyRecord _record(String teammateId, String date, int delta) {
  return TeammateDailyRecord(
    teammateId: teammateId,
    trainingDate: date,
    perPlatformDelta: {'codeforces': delta},
    totalDelta: delta,
    refreshedAt: DateTime.parse('${date}T12:00:00'),
  );
}

TeammateSolvedSnapshot _snapshot(String teammateId, String date) {
  return TeammateSolvedSnapshot(
    teammateId: teammateId,
    platform: 'codeforces',
    trainingDate: date,
    solvedTotalAtStart: 10,
    latestSolvedTotal: 12,
    updatedAt: DateTime.parse('${date}T12:00:00'),
  );
}

AppConfig _config() {
  return AppConfig(
    refreshIntervalMinutes: 60,
    accounts: {
      for (final meta in supportedOjs)
        meta.id: const OjAccountConfig(usernames: [], enabled: false),
    },
  );
}

class _FakeProvider implements OjProvider {
  _FakeProvider(this.outcomes);

  final Map<String, Object> outcomes;
  final _calls = <String, int>{};

  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final outcome = outcomes[username];
    if (outcome is List<OjProfile>) {
      final index = _calls[username] ?? 0;
      _calls[username] = index + 1;
      return outcome[index.clamp(0, outcome.length - 1)];
    }
    if (outcome is OjProfile) {
      return outcome;
    }
    if (outcome is Object) {
      throw outcome;
    }
    throw FetchException('missing');
  }
}
