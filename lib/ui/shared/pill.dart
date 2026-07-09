import 'package:flutter/material.dart';

import '../app_theme.dart';

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? textPrimaryColor;
    final background = color?.withValues(alpha: 0.1) ?? cardMutedColor;
    final outline = color?.withValues(alpha: 0.22) ?? borderColor;

    return Container(
      padding: appPillPadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(appRadiusPill),
        border: Border.all(color: outline),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
