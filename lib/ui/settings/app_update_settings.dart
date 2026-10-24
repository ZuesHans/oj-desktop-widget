import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../services/update_service.dart';

class AppUpdateSettings extends StatefulWidget {
  const AppUpdateSettings({super.key});

  @override
  State<AppUpdateSettings> createState() => _AppUpdateSettingsState();
}

class _AppUpdateSettingsState extends State<AppUpdateSettings> {
  final _service = UpdateService();
  bool _checking = false;
  String _message = '';
  UpdateCheckResult? _result;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = '';
      _result = null;
    });
    try {
      final result = await _service.check();
      if (!mounted) return;
      setState(() {
        _result = result;
        _message = switch (result.status) {
          UpdateStatus.available => '发现 ${result.version}，可以下载安装包覆盖升级。',
          UpdateStatus.current => '当前已是最新稳定版本。',
          UpdateStatus.noStableRelease => '尚无公开的稳定发行版本，可以在发布页面查看测试版本。',
        };
      });
    } catch (_) {
      if (mounted) setState(() => _message = '检查更新失败，请稍后重试或打开发布页面。');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No browser available');
      }
    } catch (_) {
      if (mounted) setState(() => _message = '无法打开浏览器，请访问 $appReleasesUrl');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OJ Float $appVersion · Build $appBuildNumber'),
          const SizedBox(height: 8),
          Text('更新后会保留本地数据。', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              key: const ValueKey('check-app-update'),
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.system_update_alt, size: 18),
              label: Text(_checking ? '正在检查…' : '检查更新'),
            ),
            TextButton(
                onPressed: () => _open(Uri.parse(appReleasesUrl)),
                child: const Text('发布与下载')),
            if (_result?.status == UpdateStatus.available)
              FilledButton.icon(
                  onPressed: () => _open(_result!.downloadUrl!),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('下载新版本')),
          ]),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      );
}
