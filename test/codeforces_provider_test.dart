import 'package:flutter_test/flutter_test.dart';
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
}
