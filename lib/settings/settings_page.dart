import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../planner/planner_exceptions.dart';

/// 设置页。现在只有「邮件」一节（只在 Windows 上有）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// 「邮箱地址」一项的 key。
  static const mailboxTileKey = ValueKey('settings-mailbox');

  /// 填写邮箱地址的输入框的 key。
  static const mailboxFieldKey = ValueKey('settings-mailbox-field');

  /// 打开设置页。
  static Future<void> open(NavigatorState navigator) => navigator.push(
    MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mailbox = ref.watch(mailboxAddressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          if (mailAvailable) ...[
            ListTile(
              title: Text(
                '邮件',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            ListTile(
              key: mailboxTileKey,
              title: const Text('邮箱地址'),
              subtitle: Text(switch (mailbox) {
                AsyncData(value: final address?) => address,
                AsyncData() => '未填写。旧格式的导出文件需要它来去重',
                AsyncError() => '读取失败',
                _ => '',
              }),
              enabled: mailbox is AsyncData,
              onTap: () => _editMailbox(context, ref, mailbox.value),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editMailbox(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _MailboxDialog(
        initial: current ?? '',
        save: (address) async {
          final service = await ref.read(mailServiceProvider.future);
          await service.setMailboxAddress(address);
        },
      ),
    );
    if (saved == true) ref.invalidate(mailboxAddressProvider);
    if (saved == false) {
      messenger.showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
  }
}

/// 填写邮箱地址的对话框。保存成功时返回 true，存储失败时返回 false，取消时
/// 返回 null；格式不对时留在对话框里显示错误。
class _MailboxDialog extends StatefulWidget {
  const _MailboxDialog({required this.initial, required this.save});

  final String initial;
  final Future<void> Function(String address) save;

  @override
  State<_MailboxDialog> createState() => _MailboxDialogState();
}

class _MailboxDialogState extends State<_MailboxDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await widget.save(_controller.text);
      navigator.pop(true);
    } on InvalidInput catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } on PlannerException {
      navigator.pop(false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('邮箱地址'),
    content: TextField(
      key: SettingsPage.mailboxFieldKey,
      controller: _controller,
      autofocus: true,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: 'name@example.com',
        helperText: '留空表示不填写',
        errorText: _error,
      ),
      onSubmitted: (_) => _saving ? null : _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _saving ? null : _save, child: const Text('保存')),
    ],
  );
}
