import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('README documents cross-device backup and restore', () async {
    final readme = await File('README.md').readAsString();

    expect(
      readme,
      matches(RegExp(r'^## Cross-device backup and restore$', multiLine: true)),
    );
    expect(readme, contains('Import Backup'));
    expect(readme, contains('safety backup'));
    expect(readme, contains('dailyStats'));
    expect(readme, contains('CSV'));
    expect(readme, contains('passwords'));
    expect(readme, contains('Cookie'));
    expect(readme, contains('Token'));
  });
}
