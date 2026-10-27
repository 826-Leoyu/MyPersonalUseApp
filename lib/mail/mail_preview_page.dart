import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../board/read_failure_view.dart';
import '../formatting/date_format.dart';
import '../planner/planner_exceptions.dart';
import '../settings/settings_page.dart';
import 'mail_detail_page.dart';
import 'mail_preview.dart';
import 'mail_service.dart';

/// 邮件预览（只在 Windows 上有）：手动选择一个导出文件导入，列出已导入的邮件
/// 的主题、发件人和收件时间，收件时间最新的在前。点一封邮件看它的正文。
class MailPreviewPage extends ConsumerStatefulWidget {
  const MailPreviewPage({super.key});

  /// 「导入文件」按钮的 key。
  static const importButtonKey = ValueKey('mail-import-button');

  /// 列表里一项的 key。
  static ValueKey<String> itemKey(String mailId) =>
      ValueKey('mail-preview-item-$mailId');

  /// 打开邮件预览。
  static Future<void> open(NavigatorState navigator) => navigator.push(
    MaterialPageRoute<void>(builder: (_) => const MailPreviewPage()),
  );

  @override
  ConsumerState<MailPreviewPage> createState() => _MailPreviewPageState();
}

class _MailPreviewPageState extends ConsumerState<MailPreviewPage> {
  /// 正在导入；导入完以前不能再点「导入文件」。
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final mails = ref.watch(mailPreviewsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('邮件预览'),
        actions: [
          TextButton.icon(
            key: MailPreviewPage.importButtonKey,
            onPressed: _importing ? null : _import,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('导入文件'),
          ),
        ],
      ),
      body: switch (mails) {
        AsyncData(value: []) => const Center(child: Text('还没有导入邮件')),
        AsyncData(:final value) => ListView(
          children: [for (final mail in value) _MailTile(mail: mail)],
        ),
        AsyncError() => ReadFailureView(
          onRetry: () => ref.invalidate(mailPreviewsProvider),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Future<void> _import() async {
    final path = await ref.read(pickMailExportFileProvider)();
    if (path == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _importing = true);
    final SnackBar snackBar;
    try {
      final service = await ref.read(mailServiceProvider.future);
      final outcome = await service.importFile(path);
      snackBar = _outcomeSnackBar(outcome, navigator);
    } on PlannerException {
      messenger.showSnackBar(const SnackBar(content: Text('导入失败，邮件没有变化，请重试')));
      return;
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    messenger.showSnackBar(snackBar);
  }

  SnackBar _outcomeSnackBar(ImportOutcome outcome, NavigatorState navigator) =>
      switch (outcome) {
        Imported(:final fileName, :final newMailCount, :final skippedCount) =>
          SnackBar(
            content: Text(
              '已导入 $fileName：新邮件 $newMailCount 封'
              '${skippedCount > 0 ? '，跳过 $skippedCount 封缺少编号的邮件' : ''}',
            ),
          ),
        AlreadyImported(:final fileName) => SnackBar(
          content: Text('$fileName 已经导入过'),
        ),
        NeedsMailbox(:final fileName) => SnackBar(
          content: Text('$fileName 没有写明邮箱，请先在设置里填写邮箱地址'),
          action: SnackBarAction(
            label: '去设置',
            onPressed: () => SettingsPage.open(navigator),
          ),
        ),
        InvalidFile(:final fileName) => SnackBar(
          content: Text('文件 $fileName 格式错误，已跳过'),
        ),
        UnreadableFile(:final fileName) => SnackBar(
          content: Text('读不出文件 $fileName'),
        ),
      };
}

class _MailTile extends StatelessWidget {
  const _MailTile({required this.mail});

  final MailPreview mail;

  @override
  Widget build(BuildContext context) {
    final sender = mail.senderName ?? mail.senderAddress ?? '（未知发件人）';
    final received = mail.receivedAt;
    return ListTile(
      key: MailPreviewPage.itemKey(mail.id),
      onTap: () => MailDetailPage.open(Navigator.of(context), mail.id),
      title: Text(
        mail.subject.isEmpty ? '（无主题）' : mail.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          sender,
          if (received != null) formatReceivedTime(received),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
