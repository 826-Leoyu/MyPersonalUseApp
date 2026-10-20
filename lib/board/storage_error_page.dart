import 'package:flutter/material.dart';

import '../planner/planner_exceptions.dart';

/// 数据库打不开时的全屏错误页。不进入画布，防止在空数据上继续操作把数据
/// 覆盖掉。
class StorageErrorPage extends StatelessWidget {
  const StorageErrorPage({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final detail = error is StorageFailure
        ? '${error.cause ?? error}'
        : '$error';
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('数据库打不开', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              SelectableText(
                detail,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('重试')),
            ],
          ),
        ),
      ),
    );
  }
}
