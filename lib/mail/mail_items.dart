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
