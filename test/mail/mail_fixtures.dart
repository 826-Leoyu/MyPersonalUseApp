// 虚构的导出文件内容。字段和获取电子邮件 (V3) 返回的一样。
import 'dart:convert';

/// 一封虚构邮件。参数为 null 的字段不出现在 JSON 里。
Map<String, Object?> fakeMessage({
  String? internetMessageId = '<default@example.com>',
  String? id = 'AAMk-default',
  String? conversationId = 'conv-default',
  String subject = 'Team lunch on Friday',
  Object? from = 'alex@example.com',
  String? receivedDateTime = '2026-10-19T14:30:00Z',
  String body = '<p>Lunch at noon.</p>',
  bool isHtml = true,
  String? bodyPreview = 'Lunch at noon.',
  String importance = 'normal',
  bool hasAttachments = false,
}) => {
  'internetMessageId': ?internetMessageId,
  'id': ?id,
  'conversationId': ?conversationId,
  'subject': subject,
  'from': ?from,
  'receivedDateTime': ?receivedDateTime,
  'body': body,
  'isHtml': isHtml,
  'bodyPreview': ?bodyPreview,
  'importance': importance,
  'hasAttachments': hasAttachments,
  'isRead': false,
  'toRecipients': 'her@example.com',
};

/// 信封格式的导出文件。
Map<String, Object?> fakeEnvelope(
  List<Object?> messages, {
  String mailbox = 'her@example.com',
  Object? version = 1,
  String format = 'dailynote-mail-export',
}) => {
  'format': format,
  'version': version,
  'mailbox': mailbox,
  'exportedAt': '2026-10-20T11:00:03Z',
  'messages': messages,
};

List<int> encode(Object? json) => utf8.encode(jsonEncode(json));
