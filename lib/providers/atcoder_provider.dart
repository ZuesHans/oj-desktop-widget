import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/http_client.dart';
import '../models/fetch_result.dart';
import 'oj_provider.dart';

class AtCoderProvider implements OjProvider, OjDailyActivityProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final data = await readJson(
      client,
      Uri.https('kenkoooo.com', '/atcoder/atcoder-api/v3/user/ac_rank', {
        'user': username,
      }),
    );
    final count = data['count'];
    if (count is! int) {
      throw FetchException('AtCoder 统计接口未返回通过数');
    }
    return OjProfile(
      solvedCount: count,
      profileUrl: 'https://atcoder.jp/users/$username',
      source: 'kenkoooo_ac_rank',
    );
  }

  @override
  Future<OjDailyActivity> fetchDailyActivity(
    http.Client client,
    String username, {
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await client
        .get(
          Uri.https(
            'kenkoooo.com',
            '/atcoder/atcoder-api/v3/user/submissions',
            {
              'user': username,
              'from_second':
                  '${start.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond}',
            },
          ),
          headers: defaultHeaders(),
        )
        .timeout(const Duration(seconds: 18));
    ensureOk(response);
    final data = jsonDecode(response.body);
    if (data is! List) {
      throw FetchException('AtCoder submissions 返回格式变化');
    }
    return OjDailyActivity(
      acceptedCount: countAtCoderAcceptedSubmissionsInWindow(
        data,
        start,
        end,
      ),
      source: 'kenkoooo_user_submissions_daily',
    );
  }
}

int countAtCoderAcceptedSubmissionsInWindow(
  List<dynamic> submissions,
  DateTime start,
  DateTime end,
) {
  final solved = <String>{};
  for (final item in submissions) {
    if (item is! Map || item['result'] != 'AC') {
      continue;
    }
    final seconds = item['epoch_second'];
    final problemId = item['problem_id'];
    if (seconds is! num || problemId is! String || problemId.isEmpty) {
      continue;
    }
    final submittedAt = DateTime.fromMillisecondsSinceEpoch(
      seconds.toInt() * 1000,
    ).toLocal();
    if (submittedAt.isBefore(start) || !submittedAt.isBefore(end)) {
      continue;
    }
    solved.add(problemId);
  }
  return solved.length;
}
