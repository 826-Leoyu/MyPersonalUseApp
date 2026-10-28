import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/planner_exceptions.dart';
import 'claude_code_analyzer.dart';
import 'import_status.dart';
import 'mail_analyzer.dart';
import 'mail_service.dart';
import 'mail_setup.dart';

/// 首次设置向导（spec 0002"界面·向导"）：同意 → 选择邮件文件夹 → 检查
/// Claude Code → 用内置示例邮件试分析。每一步都可以返回上一步；中途退出
/// 后下次从没做完的那一步继续。
class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key, this.startAt});

  static const consentKey = ValueKey('setup-consent');
  static const nextKey = ValueKey('setup-next');
  static const backKey = ValueKey('setup-back');
  static const chooseFolderKey = ValueKey('setup-choose-folder');
  static const recheckKey = ValueKey('setup-recheck');
  static const tryKey = ValueKey('setup-try');
  static const finishKey = ValueKey('setup-finish');

  /// 从哪一步开始；为 null 时从没做完的那一步开始，都做完了时从第一步开始。
  final SetupStep? startAt;

  /// 打开向导。
  static Future<void> open(NavigatorState navigator, {SetupStep? startAt}) =>
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => SetupWizardPage(startAt: startAt),
        ),
      );

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  /// 现在显示的一步；还没读出进度时为 null。
  SetupStep? _step;
  bool _failedToLoad = false;
  bool _busy = false;

  // 第 1 步
  bool _agreed = false;

  // 第 2 步
  FolderCheck? _folderCheck;

  // 第 3 步：正在检查时为 null。
  ClaudeCodeStatus? _claudeStatus;

  // 第 4 步
  AnalysisResult? _trialResult;
  AnalysisFailureType? _trialFailure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<MailService> get _service => ref.read(mailServiceProvider.future);

  Future<void> _load() async {
    try {
      final service = await _service;
      final resume = await service.setupStep();
      final agreed = await service.consentedAt() != null;
      if (!mounted) return;
      setState(() {
        _agreed = agreed;
        _failedToLoad = false;
      });
      _show(
        widget.startAt ??
            (resume == SetupStep.done ? SetupStep.consent : resume),
      );
    } on Exception {
      if (mounted) setState(() => _failedToLoad = true);
    }
  }

  void _show(SetupStep step) {
    setState(() => _step = step);
    if (step == SetupStep.folder) _checkCurrentFolder();
    if (step == SetupStep.claude) _checkClaude();
  }

  /// 已经选过文件夹时，进第 2 步就检查一次，马上显示结果。
  Future<void> _checkCurrentFolder() async {
    try {
      final service = await _service;
      final path = await service.mailFolder();
      if (path == null) return;
      final check = await service.checkFolder(path);
      if (mounted) setState(() => _folderCheck = check);
    } on StorageFailure {
      // 读不出文件夹时第 2 步显示"读取失败"，不另外提示。
    }
  }

  Future<void> _checkClaude() async {
    setState(() => _claudeStatus = null);
    final status = await ref.read(claudeCodeStatusProvider)();
    if (mounted) setState(() => _claudeStatus = status);
  }

  /// 跑 [action]，期间按钮不响应；保存失败时提示，返回 false。
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      return true;
    } on StorageFailure {
      messenger.showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    final step = _step!;
    final saved = await _run(() async {
      switch (step) {
        case SetupStep.consent:
          await (await _service).agreeToMailUse();
        case SetupStep.claude:
          await (await _service).completeClaudeCheck();
        case SetupStep.folder || SetupStep.trial || SetupStep.done:
          break;
      }
    });
    if (saved && mounted) _show(SetupStep.values[step.index + 1]);
  }

  Future<void> _chooseFolder() => _run(() async {
    final check = await chooseMailFolder(ref);
    if (check != null && mounted) setState(() => _folderCheck = check);
  });

  Future<void> _tryAnalysis() async {
    setState(() {
      _trialResult = null;
      _trialFailure = null;
    });
    await _run(() async {
      try {
        final result = await (await _service).analyzeSample();
        if (mounted) setState(() => _trialResult = result);
      } on AnalysisFailed catch (e) {
        if (mounted) setState(() => _trialFailure = e.type);
      } on StorageFailure {
        rethrow;
      } on Exception {
        // 分析器自己出了别的错：和进程异常一样算临时错误。
        if (mounted) {
          setState(() => _trialFailure = AnalysisFailureType.temporary);
        }
      }
    });
  }

  bool get _canContinue => switch (_step) {
    SetupStep.consent => _agreed,
    SetupStep.folder => ref.watch(mailFolderProvider).value != null,
    SetupStep.claude =>
      _claudeStatus is ClaudeCodeReady ||
          _claudeStatus is ClaudeCodeLoginUnknown,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _step;
    return Scaffold(
      appBar: AppBar(title: const Text('设置邮件')),
      body: switch (step) {
        _ when _failedToLoad => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('读不出设置进度'),
              TextButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
        null => const SizedBox.shrink(),
        final step => Padding(
          padding: const EdgeInsets.all(PlannerTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '第 ${step.index + 1} 步，共 4 步',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: PlannerTheme.space1),
              Text(_title(step), style: theme.textTheme.titleLarge),
              const SizedBox(height: PlannerTheme.space4),
              Expanded(child: SingleChildScrollView(child: _body(step, theme))),
              Row(
                children: [
                  if (step != SetupStep.consent)
                    TextButton(
                      key: SetupWizardPage.backKey,
                      onPressed: _busy
                          ? null
                          : () => _show(SetupStep.values[step.index - 1]),
                      child: const Text('上一步'),
                    ),
                  const Spacer(),
                  if (step == SetupStep.trial)
                    if (_trialResult != null)
                      FilledButton(
                        key: SetupWizardPage.finishKey,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('完成'),
                      )
                    else
                      const SizedBox.shrink()
                  else
                    FilledButton(
                      key: SetupWizardPage.nextKey,
                      onPressed: _canContinue && !_busy ? _next : null,
                      child: const Text('下一步'),
                    ),
                ],
              ),
            ],
          ),
        ),
      },
    );
  }

  static String _title(SetupStep step) => switch (step) {
    SetupStep.consent => '邮件怎么被使用',
    SetupStep.folder => '选择邮件文件夹',
    SetupStep.claude => '检查 Claude Code',
    SetupStep.trial || SetupStep.done => '用示例邮件试分析',
  };

  Widget _body(SetupStep step, ThemeData theme) => switch (step) {
    SetupStep.consent => _consent(),
    SetupStep.folder => _folder(),
    SetupStep.claude => _claudeCheck(theme),
    SetupStep.trial || SetupStep.done => _trial(),
  };

  Widget _consent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'DailyNote 会读取 Power Automate 导出到 OneDrive 文件夹里的邮件，'
        '找出需要你做的事和可以参加的活动。\n\n'
        '邮件内容会交给你自己账号下的 Claude 分析，不会改动、删除或回复 Outlook 里的邮件。'
        'DailyNote 不需要你的邮箱密码，也不保存你的 Claude 账号信息。',
      ),
      const SizedBox(height: PlannerTheme.space2),
      CheckboxListTile(
        key: SetupWizardPage.consentKey,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _agreed,
        onChanged: (value) => setState(() => _agreed = value ?? false),
        title: const Text('我知道了，同意这样分析我的邮件'),
      ),
    ],
  );

  Widget _folder() {
    final folder = ref.watch(mailFolderProvider);
    final check = switch (_folderCheck) {
      final check? => folderCheckText(check),
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('选择 Power Automate 保存导出文件的 OneDrive 文件夹。'),
        const SizedBox(height: PlannerTheme.space3),
        Text(switch (folder) {
          AsyncData(value: final path?) => path,
          AsyncData() => '还没有选择',
          AsyncError() => '读取失败',
          _ => '',
        }),
        if (check != null) Text(check),
        const SizedBox(height: PlannerTheme.space3),
        OutlinedButton(
          key: SetupWizardPage.chooseFolderKey,
          onPressed: _busy ? null : _chooseFolder,
          child: const Text('选择文件夹'),
        ),
      ],
    );
  }

  Widget _claudeCheck(ThemeData theme) {
    final status = _claudeStatus;
    final lines = switch (status) {
      null => const [Text('正在检查…')],
      ClaudeCodeMissing() => const [Text('找不到 Claude Code，请让设置者检查')],
      ClaudeCodeReady(:final path) => [
        Text('已找到 Claude Code：$path'),
        const Text('已登录'),
      ],
      ClaudeCodeLoginUnknown(:final path) => [
        Text('已找到 Claude Code：$path'),
        const Text('看不出是否已经登录。可以继续，下一步试分析时就知道了。'),
      ],
      ClaudeCodeNotLoggedIn(:final path) => [
        Text('已找到 Claude Code：$path'),
        const Text('还没有登录。请按下面的步骤登录：'),
        const SizedBox(height: PlannerTheme.space2),
        const Text(
          '1. 打开"开始"菜单，搜索"命令提示符"并打开。\n'
          '2. 输入 claude 并按回车。\n'
          '3. 按提示在打开的 Claude 官方网页里，用你自己的账号登录。\n'
          '4. 登录完成后关掉命令提示符，回到这里点 [重新检查]。',
        ),
        const SizedBox(height: PlannerTheme.space2),
        Text(
          '登录是在 Claude 官方的流程里完成的，DailyNote 看不到你的账号和密码。',
          style: theme.textTheme.bodySmall,
        ),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines,
        const SizedBox(height: PlannerTheme.space3),
        OutlinedButton(
          key: SetupWizardPage.recheckKey,
          onPressed: status == null ? null : _checkClaude,
          child: const Text('重新检查'),
        ),
      ],
    );
  }

  Widget _trial() {
    final result = _trialResult;
    final failure = _trialFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('用一封内置的虚构邮件试分析一次，确认整条路是通的。这封邮件不会出现在事项里。'),
        const SizedBox(height: PlannerTheme.space3),
        if (_busy)
          const Text('正在分析，可能要一两分钟…')
        else if (result != null) ...[
          Text(
            result.items.isEmpty
                ? '试分析成功：${result.reason}'
                : '试分析成功，找到的事项：'
                      '${result.items.map((i) => i.title).join('、')}',
          ),
        ] else if (failure != null)
          Text('试分析失败：${_failureText(failure)}'),
        const SizedBox(height: PlannerTheme.space3),
        if (result == null)
          OutlinedButton(
            key: SetupWizardPage.tryKey,
            onPressed: _busy ? null : _tryAnalysis,
            child: Text(failure == null ? '开始试分析' : '再试一次'),
          ),
      ],
    );
  }

  static String _failureText(AnalysisFailureType type) => switch (type) {
    AnalysisFailureType.notInstalled => '找不到 Claude Code，请让设置者检查',
    AnalysisFailureType.notLoggedIn => 'Claude 未登录，请回到上一步按步骤登录',
    AnalysisFailureType.quotaExhausted => 'Claude 额度已用完，请稍后再试',
    AnalysisFailureType.invalidOutput => 'Claude 的回答格式不对，请再试一次',
    AnalysisFailureType.temporary => '分析没有完成（超时或者连接出错），请再试一次',
  };
}

/// 选择邮件文件夹以后显示的检查结果。
String folderCheckText(FolderCheck check) => switch (check) {
  FolderFound(:final fileCount, latestFileAt: final at?) =>
    '找到 $fileCount 个导出文件，最新一个是 ${formatReceivedTime(at)}',
  FolderFound(:final fileCount) => '找到 $fileCount 个导出文件',
  FolderUnavailable() => '这个文件夹打不开，请换一个',
};
