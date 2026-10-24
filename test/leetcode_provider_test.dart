import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';

void main() {
  test('LeetCode profile parses All accepted count', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url, Uri.https('leetcode.com', '/graphql'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['variables'], {'username': 'alice'});
      return http.Response(
        jsonEncode({
          'data': {
            'matchedUser': {
              'submitStatsGlobal': {
                'acSubmissionNum': [
                  {'difficulty': 'All', 'count': 123},
                  {'difficulty': 'Easy', 'count': 50},
                ],
              },
            },
          },
        }),
        200,
      );
    });

    final profile = await LeetCodeProvider().fetchProfile(client, 'alice');

    expect(profile.solvedCount, 123);
    expect(profile.profileUrl, 'https://leetcode.com/alice/');
  });

  test('LeetCode reports missing users', () async {
    final client = MockClient(
      (_) async => http.Response('{"data":{"matchedUser":null}}', 200),
    );

    expect(
      () => LeetCodeProvider().fetchProfile(client, 'missing'),
      throwsA(
        isA<FetchException>().having(
          (error) => error.message,
          'message',
          contains('用户不存在'),
        ),
      ),
    );
  });

  test('LeetCode rejects changed response format', () async {
    final client = MockClient(
      (_) async => http.Response('{"data":{"matchedUser":{}}}', 200),
    );

    expect(
      () => LeetCodeProvider().fetchProfile(client, 'alice'),
      throwsA(isA<FetchException>()),
    );
  });

  test('LeetCode rejects invalid JSON and HTTP errors', () async {
    final invalid = MockClient((_) async => http.Response('<html>', 200));
    final unavailable = MockClient((_) async => http.Response('down', 503));

    expect(
      () => LeetCodeProvider().fetchProfile(invalid, 'alice'),
      throwsA(isA<FetchException>()),
    );
    expect(
      () => LeetCodeProvider().fetchProfile(unavailable, 'alice'),
      throwsA(isA<FetchException>()),
    );
  });
}
