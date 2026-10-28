import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../board/read_failure_view.dart';
import '../formatting/date_format.dart';
import 'mail_preview.dart';

/// 邮件预览里点开的一封邮件：转换后的正文、编号的链接和正文的提示，用来检查
/// HTML 转文本的结果。
class MailDetailPage extends ConsumerWidget {
  const MailDetailPage({super.key, required this.mailId});

  final String mailId;

  /// 打开 [mailId] 这封邮件。
  static Future<void> open(NavigatorState navigator, String mailId) =>
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => MailDetailPage(mailId: mailId)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(mailDetailProvider(mailId));
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (detail) {
          AsyncData(value: final d?) => d.preview.displaySubject,
          _ => '',
        }),
      ),
      body: switch (detail) {
        AsyncData(value: final d?) => _MailDetailView(detail: d),
        AsyncData() => const Center(child: Text('找不到这封邮件')),
        AsyncError() => ReadFailureView(
          onRetry: () => ref.invalidate(mailDetailProvider(mailId)),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _MailDetailView extends StatelessWidget {
  const _MailDetailView({required this.detail});

  final MailDetail detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final preview = detail.preview;
    final body = detail.body;
    final received = preview.receivedAt;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          [
            preview.displaySender,
            if (received != null) formatReceivedTime(received),
          ].join(' · '),
          style: textTheme.bodyMedium,
        ),
        if (body.possiblyIncomplete || body.hasInlineImages) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (body.possiblyIncomplete) const Chip(label: Text('正文可能不完整')),
              if (body.hasInlineImages) const Chip(label: Text('有内嵌图片')),
            ],
          ),
        ],
        const Divider(height: 32),
        SelectableText(
          detail.bodyCleared ? bodyClearedMessage : body.text ?? '（没有正文）',
        ),
        if (body.links.isNotEmpty) ...[
          const Divider(height: 32),
          Text('链接', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final (index, url) in body.links.indexed)
            SelectableText('[${index + 1}] $url'),
        ],
      ],
    );
  }
}
