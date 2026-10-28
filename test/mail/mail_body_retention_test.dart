// 切入点 3：正文的保留和清除（M-29）。用假时钟跨过到期时间，再扫描一次，
// 看邮件详情里的正文和链接还在不在。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_preview.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';

import 'fake_analyzer.dart';
import 'mail_fixtures.dart';
import 'mail_harness.dart';

void main() {
  late MailHarness h;

  setUp(() async {
    h = MailHarness();
    await h.mail.setMailFolder(h.directory.path);
  });
  tearDown(() => h.dispose());

  Map<String, Object?> mail(
    String subject, {
    String at = '2026-10-19T14:30:00Z',
    String conversationId = 'conv-a',
  }) => fakeMessage(
    internetMessageId: '<$subject@example.com>',
    id: 'AAMk-$subject',
    conversationId: conversationId,
    subject: subject,
    receivedDateTime: at,
    body: '<p>Fill in <a href="https://example.com/form">the form</a>.</p>',
  );

  AnalysisResult actionRequired(List<AnalyzedItem> items) => AnalysisResult(
    category: MailCategory.actionRequired,
    reason: '要填表',
    items: items,
  );

  var files = 0;

  /// 导入这些邮件，并等自动分析结束。
  Future<void> importAndAnalyze(List<Map<String, Object?>> mails) async {
    await h.importJson('mail-${files++}.json', fakeEnvelope(mails));
    await h.mail.analyzePending();
  }

  /// 把假时钟调到 [at] 这个时刻（UTC 或本地时间都可以），再扫描一次。
  Future<void> scanAt(DateTime at) async {
    h.now = at.toLocal();
    await h.mail.scanFolder();
  }

  Future<MailDetail> detail(String subject) async {
    final preview = (await h.mail.watchMails().first).singleWhere(
      (m) => m.subject == subject,
    );
    return (await h.mail.mailDetail(preview.id))!;
  }

  Future<List<String>> candidateTitles() async => [
    for (final c in await h.mail.watchCandidates().first) c.title,
  ];

  group('没有明确时间的邮件', () {
    test('收件后 30 天到期：到期前正文还在，到期后扫描时清除正文和链接，'
        '主题和事项还在', () async {
      h.analyzer.returns('Form', actionRequired([fakeItem('填表')]));
      await importAndAnalyze([mail('Form')]);

      await scanAt(DateTime.utc(2026, 11, 18, 14, 29));
      final kept = await detail('Form');
      expect(kept.bodyCleared, isFalse);
      expect(kept.body.text, contains('Fill in'));
      expect(kept.body.links, ['https://example.com/form']);

      await scanAt(DateTime.utc(2026, 11, 18, 14, 30));
      final cleared = await detail('Form');
      expect(cleared.bodyCleared, isTrue);
      expect(cleared.body.text, isNull);
      expect(cleared.body.links, isEmpty);
      expect(cleared.preview.subject, 'Form');
      expect(await candidateTitles(), ['填表']);
    });
  });

  test('找不到邮件文件夹时也照样清除', () async {
    await importAndAnalyze([mail('Form')]);
    await h.mail.setMailFolder('${h.directory.path}-missing');

    await scanAt(DateTime.utc(2026, 11, 18, 14, 30));
    expect((await detail('Form')).bodyCleared, isTrue);
  });

  group('有明确时间的邮件', () {
    test('保留到截止时间之后 7 天，不按收件后 30 天清除', () async {
      h.analyzer.returns(
        'Form',
        actionRequired([
          fakeItem(
            '填表',
            dueTime: CardTime.dateTime(DateTime.utc(2026, 12, 1, 17)),
          ),
        ]),
      );
      await importAndAnalyze([mail('Form')]);

      await scanAt(DateTime.utc(2026, 12, 8, 16, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime.utc(2026, 12, 8, 17));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    test('只有日期的截止时间：保留到那一天结束之后 7 天（本地时间）', () async {
      h.analyzer.returns(
        'Form',
        actionRequired([
          fakeItem('填表', dueTime: CardTime.date(DayKey(2026, 12, 1))),
        ]),
      );
      await importAndAnalyze([mail('Form')]);

      await scanAt(DateTime(2026, 12, 8, 23, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime(2026, 12, 9));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    test('待确认但有值的截止时间也算明确时间', () async {
      h.analyzer.returns(
        'Form',
        actionRequired([
          fakeItem(
            '填表',
            dueTime: CardTime.dateTime(
              DateTime.utc(2026, 12, 1, 17),
              pending: true,
            ),
          ),
        ]),
      );
      await importAndAnalyze([mail('Form')]);

      await scanAt(DateTime.utc(2026, 12, 8, 16, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime.utc(2026, 12, 8, 17));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    test('待确认而没有值的截止时间不算，按收件后 30 天清除', () async {
      h.analyzer.returns(
        'Form',
        actionRequired([fakeItem('填表', dueTime: const CardTime.pending())]),
      );
      await importAndAnalyze([mail('Form')]);

      await scanAt(DateTime.utc(2026, 11, 18, 14, 30));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    test('好几个事项、好几个时间时，按最晚的那个算', () async {
      h.analyzer.returns(
        'Form',
        actionRequired([
          fakeItem(
            '听讲座',
            eventTime: CardTime.dateTime(DateTime.utc(2026, 12, 5, 17)),
            dueTime: CardTime.dateTime(DateTime.utc(2026, 11, 20, 17)),
          ),
          fakeItem(
            '填表',
            dueTime: CardTime.dateTime(DateTime.utc(2026, 12, 1, 17)),
          ),
        ]),
      );
      await importAndAnalyze([mail('Form')]);

      await scanAt(DateTime.utc(2026, 12, 12, 16, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime.utc(2026, 12, 12, 17));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    /// 分析出"填表"（截止 12 月 1 日 17:00 UTC），加入以后把卡片上的截止
    /// 时间改成 [due]，再把卡片标为完成。
    Future<void> acceptAndEditDue(DateTime due) async {
      h.analyzer.returns(
        'Form',
        actionRequired([
          fakeItem(
            '填表',
            dueTime: CardTime.dateTime(DateTime.utc(2026, 12, 1, 17)),
          ),
        ]),
      );
      await importAndAnalyze([mail('Form')]);
      final itemId = (await h.mail.watchCandidates().first).single.id;
      final card = await h.mail.acceptItem(itemId, day: h.today, x: 0, y: 0);
      await h.planner.updateCardContent(
        card.id,
        title: '填表',
        note: null,
        times: (event: null, due: CardTime.dateTime(due)),
      );
      await h.planner.completeCard(card.id);
    }

    test('卡片上的截止时间被她改晚了：按卡片上的算', () async {
      await acceptAndEditDue(DateTime.utc(2026, 12, 10, 17));

      await scanAt(DateTime.utc(2026, 12, 17, 16, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime.utc(2026, 12, 17, 17));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    test('卡片上的截止时间被她改早了：按卡片上的算', () async {
      await acceptAndEditDue(DateTime.utc(2026, 11, 20, 17));

      await scanAt(DateTime.utc(2026, 11, 27, 16, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime.utc(2026, 11, 27, 17));
      expect((await detail('Form')).bodyCleared, isTrue);
    });
  });

  group('同一讨论有新邮件', () {
    test('按 30 天算的邮件顺延到新邮件收件以后 30 天', () async {
      await importAndAnalyze([mail('Form')]);
      await importAndAnalyze([
        mail('RE: Form', at: '2026-11-10T08:00:00Z'),
        mail('Other', at: '2026-11-10T08:00:00Z', conversationId: 'conv-b'),
      ]);

      await scanAt(DateTime.utc(2026, 12, 10, 7, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime.utc(2026, 12, 10, 8));
      expect((await detail('Form')).bodyCleared, isTrue);
      expect((await detail('RE: Form')).bodyCleared, isTrue);
    });

    test('新邮件的导出文件在旧邮件到期以后才读到：同一次扫描里先导入再清除，'
        '旧邮件照样顺延', () async {
      await importAndAnalyze([mail('Form')]);
      h.writeFile(
        'mail-late.json',
        fakeEnvelope([mail('RE: Form', at: '2026-11-10T08:00:00Z')]),
      );

      await scanAt(DateTime.utc(2026, 11, 18, 14));
      await scanAt(DateTime.utc(2026, 11, 18, 14, 30));
      expect(await h.subjects(), contains('RE: Form'));
      expect((await detail('Form')).bodyCleared, isFalse);
    });

    test('候选被后续邮件改写以后，原来那封邮件没有事项了：按收件后 30 天算，'
        '随同一讨论顺延', () async {
      h.analyzer.returns(
        'Form',
        actionRequired([
          fakeItem(
            '填表',
            dueTime: CardTime.dateTime(DateTime.utc(2026, 12, 20, 17)),
          ),
        ]),
      );
      await importAndAnalyze([mail('Form')]);
      final itemId = (await h.mail.watchCandidates().first).single.id;
      h.analyzer.returns(
        'RE: Form',
        actionRequired([
          fakeItem(
            '填表（提前）',
            updates: itemId,
            dueTime: CardTime.dateTime(DateTime.utc(2026, 11, 1, 17)),
          ),
        ]),
      );
      await importAndAnalyze([mail('RE: Form', at: '2026-11-10T08:00:00Z')]);

      await scanAt(DateTime.utc(2026, 12, 10, 7, 59));
      expect((await detail('Form')).bodyCleared, isFalse);

      await scanAt(DateTime.utc(2026, 12, 10, 8));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    test('按事项时间算的邮件不顺延', () async {
      h.analyzer.returns(
        'Form',
        actionRequired([
          fakeItem(
            '填表',
            dueTime: CardTime.dateTime(DateTime.utc(2026, 11, 1, 17)),
          ),
        ]),
      );
      await importAndAnalyze([mail('Form')]);
      await importAndAnalyze([mail('RE: Form', at: '2026-11-10T08:00:00Z')]);

      await scanAt(DateTime.utc(2026, 11, 8, 17));
      expect((await detail('Form')).bodyCleared, isTrue);
      expect((await detail('RE: Form')).bodyCleared, isFalse);
    });
  });

  group('不清除的情况', () {
    /// 分析出"填表"（没有时间），加入画布，返回卡片的编号。
    Future<String> acceptedCard() async {
      h.analyzer.returns('Form', actionRequired([fakeItem('填表')]));
      await importAndAnalyze([mail('Form')]);
      final itemId = (await h.mail.watchCandidates().first).single.id;
      return (await h.mail.acceptItem(itemId, day: h.today, x: 0, y: 0)).id;
    }

    test('由这封邮件加入的卡片还没完成：到期也不清除，完成以后下次扫描时清除', () async {
      final cardId = await acceptedCard();

      await scanAt(DateTime.utc(2026, 12, 1));
      expect((await detail('Form')).bodyCleared, isFalse);

      await h.planner.completeCard(cardId);
      await scanAt(DateTime.utc(2026, 12, 1, 0, 1));
      expect((await detail('Form')).bodyCleared, isTrue);
    });

    for (final (description, remove) in [
      ('进了回收站', (MailHarness h, String id) => h.planner.deleteCard(id)),
      (
        '已永久删除',
        (MailHarness h, String id) async {
          await h.planner.deleteCard(id);
          await h.planner.deleteForever(id);
        },
      ),
    ]) {
      test('加入的卡片$description：到期后清除', () async {
        await remove(h, await acceptedCard());

        await scanAt(DateTime.utc(2026, 12, 1));
        expect((await detail('Form')).bodyCleared, isTrue);
      });
    }

    test('还在待分析：到期也不清除，分析完以后下次扫描时清除', () async {
      h.analyzer.hold('Form');
      await h.importJson('mail.json', fakeEnvelope([mail('Form')]));

      await scanAt(DateTime.utc(2026, 12, 1));
      expect((await detail('Form')).bodyCleared, isFalse);

      h.analyzer.release('Form');
      await h.mail.waitForAnalysis();
      await scanAt(DateTime.utc(2026, 12, 1, 0, 1));
      expect((await detail('Form')).bodyCleared, isTrue);
    });
  });
}
