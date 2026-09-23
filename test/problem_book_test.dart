import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';

void main() {
  test('ProblemRecord JSON roundtrip stores tags as a JSON string', () {
    final problem = ProblemRecord.create(
      id: 'lxyz123abc',
      title: 'CF 1799A',
      url: 'https://codeforces.com/problemset/problem/1799/A',
      platform: ProblemPlatform.cf,
      status: ProblemStatus.AC,
      tags: const ['贪心', '构造'],
      date: '2026-06-21',
      note: '赛后补题',
      analysis: '这里写思路分析、做法总结',
      now: DateTime.parse('2026-06-21T12:00:00'),
    );

    final stored = problem.toStorageJson();
    expect(stored['tags'], '["贪心","构造"]');

    final parsed = ProblemRecord.fromJson(stored);
    expect(parsed.id, 'lxyz123abc');
    expect(parsed.tags, ['贪心', '构造']);
    expect(parsed.platform, ProblemPlatform.cf);
    expect(parsed.status, ProblemStatus.AC);
  });

  test('problem tags accept both string and array input', () {
    expect(parseProblemTags('["DP","图论"]'), ['DP', '图论']);
    expect(parseProblemTags(['DP', '图论']), ['DP', '图论']);
    expect(parseProblemTags('DP, 图论, dp'), ['DP', '图论']);
  });

  test('LocalStore migrates the legacy problem JSON into SQLite once',
      () async {
    final directory = await Directory.systemTemp.createTemp('problem_store_');
    try {
      final file = File('${directory.path}${Platform.pathSeparator}'
          'problems_v1.json');
      await file.writeAsString(jsonEncode([_problem().toStorageJson()]));

      final store = LocalStore(supportDirectory: directory);
      final problems = await store.loadProblems();

      expect(problems, hasLength(1));
      expect(problems.single.title, 'CF 1799A');
      expect(
        await File(
          '${directory.path}${Platform.pathSeparator}$problemDatabaseFileName',
        ).exists(),
        isTrue,
      );

      await file.writeAsString('[]');
      final reloaded =
          await LocalStore(supportDirectory: directory).loadProblems();
      expect(reloaded.single.title, 'CF 1799A');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('legacy migration refuses damaged rows instead of dropping data',
      () async {
    final directory = await Directory.systemTemp.createTemp('problem_store_');
    try {
      final file = File('${directory.path}${Platform.pathSeparator}'
          'problems_v1.json');
      await file.writeAsString(jsonEncode([
        _problem().toStorageJson(),
        {'id': 'broken'},
      ]));

      final store = LocalStore(supportDirectory: directory);
      await expectLater(store.loadProblems(), throwsFormatException);
      expect(await file.exists(), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('platform aliases and URL detection use canonical values', () {
    expect(parseProblemPlatform('hdu'), ProblemPlatform.hd);
    expect(parseProblemPlatform('luogu'), ProblemPlatform.lg);
    expect(parseProblemPlatform('nowcoder'), ProblemPlatform.nc);
    expect(parseProblemPlatform('娲涜胺'), ProblemPlatform.lg);
    expect(parseProblemPlatform('鐗涘'), ProblemPlatform.nc);
    expect(parseProblemPlatform('鍏朵粬'), ProblemPlatform.other);

    final cases = {
      'https://codeforces.com/problemset/problem/1799/A': ProblemPlatform.cf,
      'https://atcoder.jp/contests/abc300/tasks/abc300_a':
          ProblemPlatform.atcoder,
      'https://acm.hdu.edu.cn/showproblem.php?pid=1000': ProblemPlatform.hd,
      'https://www.luogu.com.cn/problem/P1001': ProblemPlatform.lg,
      'http://poj.org/problem?id=1000': ProblemPlatform.poj,
      'https://onlinejudge.org/index.php?option=onlinejudge&page=show_problem&problem=36':
          ProblemPlatform.uva,
      'https://ac.nowcoder.com/acm/problem/12345': ProblemPlatform.nc,
      'https://www.spoj.com/problems/TEST/': ProblemPlatform.spoj,
      'https://leetcode.cn/problems/two-sum/': ProblemPlatform.lccn,
      'https://example.com/problem/1': ProblemPlatform.other,
    };

    for (final entry in cases.entries) {
      expect(detectProblemPlatform(Uri.parse(entry.key)), entry.value);
    }
  });

  test('Codeforces and Luogu title parsing have stable fallbacks', () async {
    final service = ProblemBookService(
      client: MockClient((request) async {
        if (request.url.host == 'codeforces.com') {
          return http.Response(
            '<html><div class="problem-statement"><div class="title">A. Recent Actions</div></div></html>',
            200,
          );
        }
        return http.Response('<title>P1001 A+B Problem - Luogu</title>', 200);
      }),
    );
    addTearDown(service.dispose);

    final cf = await service.parseLink(
      'https://codeforces.com/problemset/problem/1799/A',
    );
    expect(cf.title, 'Recent Actions');
    expect(cf.platform, ProblemPlatform.cf);

    final luogu =
        await service.parseLink('https://www.luogu.com.cn/problem/P1001');
    expect(luogu.title, 'P1001 A+B Problem');
    expect(luogu.platform, ProblemPlatform.lg);

    expect(
      fallbackProblemTitle(
        Uri.parse('https://codeforces.com/contest/1799/problem/A'),
        ProblemPlatform.cf,
      ),
      'CF 1799A',
    );
  });

  test('ProblemBookService CRUD and filtering keep updated order', () {
    final service = ProblemBookService(client: MockClient((_) async {
      return http.Response('', 404);
    }));
    addTearDown(service.dispose);

    final first = _problem(
      id: 'a',
      title: 'Graph',
      status: ProblemStatus.TODO,
      tags: const ['图论'],
      updatedAt: DateTime.parse('2026-06-21T08:00:00'),
    );
    final second = _problem(
      id: 'b',
      title: 'Greedy',
      url: 'https://codeforces.com/problemset/problem/1799/B',
      status: ProblemStatus.WA,
      tags: const ['贪心'],
      updatedAt: DateTime.parse('2026-06-21T09:00:00'),
    );

    var problems = service.upsert(const [], first);
    problems = service.upsert(problems, second);
    expect(problems.map((item) => item.id), ['b', 'a']);

    final accepted = second.copyWith(
      status: ProblemStatus.AC,
      updatedAt: DateTime.parse('2026-06-21T10:00:00'),
    );
    problems = service.upsert(problems, accepted);
    expect(problems.first.status, ProblemStatus.AC);

    expect(
      service.filter(problems, query: '图论').map((item) => item.id),
      ['a'],
    );
    expect(
      service.filter(problems, status: ProblemStatus.AC).map((item) => item.id),
      ['b'],
    );
    expect(
      service.filter(problems, tag: first.tags.single).map((item) => item.id),
      ['a'],
    );

    problems = service.remove(problems, 'b');
    expect(problems.map((item) => item.id), ['a']);
  });

  test('mergeSyncedProblems appends website records and deduplicates URLs', () {
    final service = ProblemBookService(client: MockClient((_) async {
      return http.Response('', 404);
    }));
    addTearDown(service.dispose);

    final local = _problem(
      id: 'local',
      title: 'Local Title',
      updatedAt: DateTime.parse('2026-06-21T08:00:00'),
    );
    final newerWebsiteCopy = _problem(
      id: 'website-copy',
      title: 'Website Title',
      updatedAt: DateTime.parse('2026-06-21T10:00:00'),
    );
    final websiteOnly = _problem(
      id: 'website-only',
      title: 'Website Only',
      url: 'https://example.com/problem/2',
      updatedAt: DateTime.parse('2026-06-21T09:00:00'),
    );

    final merged = service.mergeSyncedProblems(
      [local],
      [newerWebsiteCopy, websiteOnly],
    );

    expect(merged, hasLength(2));
    expect(merged.map((item) => item.title), [
      'Website Title',
      'Website Only',
    ]);
  });

  test('canonical keys unify alternate URLs and ignore query or slash', () {
    final contest = _problem(
      id: 'contest',
      url: 'https://codeforces.com/contest/1799/problem/A?locale=en',
    );
    final problemset = _problem(
      id: 'problemset',
      url: 'https://codeforces.com/problemset/problem/1799/A/',
    );
    final genericA = _problem(
      id: 'generic-a',
      url: 'https://example.com/problem/1?source=edge',
      platform: ProblemPlatform.other,
    );
    final genericB = _problem(
      id: 'generic-b',
      url: 'https://example.com/problem/1',
      platform: ProblemPlatform.other,
    );
    final genericQueryA = _problem(
      id: 'generic-query-a',
      url: 'https://example.com/index.php?problem=1',
      platform: ProblemPlatform.other,
    );
    final genericQueryB = _problem(
      id: 'generic-query-b',
      url: 'https://example.com/index.php?problem=2',
      platform: ProblemPlatform.other,
    );
    final genericCaseA = _problem(
      id: 'generic-case-a',
      url: 'https://example.com/problems/ABC',
      platform: ProblemPlatform.other,
    );
    final genericCaseB = _problem(
      id: 'generic-case-b',
      url: 'https://example.com/problems/abc',
      platform: ProblemPlatform.other,
    );
    final genericSlash = _problem(
      id: 'generic-slash',
      url: 'https://example.com/problem/1/',
      platform: ProblemPlatform.other,
    );
    final genericHttp = _problem(
      id: 'generic-http',
      url: 'http://example.com/problem/1',
      platform: ProblemPlatform.other,
    );

    expect(canonicalProblemKey(contest), canonicalProblemKey(problemset));
    expect(canonicalProblemKey(genericA), canonicalProblemKey(genericB));
    expect(
      canonicalProblemKey(genericQueryA),
      isNot(canonicalProblemKey(genericQueryB)),
    );
    expect(
      canonicalProblemKey(genericCaseA),
      isNot(canonicalProblemKey(genericCaseB)),
    );
    expect(
      canonicalProblemKey(genericB),
      isNot(canonicalProblemKey(genericSlash)),
    );
    expect(
      canonicalProblemKey(genericB),
      isNot(canonicalProblemKey(genericHttp)),
    );
  });

  test('upsert merges repeated browser imports into the local record', () {
    final service = ProblemBookService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(service.dispose);
    final local = _problem(
      id: 'local',
      title: 'Original',
      url: 'https://codeforces.com/contest/1799/problem/A',
      tags: const ['greedy'],
    );
    final imported = _problem(
      id: 'browser',
      title: 'Imported',
      url: 'https://codeforces.com/problemset/problem/1799/A?x=1',
      tags: const ['implementation'],
      updatedAt: DateTime.parse('2026-06-22T12:00:00'),
    );

    final merged = service.upsert([local], imported);

    expect(merged, hasLength(1));
    expect(merged.single.id, 'local');
    expect(merged.single.title, 'Imported');
    expect(merged.single.tags, containsAll(['greedy', 'implementation']));
  });

  test('editing by ID never overwrites another record with the same key', () {
    final service = ProblemBookService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(service.dispose);
    final first = _problem(
      id: 'first',
      title: 'First original',
      url: 'https://acm.hdu.edu.cn/showproblem.php?pid=1007',
    );
    final second = _problem(
      id: 'second',
      title: 'Second original',
      url: 'https://acm.hdu.edu.cn/showproblem.php?pid=1007',
    );
    final edited = first.copyWith(
      title: 'First edited',
      updatedAt: DateTime.parse('2026-06-22T12:00:00'),
    );

    final saved = service.upsert([first, second], edited);

    expect(saved, hasLength(2));
    expect(
      saved.singleWhere((item) => item.id == 'first').title,
      'First edited',
    );
    expect(
      saved.singleWhere((item) => item.id == 'second').title,
      'Second original',
    );
  });

  test('deduplicating new records preserves both authored solutions', () {
    final service = ProblemBookService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(service.dispose);
    final existing = _problem(
      id: 'existing',
      title: 'Existing',
      url: 'https://www.luogu.com.cn/problem/P1001',
      platform: ProblemPlatform.lg,
    );
    final incoming = ProblemRecord.create(
      id: 'incoming',
      title: 'Incoming',
      url: 'https://www.luogu.com.cn/problem/P1001',
      platform: ProblemPlatform.lg,
      note: 'new note',
      analysis: 'new solution',
      now: DateTime.parse('2026-06-22T12:00:00'),
    );

    final saved = service.upsert([existing], incoming);

    expect(saved, hasLength(1));
    expect(saved.single.id, 'existing');
    expect(saved.single.note, contains('赛后补题'));
    expect(saved.single.note, contains('new note'));
    expect(saved.single.analysis, contains('思路分析'));
    expect(saved.single.analysis, contains('new solution'));
  });

  test('problem URI normalization rejects local protocols', () {
    expect(
      () => normalizeProblemUri('file:///C:/secret.txt'),
      throwsA(isA<FetchException>()),
    );
    expect(
      () => normalizeProblemUri('javascript:alert(1)'),
      throwsA(isA<FetchException>()),
    );
  });

  test('problem filtering supports workflow and platform', () {
    final backlog = _problem(
      id: 'backlog',
      url: 'https://codeforces.com/problemset/problem/1/A',
      status: ProblemStatus.TODO,
    );
    final mastered = _problem(
      id: 'mastered',
      url: 'https://codeforces.com/problemset/problem/2/A',
      status: ProblemStatus.AC,
    );

    expect(
      filterProblems(
        [backlog, mastered],
        workflowStatus: ProblemWorkflowStatus.backlog,
        platform: ProblemPlatform.cf,
      ).map((item) => item.id),
      ['backlog'],
    );
    expect(
      filterProblems([backlog], platform: ProblemPlatform.lg),
      isEmpty,
    );
  });

  test('external IDs cover supported platform URL shapes', () {
    final cases = <(String, ProblemPlatform, String)>[
      (
        'https://atcoder.jp/contests/abc300/tasks/abc300_a',
        ProblemPlatform.atcoder,
        'abc300_a',
      ),
      (
        'https://atcoder.jp/contests/custom/tasks/A',
        ProblemPlatform.atcoder,
        'custom:A',
      ),
      ('https://www.luogu.com.cn/problem/P1001', ProblemPlatform.lg, 'P1001'),
      (
        'https://ac.nowcoder.com/acm/problem/12345',
        ProblemPlatform.nc,
        '12345',
      ),
      (
        'https://leetcode.cn/problems/two-sum/',
        ProblemPlatform.lccn,
        'two-sum',
      ),
      (
        'https://acm.hdu.edu.cn/showproblem.php?pid=1000',
        ProblemPlatform.hd,
        '1000',
      ),
      ('http://poj.org/problem?id=1000', ProblemPlatform.poj, '1000'),
      (
        'https://onlinejudge.org/index.php?option=onlinejudge&page=show_problem&problem=36',
        ProblemPlatform.uva,
        '36',
      ),
      (
        'https://onlinejudge.org/problem/36',
        ProblemPlatform.uva,
        '36',
      ),
      ('https://example.com/problem/1', ProblemPlatform.other, ''),
    ];

    for (final (url, platform, expected) in cases) {
      expect(extractProblemExternalId(Uri.parse(url), platform), expected);
    }
  });

  test('all platforms keep distinct scoped problems as separate records', () {
    final cases = <(ProblemPlatform, String, String)>[
      (
        ProblemPlatform.cf,
        'https://codeforces.com/contest/100/problem/A',
        'https://codeforces.com/contest/101/problem/A',
      ),
      (
        ProblemPlatform.atcoder,
        'https://atcoder.jp/contests/custom-one/tasks/A',
        'https://atcoder.jp/contests/custom-two/tasks/A',
      ),
      (
        ProblemPlatform.hd,
        'https://acm.hdu.edu.cn/contest/problem?cid=100&pid=1007',
        'https://acm.hdu.edu.cn/contest/problem?cid=101&pid=1007',
      ),
      (
        ProblemPlatform.lg,
        'https://www.luogu.com.cn/problem/P1001',
        'https://www.luogu.com.cn/problem/P1002',
      ),
      (
        ProblemPlatform.poj,
        'http://poj.org/problem?id=1000',
        'http://poj.org/problem?id=1001',
      ),
      (
        ProblemPlatform.uva,
        'https://onlinejudge.org/index.php?problem=36',
        'https://onlinejudge.org/index.php?problem=37',
      ),
      (
        ProblemPlatform.nc,
        'https://ac.nowcoder.com/acm/problem/1007',
        'https://ac.nowcoder.com/acm/problem/1008',
      ),
      (
        ProblemPlatform.spoj,
        'https://www.spoj.com/problems/TEST/',
        'https://www.spoj.com/problems/TEST2/',
      ),
      (
        ProblemPlatform.lccn,
        'https://leetcode.cn/problems/two-sum/',
        'https://leetcode.cn/problems/three-sum/',
      ),
      (
        ProblemPlatform.other,
        'https://example.com/problem.php?id=1007',
        'https://example.com/problem.php?id=1008',
      ),
    ];
    final service = ProblemBookService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(service.dispose);

    for (var index = 0; index < cases.length; index += 1) {
      final (platform, firstUrl, secondUrl) = cases[index];
      final first = ProblemRecord.create(
        id: 'first-$index',
        title: 'First $index',
        url: firstUrl,
        platform: platform,
        externalId: 'stale-shared-id',
        now: DateTime(2026, 7, 27, 8),
      );
      final second = ProblemRecord.create(
        id: 'second-$index',
        title: 'Second $index',
        url: secondUrl,
        platform: platform,
        externalId: 'stale-shared-id',
        now: DateTime(2026, 7, 27, 9),
      );

      expect(
        canonicalProblemKey(first),
        isNot(canonicalProblemKey(second)),
        reason: '${platform.name} must not merge $firstUrl and $secondUrl',
      );
      expect(service.upsert([first], second), hasLength(2));
    }
  });

  test('HDU contest problem keys include cid so same pid stays separate', () {
    final firstUrl = Uri.parse(
      'https://acm.hdu.edu.cn/contest/problem?cid=1237&pid=1007',
    );
    final secondUrl = Uri.parse(
      'https://acm.hdu.edu.cn/contest/problem?cid=1230&pid=1007',
    );

    expect(
      extractProblemExternalId(firstUrl, ProblemPlatform.hd),
      '1237:1007',
    );
    expect(
      extractProblemExternalId(secondUrl, ProblemPlatform.hd),
      '1230:1007',
    );

    final first = ProblemRecord.create(
      id: 'hdu-1237',
      title: 'Contest 1237',
      url: firstUrl.toString(),
      platform: ProblemPlatform.hd,
      externalId: '1007',
      now: DateTime(2026, 7, 27, 8),
    );
    final second = ProblemRecord.create(
      id: 'hdu-1230',
      title: 'Contest 1230',
      url: secondUrl.toString(),
      platform: ProblemPlatform.hd,
      externalId: '1007',
      now: DateTime(2026, 7, 27, 9),
    );

    expect(canonicalProblemKey(first), 'hd:1237:1007');
    expect(canonicalProblemKey(second), 'hd:1230:1007');

    final service = ProblemBookService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(service.dispose);
    final saved = service.upsert([first], second);
    expect(saved, hasLength(2));
    expect(
      saved.map((item) => item.title),
      containsAll(['Contest 1237', 'Contest 1230']),
    );
  });

  test('UVA problem keys include query IDs instead of sharing index.php', () {
    final first = ProblemRecord.create(
      id: 'uva-36',
      title: 'UVA 36',
      url:
          'https://onlinejudge.org/index.php?option=onlinejudge&page=show_problem&problem=36',
      platform: ProblemPlatform.uva,
      now: DateTime(2026, 7, 27, 8),
    );
    final second = ProblemRecord.create(
      id: 'uva-37',
      title: 'UVA 37',
      url:
          'https://onlinejudge.org/index.php?option=onlinejudge&page=show_problem&problem=37',
      platform: ProblemPlatform.uva,
      now: DateTime(2026, 7, 27, 9),
    );

    expect(canonicalProblemKey(first), 'uva:36');
    expect(canonicalProblemKey(second), 'uva:37');
    final service = ProblemBookService(
      client: MockClient((_) async => http.Response('', 404)),
    );
    addTearDown(service.dispose);
    expect(service.upsert([first], second), hasLength(2));
  });

  test('canonical key only falls back to explicit ID without a usable URL', () {
    final problem = ProblemRecord.create(
      id: 'external',
      title: 'External',
      url: 'not-a-url',
      platform: ProblemPlatform.other,
      externalId: ' ABC-1 ',
      now: DateTime(2026, 7, 27),
    );

    expect(canonicalProblemKey(problem), 'other:abc-1');
  });

  test('fallback titles cover all supported platforms', () {
    final cases = <(ProblemPlatform, String, String)>[
      (ProblemPlatform.nc, 'https://ac.nowcoder.com/acm/problem/12', '牛客 12'),
      (
        ProblemPlatform.atcoder,
        'https://atcoder.jp/contests/abc/tasks/abc_a',
        'AtCoder abc_a',
      ),
      (
        ProblemPlatform.hd,
        'https://acm.hdu.edu.cn/showproblem.php?pid=1000',
        'HDU 1000',
      ),
      (ProblemPlatform.poj, 'http://poj.org/problem?id=1000', 'POJ 1000'),
      (ProblemPlatform.uva, 'https://onlinejudge.org/problem/36', 'UVA 36'),
      (ProblemPlatform.spoj, 'https://spoj.com/problems/TEST/', 'SPOJ TEST'),
      (
        ProblemPlatform.lccn,
        'https://leetcode.cn/problems/two-sum/',
        'LeetCode two-sum',
      ),
      (ProblemPlatform.other, 'https://example.com/problem/1', '1'),
    ];

    for (final (platform, url, expected) in cases) {
      expect(fallbackProblemTitle(Uri.parse(url), platform), expected);
    }
  });

  test('generic and Luogu injection title parsers handle page variants', () {
    expect(
      parseGenericProblemTitle('<html><h1>  Generic   Title </h1></html>'),
      'Generic Title',
    );
    final payload = jsonEncode({
      'currentData': {
        'problem': {'title': 'P1001 A+B Problem'},
      },
    });
    final encoded = jsonEncode(payload);
    expect(
      parseLuoguProblemTitle(
          '<script>window._feInjection = JSON.parse($encoded)</script>'),
      'P1001 A+B Problem',
    );
  });

  test('parseLink falls back after page fetch failure', () async {
    final service = ProblemBookService(
      client: MockClient((_) async => http.Response('down', 503)),
    );
    addTearDown(service.dispose);

    final parsed = await service.parseLink(
      'atcoder.jp/contests/abc300/tasks/abc300_a#statement',
    );

    expect(parsed.title, 'AtCoder abc300_a');
    expect(parsed.externalId, 'abc300_a');
    expect(parsed.url, isNot(contains('#')));
  });

  test('empty problem URL is rejected', () {
    expect(() => normalizeProblemUri('  '), throwsA(isA<FetchException>()));
  });

  test('tag stats count total and pending problems', () {
    final stats = buildProblemTagStats([
      _problem(id: 'a', status: ProblemStatus.TODO, tags: const ['DP']),
      _problem(id: 'b', status: ProblemStatus.AC, tags: const ['dp']),
      _problem(id: 'c', status: ProblemStatus.REVIEW, tags: const ['Graph']),
    ]);

    expect(stats.map((item) => item.tag), ['DP', 'Graph']);
    expect(stats.first.total, 2);
    expect(stats.first.pending, 1);
    expect(stats.last.total, 1);
    expect(stats.last.pending, 1);
  });
}

ProblemRecord _problem({
  String id = 'lxyz123abc',
  String title = 'CF 1799A',
  String url = 'https://codeforces.com/problemset/problem/1799/A',
  ProblemPlatform platform = ProblemPlatform.cf,
  ProblemStatus status = ProblemStatus.AC,
  List<String> tags = const ['贪心', '构造'],
  DateTime? updatedAt,
}) {
  final now = DateTime.parse('2026-06-21T12:00:00');
  return ProblemRecord(
    id: id,
    title: title,
    url: url,
    platform: platform,
    status: status,
    tags: tags,
    date: '2026-06-21',
    note: '赛后补题',
    analysis: '思路分析',
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}
