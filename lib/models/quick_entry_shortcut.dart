/// User-editable Windows global shortcut. Require Ctrl or Alt so ordinary
/// typing (including Shift+letter) cannot become an application hotkey.
class QuickEntryShortcut {
  const QuickEntryShortcut._(this.modifiers, this.key, this.label);
  static const defaultLabel = 'Ctrl+Shift+O';
  final int modifiers;
  final int key;
  final String label;

  static QuickEntryShortcut? parse(String input) {
    final parts = input.replaceAll(RegExp(r'\s+'), '').toUpperCase().split('+');
    if (parts.length < 2 || parts.toSet().length != parts.length) return null;
    var modifiers = 0;
    int? key;
    for (final part in parts) {
      switch (part) {
        case 'CTRL':
          modifiers |= 2;
        case 'ALT':
          modifiers |= 1;
        case 'SHIFT':
          modifiers |= 4;
        default:
          if (key != null || !RegExp(r'^[A-Z0-9]$').hasMatch(part)) return null;
          key = part.codeUnitAt(0);
      }
    }
    if (key == null || (modifiers & 3) == 0) return null;
    final label = [
      if ((modifiers & 2) != 0) 'Ctrl',
      if ((modifiers & 1) != 0) 'Alt',
      if ((modifiers & 4) != 0) 'Shift',
      String.fromCharCode(key),
    ].join('+');
    return QuickEntryShortcut._(modifiers, key, label);
  }

  Map<String, int> toNativeArguments() => {'modifiers': modifiers, 'key': key};
}
