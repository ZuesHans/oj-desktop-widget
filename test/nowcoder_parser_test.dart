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

    test('rejects invalid input with clear message', () {
      expect(
        () => normalizeNowcoderUserId('alice'),
        throwsA(
          isA<FetchException>().having(
            (error) => error.message,
            'message',
            contains('数字用户 ID'),
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

  test('provider fetches normalized full profile URL without real network',
      () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response('{"acceptedCount":42}', 200);
    });

    final profile = await NowcoderProvider().fetchProfile(
      client,
      'https://www.nowcoder.com/users/2468',
    );

    expect(requestedUri.path, '/users/2468');
    expect(profile.solvedCount, 42);
    expect(profile.profileUrl, 'https://www.nowcoder.com/users/2468');
  });
}
