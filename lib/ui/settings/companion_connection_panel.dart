import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class CompanionConnectionPanel extends StatefulWidget {
  const CompanionConnectionPanel({super.key});

  @override
  State<CompanionConnectionPanel> createState() =>
      _CompanionConnectionPanelState();
}

class _CompanionConnectionPanelState extends State<CompanionConnectionPanel> {
  final _client = http.Client();
  bool _checking = false;
  bool? _connected;
  String _message = '尚未检测。打开题库小程序后，点击检测连接。';

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final response = await _client
          .get(Uri.parse('http://127.0.0.1:27122/v1/health'), headers: {
        'X-OJ-Companion': 'userscript-v1',
        'Content-Length': '0'
      }).timeout(const Duration(seconds: 4));
      final data =
          response.statusCode == 200 && response.bodyBytes.length < 4096
              ? jsonDecode(response.body)
              : null;
      final connected = data is Map &&
          data['service'] == 'oj-float-companion' &&
          data['protocol'] == 1 &&
          data['ready'] == true;
      if (!mounted) return;
      setState(() {
        _connected = connected;
        _message = connected
            ? '题库小程序已连接，可以点击网页上的猪头存题。'
            : '端口有响应，但未识别到新版题库小程序。请检查版本或端口占用。';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _connected = false;
          _message = '未连接，请先打开 OJ Problem Companion（题库小程序），再重新检测。';
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openFolder() async {
    final directory = File(Platform.resolvedExecutable).parent;
    try {
      if (!await launchUrl(directory.uri,
          mode: LaunchMode.externalApplication)) {
        throw const FileSystemException('Unable to open directory');
      }
    } catch (_) {
      if (mounted) setState(() => _message = '请打开安装目录：${directory.path}');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('猪猪一键存题 · 轻量题库'),
          const SizedBox(height: 8),
          Text(
              '1. 从开始菜单打开 OJ Problem Companion。\n'
              '2. 在浏览器安装 Tampermonkey，再导入安装目录中的 oj-float-importer.user.js。\n'
              '3. 打开题目网页，点击右下角的猪头。',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                _connected == true
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                size: 18,
                color: _connected == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_message,
                    style: Theme.of(context).textTheme.bodySmall)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                key: const ValueKey('check-companion-connection'),
                onPressed: _checking ? null : _check,
                icon: const Icon(Icons.link, size: 18),
                label: Text(_checking ? '正在检测…' : '检测连接')),
            TextButton.icon(
                onPressed: _openFolder,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('打开安装文件夹')),
          ]),
        ],
      );
}
