import 'package:flutter/material.dart';

import '../../models/problem_record.dart';
import '../../services/problem_book_service.dart';

/// A small, single-purpose view; it shares the main controller and storage.
class QuickEntryView extends StatefulWidget {
  const QuickEntryView({super.key, required this.onParse, required this.onSave,
    required this.onClose});
  final Future<ParsedProblemLink> Function(String) onParse;
  final Future<void> Function(ProblemRecord) onSave;
  final VoidCallback onClose;

  @override
  State<QuickEntryView> createState() => _QuickEntryViewState();
}

class _QuickEntryViewState extends State<QuickEntryView> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _number = TextEditingController();
  final _tags = TextEditingController();
  ProblemPlatform _platform = ProblemPlatform.other;
  ProblemWorkflowStatus _status = ProblemWorkflowStatus.backlog;
  bool _busy = false;
  bool _fieldsVisible = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_url, _title, _number, _tags]) { controller.dispose(); }
    super.dispose();
  }

  Future<void> _parse() async {
    setState(() { _busy = true; _error = null; });
    try {
      final parsed = await widget.onParse(_url.text.trim());
      if (!mounted) { return; }
      setState(() {
        _url.text = parsed.url;
        _title.text = parsed.title;
        _number.text = parsed.externalId;
        _tags.text = parsed.tags.join(', ');
        _platform = parsed.platform;
        _fieldsVisible = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _fieldsVisible = true;
          _error = '解析失败，可修改链接后重试或手动填写：$error';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_fieldsVisible) { await _parse(); return; }
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty || _title.text.trim().isEmpty) {
      setState(() => _error = '请填写有效的 http(s) 题目链接和标题。');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onSave(ProblemRecord.create(
        title: _title.text, url: uri.toString(), platform: _platform,
        externalId: _number.text, tags: _tags.text.split(RegExp('[,，]')),
        workflowStatus: _status,
      ));
      if (mounted) widget.onClose();
    } catch (error) {
      if (mounted) setState(() => _error = '保存失败，输入已保留：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('快速录入'), automaticallyImplyLeading: false,
      actions: [IconButton(tooltip: '关闭快速录入', onPressed: _busy ? null : widget.onClose, icon: const Icon(Icons.close))]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      TextField(key: const ValueKey('quick-entry-url'), controller: _url, autofocus: true, enabled: !_busy,
        decoration: const InputDecoration(labelText: '粘贴题目链接'), onSubmitted: (_) => _busy ? null : _parse()),
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton(onPressed: _busy ? null : _parse, child: const Text('解析')),
        const SizedBox(width: 8),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('保存')),
        if (_busy) const Padding(padding: EdgeInsets.only(left: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (_fieldsVisible) ...[
        const SizedBox(height: 12),
        TextField(controller: _title, enabled: !_busy, decoration: const InputDecoration(labelText: '标题')),
        const SizedBox(height: 12),
        DropdownButtonFormField<ProblemPlatform>(key: ValueKey(_platform), initialValue: _platform,
          decoration: const InputDecoration(labelText: '平台'),
          items: [for (final p in ProblemPlatform.values) DropdownMenuItem(value: p, child: Text(problemPlatformLabel(p)))],
          onChanged: _busy ? null : (p) => setState(() => _platform = p!)),
        const SizedBox(height: 12),
        TextField(controller: _number, enabled: !_busy, decoration: const InputDecoration(labelText: '题号')),
        const SizedBox(height: 12),
        TextField(controller: _tags, enabled: !_busy, decoration: const InputDecoration(labelText: '标签', hintText: '用逗号分隔')),
        const SizedBox(height: 12),
        DropdownButtonFormField<ProblemWorkflowStatus>(initialValue: _status,
          decoration: const InputDecoration(labelText: '状态'),
          items: [for (final s in ProblemWorkflowStatus.values.where((s) => s != ProblemWorkflowStatus.archived)) DropdownMenuItem(value: s, child: Text(problemWorkflowStatusLabel(s)))],
          onChanged: _busy ? null : (s) => setState(() => _status = s!)),
      ],
    ]),
  );
}

