import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../shared/app_surface_card.dart';

class FirstRunCard extends StatelessWidget {
  const FirstRunCard({
    super.key,
    required this.onCreateProblem,
    required this.onConnectAccounts,
    required this.onBrowserHelp,
    required this.onSkip,
    this.busy = false,
  });

  final VoidCallback onCreateProblem;
  final VoidCallback onConnectAccounts;
  final VoidCallback onBrowserHelp;
  final VoidCallback onSkip;
  final bool busy;

  @override
  Widget build(BuildContext context) => AppSurfaceCard(
        key: const ValueKey('first-run-guide'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.waving_hand_outlined, size: 22, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
                child: Text('从一道值得再做的题开始',
                    style: Theme.of(context).textTheme.titleMedium)),
            TextButton(
                key: const ValueKey('skip-first-run'),
                onPressed: busy ? null : onSkip,
                child: const Text('稍后再说')),
          ]),
          const SizedBox(height: 8),
          Text('把题目、笔记和训练安排留在一起。不配置 OJ 账号也能使用题库与待办。',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
                key: const ValueKey('first-run-create-problem'),
                onPressed: busy ? null : onCreateProblem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('保存第一道题')),
            OutlinedButton.icon(
                onPressed: busy ? null : onConnectAccounts,
                icon: const Icon(Icons.account_circle_outlined, size: 18),
                label: const Text('连接 OJ 账号（可选）')),
            TextButton.icon(
                onPressed: busy ? null : onBrowserHelp,
                icon: const Icon(Icons.extension_outlined, size: 18),
                label: const Text('设置浏览器存题')),
          ]),
        ]),
      );
}
