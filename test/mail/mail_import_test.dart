// 切入点 3：手动导入导出文件（M-4 ～ M-9）。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/export_parser.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';
import 'package:my_personal_use_app/planner/planner_exceptions.dart';

import 'mail_fixtures.dart';
import 'mail_harness.dart';

void main() {
  late MailHarness h;

  setUp(() => h = MailHarness());
  tearDown(() => h.dispose());

  Map<String, Object?> mail(String key, {String? subject, String? at}) =>
      fakeMessage(
        internetMessageId: '<$key@example.com>',
        id: 'AAMk-$key',
        subject: subject ?? 'Mail $key',
        receivedDateTime: at ?? '2026-10-19T14:30:00Z',
      );

  group('信封格式（M-4）', () {
    test('所有邮件入库，预览里能看到主题、发件人和收件时间', () async {
      final outcome = await h.importJson(
        'mail-20261020-1.json',
        fakeEnvelope([
          fakeMessage(
            internetMessageId: '<a@example.com>',
            subject: '周五组会改到 3 点',
            from: {
              'emailAddress': {'name': '李明', 'address': 'li.ming@example.com'},
            },
            receivedDateTime: '2026-10-19T13:15:00Z',
          ),
          mail('b', subject: 'Library books due', at: '2026-10-18T08:00:00Z'),
        ]),
      );

      expect(
        outcome,
        isA<Imported>()
            .having((o) => o.fileName, 'fileName', 'mail-20261020-1.json')
            .having((o) => o.newMailCount, 'newMailCount', 2),
      );
      final previews = await h.mail.watchMails().first;
      expect(previews.map((m) => m.subject), [
        '周五组会改到 3 点',
        'Library books due',
      ]);
      expect(previews.first.senderName, '李明');
      expect(previews.first.senderAddress, 'li.ming@example.com');
      expect(previews.first.receivedAt, DateTime.utc(2026, 10, 19, 13, 15));
    });

    test('重新打开数据库后邮件还在', () async {
      await h.importJson('mail-1.json', fakeEnvelope([mail('a')]));

      await h.reopen();

      expect(await h.subjects(), ['Mail a']);
    });

    test('没有收件时间的邮件排在最后', () async {
      await h.importJson(
        'mail-1.json',
        fakeEnvelope([
          fakeMessage(
            internetMessageId: '<x@example.com>',
            subject: '无时间',
            receivedDateTime: null,
          ),
          mail('a', at: '2026-10-01T00:00:00Z'),
        ]),
      );

      expect(await h.subjects(), ['Mail a', '无时间']);
    });
  });

  group('裸数组（M-5）', () {
    test('设置了邮箱地址时可以导入', () async {
      await h.mail.setMailboxAddress('her@example.com');

      final outcome = await h.importJson('mail-old.json', [mail('a')]);

      expect(outcome, isA<Imported>());
      expect(await h.subjects(), ['Mail a']);
    });

    test('没设置邮箱地址时停在需要邮箱，邮件不入库', () async {
      final outcome = await h.importJson('mail-old.json', [mail('a')]);

      expect(outcome, isA<NeedsMailbox>());
      expect(await h.subjects(), isEmpty);
    });

    test('填写邮箱地址以后再导入同一个文件，邮件入库', () async {
      final path = h.writeFile('mail-old.json', [mail('a')]);
      await h.mail.importFile(path);

      await h.mail.setMailboxAddress('her@example.com');
      final outcome = await h.mail.importFile(path);

      expect(outcome, isA<Imported>());
      expect(await h.subjects(), ['Mail a']);
    });

    test('和信封格式的同一个邮箱共用去重', () async {
      await h.mail.setMailboxAddress('Her@Example.com');
      await h.importJson('mail-1.json', fakeEnvelope([mail('a')]));

      final outcome = await h.importJson('mail-old.json', [
        mail('a'),
        mail('b'),
      ]);

      expect((outcome as Imported).newMailCount, 1);
      expect(await h.subjects(), unorderedEquals(['Mail a', 'Mail b']));
    });
  });

  group('去重（M-6）', () {
    test('同一个文件导入两次，第二次什么都不做', () async {
      final path = h.writeFile('mail-1.json', fakeEnvelope([mail('a')]));
      await h.mail.importFile(path);

      final outcome = await h.mail.importFile(path);

      expect(outcome, isA<AlreadyImported>());
      expect(await h.subjects(), ['Mail a']);
    });

    test('内容相同、文件名不同的文件不会重复', () async {
      final content = fakeEnvelope([mail('a')]);
      await h.importJson('mail-1.json', content);

      final outcome = await h.importJson('mail-1 (1).json', content);

      expect(outcome, isA<AlreadyImported>());
      expect(await h.subjects(), ['Mail a']);
    });

    test('和之前的文件有重叠时只入库新的邮件', () async {
      await h.importJson('mail-1.json', fakeEnvelope([mail('a'), mail('b')]));

      final outcome = await h.importJson(
        'mail-2.json',
        fakeEnvelope([mail('b'), mail('c')]),
      );

      expect(
        outcome,
        isA<Imported>()
            .having((o) => o.mailCount, 'mailCount', 2)
            .having((o) => o.newMailCount, 'newMailCount', 1),
      );
      expect(await h.subjects(), hasLength(3));
    });

    test('已有的邮件不更新', () async {
      await h.importJson(
        'mail-1.json',
        fakeEnvelope([mail('a', subject: '旧主题')]),
      );

      await h.importJson(
        'mail-2.json',
        fakeEnvelope([mail('a', subject: '新主题')]),
      );

      expect(await h.subjects(), ['旧主题']);
    });

    test('同一个文件里重复出现的邮件只入库一次', () async {
      final outcome = await h.importJson(
        'mail-1.json',
        fakeEnvelope([mail('a'), mail('a')]),
      );

      expect((outcome as Imported).newMailCount, 1);
      expect(await h.subjects(), ['Mail a']);
    });

    test('不同邮箱里邮件键相同的邮件各算一封', () async {
      await h.importJson('mail-1.json', fakeEnvelope([mail('a')]));

      await h.importJson(
        'mail-2.json',
        fakeEnvelope([mail('a')], mailbox: 'other@example.com'),
      );

      expect(await h.subjects(), hasLength(2));
    });
  });

  group('缺少邮件键（M-7）', () {
    test('没有 internetMessageId 的邮件按 id 去重', () async {
      Map<String, Object?> noMessageId() =>
          fakeMessage(internetMessageId: null, id: 'AAMk-1', subject: '只有 id');
      await h.importJson('mail-1.json', fakeEnvelope([noMessageId()]));

      final outcome = await h.importJson(
        'mail-2.json',
        fakeEnvelope([noMessageId(), mail('b')]),
      );

      expect((outcome as Imported).newMailCount, 1);
      expect(await h.subjects(), unorderedEquals(['只有 id', 'Mail b']));
    });

    test('两个键都没有的邮件跳过，同一文件的其他邮件正常入库', () async {
      final outcome = await h.importJson(
        'mail-1.json',
        fakeEnvelope([
          fakeMessage(internetMessageId: null, id: null),
          mail('a'),
        ]),
      );

      expect(
        outcome,
        isA<Imported>()
            .having((o) => o.skippedCount, 'skippedCount', 1)
            .having((o) => o.newMailCount, 'newMailCount', 1),
      );
      expect(await h.subjects(), ['Mail a']);
    });
  });

  group('格式错误（M-8）', () {
    final cases = <String, (Object?, ExportFormatError)>{
      '不是 JSON': ('not json'.codeUnits, ExportFormatError.notJson),
      'format 不对': (
        fakeEnvelope([], format: 'other'),
        ExportFormatError.unknownFormat,
      ),
      'version 太新': (
        fakeEnvelope([], version: 99),
        ExportFormatError.unsupportedVersion,
      ),
      'messages 不是数组': (
        fakeEnvelope([])..['messages'] = 'x',
        ExportFormatError.messagesNotArray,
      ),
    };
    for (final MapEntry(key: name, value: (content, error)) in cases.entries) {
      test('$name：给出文件名和错误类型，数据库不变', () async {
        final outcome = await h.importJson('mail-bad.json', content);

        expect(
          outcome,
          isA<InvalidFile>()
              .having((o) => o.fileName, 'fileName', 'mail-bad.json')
              .having((o) => o.error, 'error', error),
        );
        expect(await h.subjects(), isEmpty);
      });
    }

    test('格式错误的文件不影响之后导入别的文件', () async {
      await h.importJson('mail-bad.json', 'oops'.codeUnits);

      await h.importJson('mail-1.json', fakeEnvelope([mail('a')]));

      expect(await h.subjects(), ['Mail a']);
    });

    test('文件读不出来时数据库不变', () async {
      final outcome = await h.mail.importFile(
        '${h.directory.path}/mail-missing.json',
      );

      expect(
        outcome,
        isA<UnreadableFile>().having(
          (o) => o.fileName,
          'fileName',
          'mail-missing.json',
        ),
      );
    });
  });

  group('导入中途失败（M-9）', () {
    test('数据库里没有这个文件的任何邮件，再导入一次能完整成功', () async {
      final path = h.writeFile(
        'mail-1.json',
        fakeEnvelope([mail('a'), mail('b'), mail('c')]),
      );
      // 文件状态写进去了，邮件写到一半失败。
      h.failWritesAfter(2);

      await expectLater(
        h.mail.importFile(path),
        throwsA(isA<StorageFailure>()),
      );
      h.failWrites = false;
      expect(await h.subjects(), isEmpty);

      final outcome = await h.mail.importFile(path);

      expect((outcome as Imported).newMailCount, 3);
      expect(await h.subjects(), hasLength(3));
    });
  });

  group('正文（M-10）', () {
    test('存的是转换后的正文和编号的链接，重新打开后还在', () async {
      await h.importJson(
        'mail-1.json',
        fakeEnvelope([
          fakeMessage(
            internetMessageId: '<a@example.com>',
            body:
                '<p>Sign up <a href="https://example.com/form">here</a>.</p>'
                '<img src="cid:poster@01DB">',
          ),
        ]),
      );
      await h.reopen();

      final id = (await h.mail.watchMails().first).single.id;
      final detail = (await h.mail.mailDetail(id))!;

      expect(detail.bodyText, 'Sign up here [1].\n\n[图片]');
      expect(detail.links, ['https://example.com/form']);
      expect(detail.hasInlineImages, isTrue);
      expect(detail.bodyPossiblyIncomplete, isFalse);
    });

    test('用了 bodyPreview 的邮件标记正文可能不完整', () async {
      await h.importJson(
        'mail-1.json',
        fakeEnvelope([fakeMessage(body: '', bodyPreview: 'Lunch at noon.')]),
      );

      final id = (await h.mail.watchMails().first).single.id;
      final detail = (await h.mail.mailDetail(id))!;

      expect(detail.bodyText, 'Lunch at noon.');
      expect(detail.links, isEmpty);
      expect(detail.bodyPossiblyIncomplete, isTrue);
    });

    test('没有这封邮件时返回 null', () async {
      expect(await h.mail.mailDetail('missing'), isNull);
    });
  });

  group('邮箱地址', () {
    test('保存规范形式，重新打开后还在', () async {
      await h.mail.setMailboxAddress('  Her@Example.COM ');

      await h.reopen();

      expect(await h.mail.mailboxAddress(), 'her@example.com');
    });

    test('清空以后没有邮箱地址', () async {
      await h.mail.setMailboxAddress('her@example.com');

      await h.mail.setMailboxAddress('  ');

      expect(await h.mail.mailboxAddress(), isNull);
    });

    test('格式不对时不保存', () async {
      await expectLater(
        h.mail.setMailboxAddress('not an address'),
        throwsA(isA<InvalidInput>()),
      );
      expect(await h.mail.mailboxAddress(), isNull);
    });
  });
}
