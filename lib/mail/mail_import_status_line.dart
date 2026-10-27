import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import 'import_status.dart';
import 'mail_service.dart';

/// "新邮件事项"栏顶部的状态行（spec 0002"界面·状态行"）：最靠前的一条
/// 提示，有好几条时点开看全部；[立即导入]；找不到文件夹时 [重新选择]；
/// 下面常驻一行"不代表云端流程正常"的说明。
class MailImportStatusLine extends ConsumerStatefulWidget {
  const MailImportStatusLine({super.key, required this.onOpenSettings});

  /// 状态行最上面那一条的 key。
  static const headlineKey = ValueKey('mail-import-headline');
  static const importNowKey = ValueKey('mail-import-now');
  static const chooseAgainKey = ValueKey('mail-import-choose-again');
  static const resumeAnalysisKey = ValueKey('mail-analysis-resume');
  static const retryAnalysisKey = ValueKey('mail-analysis-retry');

  /// 打开设置页（没选择文件夹时的"开始设置"）。
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<MailImportStatusLine> createState() =>
      _MailImportStatusLineState();
}

class _MailImportStatusLineState extends ConsumerState<MailImportStatusLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget content;
    switch (ref.watch(mailImportStatusProvider)) {
      case AsyncData(value: final status):
        final notices = status.notices;
        if (notices.contains(const FolderNotSet())) {
          content = _headline(
            '开始设置',
            onTap: widget.onOpenSettings,
            style: TextStyle(color: theme.colorScheme.primary),
          );
          break;
        }
        final lines = [
          for (final notice in notices) _noticeText(notice),
          _lastImportText(status),
        ];
        final headline = notices.isEmpty ? '✅ ${lines.single}' : lines.first;
        final more = lines.length > 1;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _headline(
                    headline,
                    onTap: more
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    trailing: more
                        ? Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          )
                        : null,
                  ),
                ),
                if (notices.isNotEmpty) ?_action(notices, 0),
                if (notices.contains(const FolderMissing()))
                  TextButton(
                    key: MailImportStatusLine.chooseAgainKey,
                    onPressed: _chooseAgain,
                    child: const Text('重新选择'),
                  )
                else
                  TextButton(
                    key: MailImportStatusLine.importNowKey,
                    onPressed: _importNow,
                    child: const Text('立即导入'),
                  ),
              ],
            ),
            if (_expanded && more)
              for (final (i, line) in lines.indexed.skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: PlannerTheme.space1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(line, style: theme.textTheme.bodySmall),
                      ),
                      if (i < notices.length) ?_action(notices, i),
                    ],
                  ),
                ),
            Text('这里只能说明电脑上收到了文件，不代表云端流程现在还在正常运行。', style: small),
          ],
        );
      case AsyncError():
        content = Text('读不出导入情况', style: small);
      default:
        content = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        PlannerTheme.space4,
        0,
        PlannerTheme.space2,
        PlannerTheme.space2,
      ),
      child: content,
    );
  }

  Widget _headline(
    String text, {
    VoidCallback? onTap,
    TextStyle? style,
    Widget? trailing,
  }) => InkWell(
    key: MailImportStatusLine.headlineKey,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: PlannerTheme.space1),
      child: Row(
        children: [
          Flexible(child: Text(text, style: style)),
          ?trailing,
        ],
      ),
    ),
  );

  String _noticeText(ImportNotice notice) => switch (notice) {
    FolderNotSet() => '开始设置',
    FolderMissing() => '❌ 找不到邮件文件夹',
    FilesSyncing() => '⏳ 有文件正在同步，稍后自动导入',
    FormatErrors(fileNames: [final name]) => '⚠ 文件 $name 格式不对（已跳过）',
    FormatErrors(:final fileNames) =>
      '⚠ 文件 ${fileNames.first} 等 ${fileNames.length} 个文件格式不对（已跳过）',
    NoNewFiles(:final since) =>
      '⚠ 已 ${ref.read(clockProvider).now().difference(since).inDays} 天没有'
          '新导出文件，请检查 Power Automate 流程',
    PossiblyMissedMails() => '⚠ 可能漏掉了一些邮件，请让设置者手动补读',
    AnalysisPaused() => '⏸ 今天的新邮件较多，已暂停自动分析',
    ClaudeNotInstalled() => '⚠ 没有找到 Claude Code，请先安装',
    ClaudeNotLoggedIn() => '⚠ Claude 未登录，请打开 Claude Code 登录',
    ClaudeQuotaExhausted() => '⏳ Claude 额度已用完，稍后自动重试',
    AnalysisFailures(:final count) => '⚠ $count 封邮件分析失败',
  };

  /// 第 [index] 条提示旁边的按钮；没有要她做的事时为 null。一个 [重试]
  /// 会重试所有失败的邮件，所以只放在第一条能重试的提示旁边。
  Widget? _action(List<ImportNotice> notices, int index) =>
      switch (notices[index]) {
        AnalysisPaused() => TextButton(
          key: MailImportStatusLine.resumeAnalysisKey,
          onPressed: () => _withService((s) => s.resumeAnalysis()),
          child: const Text('继续分析'),
        ),
        final notice
            when _retryable(notice) &&
                notices.indexWhere(_retryable) == index =>
          TextButton(
            key: MailImportStatusLine.retryAnalysisKey,
            onPressed: () => _withService((s) => s.retryAnalysis()),
            child: const Text('重试'),
          ),
        _ => null,
      };

  static bool _retryable(ImportNotice notice) =>
      notice is ClaudeNotInstalled ||
      notice is ClaudeNotLoggedIn ||
      notice is AnalysisFailures;

  Future<void> _withService(Future<void> Function(MailService) action) async {
    await action(await ref.read(mailServiceProvider.future));
  }

  String _lastImportText(MailImportStatus status) {
    final at = status.lastImportAt;
    if (at == null) return '还没有导入过导出文件';
    final local = at.toLocal();
    final when = DayKey.fromDateTime(local) == ref.read(todayProvider)
        ? '今天 ${formatTimeOfDay(local)}'
        : formatReceivedTime(local);
    return '上次导入：$when · 新邮件 ${status.lastImportNewMailCount} 封';
  }

  Future<void> _importNow() async {
    final schedule = await ref.read(mailScanScheduleProvider.future);
    await schedule.scanNow();
  }

  Future<void> _chooseAgain() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await chooseMailFolder(ref) is FolderUnavailable) {
        messenger.showSnackBar(const SnackBar(content: Text('这个文件夹打不开，请换一个')));
      }
    } on StorageFailure {
      messenger.showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
  }
}
