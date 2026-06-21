import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/http_client.dart';
import '../models/fetch_result.dart';
import 'oj_provider.dart';

class CodeforcesProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final handle = normalizeCodeforcesHandle(username);
    final info = await readJson(
      client,
      Uri.https('codeforces.com', '/api/user.info', {'handles': handle}),
    );
    if (info['status'] != 'OK') {
      throw FetchException(info['comment']?.toString() ?? 'Codeforces 返回异常');
    }
    final result = info['result'];
    if (result is! List || result.isEmpty) {
      throw FetchException('Codeforces 用户不存在');
    }
    final user = result.first;
    final rating = user is Map && user['rating'] is num
        ? (user['rating'] as num).toInt()
        : null;

    final profileUrl = 'https://codeforces.com/profile/$handle';
    try {
      final solvedCount = await fetchCodeforcesSolvedCountFromOjhunt(
        client,
        handle,
      );
      return OjProfile(
        solvedCount: solvedCount,
        profileUrl: profileUrl,
        rating: rating,
        source: 'ojhunt',
      );
    } catch (_) {
      // Match oj_helper's primary Codeforces solved-count source. Keep the
      // official submissions API below as a fallback when ojhunt is unavailable.
    }

    try {
      final solvedCount =
          await fetchCodeforcesSolvedCountFromSubmissions(client, handle);
      return OjProfile(
        solvedCount: solvedCount,
        profileUrl: profileUrl,
        rating: rating,
        source: 'codeforces_user_status',
      );
    } catch (_) {
      // Fall back to the public profile HTML as a last resort.
    }

    try {
      final response = await client
          .get(
            Uri.parse(profileUrl),
            headers: defaultHeaders(referer: 'https://codeforces.com/'),
          )
          .timeout(const Duration(seconds: 18));
      ensureOk(response);
      final solvedCount = parseCodeforcesProfileSolvedCount(response.body);
      if (solvedCount != null) {
        return OjProfile(
          solvedCount: solvedCount,
          profileUrl: profileUrl,
          rating: rating,
          source: 'profile_html',
        );
      }
    } catch (_) {
      // Report a single clear error below.
    }

    throw FetchException('Codeforces submission API 和主页解析均失败');
  }
}

String normalizeCodeforcesHandle(String input) {
  final value = input.trim();
  if (value.isEmpty) {
    throw FetchException('Codeforces 请填写 handle 或完整主页链接');
  }

  Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    uri = Uri.tryParse('https://$value');
  }

  if (uri != null &&
      uri.host.toLowerCase().replaceFirst('www.', '') == 'codeforces.com') {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'profile') {
      final handle = Uri.decodeComponent(segments[1]).trim();
      if (handle.isNotEmpty) {
        return handle;
      }
    }
    throw FetchException('Codeforces 请填写 handle 或完整主页链接');
  }

  if (value.contains('/') || value.contains('?') || value.contains('#')) {
    throw FetchException('Codeforces 请填写 handle 或完整主页链接');
  }
  return value;
}

int? parseCodeforcesProfileSolvedCount(String html) {
  final document = html_parser.parse(html);
  final bodyText = document.body?.text ?? document.documentElement?.text ?? '';
  final candidates = <String>[
    bodyText,
    html.replaceAll(RegExp(r'<[^>]+>'), ' '),
    html,
  ];
  final patterns = <RegExp>[
    RegExp(
      r'\bproblems?\s+solved\b[^\d]{0,120}([0-9][0-9,]*)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bsolved\s+problems?\b[^\d]{0,120}([0-9][0-9,]*)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bproblem\s+solved\b[^\d]{0,120}([0-9][0-9,]*)',
      caseSensitive: false,
    ),
  ];

  for (final candidate in candidates) {
    final normalized = candidate.replaceAll(RegExp(r'\s+'), ' ');
    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        return int.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
  }
  return null;
}

int parseCodeforcesOjhuntSolvedCount(Map<String, dynamic> data) {
  if (data['error'] == true) {
    throw FetchException(data['message']?.toString() ?? 'Codeforces 返回异常');
  }
  final payload = data['data'];
  if (payload is Map && payload['solved'] is num) {
    return (payload['solved'] as num).toInt();
  }
  throw FetchException('Codeforces 返回格式变化');
}

String? codeforcesProblemKey(Map problem) {
  final contestId = problem['contestId'];
  final index = problem['index'];
  if (contestId != null && index != null) {
    return 'contest:$contestId/$index';
  }

  final problemsetName = problem['problemsetName'];
  if (problemsetName != null && index != null) {
    return 'problemset:$problemsetName/$index';
  }

  final name = problem['name'];
  if (name != null) {
    return 'name:$name';
  }

  return null;
}

int countCodeforcesSolvedSubmissions(List<dynamic> submissions) {
  final solved = <String>{};
  for (final item in submissions) {
    if (item is! Map || item['verdict'] != 'OK') {
      continue;
    }
    final problem = item['problem'];
    if (problem is Map) {
      final key = codeforcesProblemKey(problem);
      if (key != null) {
        solved.add(key);
      }
    }
  }
  return solved.length;
}

Future<int> fetchCodeforcesSolvedCountFromOjhunt(
  http.Client client,
  String handle,
) async {
  final data = await readJson(
    client,
    Uri.https('ojhunt.com', '/api/crawlers/codeforces/$handle'),
  );
  return parseCodeforcesOjhuntSolvedCount(data);
}

Future<int> fetchCodeforcesSolvedCountFromSubmissions(
  http.Client client,
  String handle,
) async {
  final data = await readJson(
    client,
    Uri.https('codeforces.com', '/api/user.status', {
      'handle': handle,
      'from': '1',
      'count': '100000',
    }),
  );
  if (data['status'] != 'OK') {
    throw FetchException(data['comment']?.toString() ?? 'Codeforces 返回异常');
  }
  final result = data['result'];
  if (result is! List) {
    throw FetchException('Codeforces 返回格式变化');
  }
  return countCodeforcesSolvedSubmissions(result);
}
