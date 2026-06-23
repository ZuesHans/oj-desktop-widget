import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';

void main() {
  test('default sync config is disabled and does not send a request', () async {
    var requests = 0;
    final service = SyncService(
      client: MockClient((_) async {
        requests += 1;
        return http.Response('', 500);
      }),
    );
    addTearDown(service.dispose);

    final result = await service.sync(
      config: const SyncConfig(),
      token: 'secret-token',
      snapshots: const [],
      problems: const [],
    );

    expect(result.status, SyncStatus.skipped);
    expect(requests, 0);
  });

  test('default payload excludes usernames, token, note, and analysis', () {
    final payload = buildOjSyncPayload(
      config: const SyncConfig(enabled: true),
      snapshots: [
        _snapshot('2026-06-22', 'demo_user', 10, hour: 8),
        _snapshot('2026-06-22', 'demo_user', 15, hour: 20),
      ],
      problems: [_problem()],
      now: DateTime.parse('2026-06-23T15:00:00'),
    );
    final text = jsonEncode(payload);

    expect(payload['schemaVersion'], 1);
    expect(payload['app'], 'oj_float');
    expect(text, isNot(contains('demo_user')));
    expect(text, isNot(contains('secret-token')));
    expect(text, isNot(contains('private note')));
    expect(text, isNot(contains('private analysis')));
    expect(text, contains('https://example.com/problem/1'));

    final dailyStats =
        (payload['dailyStats'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(dailyStats, [
      {'date': '2026-06-22', 'totalDelta': 5},
    ]);
  });

  test('note and analysis are included only when explicit switches are on', () {
    final payload = buildOjSyncPayload(
      config: const SyncConfig(
        enabled: true,
        includeProblemNote: true,
        includeProblemAnalysis: true,
      ),
      snapshots: const [],
      problems: [_problem()],
      now: DateTime.parse('2026-06-23T15:00:00'),
    );
    final problems =
        (payload['problems'] as List<dynamic>).cast<Map<String, dynamic>>();

    expect(problems.single['note'], 'private note');
    expect(problems.single['analysis'], 'private analysis');
  });

  test('disabled sync scopes are sent as empty arrays to clear projections',
      () {
    final payload = buildOjSyncPayload(
      config: const SyncConfig(
        enabled: true,
        syncDailyStats: false,
        syncProblems: false,
      ),
      snapshots: [
        _snapshot('2026-06-22', 'demo_user', 10, hour: 8),
        _snapshot('2026-06-22', 'demo_user', 15, hour: 20),
      ],
      problems: [_problem()],
      now: DateTime.parse('2026-06-23T15:00:00'),
    );

    expect(payload['dailyStats'], isEmpty);
    expect(payload['problems'], isEmpty);
  });

  test('token and endpoint labels are safe for logs', () {
    expect(maskSyncToken(''), '');
    expect(maskSyncToken('short'), '****');
    expect(maskSyncToken('abcd1234wxyz'), 'abcd...wxyz');
    expect(
      safeEndpointLabel(Uri.parse('https://example.com/api/oj-sync?x=secret')),
      'https://example.com',
    );
  });

  test('sync sends bearer token but never includes token in the JSON body',
      () async {
    late String body;
    late String authorization;
    final service = SyncService(
      client: MockClient((request) async {
        body = request.body;
        authorization = request.headers['authorization'] ?? '';
        return http.Response('{"success":true}', 200);
      }),
    );
    addTearDown(service.dispose);

    final result = await service.sync(
      config: const SyncConfig(
        enabled: true,
        endpointUrl: 'https://example.com/api/oj-sync',
      ),
      token: 'secret-token',
      snapshots: const [],
      problems: const [],
      now: DateTime.parse('2026-06-23T15:00:00'),
    );

    expect(result.status, SyncStatus.success);
    expect(authorization, 'Bearer secret-token');
    expect(body, isNot(contains('secret-token')));
  });

  test('sync rejects plain HTTP except localhost development endpoints',
      () async {
    var requests = 0;
    final service = SyncService(
      client: MockClient((_) async {
        requests += 1;
        return http.Response('{"success":true}', 200);
      }),
    );
    addTearDown(service.dispose);

    final rejected = await service.sync(
      config: const SyncConfig(
        enabled: true,
        endpointUrl: 'http://example.com/api/oj-sync',
      ),
      token: 'secret-token',
      snapshots: const [],
      problems: const [],
    );
    final allowed = await service.sync(
      config: const SyncConfig(
        enabled: true,
        endpointUrl: 'http://localhost:8787/api/oj-sync',
      ),
      token: 'secret-token',
      snapshots: const [],
      problems: const [],
    );

    expect(rejected.status, SyncStatus.failure);
    expect(allowed.status, SyncStatus.success);
    expect(requests, 1);
  });
}

ProblemRecord _problem() {
  return ProblemRecord.create(
    id: 'p_demo',
    title: 'Example Problem',
    url: 'https://example.com/problem/1',
    platform: ProblemPlatform.other,
    status: ProblemStatus.REVIEW,
    tags: const ['dp'],
    date: '2026-06-23',
    note: 'private note',
    analysis: 'private analysis',
    now: DateTime.parse('2026-06-23T12:00:00'),
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
