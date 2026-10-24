import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../shared/app_surface_card.dart';

class StartupStatusPage extends StatelessWidget {
  const StartupStatusPage({
    super.key,
    this.error,
    this.restoring = false,
    required this.onRetry,
    required this.onRestore,
    required this.onOpenDirectory,
  });

  final Object? error;
  final bool restoring;
  final VoidCallback onRetry;
  final VoidCallback onRestore;
  final VoidCallback onOpenDirectory;

  @override
  Widget build(BuildContext context) => Scaffold(
        key: ValueKey(error == null ? 'startup-loading' : 'startup-recovery'),
        backgroundColor: appSurfaceColor,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Image.asset('assets/app_icon.png', width: 32, height: 32),
                      const SizedBox(width: 12),
                      const Text('OJ Float'),
                    ]),
                    const SizedBox(height: 24),
                    Text(
                      error == null ? '正在打开你的工作台' : '本地数据暂时无法打开',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error == null
                          ? '读取本地题库与训练记录…'
                          : '你的文件仍保存在本机。可以修复文件后重试，或从有效备份恢复。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (error == null || restoring)
                      const LinearProgressIndicator(minHeight: 3),
                    if (restoring) ...[
                      const SizedBox(height: 12),
                      const Text('正在校验备份并恢复，请稍候…'),
                    ],
                    if (error != null) ...[
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('查看错误详情'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: SelectableText('$error',
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(
                          key: const ValueKey('startup-retry'),
                          onPressed: restoring ? null : onRetry,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('重新读取'),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('startup-restore'),
                          onPressed: restoring ? null : onRestore,
                          icon: const Icon(Icons.restore_outlined, size: 18),
                          label: const Text('从备份恢复'),
                        ),
                        TextButton.icon(
                          onPressed: restoring ? null : onOpenDirectory,
                          icon:
                              const Icon(Icons.folder_open_outlined, size: 18),
                          label: const Text('打开数据文件夹'),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
