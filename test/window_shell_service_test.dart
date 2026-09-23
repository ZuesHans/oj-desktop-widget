import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('exit uses a normal close request instead of destroying the engine',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });

    await WindowShellService().exitApp();

    expect(calls.map((call) => call.method), ['setPreventClose', 'close']);
    expect(calls.first.arguments, {'isPreventClose': false});
    expect(
        calls,
        isNot(contains(predicate<MethodCall>(
          (call) => call.method == 'destroy',
        ))));
  });
}
