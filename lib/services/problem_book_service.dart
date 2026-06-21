part of '../main.dart';

class ParsedProblemLink {
  const ParsedProblemLink({
    required this.title,
    required this.url,
    required this.platform,
  });

  final String title;
  final String url;
  final ProblemPlatform platform;
}

class ProblemBookService {
  ProblemBookService({required this.client});

  final http.Client client;

  List<ProblemRecord> upsert(
    List<ProblemRecord> problems,
    ProblemRecord problem,
  ) {
    final updated = <ProblemRecord>[];
    var replaced = false;
    for (final item in problems) {
      if (item.id == problem.id) {
        updated.add(problem);
        replaced = true;
      } else {
        updated.add(item);
      }
    }
    if (!replaced) {
      updated.add(problem);
    }
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(updated);
  }

  List<ProblemRecord> remove(List<ProblemRecord> problems, String id) {
    return List.unmodifiable(problems.where((item) => item.id != id));
  }

  List<ProblemRecord> filter(
    List<ProblemRecord> problems, {
    String query = '',
    ProblemStatus? status,
    ProblemPlatform? platform,
  }) {
    return filterProblems(
      problems,
      query: query,
      status: status,
      platform: platform,
    );
  }

  Future<ParsedProblemLink> parseLink(String input) async {
    final uri = normalizeProblemUri(input);
    final platform = detectProblemPlatform(uri);
    final fallback = fallbackProblemTitle(uri, platform);
    var title = fallback;
    try {
      final response = await client
          .get(uri,
              headers: defaultHeaders(referer: '${uri.scheme}://${uri.host}/'))
          .timeout(const Duration(seconds: 18));
      ensureOk(response);
      title = parseProblemTitle(response.body, platform) ?? fallback;
    } catch (_) {
      title = fallback;
    }
    return ParsedProblemLink(
      title: title,
      url: uri.toString(),
      platform: platform,
    );
  }

  void dispose() => client.close();
}

List<ProblemRecord> filterProblems(
  List<ProblemRecord> problems, {
  String query = '',
  ProblemStatus? status,
  ProblemPlatform? platform,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  return List.unmodifiable(problems.where((problem) {
    if (status != null && problem.status != status) {
      return false;
    }
    if (platform != null && problem.platform != platform) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final haystack = [
      problem.title,
      problem.url,
      problem.note,
      problem.analysis,
      ...problem.tags,
    ].join('\n').toLowerCase();
    return haystack.contains(normalizedQuery);
  }));
}

Uri normalizeProblemUri(String input) {
  final value = input.trim();
  if (value.isEmpty) {
    throw FetchException('请输入题目链接');
  }
  final withScheme = value.contains('://') ? value : 'https://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.trim().isEmpty) {
    throw FetchException('题目链接格式不正确');
  }
  return uri;
}

ProblemPlatform detectProblemPlatform(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host == 'codeforces.com') {
    return ProblemPlatform.cf;
  }
  if (host == 'atcoder.jp') {
    return ProblemPlatform.atcoder;
  }
  if (host == 'hdu.edu.cn' || host == 'acm.hdu.edu.cn') {
    return ProblemPlatform.hd;
  }
  if (host == 'luogu.com.cn') {
    return ProblemPlatform.lg;
  }
  if (host == 'poj.org' || host == 'poj.org.cn') {
    return ProblemPlatform.poj;
  }
  if (host.contains('onlinejudge.org')) {
    return ProblemPlatform.uva;
  }
  if (host == 'nowcoder.com' ||
      host == 'ac.nowcoder.com' ||
      host.endsWith('.nowcoder.com')) {
    return ProblemPlatform.nc;
  }
  if (host == 'spoj.com' || host.endsWith('.spoj.com')) {
    return ProblemPlatform.spoj;
  }
  if (host == 'leetcode.cn' || host.endsWith('.leetcode.cn')) {
    return ProblemPlatform.lccn;
  }
  return ProblemPlatform.other;
}

String fallbackProblemTitle(Uri uri, ProblemPlatform platform) {
  switch (platform) {
    case ProblemPlatform.cf:
      final cf = _codeforcesProblemCode(uri);
      return cf == null ? 'Codeforces Problem' : 'CF $cf';
    case ProblemPlatform.lg:
      final id = _lastUsefulSegment(uri);
      return id == null ? '洛谷题目' : '洛谷 $id';
    case ProblemPlatform.nc:
      final id = _lastUsefulSegment(uri);
      return id == null ? '牛客题目' : '牛客 $id';
    case ProblemPlatform.atcoder:
      final id = _lastUsefulSegment(uri);
      return id == null ? 'AtCoder Problem' : 'AtCoder $id';
    case ProblemPlatform.hd:
      final id = uri.queryParameters['pid'] ?? _lastUsefulSegment(uri);
      return id == null ? 'HDU Problem' : 'HDU $id';
    case ProblemPlatform.poj:
      final id = uri.queryParameters['id'] ?? _lastUsefulSegment(uri);
      return id == null ? 'POJ Problem' : 'POJ $id';
    case ProblemPlatform.uva:
      final id = _lastUsefulSegment(uri);
      return id == null ? 'UVA Problem' : 'UVA $id';
    case ProblemPlatform.spoj:
      final id = _lastUsefulSegment(uri);
      return id == null ? 'SPOJ Problem' : 'SPOJ $id';
    case ProblemPlatform.lccn:
      final id = _lastUsefulSegment(uri);
      return id == null ? 'LeetCode CN Problem' : 'LeetCode $id';
    case ProblemPlatform.other:
      return _lastUsefulSegment(uri) ?? uri.host;
  }
}

String? parseProblemTitle(String html, ProblemPlatform platform) {
  switch (platform) {
    case ProblemPlatform.cf:
      return parseCodeforcesProblemTitle(html);
    case ProblemPlatform.lg:
      return parseLuoguProblemTitle(html);
    default:
      return parseGenericProblemTitle(html);
  }
}

String? parseCodeforcesProblemTitle(String html) {
  final document = html_parser.parse(html);
  final header = document.querySelector('.problem-statement .title')?.text;
  final normalizedHeader = _cleanProblemTitle(header);
  if (normalizedHeader != null) {
    return normalizedHeader.replaceFirst(RegExp(r'^[A-Z][0-9]?\.\s*'), '');
  }
  return parseGenericProblemTitle(html)?.replaceAll(' - Codeforces', '').trim();
}

String? parseLuoguProblemTitle(String html) {
  final injection = RegExp(
    r'window\._feInjection\s*=\s*JSON\.parse\("(.*?)"\)',
    dotAll: true,
  ).firstMatch(html);
  if (injection != null) {
    try {
      final raw = injection.group(1)!;
      final decodedText = jsonDecode('"$raw"') as String;
      final decoded = jsonDecode(decodedText);
      if (decoded is Map) {
        final currentData = decoded['currentData'];
        if (currentData is Map) {
          final problem = currentData['problem'];
          if (problem is Map) {
            final title = _cleanProblemTitle(problem['title']?.toString());
            if (title != null) {
              return title;
            }
          }
        }
      }
    } catch (_) {
      // Fall back to HTML title parsing below.
    }
  }
  final generic = parseGenericProblemTitle(html);
  if (generic == null) {
    return null;
  }
  return generic
      .replaceAll(RegExp(r'\s*-\s*洛谷.*$'), '')
      .replaceAll(RegExp(r'\s*-\s*Luogu.*$', caseSensitive: false), '')
      .trim();
}

String? parseGenericProblemTitle(String html) {
  final document = html_parser.parse(html);
  final selectors = ['h1', '.title', 'title'];
  for (final selector in selectors) {
    final text = _cleanProblemTitle(document.querySelector(selector)?.text);
    if (text != null) {
      return text;
    }
  }
  return null;
}

String? _codeforcesProblemCode(Uri uri) {
  final segments = uri.pathSegments;
  final problemsetIndex = segments.indexOf('problem');
  if (segments.length >= problemsetIndex + 3 &&
      problemsetIndex >= 0 &&
      segments.contains('problemset')) {
    return '${segments[problemsetIndex + 1]}${segments[problemsetIndex + 2]}';
  }
  final contestIndex = segments.indexOf('contest');
  if (contestIndex >= 0 &&
      segments.length >= contestIndex + 4 &&
      segments[contestIndex + 2] == 'problem') {
    return '${segments[contestIndex + 1]}${segments[contestIndex + 3]}';
  }
  return null;
}

String? _lastUsefulSegment(Uri uri) {
  final segments = uri.pathSegments
      .map(Uri.decodeComponent)
      .where((segment) => segment.trim().isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return null;
  }
  return segments.last.trim();
}

String? _cleanProblemTitle(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}
