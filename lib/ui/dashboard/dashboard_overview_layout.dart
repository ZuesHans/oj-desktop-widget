import 'package:flutter/material.dart';

import '../app_theme.dart';

class DashboardOverviewLayout extends StatelessWidget {
  const DashboardOverviewLayout({
    super.key,
    required this.primary,
    required this.aside,
    required this.bottom,
  });

  final Widget primary;
  final List<Widget> aside;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              ..._spaced(aside),
              ..._spaced(bottom),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: primary),
                const SizedBox(width: appSpace4),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _spaced(aside, leading: false),
                  ),
                ),
              ],
            ),
            if (bottom.isNotEmpty) ...[
              const SizedBox(height: appSpace4),
              _BottomGrid(children: bottom),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _spaced(List<Widget> children, {bool leading = true}) {
    return [
      for (var index = 0; index < children.length; index++) ...[
        if (leading || index > 0) const SizedBox(height: appSpace3),
        children[index],
      ],
    ];
  }
}

class _BottomGrid extends StatelessWidget {
  const _BottomGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 3 : 2;
        final width =
            (constraints.maxWidth - appSpace3 * (columns - 1)) / columns;
        return Wrap(
          spacing: appSpace3,
          runSpacing: appSpace3,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
