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

  test('LocalStore skips damaged problem entries', () async {
    final directory = await Directory.systemTemp.createTemp('problem_store_');
    try {
      final file = File('${directory.path}${Platform.pathSeparator}'
          'problems_v1.json');
      await file.writeAsString(jsonEncode([
        _problem().toStorageJson(),
        {'id': 'broken'},
        'not-an-object',
      ]));

      final store = LocalStore(supportDirectory: directory);
      final problems = await store.loadProblems();

      expect(problems, hasLength(1));
      expect(problems.single.title, 'CF 1799A');
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
      url: 'https://example.com/problem/1/?source=edge',
    );
    final genericB = _problem(
      id: 'generic-b',
      url: 'https://example.com/problem/1',
    );

    expect(canonicalProblemKey(contest), canonicalProblemKey(problemset));
    expect(canonicalProblemKey(genericA), canonicalProblemKey(genericB));
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
      ('https://example.com/problem/1', ProblemPlatform.other, ''),
    ];

    for (final (url, platform, expected) in cases) {
      expect(extractProblemExternalId(Uri.parse(url), platform), expected);
    }
  });

  test('canonical key prefers explicit external ID', () {
    final problem = ProblemRecord.create(
      id: 'external',
      title: 'External',
      url: 'https://example.com/anything?x=1',
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
  ProblemStatus status = ProblemStatus.AC,
  List<String> tags = const ['贪心', '构造'],
  DateTime? updatedAt,
}) {
  final now = DateTime.parse('2026-06-21T12:00:00');
  return ProblemRecord(
    id: id,
    title: title,
    url: url,
    platform: ProblemPlatform.cf,
    status: status,
    tags: tags,
    date: '2026-06-21',
    note: '赛后补题',
    analysis: '思路分析',
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}
