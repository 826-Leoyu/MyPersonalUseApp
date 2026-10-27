/// 邮件模块里存进数据库的各种状态。字段的含义见 spec 0002 的"数据模型"。
library;

/// 导出文件处理到哪一步。
enum MailExportFileStatus {
  /// 看到了，等待文件稳定。
  seen,

  /// 裸数组格式，设置里又没有邮箱地址，等用户填写。
  needsMailbox,

  /// 文件里的邮件都入库了。
  imported,

  /// 格式错误，已跳过。
  invalid,

  /// 已清理。
  deleted,
}

/// 邮件键用的是哪个字段。
enum MailKeyKind { internetMessageId, outlookId }

/// 邮件的分析状态。
enum MailAnalysisStatus {
  pending,

  /// 首次设置时较早的邮件，不自动分析。
  deferredOld,
  done,

  /// 输出格式不对重试 3 次以后。
  failed,
}

/// 邮件事项的状态。
enum MailItemStatus { candidate, accepted, ignored }

/// 更新建议的状态。
enum MailItemUpdateStatus { pending, applied, rejected, superseded }
