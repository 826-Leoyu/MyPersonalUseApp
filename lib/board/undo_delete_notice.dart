import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import 'board_canvas.dart';

/// 删除成功后的撤销提示：点「撤销」把卡片从回收站拿回来。新的提示顶替
/// 旧的，每个提示只恢复自己那张卡片。画布和已完成列表共用。
///
/// 点撤销时发起删除的界面可能已经不在了（换了一天、关了列表、存储重新
/// 打开过），所以用 [container] 读当前的 service，不依赖界面还在。恢复成功
/// 后调用 [onRestored]。
void showUndoDeleteNotice(
  TaskCard card,
  ScaffoldMessengerState messenger,
  ProviderContainer container, {
  VoidCallback? onRestored,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('已移到回收站：『${card.title}』'),
        duration: BoardCanvas.undoDuration,
        // 带按钮的提示默认不会自己消失。
        persist: false,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => _undoDelete(card, messenger, container, onRestored),
        ),
      ),
    );
}

/// 点了撤销提示上的「撤销」。卡片原来的日期已经过去、恢复时被顺延到今天
/// 的，另外提示一下（已完成的卡片不会被顺延）。
Future<void> _undoDelete(
  TaskCard card,
  ScaffoldMessengerState messenger,
  ProviderContainer container,
  VoidCallback? onRestored,
) async {
  final PlannerService service;
  try {
    service = await container.read(plannerServiceProvider.future);
    await service.restoreCard(card.id);
  } on PlannerException {
    messenger.showSnackBar(const SnackBar(content: Text('恢复失败，请重试')));
    return;
  }
  onRestored?.call();
  // 已经恢复成功；查不到现在的日期只是少一条提示，不算恢复失败。
  try {
    final location = await service.findCard(card.id);
    if (location.dayKey != card.dayKey) {
      messenger.showSnackBar(
        SnackBar(content: Text('已恢复至今天（${formatShortDate(location.dayKey)}）')),
      );
    }
  } on PlannerException {
    return;
  }
}
