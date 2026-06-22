import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('README documents cross-device backup and restore', () async {
    final readme = await File('README.md').readAsString();

    expect(readme, matches(RegExp(r'^## 备份与迁移$', multiLine: true)));
    expect(readme, contains('Import Backup'));
    expect(readme, contains('安全备份'));
    expect(readme, contains('dailyStats'));
    expect(readme, contains('CSV'));
    expect(readme, contains('密码'));
    expect(readme, contains('Cookie'));
    expect(readme, contains('Token'));
  });
}
