import '../planner/card_time.dart';

/// "新邮件事项"栏里的一条候选事项。
class MailItemCandidate {
  const MailItemCandidate({
    required this.id,
    required this.title,
    required this.summary,
    required this.actions,
    required this.location,
    required this.links,
    required this.eventTime,
    required this.dueTime,
    required this.optional,
    required this.hasUnanalyzedAttachments,
    required this.mailId,
    required this.mailSubject,
    required this.sender,
    required this.receivedAt,
  });

  final String id;
  final String title;
  final String? summary;

  /// 要做的事，可以为空列表。
  final List<String> actions;
  final String? location;

  /// 事项引用的链接，按引用的顺序。
  final List<String> links;

  final CardTime? eventTime;
  final CardTime? dueTime;

  /// 可选活动，栏里带"可选"标签。
  final bool optional;

  /// 邮件有附件或图片，没有分析，栏里提示"附件或图片未分析"。
  final bool hasUnanalyzedAttachments;

  /// 来源邮件。
  final String mailId;

  /// 来源邮件的主题，没有主题时为"（无主题）"。
  final String mailSubject;

  /// 来源邮件的发件人：名字，没有名字时用地址。
  final String sender;

  /// 来源邮件的收件时间（UTC）。
  final DateTime? receivedAt;
}

/// "已过滤的邮件"里一条是什么。
enum FilteredKind {
  /// 分类为仅供参考的邮件。
  informational,

  /// 分类为低价值的邮件。
  lowValue,

  /// 首次设置时较早的邮件，没有自动分析。
  notAnalyzed,

  /// 分析失败的邮件。
  analysisFailed,

  /// 被忽略的事项，可以 [恢复]。
  ignoredItem;

  /// 这一条是一封邮件，可以点 [这封有用]。
  bool get isMail => this != ignoredItem;
}

/// "已过滤的邮件"里的一条：一封没有生成候选事项的邮件，或者一个被忽略的
/// 事项。
class FilteredEntry {
  const FilteredEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.mailId,
    required this.sender,
    required this.receivedAt,
    required this.reason,
    required this.bodyCleared,
  });

  final FilteredKind kind;

  /// 邮件的 id，被忽略的事项时是事项的 id。
  final String id;

  /// 邮件的主题（没有主题时为"（无主题）"），被忽略的事项时是事项的标题。
  final String title;

  /// 邮件，或者事项的来源邮件。
  final String mailId;

  /// 邮件的发件人：名字，没有名字时用地址。
  final String sender;

  /// 邮件的收件时间（UTC）。
  final DateTime? receivedAt;

  /// 一句话理由。
  final String reason;

  /// 邮件的正文已经清除，[这封有用] 不可用。
  final bool bodyCleared;
}
