import 'package:flutter/material.dart';

import '../app_theme.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = appCardPadding,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(appRadiusControl);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: borderColor),
    );
    if (onTap == null) {
      return Material(
        color: color ?? cardColor,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: child,
        ),
      );
    }
    return Material(
      color: color ?? cardColor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 24),
          const SizedBox(width: appSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: appSpace1),
                Text(
                  message,
                  style: TextStyle(color: textSecondaryColor),
                ),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
