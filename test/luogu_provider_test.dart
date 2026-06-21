import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';

void main() {
  group('normalizeLuoguUserInput', () {
    test('accepts numeric uid', () {
      expect(normalizeLuoguUserInput(' 123456 '), '123456');
    });

    test('extracts uid from profile URL', () {
      expect(
        normalizeLuoguUserInput('https://www.luogu.com.cn/user/987654'),
        '987654',
      );
    });

    test('accepts username for search lookup', () {
      expect(normalizeLuoguUserInput('alice'), 'alice');
    });
  });

  test('provider searches username then parses passedProblemCount', () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      if (request.url.path == '/api/user/search') {
        return http.Response(
          '{"users":[{"uid":2468,"name":"alice"}]}',
          200,
        );
      }
      if (request.url.path == '/user/2468') {
        return http.Response('{"passedProblemCount":135}', 200);
      }
      return http.Response('unexpected', 500);
    });

    final profile = await LuoguProvider().fetchProfile(client, 'alice');

    expect(requestedUris.map((uri) => uri.path), [
      '/api/user/search',
      '/user/2468',
    ]);
    expect(profile.solvedCount, 135);
    expect(profile.profileUrl, 'https://www.luogu.com.cn/user/2468');
  });

  test('provider keeps numeric uid without search', () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      return http.Response('{"acceptedProblemCount":42}', 200);
    });

    final profile = await LuoguProvider().fetchProfile(client, '2468');

    expect(requestedUris.map((uri) => uri.path), ['/user/2468']);
    expect(profile.solvedCount, 42);
  });
}
