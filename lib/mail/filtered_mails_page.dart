import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../board/read_failure_view.dart';
import '../formatting/date_format.dart';
import '../planner/planner_exceptions.dart';
import 'mail_items.dart';
import 'mail_service.dart';

/// "已过滤的邮件"：没有生成候选事项的邮件和被忽略的事项，每条有主题、发件人、
/// 日期和理由。邮件可以点 [这封有用] 重新分析，被忽略的事项可以 [恢复] 回到
/// 栏里。只改 DailyNote 里的记录，不动 Outlook。
class FilteredMailsPage extends ConsumerWidget {
  const FilteredMailsPage({super.key});

  /// 打开已过滤的邮件。
  static Future<void> open(NavigatorState navigator) => navigator.push(
    MaterialPageRoute<void>(builder: (_) => const FilteredMailsPage()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(mailFilteredProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('已过滤的邮件')),
      body: switch (filtered) {
        AsyncData(value: []) => const Center(child: Text('没有已过滤的邮件')),
        AsyncData(:final value) => ListView(
          children: [
            for (final entry in value)
              _FilteredTile(key: ValueKey(entry.id), entry: entry),
          ],
        ),
        AsyncError() => ReadFailureView(
          onRetry: () => ref.invalidate(mailFilteredProvider),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// 一条：标题，发件人和日期，理由，右边是 [这封有用] 或 [恢复]。
class _FilteredTile extends ConsumerStatefulWidget {
  const _FilteredTile({super.key, required this.entry});

  final FilteredEntry entry;

  @override
  ConsumerState<_FilteredTile> createState() => _FilteredTileState();
}

class _FilteredTileState extends ConsumerState<_FilteredTile> {
  /// 正在处理，按钮先不响应，避免点两次。
  bool _busy = false;

  Future<void> _markUseful() async {
    if (widget.entry.bodyCleared) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(MailService.bodyClearedMessage)),
      );
      return;
    }
    await _run((service) => service.markUseful(widget.entry.mailId));
  }

  Future<void> _restore() =>
      _run((service) => service.restoreItem(widget.entry.id));

  /// 执行 [action]；失败时提示，这一条还在列表里。
  Future<void> _run(Future<void> Function(MailService service) action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      await action(await ref.read(mailServiceProvider.future));
    } on PlannerException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(e is InvalidState ? e.message : '操作失败，请重试')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final received = entry.receivedAt;
    return ListTile(
      title: Text(entry.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              entry.sender,
              if (received != null) formatReceivedTime(received),
            ].join(' · '),
          ),
          if (entry.reason.isNotEmpty) Text(entry.reason),
        ],
      ),
      trailing: entry.kind.isMail
          ? TextButton(
              onPressed: _busy ? null : _markUseful,
              child: const Text('这封有用'),
            )
          : TextButton(
              onPressed: _busy ? null : _restore,
              child: const Text('恢复'),
            ),
    );
  }
}
