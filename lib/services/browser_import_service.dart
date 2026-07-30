import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/errors.dart';
import '../core/solved_totals.dart';

const defaultBrowserImportPort = 27121;

class BrowserProblemImport {
  const BrowserProblemImport({
    required this.url,
    required this.title,
    required this.platform,
    required this.externalId,
    required this.tags,
    required this.difficulty,
  });

  factory BrowserProblemImport.fromJson(Map<String, dynamic> json) {
    final url = json['url'];
    final title = json['title'];
    final platform = json['platform'];
    final externalId = json['externalId'];
    final difficulty = json['difficulty'];
    final rawTags = json['tags'];
    if (url is! String || url.trim().isEmpty || url.length > 4096) {
      throw const FormatException('url 字段无效');
    }
    if (title != null && (title is! String || title.length > 500)) {
      throw const FormatException('title 字段无效');
    }
    if (platform != null && (platform is! String || platform.length > 40)) {
      throw const FormatException('platform 字段无效');
    }
    if (externalId != null &&
        (externalId is! String || externalId.length > 200)) {
      throw const FormatException('externalId 字段无效');
    }
    if (difficulty != null &&
        (difficulty is! String || difficulty.length > 100)) {
      throw const FormatException('difficulty 字段无效');
    }
    if (rawTags != null && rawTags is! List) {
      throw const FormatException('tags 字段无效');
    }
    final tags = <String>[];
    for (final item in rawTags is List ? rawTags.take(30) : const []) {
      if (item is! String || item.length > 100) {
        throw const FormatException('tags 字段无效');
      }
      final normalized = item.trim();
      if (normalized.isNotEmpty && !tags.contains(normalized)) {
        tags.add(normalized);
      }
    }
    return BrowserProblemImport(
      url: url.trim(),
      title: (title as String?)?.trim() ?? '',
      platform: (platform as String?)?.trim() ?? '',
      externalId: (externalId as String?)?.trim() ?? '',
      tags: List.unmodifiable(tags),
      difficulty: (difficulty as String?)?.trim() ?? '',
    );
  }

  final String url;
  final String title;
  final String platform;
  final String externalId;
  final List<String> tags;
  final String difficulty;
}

class BrowserProblemImportResult {
  const BrowserProblemImportResult({
    required this.created,
    required this.problemId,
  });

  final bool created;
  final String problemId;

  Map<String, dynamic> toJson() => {
        'status': created ? 'created' : 'existing',
        'problemId': problemId,
      };
}

abstract class BrowserImportTokenStore {
  Future<String> getOrCreateToken();
  Future<String> rotateToken();
}

class SecureBrowserImportTokenStore implements BrowserImportTokenStore {
  SecureBrowserImportTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'oj_float_browser_import_token_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String> getOrCreateToken() async {
    final existing = (await _storage.read(key: _key))?.trim() ?? '';
    if (existing.isNotEmpty) {
      return existing;
    }
    return rotateToken();
  }

  @override
  Future<String> rotateToken() async {
    final token = _randomToken();
    await _storage.write(key: _key, value: token);
    return token;
  }
}

class MemoryBrowserImportTokenStore implements BrowserImportTokenStore {
  MemoryBrowserImportTokenStore([String token = '']) : _token = token;

  String _token;

  @override
  Future<String> getOrCreateToken() async {
    if (_token.isEmpty) {
      _token = _randomToken();
    }
    return _token;
  }

  @override
  Future<String> rotateToken() async {
    _token = _randomToken();
    return _token;
  }
}

typedef BrowserProblemImporter = Future<BrowserProblemImportResult> Function(
  BrowserProblemImport problem,
);

class BrowserImportServer {
  BrowserImportServer({
    this.port = defaultBrowserImportPort,
    this.maxRequestBytes = 64 * 1024,
  });

  final int port;
  final int maxRequestBytes;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  String _token = '';
  BrowserProblemImporter? _importer;

  bool get isRunning => _server != null;
  int? get boundPort => _server?.port;

  Future<void> start({
    required String token,
    required BrowserProblemImporter importer,
  }) async {
    if (token.trim().isEmpty) {
      throw FetchException('浏览器导入令牌不能为空。');
    }
    if (_server != null) {
      _token = token.trim();
      _importer = importer;
      return;
    }
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      shared: false,
    );
    _token = token.trim();
    _importer = importer;
    _server = server;
    _subscription = server.listen((request) {
      unawaited(_handle(request));
    });
  }

  Future<void> updateToken(String token) async {
    if (token.trim().isEmpty) {
      throw FetchException('浏览器导入令牌不能为空。');
    }
    _token = token.trim();
  }

  Future<void> stop() async {
    final subscription = _subscription;
    final server = _server;
    _subscription = null;
    _server = null;
    _importer = null;
    if (subscription != null) {
      await subscription.cancel();
    }
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    _writeCorsHeaders(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    if (request.method != 'POST' || request.uri.path != '/v1/problems/import') {
      await _writeJson(
        request.response,
        HttpStatus.notFound,
        const {'error': 'not_found'},
      );
      return;
    }
    final authorization =
        request.headers.value(HttpHeaders.authorizationHeader);
    final candidate = authorization?.startsWith('Bearer ') == true
        ? authorization!.substring(7).trim()
        : '';
    if (!_constantTimeEquals(candidate, _token)) {
      await _writeJson(
        request.response,
        HttpStatus.unauthorized,
        const {'error': 'invalid_token'},
      );
      return;
    }
    try {
      final bytes = <int>[];
      var tooLarge = false;
      await for (final chunk in request) {
        if (!tooLarge && bytes.length + chunk.length <= maxRequestBytes) {
          bytes.addAll(chunk);
        } else {
          tooLarge = true;
        }
      }
      if (tooLarge) {
        throw const _PayloadTooLargeException();
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('请求体必须是 JSON 对象');
      }
      final problem = BrowserProblemImport.fromJson(
        decoded.cast<String, dynamic>(),
      );
      final importer = _importer;
      if (importer == null) {
        throw FetchException('桌面客户端导入服务尚未就绪。');
      }
      final result = await importer(problem);
      await _writeJson(request.response, HttpStatus.ok, result.toJson());
    } on _PayloadTooLargeException {
      await _writeJson(
        request.response,
        HttpStatus.requestEntityTooLarge,
        const {'error': 'payload_too_large'},
      );
    } on FormatException catch (error) {
      await _writeJson(
        request.response,
        HttpStatus.badRequest,
        {'error': 'invalid_payload', 'message': error.message},
      );
    } catch (error) {
      await _writeJson(
        request.response,
        HttpStatus.internalServerError,
        {'error': 'import_failed', 'message': normalizeError(error)},
      );
    }
  }
}

class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException();
}

String _randomToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

bool _constantTimeEquals(String left, String right) {
  var difference = left.length ^ right.length;
  final length = max(left.length, right.length);
  for (var index = 0; index < length; index += 1) {
    final leftCode = index < left.length ? left.codeUnitAt(index) : 0;
    final rightCode = index < right.length ? right.codeUnitAt(index) : 0;
    difference |= leftCode ^ rightCode;
  }
  return difference == 0;
}

void _writeCorsHeaders(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'POST, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Authorization, Content-Type')
    ..set('Cache-Control', 'no-store');
}

Future<void> _writeJson(
  HttpResponse response,
  int statusCode,
  Map<String, dynamic> body,
) async {
  response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await response.close();
}
