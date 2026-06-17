import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';

void main() {
  group('normalizeNowcoderUserId', () {
    test('accepts numeric user id', () {
      expect(normalizeNowcoderUserId(' 123456 '), '123456');
    });

    test('accepts full profile URL', () {
      expect(
        normalizeNowcoderUserId('https://www.nowcoder.com/users/987654'),
        '987654',
      );
    });

    test('accepts username for OJ Hunt lookup', () {
      expect(normalizeNowcoderUserId(' alice '), 'alice');
    });

    test('rejects empty input with clear message', () {
      expect(
        () => normalizeNowcoderUserId('   '),
        throwsA(
          isA<FetchException>().having(
            (error) => error.message,
            'message',
            contains('数字用户 ID、用户名'),
          ),
        ),
      );
    });
  });

  group('parseNowcoderOjhuntSolvedCount', () {
    test('reads data.solved from OJ Hunt response', () {
      expect(
        parseNowcoderOjhuntSolvedCount({
          'data': {'solved': 42},
        }),
        42,
      );
      expect(
        parseNowcoderOjhuntSolvedCount({
          'data': {'solved': '43'},
        }),
        43,
      );
    });

    test('throws a clear error when OJ Hunt solved count is missing', () {
      expect(
        () => parseNowcoderOjhuntSolvedCount({'data': {}}),
        throwsA(
          isA<FetchException>().having(
            (error) => error.message,
            'message',
            contains('data.solved'),
          ),
        ),
      );
    });
  });

  group('parseNowcoderSolvedCount', () {
    test('reads supported JSON count fields', () {
      expect(parseNowcoderSolvedCount('{"acceptedCount":12}'), 12);
      expect(parseNowcoderSolvedCount('{"acceptCount":13}'), 13);
      expect(parseNowcoderSolvedCount('{"acCount":14}'), 14);
      expect(parseNowcoderSolvedCount('{"solvedCount":15}'), 15);
      expect(parseNowcoderSolvedCount('{"passedProblemCount":16}'), 16);
    });

    test('reads supported Chinese labels from HTML text', () {
      expect(parseNowcoderSolvedCount('<span>通过题目</span><b>21</b>'), 21);
      expect(parseNowcoderSolvedCount('<div>已通过 22</div>'), 22);
      expect(parseNowcoderSolvedCount('<p>AC题数：23</p>'), 23);
    });

    test('throws a clear error when solved count cannot be found', () {
      expect(
        () => parseNowcoderSolvedCount('<html>empty</html>'),
        throwsA(
          isA<FetchException>().having(
            (error) => error.message,
            'message',
            contains('未找到通过题目数'),
          ),
        ),
      );
    });
  });

  test('provider fetches OJ Hunt first without real network', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        '{"data":{"solved":42}}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final profile = await NowcoderProvider().fetchProfile(
      client,
      'https://www.nowcoder.com/users/2468',
    );

    expect(requestedUri.host, 'ojhunt.com');
    expect(requestedUri.path, '/api/crawlers/nowcoder/2468');
    expect(profile.solvedCount, 42);
    expect(profile.profileUrl, 'https://www.nowcoder.com/users/2468');
  });

  test('provider falls back to profile parsing when OJ Hunt fails', () async {
    final requestedUris = <Uri>[];
    final client = MockClient((request) async {
      requestedUris.add(request.url);
      if (request.url.host == 'ojhunt.com') {
        return http.Response('temporary failure', 500);
      }
      return http.Response('{"acceptedCount":44}', 200);
    });

    final profile = await NowcoderProvider().fetchProfile(client, '13579');

    expect(requestedUris.map((uri) => uri.host), [
      'ojhunt.com',
      'www.nowcoder.com',
    ]);
    expect(profile.solvedCount, 44);
  });

  test('provider reports both OJ Hunt and profile failures', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'ojhunt.com') {
        return http.Response('temporary failure', 500);
      }
      return http.Response('<html>empty</html>', 200);
    });

    await expectLater(
      NowcoderProvider().fetchProfile(client, '13579'),
      throwsA(
        isA<FetchException>().having(
          (error) => error.message,
          'message',
          allOf(contains('OJ Hunt'), contains('主页解析失败')),
        ),
      ),
    );
  });
}
