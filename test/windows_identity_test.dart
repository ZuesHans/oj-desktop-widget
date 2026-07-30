import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows metadata preserves the existing application data directory',
      () async {
    final runnerResource =
        await File('windows/runner/Runner.rc').readAsString();

    expect(
      runnerResource,
      contains('VALUE "CompanyName", "com.example"'),
    );
    expect(
      runnerResource,
      contains('VALUE "ProductName", "oj_float"'),
    );
    expect(
      runnerResource,
      contains('VALUE "FileDescription", "OJ Float desktop client"'),
    );
  });

  test('Windows runner leaves window visibility to the Dart lifecycle',
      () async {
    final flutterWindow =
        await File('windows/runner/flutter_window.cpp').readAsString();

    expect(flutterWindow, isNot(contains('this->Show();')));
    expect(flutterWindow, isNot(contains('ForceRedraw();')));
  });
}
