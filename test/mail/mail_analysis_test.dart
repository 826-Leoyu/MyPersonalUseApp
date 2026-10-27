// 切入点 3：分析新邮件、候选事项、加入和忽略（M-13、M-14、M-16、M-17、
// M-23、M-27）。分析器是按脚本返回结果的假分析器。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_items.dart';
import 'package:my_personal_use_app/mail/mail_states.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_exceptions.dart';

import 'fake_analyzer.dart';
import 'mail_fixtures.dart';
import 'mail_harness.dart';

void main() {
  late MailHarness h;

  setUp(() => h = MailHarness());
  tearDown(() => h.dispose());

  Map<String, Object?> mail(
    String subject, {
    String? key,
    String at = '2026-10-19T14:30:00Z',
    String? conversationId,
    String body = '<p>Details inside.</p>',
  }) => fakeMessage(
    internetMessageId: '<${key ?? subject}@example.com>',
    id: 'AAMk-${key ?? subject}',
    conversationId: conversationId ?? 'conv-${key ?? subject}',
    subject: subject,
    receivedDateTime: at,
    body: body,
  );

  AnalysisResult actionRequired(List<AnalyzedItem> items) => AnalysisResult(
    category: MailCategory.actionRequired,
    reason: '有截止时间',
    items: items,
  );

  /// 导入这些邮件，并等自动分析结束。
  Future<void> importAndAnalyze(List<Map<String, Object?>> mails) async {
    await h.importJson('mail-${h.analyzer.requests.length}.json', fakeEnvelope(mails));
    await h.mail.analyzePending();
  }

  Future<List<MailItemCandidate>> candidates() =>
      h.mail.watchCandidates().first;

  Future<List<String>> candidateTitles() async =>
      [for (final c in await candidates()) c.title];

  group('自动分析（M-13）', () {
    test('新入库的邮件被自动分析，收件时间新的在前', () async {
      await importAndAnalyze([
        mail('Older', at: '2026-10-18T08:00:00Z'),
        mail('Newer', at: '2026-10-19T08:00:00Z'),
      ]);

      expect(h.analyzer.analyzedSubjects, ['Newer', 'Older']);
    });

    test('导入以后不用调用就开始分析', () async {
      await h.importJson('mail-1.json', fakeEnvelope([mail('A')]));

      await pumpEventQueue();

      expect(h.analyzer.analyzedSubjects, ['A']);
    });

    test('重复导入同一封邮件不会再分析一次', () async {
      await importAndAnalyze([mail('A')]);
      await h.importJson('mail-again.json', fakeEnvelope([mail('A'), mail('B')]));
      await h.mail.analyzePending();

      expect(h.analyzer.analyzedSubjects, ['A', 'B']);
    });

    test('重启以后分析完的邮件不再分析，没分析的接着分析', () async {
      h.analyzer.fails('B', AnalysisFailureType.temporary);
      await importAndAnalyze([
        mail('A', at: '2026-10-19T08:00:00Z'),
        mail('B', at: '2026-10-18T08:00:00Z'),
      ]);
      h.analyzer.returns('B', actionRequired([fakeItem('Do B')]));

      await h.reopen();
      await h.mail.analyzePending();

      expect(h.analyzer.analyzedSubjects, ['A', 'B', 'B']);
      expect(await candidateTitles(), ['Do B']);
    });

    test('正在分析时再调用，等这一轮结束，不会把同一封分析两次', () async {
      await h.importJson('mail-1.json', fakeEnvelope([mail('A'), mail('B')]));

      await Future.wait([h.mail.analyzePending(), h.mail.analyzePending()]);

      expect(h.analyzer.analyzedSubjects..sort(), ['A', 'B']);
    });
  });

  group('分析失败', () {
    test('一封失败不影响其他邮件，失败的下一轮再分析', () async {
      h.analyzer.fails('A', AnalysisFailureType.temporary);
      await importAndAnalyze([
        mail('A', at: '2026-10-19T08:00:00Z'),
        mail('B', at: '2026-10-18T08:00:00Z'),
      ]);
      expect(h.analyzer.analyzedSubjects, ['A', 'B']);

      h.analyzer.returns('A', actionRequired([fakeItem('Do A')]));
      await h.mail.analyzePending();

      expect(h.analyzer.analyzedSubjects, ['A', 'B', 'A']);
      expect(await candidateTitles(), ['Do A']);
    });

    test('输出格式不对时不产生任何事项，邮件还是待分析（M-23）', () async {
      h.analyzer.fails('A', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('A')]);

      expect(await candidates(), isEmpty);
      await h.mail.analyzePending();
      expect(h.analyzer.analyzedSubjects, ['A', 'A']);
    });

    for (final type in [
      AnalysisFailureType.notInstalled,
      AnalysisFailureType.notLoggedIn,
      AnalysisFailureType.quotaExhausted,
    ]) {
      test('${type.name}：这一轮停下来，后面的邮件不再白白调用', () async {
        h.analyzer.fails('A', type);
        await importAndAnalyze([
          mail('A', at: '2026-10-19T08:00:00Z'),
          mail('B', at: '2026-10-18T08:00:00Z'),
        ]);

        expect(h.analyzer.analyzedSubjects, ['A']);
      });
    }
  });

  group('请求的内容（M-27）', () {
    test('只有分析需要的内容，没有收件人、邮件头和附件', () async {
      await importAndAnalyze([
        mail('A', body: '<p>Form: <a href="https://example.com/f">here</a></p>'),
      ]);

      final request = h.analyzer.requests.single;
      final json = request.toJson();
      expect(json.keys, {'mail', 'timeZone', 'relatedItems', 'markedUseful'});
      expect((json['mail']! as Map).keys, {
        'subject',
        'senderName',
        'senderAddress',
        'receivedAt',
        'importance',
        'bodyText',
        'links',
        'hasAttachments',
        'hasInlineImages',
        'bodyPossiblyIncomplete',
      });
      expect(request.links, ['https://example.com/f']);
      expect(request.bodyText, contains('[1]'));
      expect(request.timeZone, 'Eastern Daylight Time');
      expect(request.markedUseful, isFalse);
      expect(request.toJson().toString(), isNot(contains('her@example.com')));
    });

    test('同一讨论里已有的事项作为可能相关的事项，只有编号、标题、时间和状态', () async {
      h.analyzer.returns(
        'Assignment 3',
        actionRequired([
          fakeItem('Submit A3', dueTime: CardTime.date(DayKey(2026, 10, 23))),
        ]),
      );
      await importAndAnalyze([mail('Assignment 3', conversationId: 'conv-a3')]);
      final itemId = (await candidates()).single.id;

      await importAndAnalyze([
        mail('RE: Assignment 3', conversationId: 'conv-a3'),
      ]);

      final related = h.analyzer.requests.last.relatedItems.single;
      expect(related.id, itemId);
      expect(related.toJson(), {
        'itemId': itemId,
        'title': 'Submit A3',
        'eventTime': null,
        'dueTime': {
          'value': '2026-10-23',
          'precision': 'date',
          'unconfirmed': false,
        },
        'status': 'candidate',
      });
    });

    test('最近 30 天由邮件生成、还没完成的事项也在里面，忽略过的和完成的不在', () async {
      h.analyzer
        ..returns('Keep', actionRequired([fakeItem('Keep item')]))
        ..returns('Ignore', actionRequired([fakeItem('Ignored item')]))
        ..returns('Done', actionRequired([fakeItem('Done item')]));
      await importAndAnalyze([mail('Keep'), mail('Ignore'), mail('Done')]);
      final byTitle = {for (final c in await candidates()) c.title: c.id};
      await h.mail.ignoreItem(byTitle['Ignored item']!);
      final card = await h.mail.acceptItem(
        byTitle['Done item']!,
        day: h.today,
        x: 0,
        y: 0,
      );
      await h.planner.completeCard(card.id);

      await importAndAnalyze([mail('Unrelated')]);

      expect(
        [for (final r in h.analyzer.requests.last.relatedItems) r.title],
        ['Keep item'],
      );
    });
  });

  group('候选事项（M-14）', () {
    test('需要行动的邮件可以有 0 个、1 个或多个事项', () async {
      h.analyzer
        ..returns('None', actionRequired([]))
        ..returns('One', actionRequired([fakeItem('Item 1')]))
        ..returns('Two', actionRequired([fakeItem('Item 2a'), fakeItem('Item 2b')]));

      await importAndAnalyze([mail('None'), mail('One'), mail('Two')]);

      expect(
        await candidateTitles(),
        unorderedEquals(['Item 1', 'Item 2a', 'Item 2b']),
      );
    });

    test('仅供参考和低价值的邮件不生成候选事项', () async {
      h.analyzer
        ..returns(
          'Info',
          AnalysisResult(
            category: MailCategory.informational,
            reason: '通知',
            items: [fakeItem('Should not appear')],
          ),
        )
        ..returns(
          'Ad',
          AnalysisResult(
            category: MailCategory.lowValue,
            reason: '广告',
            items: [fakeItem('Buy now')],
          ),
        );

      await importAndAnalyze([mail('Info'), mail('Ad')]);

      expect(await candidates(), isEmpty);
    });

    test('需要行动在前，可选活动在后；同类按时间从近到远，没有时间的在最后', () async {
      h.analyzer
        ..returns(
          'Events',
          AnalysisResult(
            category: MailCategory.optionalEvent,
            reason: '讲座',
            items: [
              fakeItem(
                'Talk later',
                optional: true,
                eventTime: CardTime.date(DayKey(2026, 10, 30)),
              ),
              fakeItem(
                'Talk sooner',
                optional: true,
                eventTime: CardTime.date(DayKey(2026, 10, 22)),
              ),
            ],
          ),
        )
        ..returns(
          'Tasks',
          actionRequired([
            fakeItem('No time'),
            fakeItem(
              'Due later',
              dueTime: CardTime.dateTime(DateTime.utc(2026, 10, 28, 12)),
            ),
            fakeItem('Pending time', dueTime: const CardTime.pending()),
            fakeItem(
              'Due sooner',
              dueTime: CardTime.date(DayKey(2026, 10, 21)),
            ),
          ]),
        );

      await importAndAnalyze([mail('Events'), mail('Tasks')]);

      final titles = await candidateTitles();
      expect(titles.take(2), ['Due sooner', 'Due later']);
      expect(titles.sublist(2, 4), unorderedEquals(['No time', 'Pending time']));
      expect(titles.skip(4), ['Talk sooner', 'Talk later']);
    });

    test('每条带着来自哪封邮件、谁发的', () async {
      h.analyzer.returns('Assignment 3', actionRequired([fakeItem('Submit')]));

      await importAndAnalyze([mail('Assignment 3')]);

      final candidate = (await candidates()).single;
      expect(candidate.mailSubject, 'Assignment 3');
      expect(candidate.sender, 'alex@example.com');
      expect(candidate.optional, isFalse);
      expect(candidate.receivedAt, DateTime.utc(2026, 10, 19, 14, 30));
    });

    test('重新打开数据库后候选事项还在', () async {
      h.analyzer.returns('A', actionRequired([fakeItem('Do A')]));
      await importAndAnalyze([mail('A')]);

      await h.reopen();

      expect(await candidateTitles(), ['Do A']);
    });
  });

  group('加入（M-16、M-17）', () {
    Future<MailItemCandidate> oneCandidate(AnalyzedItem item) async {
      h.analyzer.returns(
        'Assignment 3',
        actionRequired([item]),
      );
      await importAndAnalyze([
        mail(
          'Assignment 3',
          body:
              '<p>Upload <a href="https://example.com/a">here</a>, '
              'rubric <a href="https://example.com/b">here</a>.</p>',
        ),
      ]);
      return (await candidates()).single;
    }

    test('今天的画布上出现一张卡片，标题、备注和时间来自事项', () async {
      final due = CardTime.dateTime(DateTime.utc(2026, 10, 24, 3, 59));
      final event = CardTime.date(DayKey(2026, 10, 22));
      final candidate = await oneCandidate(
        fakeItem(
          'Submit assignment 3',
          summary: 'Upload the PDF report.',
          actions: ['Write the report', 'Upload the PDF'],
          location: 'Room 101',
          linkRefs: [2, 1],
          eventTime: event,
          dueTime: due,
        ),
      );

      final card = await h.mail.acceptItem(
        candidate.id,
        day: h.today,
        x: 30,
        y: 40,
      );

      final board = await h.planner.watchDay(h.today).first;
      final saved = board.cards.single;
      expect(saved.id, card.id);
      expect(saved.title, 'Submit assignment 3');
      expect(
        saved.note,
        'Upload the PDF report.\n'
        '- Write the report\n'
        '- Upload the PDF\n'
        '地点：Room 101\n'
        'https://example.com/b',
      );
      expect((saved.x, saved.y), (30, 40));
      expect(saved.eventTime, event);
      expect(saved.dueTime, due);
    });

    test('加入以后事项从栏里消失，卡片记为来自邮件', () async {
      final candidate = await oneCandidate(fakeItem('Submit'));

      final card = await h.mail.acceptItem(
        candidate.id,
        day: h.today,
        x: 0,
        y: 0,
      );

      expect(await candidates(), isEmpty);
      expect(await h.mail.watchMailCardIds().first, {card.id});
      expect(
        await h.mail.sourceMailOfCard(card.id),
        candidate.mailId,
      );
    });

    test('没有备注内容时卡片没有备注', () async {
      final candidate = await oneCandidate(fakeItem('Submit'));

      await h.mail.acceptItem(candidate.id, day: h.today, x: 0, y: 0);

      final board = await h.planner.watchDay(h.today).first;
      expect(board.cards.single.note, isNull);
    });

    test('可以放到以后的某一天', () async {
      final candidate = await oneCandidate(fakeItem('Submit'));
      final later = h.today.addDays(3);

      await h.mail.acceptItem(candidate.id, day: later, x: 0, y: 0);

      expect((await h.planner.watchDay(later).first).cards, hasLength(1));
      expect((await h.planner.watchDay(h.today).first).cards, isEmpty);
    });

    test('不能放到过去，事项还是候选', () async {
      final candidate = await oneCandidate(fakeItem('Submit'));

      await expectLater(
        h.mail.acceptItem(candidate.id, day: h.today.addDays(-1), x: 0, y: 0),
        throwsA(isA<InvalidState>()),
      );

      expect(await candidateTitles(), ['Submit']);
    });

    test('新建卡片失败时事项还是候选，画布上没有新卡片（M-17）', () async {
      final candidate = await oneCandidate(fakeItem('Submit'));

      h.failWrites = true;
      await expectLater(
        h.mail.acceptItem(candidate.id, day: h.today, x: 0, y: 0),
        throwsA(isA<StorageFailure>()),
      );
      h.failWrites = false;

      expect(await candidateTitles(), ['Submit']);
      expect((await h.planner.watchDay(h.today).first).cards, isEmpty);
    });

    test('卡片建好、事项状态写入失败时，整体回滚（M-17）', () async {
      final candidate = await oneCandidate(fakeItem('Submit'));

      h.failWritesAfter(1);
      await expectLater(
        h.mail.acceptItem(candidate.id, day: h.today, x: 0, y: 0),
        throwsA(isA<StorageFailure>()),
      );
      h.failWrites = false;

      expect(await candidateTitles(), ['Submit']);
      expect((await h.planner.watchDay(h.today).first).cards, isEmpty);
    });

    test('已经加入的事项不能再加入一次', () async {
      final candidate = await oneCandidate(fakeItem('Submit'));
      await h.mail.acceptItem(candidate.id, day: h.today, x: 0, y: 0);

      await expectLater(
        h.mail.acceptItem(candidate.id, day: h.today, x: 0, y: 0),
        throwsA(isA<InvalidState>()),
      );
      expect((await h.planner.watchDay(h.today).first).cards, hasLength(1));
    });

    test('太长的标题截到卡片允许的长度', () async {
      final candidate = await oneCandidate(fakeItem('长' * 300));

      await h.mail.acceptItem(candidate.id, day: h.today, x: 0, y: 0);

      final board = await h.planner.watchDay(h.today).first;
      expect(board.cards.single.title, '长' * 200);
    });
  });

  group('忽略', () {
    test('事项从栏里消失，重新打开后也不回来', () async {
      h.analyzer.returns(
        'A',
        actionRequired([fakeItem('Keep'), fakeItem('Drop')]),
      );
      await importAndAnalyze([mail('A')]);
      final drop = (await candidates()).singleWhere((c) => c.title == 'Drop');

      await h.mail.ignoreItem(drop.id);
      await h.reopen();

      expect(await candidateTitles(), ['Keep']);
      expect(await h.mail.itemStatus(drop.id), MailItemStatus.ignored);
    });
  });
}
