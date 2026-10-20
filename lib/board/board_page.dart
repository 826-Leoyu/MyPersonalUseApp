import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import 'board_canvas.dart';
import 'storage_error_page.dart';

/// 画布页面：存储打开后显示顶部标题和当前显示那一天的画布。存储打不开、或者读不出
/// 画布内容时显示错误页，不显示空画布。
class BoardPage extends ConsumerWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final day = ref.watch(displayedDayProvider);
    // 画布内容依赖打开好的 service，所以打不开时这里也是错误状态。
    final board = ref.watch(dayBoardProvider(day));
    if (board case AsyncError(:final error)) {
      return StorageErrorPage(
        error: error,
        // 重新打开存储；画布内容随之重新读取。
        onRetry: () => ref.invalidate(plannerServiceProvider),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          day == today ? '${formatFullDate(day)} · 今天' : formatFullDate(day),
        ),
      ),
      body: switch (board) {
        AsyncData(:final value) => BoardCanvas(
          board: value,
          // 过去的日期不能新建卡片。
          canCreateCards: day >= today,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
