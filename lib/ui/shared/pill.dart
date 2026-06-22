import 'package:flutter/material.dart';

import '../app_theme.dart';

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cardMutedColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
