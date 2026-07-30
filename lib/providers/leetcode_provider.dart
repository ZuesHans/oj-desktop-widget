import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/http_client.dart';
import '../models/fetch_result.dart';
import 'oj_provider.dart';

class LeetCodeProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final response = await client
        .post(
          Uri.https('leetcode.com', '/graphql'),
          headers: defaultHeaders(
            referer: 'https://leetcode.com/$username/',
            contentType: 'application/json',
          ),
          body: jsonEncode({
            'query': '''
query userSessionProgress(\$username: String!) {
  matchedUser(username: \$username) {
    submitStatsGlobal {
      acSubmissionNum {
        difficulty
        count
      }
    }
  }
}
''',
            'variables': {'username': username},
          }),
        )
        .timeout(const Duration(seconds: 18));
    ensureOk(response);
    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw FetchException('LeetCode 返回格式变化');
    }
    if (decoded is! Map) {
      throw FetchException('LeetCode 返回格式变化');
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw FetchException('LeetCode 返回格式变化');
    }
    final matchedUser = data['matchedUser'];
    if (matchedUser == null) {
      throw FetchException('LeetCode 用户不存在或不可公开访问');
    }
    if (matchedUser is! Map) {
      throw FetchException('LeetCode 返回格式变化');
    }
    final submitStats = matchedUser['submitStatsGlobal'];
    final list = submitStats is Map ? submitStats['acSubmissionNum'] : null;
    if (list is! List) {
      throw FetchException('LeetCode 返回格式变化');
    }
    Map? all;
    for (final item in list) {
      if (item is Map && item['difficulty'] == 'All') {
        all = item;
        break;
      }
    }
    final count = all?['count'];
    if (count is! int) {
      throw FetchException('LeetCode 返回格式变化');
    }
    return OjProfile(
      solvedCount: count,
      profileUrl: 'https://leetcode.com/$username/',
      source: 'leetcode_graphql',
    );
  }
}
