/// 导出文件解析：把一个导出文件的字节解析成 [ExportBatch]。纯函数，不碰数据库。
///
/// 格式见 spec 0002 的"导出文件格式"。
library;

import 'dart:convert';

import 'body_text.dart';
import 'mail_states.dart';

/// 信封格式的 `format` 字段。
const exportFormatName = 'dailynote-mail-export';

/// 能读的最高信封版本。
const latestExportVersion = 1;

/// 文件整体的格式错误。
enum ExportFormatError {
  /// 不是 UTF-8 编码的 JSON。
  notJson,

  /// 顶层既不是信封也不是数组，或者 `format` 不对。
  unknownFormat,

  /// `version` 比 [latestExportVersion] 新。
  unsupportedVersion,

  /// 信封里的 `messages` 不是数组。
  messagesNotArray,
}

/// 文件格式错误，整个文件都不能用。
class InvalidExportFile implements Exception {
  const InvalidExportFile(this.error);

  final ExportFormatError error;

  @override
  String toString() => 'InvalidExportFile: ${error.name}';
}

/// 一个导出文件里的内容。
class ExportBatch {
  const ExportBatch({
    required this.mailbox,
    required this.exportedAt,
    required this.mails,
    required this.skippedCount,
  });

  /// 信封里的邮箱地址（已规范化，见 [normalizeMailbox]）；裸数组时为 null。
  final String? mailbox;

  /// 信封里的导出时间（UTC）；裸数组或者没有时为 null。
  final DateTime? exportedAt;

  final List<ExportedMail> mails;

  /// `internetMessageId` 和 `id` 都没有、被跳过的邮件数。
  final int skippedCount;
}

/// 导出文件里的一封邮件，只包括用得到的字段。
class ExportedMail {
  const ExportedMail({
    required this.key,
    required this.keyKind,
    required this.outlookId,
    required this.conversationId,
    required this.subject,
    required this.senderName,
    required this.senderAddress,
    required this.receivedAt,
    required this.importance,
    required this.hasAttachments,
    required this.body,
  });

  /// 邮件键：`internetMessageId`，没有时用 `id`。
  final String key;
  final MailKeyKind keyKind;
  final String? outlookId;
  final String? conversationId;
  final String subject;
  final String? senderName;
  final String? senderAddress;

  /// 收件时间（UTC）；没有或者解析不了时为 null。
  final DateTime? receivedAt;
  final String? importance;
  final bool hasAttachments;

  /// 转换后的正文，见 [convertMailBody]。
  final MailBody body;
}

/// 邮箱地址的规范形式：去掉首尾空白，转成小写。
String normalizeMailbox(String address) => address.trim().toLowerCase();

/// 解析一个导出文件。整个文件格式错误时抛出 [InvalidExportFile]；
/// 单封邮件缺少邮件键时跳过，计入 [ExportBatch.skippedCount]。
ExportBatch parseExport(List<int> bytes) {
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes).replaceFirst('﻿', ''));
  } on FormatException {
    throw const InvalidExportFile(ExportFormatError.notJson);
  }
  return switch (json) {
    List<Object?>() => _batch(json, mailbox: null, exportedAt: null),
    {'format': exportFormatName, 'version': final int version}
        when version > latestExportVersion =>
      throw const InvalidExportFile(ExportFormatError.unsupportedVersion),
    {'format': exportFormatName, 'version': int(), 'messages': final messages}
        when messages is List<Object?> =>
      _batch(
        messages,
        mailbox: switch (json['mailbox']) {
          final String m when m.trim().isNotEmpty => normalizeMailbox(m),
          _ => null,
        },
        exportedAt: _time(json['exportedAt']),
      ),
    {'format': exportFormatName, 'version': int()} =>
      throw const InvalidExportFile(ExportFormatError.messagesNotArray),
    _ => throw const InvalidExportFile(ExportFormatError.unknownFormat),
  };
}

ExportBatch _batch(
  List<Object?> messages, {
  required String? mailbox,
  required DateTime? exportedAt,
}) {
  final mails = [
    for (final message in messages)
      if (message is Map<String, Object?>) ?_mail(message),
  ];
  return ExportBatch(
    mailbox: mailbox,
    exportedAt: exportedAt,
    mails: mails,
    skippedCount: messages.length - mails.length,
  );
}

ExportedMail? _mail(Map<String, Object?> m) {
  final internetMessageId = _text(m['internetMessageId']);
  final outlookId = _text(m['id']);
  final (key, keyKind) = switch ((internetMessageId, outlookId)) {
    (final id?, _) => (id, MailKeyKind.internetMessageId),
    (null, final id?) => (id, MailKeyKind.outlookId),
    _ => (null, null),
  };
  if (key == null || keyKind == null) return null;
  // 获取电子邮件 (V3) 里 `from` 是地址字符串，`body` 是字符串加 `isHtml`；
  // Graph 的原始格式是对象。两种都接受。
  final (senderName, senderAddress) = switch (m['from']) {
    final String address => (null, _text(address)),
    {'emailAddress': final Map<String, Object?> e} => (
      _text(e['name']),
      _text(e['address']),
    ),
    _ => (null, null),
  };
  final (content, isHtml) = switch (m['body']) {
    final String content => (content, m['isHtml'] == true),
    {'content': final String content} => (
      content,
      (m['body'] as Map)['contentType'] == 'html',
    ),
    _ => ('', false),
  };
  final body = convertMailBody(
    body: content,
    isHtml: isHtml,
    bodyPreview: _text(m['bodyPreview']),
    hasInlineImageAttachment: _hasInlineImageAttachment(m),
  );
  return ExportedMail(
    key: key,
    keyKind: keyKind,
    outlookId: outlookId,
    conversationId: _text(m['conversationId']),
    subject: _text(m['subject']) ?? '',
    senderName: senderName,
    senderAddress: senderAddress,
    receivedAt: _time(m['receivedDateTime']),
    importance: _text(m['importance']),
    hasAttachments: m['hasAttachments'] == true,
    body: body,
  );
}

bool _hasInlineImageAttachment(Map<String, Object?> m) =>
    switch (m['attachments']) {
      final List<Object?> attachments => attachments.any(
        (a) => switch (a) {
          {'isInline': true, 'contentType': final String type} =>
            type.toLowerCase().startsWith('image/'),
          _ => false,
        },
      ),
      _ => false,
    };

/// 非空字符串，去掉首尾空白；其他都当作没有。
String? _text(Object? value) => switch (value) {
  final String s when s.trim().isNotEmpty => s.trim(),
  _ => null,
};

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
