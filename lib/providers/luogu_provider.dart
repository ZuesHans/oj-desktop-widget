import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/http_client.dart';
import '../models/fetch_result.dart';
import 'oj_provider.dart';

class LuoguProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final input = normalizeLuoguUserInput(username);
    final uid = int.tryParse(input) != null
        ? input
        : await fetchLuoguUidByKeyword(client, input);
    final uri = Uri.https('www.luogu.com.cn', '/user/$uid');
    final response = await client
        .get(
          uri,
          headers: defaultHeaders(referer: 'https://www.luogu.com.cn/'),
        )
        .timeout(const Duration(seconds: 18));
    ensureOk(response);
    return OjProfile(
      solvedCount: parseLuoguSolvedCount(response.body),
      profileUrl: uri.toString(),
      source: 'luogu_profile_html',
    );
  }
}

String normalizeLuoguUserInput(String input) {
  final value = input.trim();
  if (value.isEmpty) {
    throw FetchException('洛谷请填写 UID、用户名或完整主页链接');
  }

  Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    uri = Uri.tryParse('https://$value');
  }

  if (uri != null &&
      uri.host.toLowerCase().replaceFirst('www.', '') == 'luogu.com.cn') {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'user') {
      final uid = Uri.decodeComponent(segments[1]).trim();
      if (uid.isNotEmpty) {
        return uid;
      }
    }
    throw FetchException('洛谷请填写 UID、用户名或完整主页链接');
  }

  if (value.contains('/') || value.contains('?') || value.contains('#')) {
    throw FetchException('洛谷请填写 UID、用户名或完整主页链接');
  }
  return value;
}

Future<String> fetchLuoguUidByKeyword(
    http.Client client, String keyword) async {
  final data = await readJson(
    client,
    Uri.https('www.luogu.com.cn', '/api/user/search', {'keyword': keyword}),
    headers: defaultHeaders(
      referer: 'https://www.luogu.com.cn/',
      requestedWith: 'XMLHttpRequest',
    ),
  );
  final users = data['users'];
  if (users is! List || users.isEmpty) {
    throw FetchException('洛谷未找到用户：$keyword');
  }
  final exact = users.cast<Object?>().whereType<Map>().firstWhere(
        (user) => user['name']?.toString() == keyword,
        orElse: () => users.first as Map,
      );
  final uid = exact['uid'];
  if (uid == null) {
    throw FetchException('洛谷搜索结果缺少 UID');
  }
  return uid.toString();
}

int parseLuoguSolvedCount(String body) {
  final patterns = [
    RegExp(r'"passedProblemCount"\s*:\s*(\d+)'),
    RegExp(r'"acceptedProblemCount"\s*:\s*(\d+)'),
    RegExp(r'passedProblemCount\?":\s*(\d+)'),
    RegExp(r'acceptedProblemCount\?":\s*(\d+)'),
    RegExp(r'通过题目\s*</[^>]+>\s*<[^>]+>\s*(\d+)'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(body);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
  }
  throw FetchException('洛谷页面未找到通过题数');
}
