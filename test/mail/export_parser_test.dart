import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/export_parser.dart';
import 'package:my_personal_use_app/mail/mail_states.dart';

import 'mail_fixtures.dart';

void main() {
  Matcher formatError(ExportFormatError error) =>
      throwsA(isA<InvalidExportFile>().having((e) => e.error, 'error', error));

  group('信封格式', () {
    test('读出邮箱、导出时间和邮件', () {
      final batch = parseExport(
        encode(fakeEnvelope([fakeMessage()], mailbox: ' Her@Example.com ')),
      );

      expect(batch.mailbox, 'her@example.com');
      expect(batch.exportedAt, DateTime.utc(2026, 10, 20, 11, 0, 3));
      expect(batch.mails, hasLength(1));
      expect(batch.skippedCount, 0);
    });

    test('一封邮件的字段都读出来', () {
      final mail = parseExport(
        encode(
          fakeEnvelope([
            fakeMessage(
              internetMessageId: '<a1@example.com>',
              id: 'AAMk-a1',
              conversationId: 'conv-1',
              subject: '周五下午的组会改到 3 点',
              from: 'li.ming@example.com',
              receivedDateTime: '2026-10-19T09:15:00-04:00',
              body: '<p>大家好</p>',
              bodyPreview: '大家好',
              importance: 'high',
              hasAttachments: true,
            ),
          ]),
        ),
      ).mails.single;

      expect(mail.key, '<a1@example.com>');
      expect(mail.keyKind, MailKeyKind.internetMessageId);
      expect(mail.outlookId, 'AAMk-a1');
      expect(mail.conversationId, 'conv-1');
      expect(mail.subject, '周五下午的组会改到 3 点');
      expect(mail.senderAddress, 'li.ming@example.com');
      expect(mail.receivedAt, DateTime.utc(2026, 10, 19, 13, 15));
      expect(mail.body, '<p>大家好</p>');
      expect(mail.isHtml, isTrue);
      expect(mail.bodyPreview, '大家好');
      expect(mail.importance, 'high');
      expect(mail.hasAttachments, isTrue);
    });

    test('文件开头有 BOM 也能读', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...encode(fakeEnvelope([]))];

      expect(parseExport(bytes).mails, isEmpty);
    });
  });

  test('顶层是数组时没有邮箱和导出时间', () {
    final batch = parseExport(encode([fakeMessage(), fakeMessage()]));

    expect(batch.mailbox, isNull);
    expect(batch.exportedAt, isNull);
    expect(batch.mails, hasLength(2));
  });

  test('没有 internetMessageId 时用 id 当邮件键', () {
    final mail = parseExport(
      encode([fakeMessage(internetMessageId: null, id: 'AAMk-only')]),
    ).mails.single;

    expect(mail.key, 'AAMk-only');
    expect(mail.keyKind, MailKeyKind.outlookId);
  });

  test('两个键都没有的邮件跳过，同一文件的其他邮件照常读出', () {
    final batch = parseExport(
      encode(
        fakeEnvelope([
          fakeMessage(internetMessageId: null, id: null),
          fakeMessage(internetMessageId: '<ok@example.com>'),
          'not a message',
        ]),
      ),
    );

    expect(batch.mails.map((m) => m.key), ['<ok@example.com>']);
    expect(batch.skippedCount, 2);
  });

  test('Graph 格式的发件人和正文也能读', () {
    final message = fakeMessage(
      from: {
        'emailAddress': {'name': 'Alex Chen', 'address': 'alex@example.com'},
      },
    )..['body'] = {'contentType': 'html', 'content': '<p>Hi</p>'};

    final mail = parseExport(encode([message])).mails.single;

    expect(mail.senderName, 'Alex Chen');
    expect(mail.senderAddress, 'alex@example.com');
    expect(mail.body, '<p>Hi</p>');
    expect(mail.isHtml, isTrue);
  });

  test('收件时间缺失或解析不了时为空', () {
    final mails = parseExport(
      encode([
        fakeMessage(receivedDateTime: null),
        fakeMessage(receivedDateTime: 'yesterday'),
      ]),
    ).mails;

    expect(mails.map((m) => m.receivedAt), [null, null]);
  });

  group('格式错误', () {
    test('不是 JSON', () {
      expect(
        () => parseExport(utf8.encode('{oops')),
        formatError(ExportFormatError.notJson),
      );
    });

    test('不是 UTF-8', () {
      expect(
        () => parseExport([0xFF, 0xFE, 0x00]),
        formatError(ExportFormatError.notJson),
      );
    });

    test('format 不对', () {
      expect(
        () => parseExport(encode(fakeEnvelope([], format: 'something-else'))),
        formatError(ExportFormatError.unknownFormat),
      );
    });

    test('顶层是字符串', () {
      expect(
        () => parseExport(encode('hello')),
        formatError(ExportFormatError.unknownFormat),
      );
    });

    test('version 比已知的新', () {
      expect(
        () => parseExport(encode(fakeEnvelope([], version: 2))),
        formatError(ExportFormatError.unsupportedVersion),
      );
    });

    test('version 不是整数', () {
      expect(
        () => parseExport(encode(fakeEnvelope([], version: '1'))),
        formatError(ExportFormatError.unknownFormat),
      );
    });

    test('messages 不是数组', () {
      expect(
        () => parseExport(encode(fakeEnvelope([])..['messages'] = {})),
        formatError(ExportFormatError.messagesNotArray),
      );
    });
  });
}
