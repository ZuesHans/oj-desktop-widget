part of '../main.dart';

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
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final matchedUser = data['data']?['matchedUser'];
    if (matchedUser == null) {
      throw FetchException('LeetCode 用户不存在或不可公开访问');
    }
    final list = matchedUser['submitStatsGlobal']?['acSubmissionNum'];
    if (list is! List) {
      throw FetchException('LeetCode 返回格式变化');
    }
    final all = list.cast<Map<String, dynamic>>().firstWhere(
          (item) => item['difficulty'] == 'All',
          orElse: () => {'count': 0},
        );
    return OjProfile(
      solvedCount: all['count'] as int? ?? 0,
      profileUrl: 'https://leetcode.com/$username/',
    );
  }
}
