import 'package:flutter/material.dart';

/// Shared heading rhythm for workspace pages, without an enclosing card.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 16),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions),
        ],
      ],
    );
  }
}
