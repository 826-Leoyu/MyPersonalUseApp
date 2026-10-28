import 'body_text.dart';

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

  /// 显示用的主题：没有主题时为"（无主题）"。
  String get displaySubject => subject.isEmpty ? '（无主题）' : subject;

  /// 显示用的发件人：名字，没有名字时用地址。
  String get displaySender => senderName ?? senderAddress ?? '（未知发件人）';
}

/// 邮件预览里点开的一封邮件：转换后的正文和链接。
class MailDetail {
  const MailDetail({
    required this.preview,
    required this.body,
    required this.bodyCleared,
  });

  final MailPreview preview;
  final MailBody body;

  /// 正文到期、已经清除（spec 0002"正文保留规则"）。
  final bool bodyCleared;
}
