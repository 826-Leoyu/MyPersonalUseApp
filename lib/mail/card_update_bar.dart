import 'package:flutter/material.dart';

import '../app/planner_theme.dart';
import '../formatting/date_format.dart';
import '../planner/card_time.dart';
import 'item_changes.dart';
import 'mail_items.dart';

/// 卡片底部的黄色更新提示条："📩 有更新：截止 Oct 30 → Nov 2"，带
/// [采用] 和 [不用]（spec 0002"界面·卡片"）。
class CardUpdateBar extends StatelessWidget {
  const CardUpdateBar({
    super.key,
    required this.update,
    required this.busy,
    required this.onApply,
    required this.onReject,
    this.applyKey,
    this.rejectKey,
  });

  final CardUpdate update;

  /// 正在采用或不用，按钮先不响应，避免点两次。
  final bool busy;
  final VoidCallback onApply;
  final VoidCallback onReject;
  final Key? applyKey;
  final Key? rejectKey;

  static const _background = Color(0xFFFFF3C4);
  static const _foreground = Color(0xFF3D3000);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: _foreground,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: PlannerTheme.space2),
    );
    return Material(
      color: _background,
      borderRadius: PlannerTheme.rowRadius,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PlannerTheme.space3,
          PlannerTheme.space2,
          PlannerTheme.space1,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              describeCardUpdate(update),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: _foreground),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: rejectKey,
                  style: buttonStyle,
                  onPressed: busy ? null : onReject,
                  child: const Text('不用'),
                ),
                TextButton(
                  key: applyKey,
                  style: buttonStyle,
                  onPressed: busy ? null : onApply,
                  child: const Text('采用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 提示条上的文字，例如 `📩 有更新：截止 Oct 30 → Nov 2`。时间写出卡片上
/// 现在的和建议的；其他字段只说改了什么。
String describeCardUpdate(CardUpdate update) {
  final fields = update.changes.fields;
  final values = update.changes.values;
  String time(CardTime? time) => time == null ? '无' : formatCardTime(time);
  final parts = [
    if (fields.contains(ItemField.title)) '标题改为《${values.title}》',
    if (fields.contains(ItemField.eventTime))
      '活动 ${time(update.cardTimes.event)} → ${time(values.eventTime)}',
    if (fields.contains(ItemField.dueTime))
      '截止 ${time(update.cardTimes.due)} → ${time(values.dueTime)}',
    if (fields.contains(ItemField.location))
      switch (values.location) {
        final location? => '地点改为 $location',
        null => '去掉地点',
      },
    if (fields.contains(ItemField.summary)) '摘要有变化',
    if (fields.contains(ItemField.actions)) '要做的事有变化',
    if (fields.contains(ItemField.links)) '链接有变化',
  ];
  return '📩 有更新：${parts.join('；')}';
}
