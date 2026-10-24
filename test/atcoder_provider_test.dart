import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';

void main() {
  test('AtCoder profile reads accepted count', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/atcoder/atcoder-api/v3/user/ac_rank');
      expect(request.url.queryParameters['user'], 'alice');
      return http.Response('{"count":42}', 200);
    });

    final profile = await AtCoderProvider().fetchProfile(client, 'alice');

    expect(profile.solvedCount, 42);
    expect(profile.profileUrl, 'https://atcoder.jp/users/alice');
  });

  test('AtCoder profile rejects changed response format', () async {
    final client = MockClient((_) async => http.Response('[]', 200));

    expect(
      () => AtCoderProvider().fetchProfile(client, 'alice'),
      throwsA(isA<FetchException>()),
    );
  });

  test('AtCoder profile rejects missing count', () async {
    final client = MockClient((_) async => http.Response('{}', 200));

    expect(
      () => AtCoderProvider().fetchProfile(client, 'missing'),
      throwsA(isA<FetchException>()),
    );
  });

  test('AtCoder provider surfaces HTTP errors', () async {
    final client = MockClient((_) async => http.Response('failed', 503));

    expect(
      () => AtCoderProvider().fetchProfile(client, 'alice'),
      throwsA(isA<FetchException>()),
    );
  });

  test('AtCoder daily activity is unique and uses half-open boundaries',
      () async {
    final start = DateTime(2026, 7, 27, 4);
    final end = DateTime(2026, 7, 28, 4);
    int seconds(DateTime value) => value.toUtc().millisecondsSinceEpoch ~/ 1000;
    final submissions = [
      {'result': 'AC', 'problem_id': 'a', 'epoch_second': seconds(start)},
      {
        'result': 'AC',
        'problem_id': 'a',
        'epoch_second': seconds(start.add(const Duration(hours: 1))),
      },
      {
        'result': 'WA',
        'problem_id': 'b',
        'epoch_second': seconds(start.add(const Duration(hours: 2))),
      },
      {
        'result': 'AC',
        'problem_id': 'c',
        'epoch_second': seconds(end),
      },
      {
        'result': 'AC',
        'problem_id': 'd',
        'epoch_second': seconds(end.subtract(const Duration(seconds: 1))),
      },
    ];
    final client = MockClient((request) async {
      expect(
        request.url.queryParameters['from_second'],
        '${seconds(start)}',
      );
      return http.Response(jsonEncode(submissions), 200);
    });

    final activity = await AtCoderProvider().fetchDailyActivity(
      client,
      'alice',
      start: start,
      end: end,
    );

    expect(activity.acceptedCount, 2);
  });

  test('AtCoder daily activity rejects malformed payload', () async {
    final client = MockClient((_) async => http.Response('{}', 200));

    expect(
      () => AtCoderProvider().fetchDailyActivity(
        client,
        'alice',
        start: DateTime(2026, 7, 27, 4),
        end: DateTime(2026, 7, 28, 4),
      ),
      throwsA(isA<FetchException>()),
    );
  });
}
