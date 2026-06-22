import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';

void main() {
  group('normalizeCodeforcesHandle', () {
    test('keeps plain handle', () {
      expect(normalizeCodeforcesHandle('tourist'), 'tourist');
    });

    test('extracts handle from profile URL', () {
      expect(
        normalizeCodeforcesHandle('https://codeforces.com/profile/tourist'),
        'tourist',
      );
    });

    test('trims spaces and ignores query string', () {
      expect(
        normalizeCodeforcesHandle(
          ' https://codeforces.com/profile/tourist?locale=en ',
        ),
        'tourist',
      );
    });

    test('rejects empty input', () {
      expect(
          () => normalizeCodeforcesHandle(''), throwsA(isA<FetchException>()));
    });
  });

  group('parseCodeforcesProfileSolvedCount', () {
    test('parses Problems solved text', () {
      expect(
        parseCodeforcesProfileSolvedCount(
          '<html><body>Problems solved: 1234</body></html>',
        ),
        1234,
      );
    });

    test('parses Solved problems text', () {
      expect(
        parseCodeforcesProfileSolvedCount(
          '<html><body>Solved problems 567</body></html>',
        ),
        567,
      );
    });

    test('parses label and count split by HTML tags', () {
      expect(
        parseCodeforcesProfileSolvedCount(
          '<span>Problems solved</span><div><span>1,999</span></div>',
        ),
        1999,
      );
    });

    test('returns null when not found', () {
      expect(
        parseCodeforcesProfileSolvedCount(
          '<html><body>no solved count</body></html>',
        ),
        isNull,
      );
    });
  });

  group('parseCodeforcesOjhuntSolvedCount', () {
    test('reads data.solved', () {
      expect(
        parseCodeforcesOjhuntSolvedCount({
          'crawler': 'codeforces',
          'username': 'tourist',
          'error': false,
          'data': {'solved': 3015},
        }),
        3015,
      );
    });

    test('rejects error responses', () {
      expect(
        () => parseCodeforcesOjhuntSolvedCount({
          'error': true,
          'message': 'not found',
        }),
        throwsA(isA<FetchException>()),
      );
    });
  });

  group('codeforcesProblemKey', () {
    test('uses contest id and index first', () {
      expect(
        codeforcesProblemKey({
          'contestId': 1,
          'index': 'A',
          'name': 'Old Name',
        }),
        'contest:1/A',
      );
    });

    test('uses problemset name and index without contest id', () {
      expect(
        codeforcesProblemKey({
          'problemsetName': 'acmsguru',
          'index': '100',
          'name': 'A+B',
        }),
        'problemset:acmsguru/100',
      );
    });

    test('falls back to name', () {
      expect(codeforcesProblemKey({'name': 'Only Name'}), 'name:Only Name');
    });

    test('returns null for empty problem', () {
      expect(codeforcesProblemKey({}), isNull);
    });
  });

  group('countCodeforcesSolvedSubmissions', () {
    test(
        'counts only accepted unique problems without using name in contest key',
        () {
      expect(
        countCodeforcesSolvedSubmissions([
          {
            'verdict': 'OK',
            'problem': {'contestId': 1, 'index': 'A', 'name': 'Old Name'},
          },
          {
            'verdict': 'OK',
            'problem': {'contestId': 1, 'index': 'A', 'name': 'New Name'},
          },
          {
            'verdict': 'WRONG_ANSWER',
            'problem': {'contestId': 2, 'index': 'B', 'name': 'Nope'},
          },
          {
            'verdict': 'OK',
            'problem': {'problemsetName': 'acmsguru', 'index': '100'},
          },
          {
            'verdict': 'OK',
            'problem': {'name': 'Legacy Problem'},
          },
        ]),
        3,
      );
    });
  });

  test('provider prefers ojhunt solved count like oj_helper', () async {
    final requestedHostsAndPaths = <String>[];
    final client = MockClient((request) async {
      requestedHostsAndPaths.add('${request.url.host}${request.url.path}');
      if (request.url.host == 'codeforces.com' &&
          request.url.path == '/api/user.info') {
        return http.Response(
          '{"status":"OK","result":[{"handle":"tourist","rating":3900}]}',
          200,
        );
      }
      if (request.url.host == 'ojhunt.com' &&
          request.url.path == '/api/crawlers/codeforces/tourist') {
        return http.Response(
          jsonEncode({
            'crawler': 'codeforces',
            'username': 'tourist',
            'error': false,
            'data': {'solved': 670},
          }),
          200,
        );
      }
      return http.Response('unexpected', 500);
    });

    final profile = await CodeforcesProvider().fetchProfile(client, 'tourist');

    expect(requestedHostsAndPaths, [
      'codeforces.com/api/user.info',
      'ojhunt.com/api/crawlers/codeforces/tourist',
    ]);
    expect(profile.solvedCount, 670);
    expect(profile.rating, 3900);
    expect(profile.source, 'ojhunt');
  });

  test('provider falls back to official user.status when ojhunt fails',
      () async {
    final requestedHostsAndPaths = <String>[];
    final client = MockClient((request) async {
      requestedHostsAndPaths.add('${request.url.host}${request.url.path}');
      if (request.url.host == 'codeforces.com' &&
          request.url.path == '/api/user.info') {
        return http.Response(
          '{"status":"OK","result":[{"handle":"tourist","rating":3900}]}',
          200,
        );
      }
      if (request.url.host == 'ojhunt.com' &&
          request.url.path == '/api/crawlers/codeforces/tourist') {
        return http.Response('temporary failure', 503);
      }
      if (request.url.host == 'codeforces.com' &&
          request.url.path == '/api/user.status') {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'result': [
              {
                'verdict': 'OK',
                'problem': {'contestId': 1, 'index': 'A', 'name': 'A'},
              },
              {
                'verdict': 'OK',
                'problem': {'contestId': 1, 'index': 'A', 'name': 'Renamed'},
              },
              {
                'verdict': 'WRONG_ANSWER',
                'problem': {'contestId': 2, 'index': 'B', 'name': 'B'},
              },
            ],
          }),
          200,
        );
      }
      return http.Response('unexpected', 500);
    });

    final profile = await CodeforcesProvider().fetchProfile(client, 'tourist');

    expect(requestedHostsAndPaths, [
      'codeforces.com/api/user.info',
      'ojhunt.com/api/crawlers/codeforces/tourist',
      'codeforces.com/api/user.status',
    ]);
    expect(profile.solvedCount, 1);
    expect(profile.rating, 3900);
    expect(profile.source, 'codeforces_user_status');
  });
}
