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

/// 邮件预览里点开的一封邮件：转换后的正文和链接。
class MailDetail {
  const MailDetail({
    required this.preview,
    required this.bodyText,
    required this.links,
    required this.hasInlineImages,
    required this.bodyPossiblyIncomplete,
  });

  final MailPreview preview;

  /// 转换后的正文；没有正文时为 null。
  final String? bodyText;

  /// 第 n 个对应正文里的 `[n]`。
  final List<String> links;
  final bool hasInlineImages;
  final bool bodyPossiblyIncomplete;
}
