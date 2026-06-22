import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/http_client.dart';
import '../models/fetch_result.dart';
import 'oj_provider.dart';

class AtCoderProvider implements OjProvider {
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
}
