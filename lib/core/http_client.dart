part of '../main.dart';

Future<Map<String, dynamic>> readJson(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
}) async {
  final response = await client
      .get(uri, headers: headers ?? defaultHeaders())
      .timeout(const Duration(seconds: 18));
  ensureOk(response);
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Map<String, String> defaultHeaders({
  String? referer,
  String? contentType,
  String? requestedWith,
}) {
  return {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0 Safari/537.36',
    'Accept': 'application/json,text/html,application/xhtml+xml',
    if (referer != null) 'Referer': referer,
    if (contentType != null) 'Content-Type': contentType,
    if (requestedWith != null) 'X-Requested-With': requestedWith,
  };
}

void ensureOk(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw FetchException('HTTP ${response.statusCode}');
  }
}
