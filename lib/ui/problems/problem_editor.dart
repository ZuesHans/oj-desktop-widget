import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../core/time.dart';
import '../../models/problem_record.dart';
import '../../services/problem_book_service.dart';
import '../app_theme.dart';

class ProblemEditorDialog extends StatefulWidget {
  const ProblemEditorDialog({
    super.key,
    this.initial,
    required this.onParseLink,
  });

  final ProblemRecord? initial;
  final Future<ParsedProblemLink> Function(String url) onParseLink;

  @override
  State<ProblemEditorDialog> createState() => _ProblemEditorDialogState();
}

class _ProblemEditorDialogState extends State<ProblemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _tagsController;
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;
  late final TextEditingController _analysisController;
  late ProblemPlatform _platform;
  late ProblemStatus _status;
  bool _parsing = false;
  String? _parseMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _urlController = TextEditingController(text: initial?.url ?? '');
    _tagsController =
        TextEditingController(text: initial?.tags.join(', ') ?? '');
    _dateController =
        TextEditingController(text: initial?.date ?? dateKey(DateTime.now()));
    _noteController = TextEditingController(text: initial?.note ?? '');
    _analysisController = TextEditingController(text: initial?.analysis ?? '');
    _platform = initial?.platform ?? ProblemPlatform.other;
    _status = initial?.status ?? ProblemStatus.TODO;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _tagsController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    _analysisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('problem-editor-dialog'),
      title: Text(widget.initial == null ? '添加题目' : '编辑题目'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('problem-url-field'),
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: '题目链接',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      key: const ValueKey('parse-problem-link-button'),
                      onPressed: _parsing ? null : _parseLink,
                      icon: _parsing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore),
                      label: const Text('解析'),
                    ),
                  ],
                ),
                if (_parseMessage != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _parseMessage!,
                      style: const TextStyle(color: textSecondaryColor),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('problem-title-field'),
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '题目标题',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth >= 560
                        ? (constraints.maxWidth - 16) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: DropdownButtonFormField<ProblemPlatform>(
                            isExpanded: true,
                            key: const ValueKey('problem-platform-field'),
                            initialValue: _platform,
                            decoration: const InputDecoration(
                              labelText: '来源',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final platform in ProblemPlatform.values)
                                DropdownMenuItem(
                                  value: platform,
                                  child: Text(problemPlatformLabel(platform)),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _platform = value ?? ProblemPlatform.other,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: DropdownButtonFormField<ProblemStatus>(
                            isExpanded: true,
                            key: const ValueKey('problem-status-field'),
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: '状态',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final status in ProblemStatus.values)
                                DropdownMenuItem(
                                  value: status,
                                  child: Text(status.name),
                                ),
                            ],
                            onChanged: (value) => setState(
                              () => _status = value ?? ProblemStatus.TODO,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: TextFormField(
                            key: const ValueKey('problem-date-field'),
                            controller: _dateController,
                            decoration: const InputDecoration(
                              labelText: '记录日期',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validDate,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('problem-tags-field'),
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: '标签，逗号分隔',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('problem-note-field'),
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('problem-analysis-field'),
                  controller: _analysisController,
                  decoration: const InputDecoration(
                    labelText: '题解心得 / Warning',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 4,
                  maxLines: 8,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('save-problem-button'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _parseLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _parseMessage = '请输入题目链接');
      return;
    }
    setState(() {
      _parsing = true;
      _parseMessage = null;
    });
    try {
      final parsed = await widget.onParseLink(url);
      if (!mounted) {
        return;
      }
      setState(() {
        _titleController.text = parsed.title;
        _urlController.text = parsed.url;
        _platform = parsed.platform;
        _parseMessage = '解析完成';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _platform = detectProblemPlatform(normalizeProblemUri(url));
        _titleController.text = _titleController.text.trim().isEmpty
            ? fallbackProblemTitle(normalizeProblemUri(url), _platform)
            : _titleController.text;
        _parseMessage = '解析失败，已保留链接，可手动补全：${normalizeError(error)}';
      });
    } finally {
      if (mounted) {
        setState(() => _parsing = false);
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    final initial = widget.initial;
    final record = initial == null
        ? ProblemRecord.create(
            title: _titleController.text,
            url: _urlController.text,
            platform: _platform,
            status: _status,
            tags: normalizeProblemTags(_tagsController.text.split(',')),
            date: _dateController.text.trim(),
            note: _noteController.text,
            analysis: _analysisController.text,
            now: now,
          )
        : initial.copyWith(
            title: _titleController.text,
            url: _urlController.text,
            platform: _platform,
            status: _status,
            tags: normalizeProblemTags(_tagsController.text.split(',')),
            date: _dateController.text.trim(),
            note: _noteController.text,
            analysis: _analysisController.text,
            updatedAt: now,
          );
    Navigator.pop(context, record);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '必填';
    }
    return null;
  }

  String? _validDate(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return '格式应为 YYYY-MM-DD';
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null || dateKey(parsed) != text) {
      return '日期无效';
    }
    return null;
  }
}
