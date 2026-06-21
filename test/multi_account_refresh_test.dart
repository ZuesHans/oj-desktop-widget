import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';

void main() {
  test('same platform account failure does not block another success',
      () async {
    final service = RefreshService(
      client: http.Client(),
      providers: {
        'codeforces': _FakeProvider({
          'a': const OjProfile(
            solvedCount: 7,
            profileUrl: 'https://example.test/a',
          ),
          'b': FetchException('broken'),
        }),
      },
    );

    try {
      final results = await service.refresh(
        AppConfig(
          refreshIntervalMinutes: 60,
          accounts: {
            for (final meta in supportedOjs)
              meta.id: meta.id == 'codeforces'
                  ? const OjAccountConfig(
                      usernames: ['a', 'b'],
                      enabled: true,
                    )
                  : const OjAccountConfig(usernames: [], enabled: false),
          },
        ),
      );

      final byUsername = {
        for (final result in results['codeforces']!) result.username: result,
      };
      expect(byUsername['a']!.status, FetchStatus.success);
      expect(byUsername['a']!.solvedCount, 7);
      expect(byUsername['b']!.status, FetchStatus.failure);
      expect(byUsername['b']!.error, 'broken');
    } finally {
      service.dispose();
    }
  });

  test('failed accounts are not counted in total solved', () {
    final total = totalSolvedFromLatest({
      'codeforces': [
        FetchResult.success(
          ojId: 'codeforces',
          username: 'a',
          solvedCount: 7,
          fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
        ),
        FetchResult.failure(
          ojId: 'codeforces',
          username: 'b',
          error: 'broken',
          fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
        ),
      ],
    });

    expect(total, 7);
  });

  test('blocked account displays retained solved count in totals', () {
    final total = totalSolvedFromLatest({
      'codeforces': [
        FetchResult.failure(
          ojId: 'codeforces',
          username: 'a',
          error: 'retained',
          fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
          solvedCount: 0,
          previousSolvedCount: 670,
        ),
      ],
    });

    expect(total, 670);
  });
}

class _FakeProvider implements OjProvider {
  const _FakeProvider(this.outcomes);

  final Map<String, Object> outcomes;

  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final outcome = outcomes[username];
    if (outcome is OjProfile) {
      return outcome;
    }
    if (outcome is Object) {
      throw outcome;
    }
    throw FetchException('missing');
  }
}
