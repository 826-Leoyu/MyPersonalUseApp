// 切入点 3：后续邮件的更新建议（M-24、M-25、M-26）。分析器是按脚本返回
// 结果的假分析器，后续邮件的结果用 `updates` 指向现有事项。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/item_changes.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_items.dart';
import 'package:my_personal_use_app/mail/mail_states.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_exceptions.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'fake_analyzer.dart';
import 'mail_fixtures.dart';
import 'mail_harness.dart';

void main() {
  late MailHarness h;

  setUp(() => h = MailHarness());
  tearDown(() => h.dispose());

  Map<String, Object?> mail(
    String subject, {
    String at = '2026-10-19T14:30:00Z',
    String body = '<p>Details inside.</p>',
  }) => fakeMessage(
    internetMessageId: '<$subject@example.com>',
    id: 'AAMk-$subject',
    conversationId: 'conv-a3',
    subject: subject,
    receivedDateTime: at,
    body: body,
  );

  AnalysisResult actionRequired(List<AnalyzedItem> items) => AnalysisResult(
    category: MailCategory.actionRequired,
    reason: '有截止时间',
    items: items,
  );

  var files = 0;

  /// 导入这些邮件，并等自动分析结束。
  Future<void> importAndAnalyze(List<Map<String, Object?>> mails) async {
    await h.importJson('mail-${files++}.json', fakeEnvelope(mails));
    await h.mail.analyzePending();
  }

  Future<List<MailItemCandidate>> candidates() =>
      h.mail.watchCandidates().first;

  final oct30 = CardTime.date(DayKey(2026, 10, 30));
  final nov2 = CardTime.date(DayKey(2026, 11, 2));

  /// 第一封邮件分析出事项"交作业 3"（截止 Oct 30），返回它的编号。
  Future<String> firstItem({String? summary, String? location}) async {
    h.analyzer.returns(
      'Assignment 3',
      actionRequired([
        fakeItem('交作业 3', summary: summary, location: location, dueTime: oct30),
      ]),
    );
    await importAndAnalyze([mail('Assignment 3')]);
    return (await candidates()).single.id;
  }

  /// 后续邮件 [subject] 把事项 [itemId] 改成 [item]。
  Future<void> followUp(String subject, AnalyzedItem item) async {
    h.analyzer.returns(subject, actionRequired([item]));
    await importAndAnalyze([mail(subject, at: '2026-10-20T08:00:00Z')]);
  }

  group('更新候选事项（M-24）', () {
    test('候选被直接改写并标"已更新"，栏里没有重复的事项', () async {
      final itemId = await firstItem();

      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3（延期）', updates: itemId, dueTime: nov2),
      );

      final candidate = (await candidates()).single;
      expect(candidate.id, itemId);
      expect(candidate.title, '交作业 3（延期）');
      expect(candidate.dueTime, nov2);
      expect(candidate.updated, isTrue);
      expect(candidate.mailSubject, 'RE: Assignment 3');
    });

    test('没被后续邮件更新过的候选不标"已更新"', () async {
      await firstItem();

      expect((await candidates()).single.updated, isFalse);
    });
  });

  group('更新已加入的卡片（M-25）', () {
    /// 第一封邮件的事项加入今天的画布，返回卡片的编号和事项的编号。
    Future<({String cardId, String itemId})> accepted({
      String? summary,
      String? location,
    }) async {
      final itemId = await firstItem(summary: summary, location: location);
      final card = await h.mail.acceptItem(itemId, day: h.today, x: 0, y: 0);
      return (cardId: card.id, itemId: itemId);
    }

    Future<CardUpdate?> updateOf(String cardId) async =>
        (await h.mail.watchCardUpdates().first)[cardId];

    Future<TaskCard> cardOnBoard() async =>
        (await h.planner.watchDay(h.today).first).cards.single;

    test('卡片上出现更新建议，点 [采用] 之前卡片内容不变', () async {
      final (:cardId, :itemId) = await accepted();

      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );

      final update = (await updateOf(cardId))!;
      expect(update.changes.fields, {ItemField.dueTime});
      expect(update.changes.values.dueTime, nov2);
      expect(update.cardTimes.due, oct30);
      expect((await cardOnBoard()).dueTime, oct30);
      expect(await candidates(), isEmpty);
    });

    test('[采用] 只改提示里列出的字段，她改过的其他内容不变', () async {
      final (:cardId, :itemId) = await accepted(
        summary: '提交到 Brightspace',
        location: 'Room 101',
      );
      await h.planner.updateCardContent(
        cardId,
        title: '我的作业 3',
        note: '提交到 Brightspace\n地点：Room 101\n记得先问助教',
      );
      await followUp(
        'RE: Assignment 3',
        fakeItem(
          '交作业 3',
          updates: itemId,
          summary: '提交到 Brightspace',
          location: 'Room 205',
          dueTime: nov2,
        ),
      );

      await h.mail.applyUpdate((await updateOf(cardId))!.id);

      final card = await cardOnBoard();
      expect(card.title, '我的作业 3');
      expect(card.note, '提交到 Brightspace\n地点：Room 205\n记得先问助教');
      expect(card.dueTime, nov2);
      expect(await updateOf(cardId), isNull);
    });

    test('[采用] 改标题和摘要；备注里找不到旧内容时把新内容加在最后', () async {
      final (:cardId, :itemId) = await accepted(summary: '旧摘要');
      await h.planner.updateCardContent(cardId, title: '交作业 3', note: '我的备注');
      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3（延期）', updates: itemId, summary: '新摘要', dueTime: oct30),
      );

      await h.mail.applyUpdate((await updateOf(cardId))!.id);

      final card = await cardOnBoard();
      expect(card.title, '交作业 3（延期）');
      expect(card.note, '我的备注\n新摘要');
      expect(card.dueTime, oct30);
    });

    test('[不用] 之后提示消失，同样的改动不再出现，卡片不变', () async {
      final (:cardId, :itemId) = await accepted();
      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );

      await h.mail.rejectUpdate((await updateOf(cardId))!.id);
      expect(await updateOf(cardId), isNull);

      await followUp(
        'RE: RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );
      expect(await updateOf(cardId), isNull);
      expect((await cardOnBoard()).dueTime, oct30);
    });

    test('同一张卡片只显示最新的一条建议', () async {
      final (:cardId, :itemId) = await accepted();
      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );
      final first = (await updateOf(cardId))!.id;
      final nov5 = CardTime.date(DayKey(2026, 11, 5));

      await followUp(
        'RE: RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov5),
      );

      final latest = (await updateOf(cardId))!;
      expect(latest.id, isNot(first));
      expect(latest.changes.values.dueTime, nov5);
      await expectLater(
        h.mail.applyUpdate(first),
        throwsA(isA<InvalidState>()),
      );
    });

    test('[不用] 过摘要的改动以后再 [采用] 新的摘要：备注里的旧摘要被换掉，不重复', () async {
      final (:cardId, :itemId) = await accepted(summary: '摘要 A');
      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, summary: '摘要 B', dueTime: oct30),
      );
      await h.mail.rejectUpdate((await updateOf(cardId))!.id);
      await followUp(
        'RE: RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, summary: '摘要 C', dueTime: oct30),
      );

      await h.mail.applyUpdate((await updateOf(cardId))!.id);

      expect((await cardOnBoard()).note, '摘要 C');
    });

    test('[不用] 以后，后续邮件改回卡片上原来的值：不出现建议', () async {
      final (:cardId, :itemId) = await accepted();
      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );
      await h.mail.rejectUpdate((await updateOf(cardId))!.id);

      await followUp(
        'RE: RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: oct30),
      );

      expect(await updateOf(cardId), isNull);
    });

    test('更新的邮件改回卡片上的值：之前的建议被替代，不再显示', () async {
      final (:cardId, :itemId) = await accepted();
      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );

      await followUp(
        'RE: RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: oct30),
      );

      expect(await updateOf(cardId), isNull);
    });

    test('后续邮件没有改动任何内容时不出现建议', () async {
      final (:cardId, :itemId) = await accepted();

      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: oct30),
      );

      expect(await updateOf(cardId), isNull);
    });
  });

  group('已完成、已删除或已忽略的事项（M-26）', () {
    /// 第一封邮件的事项加入画布后按 [finish] 处理卡片，再来一封后续邮件。
    Future<void> followUpAfter(
      Future<void> Function(String cardId) finish,
    ) async {
      final itemId = await firstItem();
      final card = await h.mail.acceptItem(itemId, day: h.today, x: 0, y: 0);
      await finish(card.id);
      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );
    }

    for (final (description, finish, note) in [
      (
        '已完成',
        (MailHarness h, String id) => h.planner.completeCard(id),
        '可能和已完成的《交作业 3》有关',
      ),
      (
        '在回收站',
        (MailHarness h, String id) => h.planner.deleteCard(id),
        '可能和已删除的《交作业 3》有关',
      ),
      (
        '已永久删除',
        (MailHarness h, String id) async {
          await h.planner.deleteCard(id);
          await h.planner.deleteForever(id);
        },
        '可能和已删除的《交作业 3》有关',
      ),
    ]) {
      test('卡片$description：栏里出现一条新候选并注明相关事项', () async {
        await followUpAfter((id) => finish(h, id));

        final candidate = (await candidates()).single;
        expect(candidate.title, '交作业 3');
        expect(candidate.dueTime, nov2);
        expect(candidate.relatedHint, note);
        expect(candidate.updated, isFalse);
        expect(await h.mail.watchCardUpdates().first, isEmpty);
      });
    }

    test('原卡片不变', () async {
      late String cardId;
      await followUpAfter((id) async {
        cardId = id;
        await h.planner.completeCard(id);
      });

      final completed = await h.planner.watchCompleted(h.today).first;
      final card = completed.singleWhere((c) => c.id == cardId);
      expect(card.dueTime, oct30);
    });

    test('忽略过的事项：栏里再出现一次，注明和忽略过的事项有关', () async {
      final itemId = await firstItem();
      await h.mail.ignoreItem(itemId);

      await followUp(
        'RE: Assignment 3',
        fakeItem('交作业 3', updates: itemId, dueTime: nov2),
      );

      final candidate = (await candidates()).single;
      expect(candidate.id, isNot(itemId));
      expect(candidate.relatedHint, '和你忽略过的《交作业 3》有关');
      expect(await h.mail.itemStatus(itemId), MailItemStatus.ignored);
    });

    test('新事项没有相关事项的说明', () async {
      await firstItem();

      expect((await candidates()).single.relatedHint, isNull);
    });
  });
}
