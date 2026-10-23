import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../planner/task_card.dart';
import 'board_canvas.dart';
import 'restore_from_trash.dart';

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
          onPressed: () => restoreFromTrash(
            card,
            messenger,
            container,
            onRestored: onRestored,
          ),
        ),
      ),
    );
}
