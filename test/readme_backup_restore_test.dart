import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('README documents cross-device backup and restore', () async {
    final readme = await File('README.md').readAsString();

    expect(readme, contains('## Cross-device backup and restore'));
    expect(readme, contains('Import Backup'));
    expect(readme, contains('safety backup'));
    expect(readme, contains('dailyStats'));
    expect(readme, contains('CSV'));
  });
}
