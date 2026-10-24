import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_info.dart';

enum UpdateStatus { available, current, noStableRelease }

class UpdateCheckResult {
  const UpdateCheckResult(this.status, {this.version, this.downloadUrl});
  final UpdateStatus status;
  final String? version;
  final Uri? downloadUrl;
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<UpdateCheckResult> check({String currentVersion = appVersion}) async {
    final current = _Version.parse(currentVersion);
    final request = http.Request(
        'GET',
        Uri.parse(
            'https://api.github.com/repos/ZuesHans/oj-desktop-widget/releases/latest'))
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'OJ-Float/$currentVersion',
      });
    return _check(request, current).timeout(const Duration(seconds: 10));
  }

  Future<UpdateCheckResult> _check(
      http.Request request, _Version current) async {
    final response = await _client.send(request);
    if (response.statusCode == 404) {
      await response.stream.drain<void>();
      return const UpdateCheckResult(UpdateStatus.noStableRelease);
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw Exception(response.statusCode == 403 || response.statusCode == 429
          ? '检查次数过多，请稍后再试。'
          : '更新服务暂时不可用（${response.statusCode}）。');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (bytes.length > 256 * 1024) {
        throw const FormatException('更新信息过大，请前往发布页面查看。');
      }
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map ||
        data['draft'] != false ||
        data['prerelease'] != false ||
        data['tag_name'] is! String) {
      throw const FormatException('更新信息无效，请前往发布页面查看。');
    }
    final tag = data['tag_name'] as String;
    final version = _Version.parse(tag);
    if (version.prerelease.isNotEmpty) {
      throw const FormatException('更新服务返回了预发行版本。');
    }
    if (version.compareTo(current) <= 0) {
      return UpdateCheckResult(UpdateStatus.current, version: tag);
    }
    final page = _releaseLink(data['html_url'], download: false);
    var download = page;
    if (data['assets'] is List) {
      for (final asset in data['assets'] as List) {
        if (asset is Map &&
            asset['name'] is String &&
            (asset['name'] as String).endsWith('-windows-x64-setup.exe')) {
          download =
              _releaseLink(asset['browser_download_url'], download: true);
          break;
        }
      }
    }
    return UpdateCheckResult(UpdateStatus.available,
        version: tag, downloadUrl: download);
  }

  Uri _releaseLink(Object? value, {required bool download}) {
    final uri = value is String ? Uri.tryParse(value) : null;
    final prefix =
        '/ZuesHans/oj-desktop-widget/releases/${download ? 'download/' : 'tag/'}';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        !uri.path.startsWith(prefix) ||
        uri.pathSegments.any((s) => s == '..')) {
      throw const FormatException('更新下载地址无效，请前往发布页面查看。');
    }
    return uri;
  }

  void dispose() => _client.close();
}

class _Version implements Comparable<_Version> {
  _Version(this.parts, this.prerelease);
  final List<int> parts;
  final String prerelease;

  factory _Version.parse(String value) {
    final match = RegExp(
            r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$')
        .firstMatch(value);
    if (match == null) throw const FormatException('无法识别版本号。');
    return _Version(
        [for (var i = 1; i <= 3; i++) int.parse(match[i]!)], match[4] ?? '');
  }

  @override
  int compareTo(_Version other) {
    for (var i = 0; i < parts.length; i++) {
      final result = parts[i].compareTo(other.parts[i]);
      if (result != 0) return result;
    }
    if (prerelease.isEmpty && other.prerelease.isNotEmpty) return 1;
    if (prerelease.isNotEmpty && other.prerelease.isEmpty) return -1;
    final left = prerelease.split('.');
    final right = other.prerelease.split('.');
    for (var i = 0; i < left.length && i < right.length; i++) {
      final ln = int.tryParse(left[i]);
      final rn = int.tryParse(right[i]);
      final result = ln != null && rn != null
          ? ln.compareTo(rn)
          : ln != null
              ? -1
              : rn != null
                  ? 1
                  : left[i].compareTo(right[i]);
      if (result != 0) return result;
    }
    return left.length.compareTo(right.length);
  }
}
