import 'package:flutter/material.dart';

import '../app_theme.dart';

class FeaturePageShell extends StatelessWidget {
  const FeaturePageShell({
    super.key,
    required this.header,
    required this.child,
  });

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
