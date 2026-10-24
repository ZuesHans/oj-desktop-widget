import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/core/app_info.dart';
import 'package:oj_float/services/diagnostics_service.dart';

import 'test_support.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('oj_diagnostics_');
  });

  tearDown(() => deleteTestDirectory(directory));

  group('error recording', () {
    test('framework and unhandled async errors both leave records', () async {
      final service = DiagnosticsService(
        logDirectory: directory,
        clock: () => DateTime.utc(2026, 10, 24, 12),
      );
      DiagnosticsService.instance = service;
      installDiagnosticsErrorHandlers();

      final previousFlutterHandler = FlutterError.onError;
      final previousPlatformHandler = PlatformDispatcher.instance.onError;
      try {
        FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('framework boom')),
        );
        PlatformDispatcher.instance.onError!(
          StateError('async boom'),
          StackTrace.current,
        );
      } finally {
        FlutterError.onError = previousFlutterHandler;
        PlatformDispatcher.instance.onError = previousPlatformHandler;
      }

      await service.flush();

      final log = await File(
        '${directory.path}/diagnostics.log',
      ).readAsString();
      expect(log, contains('"event":"framework_error"'));
      expect(log, contains('"event":"unhandled_async_error"'));
      expect(log, contains('framework boom'));
      expect(log, contains('async boom'));
    });
  });

  group('rotation', () {
    test('caps disk usage to one active file plus retained files', () async {
      final service = DiagnosticsService(
        logDirectory: directory,
        maxFileBytes: 512,
        maxRotatedFiles: 3,
      );
      for (var i = 0; i < 120; i++) {
        service.recordEvent('event', 'entry $i ${'x' * 120}');
      }
      await service.flush();

      final logFiles = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('diagnostics.log'))
          .toList();
      expect(logFiles.length, lessThanOrEqualTo(4));
      var totalBytes = 0;
      for (final file in logFiles) {
        final length = await file.length();
        totalBytes += length;
        expect(length, lessThanOrEqualTo(512));
      }
      expect(totalBytes, lessThanOrEqualTo(4 * 512));
    });
  });

  group('failure policy', () {
    test('unwritable log directory does not throw or break startup', () async {
      final blocker = File('${directory.path}/blocker');
      await blocker.writeAsString('x');
      final service = DiagnosticsService(
        logDirectory: Directory('${blocker.path}/logs'),
      );

      expect(
        () => service.recordError(
          eventType: 'boom',
          error: StateError('cannot write'),
        ),
        returnsNormally,
      );
      await service.flush();
    });
  });

  group('redaction', () {
    test('removes token, Windows user, OJ account and URL query params', () {
      final redactor = DiagnosticsRedactor(ojUsernames: ['SomeOJUser']);
      const sample = 'Bearer supersecrettoken123\n'
          r'path=C:\Users\Somebody\Documents\oj.json'
          '\n'
          'account SomeOJUser\n'
          'url https://example.com/profile/SomeOJUser?token=abc123&user=Somebody';

      final result = redactor.redact(sample);

      expect(result, isNot(contains('supersecrettoken123')));
      expect(result, isNot(contains('Somebody')));
      expect(result, isNot(contains('SomeOJUser')));
      expect(result, isNot(contains('abc123')));
      expect(result, contains('{token}'));
      expect(result, contains('{local_user}'));
      expect(result, contains('{oj_user_1}'));
      expect(result, contains('{url_param}'));
    });
  });

  group('export', () {
    test(
      'exported bundle contains version, schema and operation summary',
      () async {
        final service = DiagnosticsService(
          logDirectory: directory,
          clock: () => DateTime.utc(2026, 10, 24, 12),
        );
        DiagnosticsService.instance = service;
        service.recordOperation('refresh codeforces ok');
        await service.flush();

        final target = File('${directory.path}/export.txt');
        await service.exportTo(target);

        final content = await target.readAsString();
        expect(content, contains('$appVersion+$appBuildNumber'));
        expect(content, contains('配置 schema 版本: 4'));
        expect(content, contains('数据库 schema 版本: 4'));
        expect(content, contains('refresh codeforces ok'));
      },
    );
  });
}
