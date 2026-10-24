import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows metadata and companion share the stable product identity',
      () async {
    final runnerResource =
        await File('windows/runner/Runner.rc').readAsString();

    expect(
      runnerResource,
      contains('VALUE "CompanyName", "ZuesHans"'),
    );
    expect(
      runnerResource,
      contains('VALUE "ProductName", "OJ Float"'),
    );
    expect(
      runnerResource,
      contains('VALUE "FileDescription", "OJ Float desktop client"'),
    );
    final companion =
        await File('native_companion/src/main.cpp').readAsString();
    expect(companion, contains('path / L"ZuesHans" / L"OJ Float"'));
  });

  test('Windows runner leaves window visibility to the Dart lifecycle',
      () async {
    final flutterWindow =
        await File('windows/runner/flutter_window.cpp').readAsString();

    expect(flutterWindow, isNot(contains('this->Show();')));
    expect(flutterWindow, isNot(contains('ForceRedraw();')));
  });
}
