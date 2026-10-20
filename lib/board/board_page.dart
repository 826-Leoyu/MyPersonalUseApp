import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import 'board_canvas.dart';
import 'storage_error_page.dart';

/// 画布页面：存储打开后显示顶部标题和今天的画布。存储打不开、或者读不出
/// 画布内容时显示错误页，不显示空画布。
class BoardPage extends ConsumerWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    // 画布内容依赖打开好的 service，所以打不开时这里也是错误状态。
    final board = ref.watch(dayBoardProvider(today));
    if (board case AsyncError(:final error)) {
      return StorageErrorPage(
        error: error,
        // 重新打开存储；画布内容随之重新读取。
        onRetry: () => ref.invalidate(plannerServiceProvider),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('${formatFullDate(today)} · 今天')),
      body: switch (board) {
        AsyncData(:final value) => BoardCanvas(board: value),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
