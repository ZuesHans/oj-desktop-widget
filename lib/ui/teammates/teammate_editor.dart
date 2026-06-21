import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../models/teammate.dart';

class TeammateEditorDialog extends StatefulWidget {
  const TeammateEditorDialog({
    super.key,
    this.initial,
  });

  final TeammateProfile? initial;

  @override
  State<TeammateEditorDialog> createState() => _TeammateEditorDialogState();
}

class _TeammateEditorDialogState extends State<TeammateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final Map<String, TextEditingController> _accountControllers;
  late final Map<String, bool> _enabled;

  @override
  void initState() {
    super.initState();
    final accounts = {
      for (final account
          in widget.initial?.accounts ?? const <TeammateAccount>[])
        account.platform: account,
    };
    _nicknameController =
        TextEditingController(text: widget.initial?.nickname ?? '');
    _accountControllers = {
      for (final meta in supportedOjs)
        meta.id: TextEditingController(text: accounts[meta.id]?.handle ?? ''),
    };
    _enabled = {
      for (final meta in supportedOjs)
        meta.id: accounts[meta.id]?.enabled ?? false,
    };
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    for (final controller in _accountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('teammate-editor-dialog'),
      title: Text(widget.initial == null ? '添加队友' : '编辑队友'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('teammate-nickname-field'),
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                ...supportedOjs.map((meta) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          key: ValueKey('teammate-platform-${meta.id}'),
                          value: _enabled[meta.id] ?? false,
                          onChanged: (value) {
                            setState(() => _enabled[meta.id] = value ?? false);
                          },
                        ),
                        SizedBox(
                          width: 104,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 13),
                            child: Text(meta.name),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('teammate-account-${meta.id}'),
                            controller: _accountControllers[meta.id],
                            decoration: InputDecoration(
                              hintText: meta.hint,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (_enabled[meta.id] == true &&
                                  (value == null || value.trim().isEmpty)) {
                                return '账号不能为空';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
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
          key: const ValueKey('save-teammate-button'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '必填';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final accounts = [
      for (final meta in supportedOjs)
        if (_enabled[meta.id] == true)
          TeammateAccount(
            platform: meta.id,
            handle: _accountControllers[meta.id]!.text,
            enabled: true,
          ),
    ];
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少启用一个平台账号')),
      );
      return;
    }
    final now = DateTime.now();
    final initial = widget.initial;
    final profile = initial == null
        ? TeammateProfile.create(
            nickname: _nicknameController.text,
            accounts: accounts,
            now: now,
          )
        : initial.copyWith(
            nickname: _nicknameController.text,
            accounts: accounts,
            updatedAt: now,
          );
    Navigator.pop(context, profile);
  }
}
