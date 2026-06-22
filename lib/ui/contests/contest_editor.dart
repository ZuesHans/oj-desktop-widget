import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../models/contest_record.dart';
import '../app_theme.dart';

class ContestEditorDialog extends StatefulWidget {
  const ContestEditorDialog({super.key, this.initial});

  final ContestRecord? initial;

  @override
  State<ContestEditorDialog> createState() => _ContestEditorDialogState();
}

class _ContestEditorDialogState extends State<ContestEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  late final TextEditingController _rankController;
  late final TextEditingController _totalController;
  late final TextEditingController _solvedController;
  late final TextEditingController _penaltyController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _dateController =
        TextEditingController(text: initial?.date ?? dateKey(DateTime.now()));
    _rankController =
        TextEditingController(text: initial == null ? '' : '${initial.rank}');
    _totalController = TextEditingController(
      text: initial?.totalParticipants == null
          ? ''
          : '${initial!.totalParticipants}',
    );
    _solvedController = TextEditingController(
      text: initial?.solvedCount == null ? '' : '${initial!.solvedCount}',
    );
    _penaltyController = TextEditingController(
      text: initial?.penalty == null ? '' : '${initial!.penalty}',
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _rankController.dispose();
    _totalController.dispose();
    _solvedController.dispose();
    _penaltyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('contest-editor-dialog'),
      title: Text(widget.initial == null ? '新增比赛记录' : '编辑比赛记录'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('contest-title-field'),
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '比赛名称',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth >= 520
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: TextFormField(
                            key: const ValueKey('contest-date-field'),
                            controller: _dateController,
                            decoration: const InputDecoration(
                              labelText: '日期',
                              hintText: 'YYYY-MM-DD',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validDate,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: TextFormField(
                            key: const ValueKey('contest-rank-field'),
                            controller: _rankController,
                            decoration: const InputDecoration(
                              labelText: '排名',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _positiveRequired,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: TextFormField(
                            key: const ValueKey('contest-total-field'),
                            controller: _totalController,
                            decoration: const InputDecoration(
                              labelText: '总人数（可选）',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _validTotal,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: TextFormField(
                            key: const ValueKey('contest-solved-field'),
                            controller: _solvedController,
                            decoration: const InputDecoration(
                              labelText: '过题数（可选）',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _nonNegativeOptional,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: TextFormField(
                            key: const ValueKey('contest-penalty-field'),
                            controller: _penaltyController,
                            decoration: const InputDecoration(
                              labelText: '罚时（可选）',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: _nonNegativeOptional,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('contest-note-field'),
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '排名数值越小代表成绩越好。',
                    style: TextStyle(color: textSecondaryColor, fontSize: 12),
                  ),
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
          key: const ValueKey('save-contest-button'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    final initial = widget.initial;
    final total = _optionalInt(_totalController.text);
    final solved = _optionalInt(_solvedController.text);
    final penalty = _optionalInt(_penaltyController.text);
    final record = initial == null
        ? ContestRecord.create(
            title: _titleController.text,
            date: _dateController.text.trim(),
            rank: int.parse(_rankController.text.trim()),
            totalParticipants: total,
            solvedCount: solved,
            penalty: penalty,
            note: _noteController.text,
            now: now,
          )
        : initial.copyWith(
            title: _titleController.text,
            date: _dateController.text.trim(),
            rank: int.parse(_rankController.text.trim()),
            totalParticipants: total,
            clearTotalParticipants: total == null,
            solvedCount: solved,
            clearSolvedCount: solved == null,
            penalty: penalty,
            clearPenalty: penalty == null,
            note: _noteController.text,
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
    if (!isValidDateKey(text)) {
      return '日期无效';
    }
    return null;
  }

  String? _positiveRequired(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    final number = int.tryParse(value!.trim());
    if (number == null || number <= 0) {
      return '请输入正整数';
    }
    return null;
  }

  String? _validTotal(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final total = int.tryParse(text);
    if (total == null || total <= 0) {
      return '请输入正整数';
    }
    final rank = int.tryParse(_rankController.text.trim());
    if (rank != null && total < rank) {
      return '总人数不能小于排名';
    }
    return null;
  }

  String? _nonNegativeOptional(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final number = int.tryParse(text);
    if (number == null || number < 0) {
      return '请输入非负整数';
    }
    return null;
  }

  int? _optionalInt(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    return int.parse(text);
  }
}
