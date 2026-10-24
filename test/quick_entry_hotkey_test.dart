import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/models/app_config.dart';
import 'package:oj_float/models/quick_entry_shortcut.dart';
import 'package:oj_float/services/local_store.dart';
import 'package:oj_float/services/quick_entry_hotkey_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shortcut normalizes modifier order, spaces and lower case', () {
    final shortcut = QuickEntryShortcut.parse(' shift + q + Alt ')!;
    expect(shortcut.label, 'Alt+Shift+Q');
    expect(shortcut.toNativeArguments(), {'modifiers': 5, 'key': 81});
    expect(QuickEntryShortcut.parse('ctrl+alt+3')!.label, 'Ctrl+Alt+3');
    for (final value in [
      '',
      'Q',
      'Shift+Q',
      'Ctrl+Ctrl+Q',
      'Ctrl+Q+W',
      'Ctrl+F12',
      'Ctrl++',
      'Control+Q'
    ]) {
      expect(QuickEntryShortcut.parse(value), isNull, reason: value);
    }
  });

  test(
      'old or invalid config gets default and saved custom shortcut survives reload',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect(AppConfig.fromJson({}).quickEntryHotkey, 'Ctrl+Shift+O');
    expect(AppConfig.fromJson({'quickEntryHotkey': 'bad'}).quickEntryHotkey,
        'Ctrl+Shift+O');
    final store = LocalStore();
    await store.saveConfig(
        AppConfig.defaults().copyWith(quickEntryHotkey: 'Alt+Shift+Q'));
    final loaded = await store.loadConfig();
    expect(loaded.quickEntryHotkey, 'Alt+Shift+Q');
    expect(loaded.copyWith(closeToTray: true).quickEntryHotkey, 'Alt+Shift+Q');
  });

  test(
      'native service sends selected keys and exposes conflicts rather than success',
      () async {
    const channel = MethodChannel('test/quick_entry');
    const service = QuickEntryHotkeyService(channel: channel);
    final calls = <MethodCall>[];
    var conflict = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return !conflict;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await service.register('alt+shift+q');
    expect(calls.single.arguments, {'modifiers': 5, 'key': 81});
    conflict = true;
    await expectLater(service.register('Ctrl+Shift+O'), throwsStateError);
    await expectLater(service.register('Q'), throwsFormatException);
    expect(calls.length, 2);
  });
}
