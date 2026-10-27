/// 邮件文件夹和导入的情况，给"新邮件事项"栏顶部的状态行用（spec 0002
/// "界面·状态行"）。
library;

/// 状态行要说明的一件事。
sealed class ImportNotice {
  const ImportNotice();
}

/// 没有附加内容的提示：同一种就相等。
sealed class _PlainNotice extends ImportNotice {
  const _PlainNotice();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => '$runtimeType';
}

/// 还没有选择邮件文件夹。
class FolderNotSet extends _PlainNotice {
  const FolderNotSet();
}

/// 邮件文件夹不存在或者没有权限。
class FolderMissing extends _PlainNotice {
  const FolderMissing();
}

/// 有文件还在写入或同步。
class FilesSyncing extends _PlainNotice {
  const FilesSyncing();
}

/// 这些文件格式不对，已跳过。
class FormatErrors extends ImportNotice {
  const FormatErrors(this.fileNames);

  /// 按文件名排序。
  final List<String> fileNames;

  @override
  bool operator ==(Object other) =>
      other is FormatErrors &&
      other.fileNames.join('\n') == fileNames.join('\n');

  @override
  int get hashCode => Object.hashAll(fileNames);

  @override
  String toString() => 'FormatErrors($fileNames)';
}

/// 超过 2 天没有新的导出文件，云端的流程可能停了。
class NoNewFiles extends ImportNotice {
  const NoNewFiles(this.since);

  /// 最后一个新文件出现的时间；一个文件都还没有时是选择文件夹的时间（UTC）。
  final DateTime since;

  @override
  bool operator ==(Object other) => other is NoNewFiles && other.since == since;

  @override
  int get hashCode => since.hashCode;

  @override
  String toString() => 'NoNewFiles($since)';
}

/// 最近导入的文件和之前的文件之间有空档，并且两个都是满的：中间的邮件
/// 可能没有导出。
class PossiblyMissedMails extends _PlainNotice {
  const PossiblyMissedMails();
}

/// 今天自动分析的邮件到了上限，已暂停；点 [继续] 解除今天的暂停。
class AnalysisPaused extends _PlainNotice {
  const AnalysisPaused();
}

/// 没有找到 Claude Code，有邮件在等它分析。
class ClaudeNotInstalled extends _PlainNotice {
  const ClaudeNotInstalled();
}

/// Claude Code 没有登录，有邮件在等它分析。
class ClaudeNotLoggedIn extends _PlainNotice {
  const ClaudeNotLoggedIn();
}

/// Claude 的额度用完了，稍后自动重试。
class ClaudeQuotaExhausted extends _PlainNotice {
  const ClaudeQuotaExhausted();
}

/// 这么多封邮件分析失败（输出格式不对重试了 3 次），点 [重试] 再分析。
class AnalysisFailures extends ImportNotice {
  const AnalysisFailures(this.count);

  final int count;

  @override
  bool operator ==(Object other) =>
      other is AnalysisFailures && other.count == count;

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'AnalysisFailures($count)';
}

/// 导入的情况。
class MailImportStatus {
  const MailImportStatus({
    required this.notices,
    this.lastImportAt,
    this.lastImportNewMailCount = 0,
  });

  /// 要说明的事，按状态行的优先顺序：排在前面的显示在状态行上。没有时
  /// 状态行显示上次导入。
  final List<ImportNotice> notices;

  /// 上一次导入了文件的扫描的时间（UTC）；还没导入过时为 null。
  final DateTime? lastImportAt;

  /// 那一次扫描新入库的邮件数。
  final int lastImportNewMailCount;
}

/// 检查一个文件夹的结果，选择邮件文件夹时显示。
sealed class FolderCheck {
  const FolderCheck();
}

/// 文件夹可以用。
class FolderFound extends FolderCheck {
  const FolderFound({required this.fileCount, required this.latestFileAt});

  /// 里面的导出文件（`mail-*.json`）个数。
  final int fileCount;

  /// 最新一个导出文件的修改时间（UTC）；没有文件时为 null。
  final DateTime? latestFileAt;
}

/// 文件夹不存在或者没有权限。
class FolderUnavailable extends FolderCheck {
  const FolderUnavailable();
}
