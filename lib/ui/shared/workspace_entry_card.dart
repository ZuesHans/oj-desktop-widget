import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'app_surface_card.dart';

class WorkspaceEntryCard extends StatelessWidget {
  const WorkspaceEntryCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.description,
      required this.onOpen,
      required this.openKey,
      this.child,
      this.actions = const []});

  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onOpen;
  final Key openKey;
  final Widget? child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 19, color: accentColor),
            const SizedBox(width: 9),
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
                key: openKey,
                tooltip: '打开$title',
                onPressed: onOpen,
                icon: Icon(Icons.arrow_outward,
                    size: 18, color: textSecondaryColor)),
          ]),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          if (child != null) ...[const SizedBox(height: 14), child!],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: actions),
          ],
        ]),
      );
}
