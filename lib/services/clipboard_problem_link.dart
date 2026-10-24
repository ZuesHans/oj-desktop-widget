/// Only recognize supported OJ problem pages, never arbitrary clipboard text,
/// account/profile pages, or a lookalike host. Recognition performs no I/O.
String? findClipboardProblemLink(String text) {
  for (final match in RegExp(r'''https?://[^\s<>"'`]+''', caseSensitive: false)
      .allMatches(text)) {
    final candidate = match
        .group(0)!
        .replaceFirst(RegExp(r'''[.,;:!?，。；：！？、)\]}）】》]+$'''), '');
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        !['http', 'https'].contains(uri.scheme)) {
      continue;
    }
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final path = uri.path;
    final supported = switch (host) {
      'codeforces.com' => RegExp(
              r'^/(?:problemset/problem/\d+/[A-Za-z0-9]+|(?:contest|gym)/\d+/problem/[A-Za-z0-9]+)/?$')
          .hasMatch(path),
      'atcoder.jp' => RegExp(r'^/contests/[^/]+/tasks/[^/]+/?$').hasMatch(path),
      'luogu.com.cn' => RegExp(r'^/problem/[^/]+/?$').hasMatch(path),
      'leetcode.cn' ||
      'leetcode.com' =>
        RegExp(r'^/problems/[^/]+(?:/.*)?$').hasMatch(path),
      'nowcoder.com' || 'ac.nowcoder.com' => RegExp(
              r'^/(?:acm/problem/\d+|acm/contest/\d+/[A-Za-z0-9]+|practice/[A-Za-z0-9]+)(?:/.*)?$')
          .hasMatch(path),
      'hdu.edu.cn' ||
      'acm.hdu.edu.cn' =>
        path.endsWith('/showproblem.php') && _hasId(uri, 'pid'),
      'poj.org' || 'poj.org.cn' => path == '/problem' && _hasId(uri, 'id'),
      'onlinejudge.org' || 'uva.onlinejudge.org' => _hasId(uri, 'problem') ||
          RegExp(r'^/(?:external/\d+/\d+\.html|problem/\d+)/?$').hasMatch(path),
      'spoj.com' => RegExp(r'^/problems/[^/]+/?$').hasMatch(path),
      _ => false,
    };
    if (supported) return uri.toString();
  }
  return null;
}

bool _hasId(Uri uri, String key) =>
    RegExp(r'^\d+$').hasMatch(uri.queryParameters[key] ?? '');
