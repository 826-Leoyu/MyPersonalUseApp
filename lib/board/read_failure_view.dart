import 'package:flutter/material.dart';

/// 列表页读不出来时显示的提示：「读取失败，请重试」和「重试」按钮。
/// 已完成列表和回收站共用。
class ReadFailureView extends StatelessWidget {
  const ReadFailureView({super.key, required this.onRetry});

  /// 点「重试」时重新读取。
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('读取失败，请重试'),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
