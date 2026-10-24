import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/core/app_info.dart';
import 'package:oj_float/services/update_service.dart';

void main() {
  test('app version agrees with the manifest and native version source', () {
    final manifest = File('pubspec.yaml').readAsStringSync();
    expect(manifest, contains('version: $appVersion+$appBuildNumber'));
    expect(File('native_companion/CMakeLists.txt').readAsStringSync(),
        contains('pubspec.yaml'));
  });

  test('latest stable installer is offered over the repository HTTPS URL',
      () async {
    final service = UpdateService(client: MockClient((request) async {
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'api.github.com');
      expect(request.followRedirects, isFalse);
      return http.Response(jsonEncode(_release('v0.3.0')), 200);
    }));
    addTearDown(service.dispose);
    final result = await service.check(currentVersion: '0.2.0+8');
    expect(result.status, UpdateStatus.available);
    expect(result.downloadUrl.toString(),
        '$appRepositoryUrl/releases/download/v0.3.0/OJ-Float-v0.3.0-windows-x64-setup.exe');
  });

  test(
      'numeric versions, current builds, and prerelease upgrades compare correctly',
      () async {
    for (final (current, remote, expected) in [
      ('0.2.0', 'v0.2.0', UpdateStatus.current),
      ('0.3.0', 'v0.2.0', UpdateStatus.current),
      ('0.9.0', 'v0.10.0', UpdateStatus.available),
      ('0.2.0-beta.7', 'v0.2.0', UpdateStatus.available),
      ('0.2.0+8', 'v0.2.0+9', UpdateStatus.current),
    ]) {
      final service = UpdateService(
          client: MockClient(
              (_) async => http.Response(jsonEncode(_release(remote)), 200)));
      expect((await service.check(currentVersion: current)).status, expected);
      service.dispose();
    }
  });

  test(
      'unpublished stable releases and older compatible ZIP releases have clear outcomes',
      () async {
    final none =
        UpdateService(client: MockClient((_) async => http.Response('', 404)));
    expect((await none.check()).status, UpdateStatus.noStableRelease);
    none.dispose();
    final zip = UpdateService(
        client: MockClient((_) async => http.Response(
            jsonEncode(_release('v0.3.0')..['assets'] = []), 200)));
    expect((await zip.check()).downloadUrl.toString(),
        '$appRepositoryUrl/releases/tag/v0.3.0');
    zip.dispose();
  });

  test(
      'drafts, prereleases, invalid JSON, redirects, and external downloads are rejected',
      () async {
    for (final data in [
      _release('v0.3.0')..['draft'] = true,
      _release('v0.3.0')..['prerelease'] = true,
      _release('v0.3.0-rc.1'),
      _release('unexpected'),
      _release('v0.3.0')
        ..['html_url'] =
            'http://github.com/ZuesHans/oj-desktop-widget/releases/tag/v0.3.0',
      _release('v0.3.0')
        ..['assets'] = [
          {
            'name': 'malicious-windows-x64-setup.exe',
            'browser_download_url': 'https://unrelated.test/setup.exe'
          }
        ],
    ]) {
      final service = UpdateService(
          client:
              MockClient((_) async => http.Response(jsonEncode(data), 200)));
      await expectLater(service.check(), throwsFormatException);
      service.dispose();
    }
    for (final code in [301, 403, 429, 500]) {
      final service = UpdateService(
          client: MockClient((_) async => http.Response('', code)));
      await expectLater(service.check(), throwsException);
      service.dispose();
    }
    final malformed =
        UpdateService(client: MockClient((_) async => http.Response('{', 200)));
    await expectLater(malformed.check(), throwsFormatException);
    malformed.dispose();
    final huge = UpdateService(
        client: MockClient(
            (_) async => http.Response('x' * (256 * 1024 + 1), 200)));
    await expectLater(huge.check(), throwsFormatException);
    huge.dispose();
  });
}

Map<String, dynamic> _release(String tag) => {
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'html_url': '$appRepositoryUrl/releases/tag/$tag',
      'assets': [
        {
          'name': 'OJ-Float-$tag-windows-x64-setup.exe',
          'browser_download_url':
              '$appRepositoryUrl/releases/download/$tag/OJ-Float-$tag-windows-x64-setup.exe'
        }
      ],
    };
