import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/planner_exceptions.dart';
import '../planner/trashed_card.dart';
import 'board_selection.dart';
import 'restore_from_trash.dart';

/// 回收站：每项显示原日期（完整格式）和「还剩 N 天」，按删除时间倒序。
/// 不显示「顺延」标记。永久删除单张和清空回收站之前都先确认。
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  /// 列表里一项的 key。
  static ValueKey<String> itemKey(String cardId) =>
      ValueKey('trash-item-$cardId');

  /// 打开回收站。
  static Future<void> open(NavigatorState navigator) => navigator.push(
    MaterialPageRoute<void>(builder: (_) => const TrashPage()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashProvider);
    final items = trash.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          // 回收站是空的、或者还没读出来时点不了。
          TextButton(
            onPressed: items == null || items.isEmpty
                ? null
                : () => _empty(context, ref, items.length),
            child: const Text('清空'),
          ),
        ],
      ),
      body: switch (trash) {
        AsyncData(value: []) => const Center(child: Text('回收站是空的')),
        AsyncData(:final value) => ListView(
          children: [for (final item in value) _TrashItem(item: item)],
        ),
        AsyncError() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('读取失败，请重试'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(trashProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  /// 清空回收站：确认以后永久删除里面的所有卡片。
  Future<void> _empty(BuildContext context, WidgetRef ref, int count) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await _confirm(
      context,
      title: '清空回收站？',
      content: '回收站里的 $count 张卡片会被永久删除，无法恢复。',
      action: '清空',
    );
    if (!confirmed) return;
    try {
      final service = await ref.read(plannerServiceProvider.future);
      await service.emptyTrash();
    } on PlannerException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
    }
  }
}

/// 回收站的一项：标题，原日期和剩余天数，以及「恢复」和「永久删除」按钮。
class _TrashItem extends ConsumerWidget {
  const _TrashItem({required this.item});

  final TrashedCard item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = item.card;
    return ListTile(
      key: TrashPage.itemKey(card.id),
      title: Text(card.title),
      subtitle: Text('${formatFullDate(card.dayKey)} · 还剩 ${item.daysLeft} 天'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '恢复',
            icon: const Icon(Icons.restore),
            onPressed: () => _restore(context),
          ),
          IconButton(
            tooltip: '永久删除',
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: () => _deleteForever(context, ref),
          ),
        ],
      ),
    );
  }

  /// 恢复：按 `restoreCard` 的规则回到原日期，或者顺延到今天；从列表里消失。
  void _restore(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    // 恢复成功后这一项就不在了，用页面外面的容器。
    final container = ProviderScope.containerOf(context, listen: false);
    restoreFromTrash(item.card, messenger, container);
  }

  /// 永久删除：确认以后删掉这张卡片和它的连线、历史记录。
  Future<void> _deleteForever(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await _confirm(
      context,
      title: '永久删除『${item.card.title}』？',
      content: '永久删除后无法恢复。',
      action: '永久删除',
    );
    if (!confirmed) return;
    try {
      final service = await ref.read(plannerServiceProvider.future);
      await service.deleteForever(item.card.id);
    } on PlannerException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
    }
  }
}

/// 弹出确认框，用户点了 [action] 时返回 true；点「取消」或者点框外关掉时
/// 返回 false。
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String content,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
