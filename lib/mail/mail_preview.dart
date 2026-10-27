/// 邮件预览列表里的一封邮件。
class MailPreview {
  const MailPreview({
    required this.id,
    required this.subject,
    required this.senderName,
    required this.senderAddress,
    required this.receivedAt,
  });

  final String id;

  /// 没有主题时为空字符串。
  final String subject;
  final String? senderName;
  final String? senderAddress;

  /// 收件时间（UTC）；导出文件里没有时为 null。
  final DateTime? receivedAt;
}
