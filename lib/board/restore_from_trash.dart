import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';

/// 把 [card] 从回收站拿回来。删除的撤销提示和回收站共用。
///
/// 失败时提示「恢复失败，请重试」。卡片原来的日期已经过去、恢复时被顺延
/// 到今天的，另外提示一下（已完成的卡片不会被顺延）。发起恢复的界面可能
/// 已经不在了，所以用 [container] 读当前的 service。恢复成功后先调用
/// [onRestored]，再查卡片现在的日期。
Future<void> restoreFromTrash(
  TaskCard card,
  ScaffoldMessengerState? messenger,
  ProviderContainer container, {
  VoidCallback? onRestored,
}) async {
  final PlannerService service;
  try {
    service = await container.read(plannerServiceProvider.future);
    await service.restoreCard(card.id);
  } on PlannerException {
    messenger?.showSnackBar(const SnackBar(content: Text('恢复失败，请重试')));
    return;
  }
  onRestored?.call();
  // 已经恢复成功；查不到现在的日期只是少一条提示，不算恢复失败。
  try {
    final location = await service.findCard(card.id);
    if (location.dayKey != card.dayKey) {
      messenger?.showSnackBar(
        SnackBar(content: Text('已恢复至今天（${formatShortDate(location.dayKey)}）')),
      );
    }
  } on PlannerException {
    return;
  }
}
