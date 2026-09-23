import 'package:flutter/services.dart';
import '../models/quick_entry_shortcut.dart';

class QuickEntryHotkeyService {
  const QuickEntryHotkeyService(
      {this.channel = const MethodChannel('oj_float/quick_entry')});
  final MethodChannel channel;

  Future<void> register(String label) async {
    final shortcut = QuickEntryShortcut.parse(label);
    if (shortcut == null) throw const FormatException('快捷键格式无效。');
    final registered = await channel.invokeMethod<bool>(
        'register', shortcut.toNativeArguments());
    if (registered != true) {
      throw StateError(
          '${shortcut.label} 被其他程序占用或系统不允许注册，请在设置中更换组合。原可用快捷键保持不变。');
    }
  }
}
