import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError;

import '../core/app_info.dart';
import '../models/app_config.dart';
import 'app_data_directory.dart';
import 'problem_database.dart';

/// Rotation and retention parameters for the on-disk diagnostics log.
///
/// These values are centralized here and documented in
/// [docs/diagnostics.md]. They are compile-time constants because the
/// diagnostics service is installed before any user configuration exists.
const diagnosticsActiveLogFileName = 'diagnostics.log';
const diagnosticsMaxFileBytes = 1 * 1024 * 1024; // 1 MiB per file.
const diagnosticsMaxRotatedFiles = 5; // keep at most 5 rotated files.
const diagnosticsMaxRecentOperations =
    20; // operation summaries kept in memory.
const diagnosticsMaxRecordMessageBytes = 8 * 1024;
const diagnosticsMaxRecordStackBytes = 16 * 1024;

/// Stable redaction aliases. Using the same alias for the same logical value
/// across records keeps a support bundle correlatable without leaking the
/// underlying secret or identity.
const diagnosticsOjUserAliasPrefix = '{oj_user_';
const diagnosticsLocalUserAlias = '{local_user}';
const diagnosticsUrlParameterAlias = '{url_param}';
const diagnosticsTokenAlias = '{token}';
const diagnosticsSensitiveValueAlias = '{redacted}';

/// Redacts secrets and identities from a single diagnostic string before it is
/// written to disk or exported.
///
/// The redactor is deliberately small and deterministic: the same account set
/// produces the same aliases, so `{oj_user_1}` refers to the same account
/// across all records captured during one run.
class DiagnosticsRedactor {
  DiagnosticsRedactor({List<String> ojUsernames = const []})
      : _ojAliases = _buildOjAliases(ojUsernames),
        _ojReplacementOrder = _buildOjReplacementOrder(ojUsernames);

  final Map<String, String> _ojAliases;
  final List<String> _ojReplacementOrder;

  static Map<String, String> _buildOjAliases(List<String> usernames) {
    final unique = <String>[];
    final seen = <String>{};
    for (final name in usernames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      unique.add(trimmed);
    }
    unique.sort();
    return {
      for (var i = 0; i < unique.length; i++)
        unique[i]: '$diagnosticsOjUserAliasPrefix${i + 1}}',
    };
  }

  static List<String> _buildOjReplacementOrder(List<String> usernames) {
    final unique = <String>{};
    for (final name in usernames) {
      final trimmed = name.trim();
      if (trimmed.isNotEmpty) {
        unique.add(trimmed);
      }
    }
    final ordered = unique.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return ordered;
  }

  String redact(String text) {
    if (text.isEmpty) {
      return text;
    }
    var result = text;

    // 1. Windows (and POSIX-style) absolute paths containing a user name.
    result = result.replaceAllMapped(_userPathPattern, (match) {
      final drive = match.group(1) ?? '';
      final separator = match.group(2) ?? '\\';
      return '${drive}Users$separator$diagnosticsLocalUserAlias';
    });

    // 2. Known OJ account names, longest first so compound names win.
    for (final username in _ojReplacementOrder) {
      final alias = _ojAliases[username];
      if (alias != null) {
        result = result.replaceAll(username, alias);
      }
    }

    // 3. Bearer-style tokens.
    result = result.replaceAllMapped(
      _bearerPattern,
      (_) => 'Bearer $diagnosticsTokenAlias',
    );

    // 4. Sensitive key=value pairs and URL query parameters.
    result = _redactSensitiveAssignments(result);
    result = _redactUrlParameters(result);

    return result;
  }

  static final RegExp _userPathPattern = RegExp(
    r'\b([A-Za-z]:[\\/]|/)?Users([\\/])([^\\/<>:"|?*\s]+)',
  );

  static final RegExp _bearerPattern = RegExp(
    r'\bBearer\s+\S+',
    caseSensitive: false,
  );

  static final RegExp _sensitiveAssignmentPattern = RegExp(
    r'\b(password|passwd|pwd|token|secret|api[_-]?key|apikey|'
    r'authorization|cookie|set-cookie|access[_-]?token|'
    r'refresh[_-]?token)\b\s*[=:]\s*([^\s&;,]+)',
    caseSensitive: false,
  );

  static final RegExp _urlPattern = RegExp(r'''https?://[^\s<>"'()\[\]]+''');

  String _redactSensitiveAssignments(String text) {
    return text.replaceAllMapped(_sensitiveAssignmentPattern, (match) {
      final key = match.group(1) ?? 'secret';
      return '$key=$diagnosticsSensitiveValueAlias';
    });
  }

  String _redactUrlParameters(String text) {
    return text.replaceAllMapped(_urlPattern, (match) {
      return _redactQueryValues(match.group(0)!);
    });
  }

  String _redactQueryValues(String url) {
    final hashIndex = url.indexOf('#');
    final fragment = hashIndex >= 0 ? url.substring(hashIndex) : '';
    final withoutFragment = hashIndex >= 0 ? url.substring(0, hashIndex) : url;
    final queryIndex = withoutFragment.indexOf('?');
    if (queryIndex < 0 || queryIndex == withoutFragment.length - 1) {
      return url;
    }
    final base = withoutFragment.substring(0, queryIndex + 1);
    final query = withoutFragment.substring(queryIndex + 1);
    final redacted = query.split('&').map((part) {
      final equals = part.indexOf('=');
      if (equals < 0) {
        return '$part=$diagnosticsUrlParameterAlias';
      }
      return '${part.substring(0, equals)}=$diagnosticsUrlParameterAlias';
    }).join('&');
    return '$base$redacted$fragment';
  }
}

/// Routes framework and unhandled asynchronous errors into
/// [DiagnosticsService.instance] without using a custom zone. Because the
/// binding and `runApp` share the root zone, the same error is recorded only
/// once.
void installDiagnosticsErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DiagnosticsService.instance?.recordError(
      eventType: 'framework_error',
      error: details.exception,
      stack: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagnosticsService.instance?.recordError(
      eventType: 'unhandled_async_error',
      error: error,
      stack: stack,
    );
    return true;
  };
}

/// Collects sanitized diagnostics records, rotates them on disk, and renders a
/// self-contained export bundle.
///
/// Every write path swallows failures so the diagnostics log can never recurse
/// into an error handler or prevent the application from exiting normally.
class DiagnosticsService {
  DiagnosticsService({
    Directory? logDirectory,
    DateTime Function()? clock,
    int maxFileBytes = diagnosticsMaxFileBytes,
    int maxRotatedFiles = diagnosticsMaxRotatedFiles,
  })  : _logDirectory = logDirectory,
        _clock = clock ?? DateTime.now,
        _maxFileBytes = maxFileBytes,
        _maxRotatedFiles = maxRotatedFiles;

  /// The process-wide service installed by [install]. Access it through this
  /// getter from services and UI that need to record an operation.
  static DiagnosticsService? instance;

  static DiagnosticsService install({
    Directory? logDirectory,
    DateTime Function()? clock,
    int maxFileBytes = diagnosticsMaxFileBytes,
    int maxRotatedFiles = diagnosticsMaxRotatedFiles,
  }) {
    final service = DiagnosticsService(
      logDirectory: logDirectory,
      clock: clock,
      maxFileBytes: maxFileBytes,
      maxRotatedFiles: maxRotatedFiles,
    );
    instance = service;
    return service;
  }

  final Directory? _logDirectory;
  final DateTime Function() _clock;
  final int _maxFileBytes;
  final int _maxRotatedFiles;
  DiagnosticsRedactor _redactor = DiagnosticsRedactor();
  final List<String> _recentOperations = [];
  Future<void> _writeTail = Future.value();

  String get _appVersionLabel => '$appVersion+$appBuildNumber';

  int get _configSchemaVersion => currentAppConfigVersion;

  int get _databaseSchemaVersion => ProblemDatabase.schemaVersion;

  List<String> get recentOperations => List.unmodifiable(_recentOperations);

  /// Registers the set of OJ account names that the redactor must replace with
  /// stable aliases. Call this whenever the configured accounts change.
  void updateKnownAccounts(Iterable<String> usernames) {
    _redactor = DiagnosticsRedactor(ojUsernames: usernames.toList());
  }

  /// Records a non-error event (for example, an operation summary).
  void recordEvent(String eventType, String message) {
    _record(eventType: eventType, message: message);
  }

  /// Records a concise operation summary and keeps it in the recent list used
  /// by the export bundle.
  void recordOperation(String summary) {
    final redacted = _redactor.redact(summary);
    _recentOperations.add(redacted);
    while (_recentOperations.length > diagnosticsMaxRecentOperations) {
      _recentOperations.removeAt(0);
    }
    _record(eventType: 'operation', message: redacted);
  }

  /// Records an error with an optional stack trace. The error handler must
  /// never observe an exception raised from here.
  void recordError({
    required String eventType,
    required Object error,
    StackTrace? stack,
  }) {
    final message = _redactor.redact(_describeError(error));
    final stackText = stack == null ? null : _redactor.redact(stack.toString());
    _record(eventType: eventType, message: message, stack: stackText);
  }

  void _record({
    required String eventType,
    required String message,
    String? stack,
  }) {
    try {
      final line = _encodeRecord(
        eventType: eventType,
        message: message,
        stack: stack,
      );
      // Chain onto the previous write so records stay ordered and tests can
      // wait for durability with [flush]. The caller is never blocked.
      _writeTail = _writeTail.then((_) => _appendLine(line));
    } catch (_) {
      // Never propagate back into an error handler.
    }
  }

  /// Completes when every previously recorded line has been written (or has
  /// been safely dropped after a write failure).
  Future<void> flush() => _writeTail;

  String _describeError(Object error) {
    // FetchException.toString() already returns its message, and other
    // exceptions fall back to their own string form.
    return error.toString();
  }

  String _encodeRecord({
    required String eventType,
    required String message,
    String? stack,
  }) {
    final payload = <String, dynamic>{
      'ts': _clock().toUtc().toIso8601String(),
      'app': _appVersionLabel,
      'configSchema': _configSchemaVersion,
      'dbSchema': _databaseSchemaVersion,
      'event': eventType,
      'message': _truncate(message, diagnosticsMaxRecordMessageBytes),
      'ops': List<String>.from(_recentOperations),
    };
    if (stack != null) {
      payload['stack'] = _truncate(stack, diagnosticsMaxRecordStackBytes);
    }
    return jsonEncode(payload);
  }

  String _truncate(String value, int maxBytes) {
    if (value.isEmpty) {
      return value;
    }
    final bytes = utf8.encode(value);
    if (bytes.length <= maxBytes) {
      return value;
    }
    var cut = maxBytes;
    while (cut > 0 && (bytes[cut] & 0xC0) == 0x80) {
      cut--;
    }
    return '${utf8.decode(bytes.sublist(0, cut))}…';
  }

  Future<Directory?> _resolveDirectory() async {
    if (_logDirectory != null) {
      return _logDirectory;
    }
    try {
      return await applicationDataDirectory();
    } catch (_) {
      return null;
    }
  }

  Future<void> _appendLine(String line) async {
    try {
      final directory = await _resolveDirectory();
      if (directory == null) {
        return;
      }
      await directory.create(recursive: true);
      final active = File(
        '${directory.path}${Platform.pathSeparator}'
        '$diagnosticsActiveLogFileName',
      );
      if (await active.exists()) {
        final currentSize = await active.length();
        final incomingBytes = utf8.encode('$line\n').length;
        if (currentSize > 0 && currentSize + incomingBytes > _maxFileBytes) {
          await _rotate(directory, active);
        }
      }
      await active.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Swallow all write failures.
    }
  }

  Future<void> _rotate(Directory directory, File active) async {
    final oldest = File(
      '${directory.path}${Platform.pathSeparator}'
      '$diagnosticsActiveLogFileName.$_maxRotatedFiles',
    );
    if (await oldest.exists()) {
      await oldest.delete();
    }
    for (var index = _maxRotatedFiles; index > 1; index--) {
      final from = File(
        '${directory.path}${Platform.pathSeparator}'
        '$diagnosticsActiveLogFileName.${index - 1}',
      );
      final to = File(
        '${directory.path}${Platform.pathSeparator}'
        '$diagnosticsActiveLogFileName.$index',
      );
      if (await to.exists()) {
        await to.delete();
      }
      if (await from.exists()) {
        await from.rename(to.path);
      }
    }
    final first = File(
      '${directory.path}${Platform.pathSeparator}'
      '$diagnosticsActiveLogFileName.1',
    );
    if (await first.exists()) {
      await first.delete();
    }
    await active.rename(first.path);
  }

  /// Builds a self-contained, human-readable text bundle for export. It
  /// contains version and schema metadata, the recent operation summaries, and
  /// the full rotated log (already redacted at write time).
  Future<String> buildExportBundle() async {
    final buffer = StringBuffer();
    buffer.writeln('OJ Float 诊断信息');
    buffer.writeln('导出时间: ${_clock().toUtc().toIso8601String()}');
    buffer.writeln('应用版本: $_appVersionLabel');
    buffer.writeln('配置 schema 版本: $_configSchemaVersion');
    buffer.writeln('数据库 schema 版本: $_databaseSchemaVersion');
    buffer.writeln('');
    buffer.writeln('最近操作 (最近 $diagnosticsMaxRecentOperations 条):');
    if (_recentOperations.isEmpty) {
      buffer.writeln('  (无)');
    } else {
      for (final operation in _recentOperations) {
        buffer.writeln('  - $operation');
      }
    }
    buffer.writeln('');
    buffer.writeln('诊断日志 (已脱敏):');
    final logs = await _readAllLogs();
    if (logs.trim().isEmpty) {
      buffer.writeln('  (暂无日志)');
    } else {
      buffer.write(logs);
    }
    return buffer.toString();
  }

  Future<String> _readAllLogs() async {
    final directory = await _resolveDirectory();
    if (directory == null || !await directory.exists()) {
      return '';
    }
    final files = <File>[];
    final active = File(
      '${directory.path}${Platform.pathSeparator}$diagnosticsActiveLogFileName',
    );
    if (await active.exists()) {
      files.add(active);
    }
    for (var index = 1; index <= _maxRotatedFiles; index++) {
      final rotated = File(
        '${directory.path}${Platform.pathSeparator}'
        '$diagnosticsActiveLogFileName.$index',
      );
      if (await rotated.exists()) {
        files.add(rotated);
      }
    }
    final buffer = StringBuffer();
    for (final file in files) {
      buffer.write(await file.readAsString());
    }
    return buffer.toString();
  }

  Future<File> exportTo(File target) async {
    final content = await buildExportBundle();
    await target.writeAsString(content, flush: true);
    return target;
  }
}
