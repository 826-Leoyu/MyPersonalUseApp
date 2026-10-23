import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import 'board_selection.dart';
import 'undo_delete_notice.dart';

/// 某一天的「已完成」列表：标题是完整格式的日期和完成数量，每项显示完成
/// 时间 `HH:mm`，按完成时间倒序。不显示「顺延」标记。
class CompletedPage extends ConsumerWidget {
  const CompletedPage({super.key, required this.day});

  /// 列表里一项的 key。
  static ValueKey<String> itemKey(String cardId) =>
      ValueKey('completed-item-$cardId');

  /// 打开 [day] 这一天的已完成列表。
  static Future<void> open(NavigatorState navigator, DayKey day) => navigator
      .push(MaterialPageRoute<void>(builder: (_) => CompletedPage(day: day)));

  final DayKey day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(completedCardsProvider(day));
    final title = switch (cards) {
      AsyncData(:final value) =>
        '${formatFullDate(day)} · 已完成 ${value.length} 项',
      _ => formatFullDate(day),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: switch (cards) {
        AsyncData(:final value) => ListView(
          children: [for (final card in value) _CompletedItem(card: card)],
        ),
        AsyncError() => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('读取失败，请重试'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(completedCardsProvider(day)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// 已完成列表的一项：完成时间、标题，以及「取消完成」和「删除」按钮。
class _CompletedItem extends ConsumerWidget {
  const _CompletedItem({required this.card});

  final TaskCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: CompletedPage.itemKey(card.id),
      leading: Text(formatTimeOfDay(card.completedAt!)),
      title: Text(card.title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '取消完成',
            icon: const Icon(Icons.undo),
            onPressed: () => _uncomplete(context, ref),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  /// 取消完成：卡片回到画布，从列表里消失。卡片的日期已经过去、被顺延到
  /// 别的日期的，另外提示一下（系统时钟回拨时不一定是时钟的今天）。
  Future<void> _uncomplete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final PlannerService service;
    try {
      service = await ref.read(plannerServiceProvider.future);
      await service.uncompleteCard(card.id);
    } on PlannerException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
      return;
    }
    // 已经取消完成；查不到现在的日期只是少一条提示，不算失败。
    try {
      final location = await service.findCard(card.id);
      if (location.dayKey != card.dayKey) {
        messenger?.showSnackBar(
          SnackBar(content: Text('已顺延至 ${formatShortDate(location.dayKey)}')),
        );
      }
    } on PlannerException {
      return;
    }
  }

  /// 删除：卡片移到回收站，从列表里消失。提示里点「撤销」把它拿回来。
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // 撤销时这一项已经不在了，用页面外面的容器。
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final service = await ref.read(plannerServiceProvider.future);
      await service.deleteCard(card.id);
    } on PlannerException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
      return;
    }
    if (messenger != null) showUndoDeleteNotice(card, messenger, container);
  }
}
