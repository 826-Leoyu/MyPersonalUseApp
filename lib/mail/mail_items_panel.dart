import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../board/read_failure_view.dart';
import '../formatting/date_format.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import 'filtered_mails_page.dart';
import 'mail_detail_page.dart';
import 'mail_import_status_line.dart';
import 'mail_items.dart';
import 'mail_service.dart';
import 'mail_setup.dart';

/// "新邮件事项"栏的宽度（宽屏时在画布右边），连同四周的留白。
const mailItemsPanelWidth = 336.0;

/// "新邮件事项"栏的内容：标题、状态行、候选事项，底部是
/// "已过滤的邮件 (N)"。每条候选可以 [加入]（默认今天，
/// "改日期"可以选今天或以后）或 [忽略]。宽屏时放在画布右边的面板里，窄屏
/// 时放在底部面板里，内容一样。
class MailItemsPanel extends ConsumerWidget {
  const MailItemsPanel({
    super.key,
    required this.newCardPosition,
    required this.onOpenSetup,
    this.onCollapse,
  });

  /// 栏右上角收起栏的按钮的 key。
  static const collapseButtonKey = ValueKey('mail-items-collapse');

  /// 一条候选事项上 [加入]、[忽略]、"改日期"按钮的 key。
  static Key acceptButtonKey(String itemId) =>
      ValueKey('mail-item-accept-$itemId');
  static Key ignoreButtonKey(String itemId) =>
      ValueKey('mail-item-ignore-$itemId');
  static Key dateButtonKey(String itemId) => ValueKey('mail-item-date-$itemId');

  /// 加入到 [day] 时新卡片左上角在画布上的位置。
  final Offset Function(DayKey day) newCardPosition;

  /// 打开首次设置向导，见 [MailImportStatusLine.onOpenSetup]。
  final void Function([SetupStep? step]) onOpenSetup;

  /// 收起栏；为 null 时没有收起按钮（底部面板）。
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(mailCandidatesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            PlannerTheme.space4,
            PlannerTheme.space2,
            PlannerTheme.space1,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '新邮件事项',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onCollapse case final onCollapse?)
                IconButton(
                  key: collapseButtonKey,
                  tooltip: '收起',
                  onPressed: onCollapse,
                  icon: const Icon(Icons.keyboard_tab),
                ),
            ],
          ),
        ),
        MailImportStatusLine(onOpenSetup: onOpenSetup),
        Expanded(
          child: switch (candidates) {
            AsyncData(value: []) => const Center(child: Text('没有新的邮件事项')),
            AsyncData(:final value) => ListView(
              padding: const EdgeInsets.all(PlannerTheme.space2),
              children: [
                for (final item in value)
                  _CandidateTile(
                    key: ValueKey(item.id),
                    item: item,
                    newCardPosition: newCardPosition,
                  ),
              ],
            ),
            AsyncError() => ReadFailureView(
              onRetry: () => ref.invalidate(mailCandidatesProvider),
            ),
            _ => const SizedBox.shrink(),
          },
        ),
        const _FilteredMailsButton(),
      ],
    );
  }
}

/// 栏底部的"已过滤的邮件 (N)"，打开已过滤的邮件。读不出来时不显示数字。
class _FilteredMailsButton extends ConsumerWidget {
  const _FilteredMailsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(mailFilteredProvider).value?.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PlannerTheme.space2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => FilteredMailsPage.open(Navigator.of(context)),
          icon: const Icon(Icons.filter_list, size: 18),
          label: Text(count == null ? '已过滤的邮件' : '已过滤的邮件 ($count)'),
        ),
      ),
    );
  }
}

/// 一条候选事项：标题、"可选"标签、时间、来自哪封邮件，下面是"改日期"、
/// [忽略] 和 [加入]。点它展开详情：摘要、要做的事、地点、链接和
/// [查看原邮件]。
class _CandidateTile extends ConsumerStatefulWidget {
  const _CandidateTile({
    super.key,
    required this.item,
    required this.newCardPosition,
  });

  final MailItemCandidate item;
  final Offset Function(DayKey day) newCardPosition;

  @override
  ConsumerState<_CandidateTile> createState() => _CandidateTileState();
}

class _CandidateTileState extends ConsumerState<_CandidateTile> {
  /// 选的日期；为 null 时是今天（跟着"今天"变）。
  DayKey? _day;

  /// 正在加入或忽略，按钮先不响应，避免点两次。
  bool _busy = false;

  /// 展开着详情没有。
  bool _expanded = false;

  DayKey get _targetDay {
    final today = ref.read(todayProvider);
    final day = _day;
    return day == null || day < today ? today : day;
  }

  Future<void> _pickDay() async {
    final today = ref.read(todayProvider);
    final initial = _targetDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      // 不能加入到过去的日子。
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = DayKey(picked.year, picked.month, picked.day));
  }

  Future<void> _accept() async {
    final day = _targetDay;
    final position = widget.newCardPosition(day);
    await _run(
      (service) => service.acceptItem(
        widget.item.id,
        day: day,
        x: position.dx,
        y: position.dy,
      ),
      failure: '加入失败，请重试',
    );
  }

  Future<void> _ignore() => _run(
    (service) => service.ignoreItem(widget.item.id),
    failure: '忽略失败，请重试',
  );

  /// 执行 [action]；失败时提示 [failure]，事项还在栏里。
  Future<void> _run(
    Future<void> Function(MailService service) action, {
    required String failure,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      await action(await ref.read(mailServiceProvider.future));
    } on PlannerException {
      messenger?.showSnackBar(SnackBar(content: Text(failure)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mutedColor = textTheme.bodySmall?.color?.withValues(alpha: 0.7);
    final item = widget.item;
    final timeLine = formatCardTimeLine((
      event: item.eventTime,
      due: item.dueTime,
    ));
    final today = ref.watch(todayProvider);
    final day = _targetDay;
    final id = item.id;
    final details = [
      ?item.summary,
      for (final action in item.actions) '- $action',
      if (item.location case final location?) '地点：$location',
      ...item.links,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: PlannerTheme.space2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            PlannerTheme.space3,
            PlannerTheme.space3,
            PlannerTheme.space2,
            PlannerTheme.space1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.title, style: textTheme.titleSmall),
                  ),
                  if (item.updated) ...[
                    const SizedBox(width: PlannerTheme.space2),
                    const _Tag('已更新'),
                  ],
                  if (item.optional) ...[
                    const SizedBox(width: PlannerTheme.space2),
                    const _Tag('可选'),
                  ],
                ],
              ),
              if (timeLine != null) Text(timeLine, style: textTheme.bodySmall),
              Text(
                '来自 ${item.sender}《${item.mailSubject}》',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
              if (item.relatedHint case final note?)
                Text(
                  note,
                  style: textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
              if (item.hasUnanalyzedAttachments)
                Text(
                  '附件或图片未分析',
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              if (_expanded) ...[
                const SizedBox(height: PlannerTheme.space2),
                for (final line in details)
                  SelectableText(line, style: textTheme.bodyMedium),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () =>
                        MailDetailPage.open(Navigator.of(context), item.mailId),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('查看原邮件'),
                  ),
                ),
              ],
              Row(
                children: [
                  Tooltip(
                    message: '改日期',
                    child: TextButton.icon(
                      key: MailItemsPanel.dateButtonKey(id),
                      onPressed: _busy ? null : _pickDay,
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(day == today ? '今天' : formatShortDate(day)),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: MailItemsPanel.ignoreButtonKey(id),
                    onPressed: _busy ? null : _ignore,
                    child: const Text('忽略'),
                  ),
                  FilledButton.tonal(
                    key: MailItemsPanel.acceptButtonKey(id),
                    onPressed: _busy ? null : _accept,
                    child: const Text('加入'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 事项标题旁边的小标签：可选活动的"可选"、被后续邮件更新过的"已更新"。
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: PlannerTheme.tagRadius,
      ),
      child: Padding(
        padding: PlannerTheme.tagPadding,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
