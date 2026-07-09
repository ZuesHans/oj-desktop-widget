import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/http_client.dart';
import '../core/solved_totals.dart';
import '../models/fetch_result.dart';
import 'oj_provider.dart';

class NowcoderProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final account = normalizeNowcoderUserId(username);
    var profileUri = nowcoderProfileUri(account);
    Object? ojhuntError;
    try {
      final data = await readJson(
        client,
        Uri.https('ojhunt.com', '/api/crawlers/nowcoder/$account'),
      );
      return OjProfile(
        solvedCount: parseNowcoderOjhuntSolvedCount(data),
        profileUrl: profileUri.toString(),
        source: 'ojhunt',
      );
    } catch (error) {
      ojhuntError = error;
    }

    try {
      if (!isNowcoderNumericUserId(account)) {
        final resolvedId = await resolveNowcoderUserId(client, account);
        profileUri = nowcoderProfileUri(resolvedId);
      }
      final response =
          await client.get(profileUri, headers: defaultHeaders()).timeout(
                const Duration(seconds: 18),
              );
      ensureOk(response);
      return OjProfile(
        solvedCount: parseNowcoderSolvedCount(response.body),
        profileUrl: profileUri.toString(),
        source: 'profile_html',
      );
    } catch (error) {
      throw FetchException(
        '牛客获取失败：OJ Hunt 接口失败 ${normalizeError(ojhuntError)}；'
        '主页解析失败 ${normalizeError(error)}。'
        '如果填写的是昵称，请改用牛客个人主页里的数字用户 ID',
      );
    }
  }
}

String normalizeNowcoderUserId(String value) {
  final input = value.trim();
  if (input.isEmpty) {
    throw FetchException('牛客用户请输入数字用户 ID、用户名，或完整主页链接');
  }
  final uri = Uri.tryParse(input);
  if (uri != null &&
      uri.host.toLowerCase().endsWith('nowcoder.com') &&
      uri.pathSegments.length >= 2 &&
      uri.pathSegments[0] == 'users' &&
      uri.pathSegments[1].trim().isNotEmpty) {
    return uri.pathSegments[1];
  }
  return input;
}

bool isNowcoderNumericUserId(String value) => RegExp(r'^\d+$').hasMatch(value);

Uri nowcoderProfileUri(String account) {
  if (isNowcoderNumericUserId(account)) {
    return Uri.https('www.nowcoder.com', '/users/$account');
  }
  return Uri.https('www.nowcoder.com', '/search/all', {'query': account});
}

Future<String> resolveNowcoderUserId(
    http.Client client, String nickname) async {
  final response = await client
      .get(
        Uri.https('www.nowcoder.com', '/search/all', {'query': nickname}),
        headers: defaultHeaders(),
      )
      .timeout(const Duration(seconds: 18));
  ensureOk(response);
  final userId = parseNowcoderSearchUserId(nickname, response.body);
  if (userId == null) {
    throw FetchException('牛客昵称 "$nickname" 未能解析到精确用户，请填写数字用户 ID');
  }
  return userId;
}

String? parseNowcoderSearchUserId(String nickname, String body) {
  final normalizedNickname = nickname.trim().toLowerCase();
  final userBriefPattern = RegExp(
    r'"userId"\s*:\s*(\d+)\s*,\s*"nickname"\s*:\s*"([^"]+)"',
  );
  for (final match in userBriefPattern.allMatches(body)) {
    final foundNickname = match.group(2)?.trim().toLowerCase();
    if (foundNickname == normalizedNickname) {
      return match.group(1);
    }
  }
  return null;
}

int parseNowcoderOjhuntSolvedCount(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map) {
    final solved = data['solved'];
    if (solved is int) {
      return solved;
    }
    if (solved is num) {
      return solved.toInt();
    }
    if (solved is String) {
      final parsed = int.tryParse(solved);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  throw FetchException('OJ Hunt 牛客接口未返回 data.solved');
}

int parseNowcoderSolvedCount(String body) {
  const jsonFields = [
    'acceptedCount',
    'acceptCount',
    'acCount',
    'solvedCount',
    'passedProblemCount',
  ];
  for (final field in jsonFields) {
    final match = RegExp('"$field"\\s*:\\s*(\\d+)').firstMatch(body);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
  }

  final labelPattern = RegExp(r'(?:通过题目|已通过|AC题数)[^0-9]{0,80}(\d+)');
  final rawTextMatch = labelPattern.firstMatch(body);
  if (rawTextMatch != null) {
    return int.parse(rawTextMatch.group(1)!);
  }

  final document = html_parser.parse(body);
  final text = document.body?.text ?? '';
  final textMatch = labelPattern.firstMatch(text);
  if (textMatch != null) {
    return int.parse(textMatch.group(1)!);
  }
  throw FetchException('牛客页面未找到通过题目数，请确认主页可公开访问或页面结构未变更');
}
