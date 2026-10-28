// 切入点 3：已过滤的邮件、[这封有用] 和 [恢复]（M-15、M-18、M-19、M-21）。
// 分析器是按脚本返回结果的假分析器。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_items.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';
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
    String at = '2026-10-19T14:30:00Z',
    String sender = 'Registrar',
  }) => fakeMessage(
    internetMessageId: '<$subject@example.com>',
    id: 'AAMk-$subject',
    conversationId: 'conv-$subject',
    subject: subject,
    from: {
      'emailAddress': {'name': sender, 'address': 'office@example.com'},
    },
    receivedDateTime: at,
  );

  Future<void> importAndAnalyze(List<Map<String, Object?>> mails) async {
    await h.importJson(
      'mail-${h.analyzer.requests.length}.json',
      fakeEnvelope(mails),
    );
    await h.mail.analyzePending();
  }

  Future<List<FilteredEntry>> filtered() => h.mail.watchFiltered().first;

  Future<List<String>> candidateTitles() async => [
    for (final c in await h.mail.watchCandidates().first) c.title,
  ];

  group('分类为仅供参考和低价值的邮件（M-15）', () {
    test('不生成候选事项，出现在已过滤的邮件里，带主题、发件人、日期和理由', () async {
      h.analyzer
        ..returns(
          'Library hours',
          AnalysisResult(
            category: MailCategory.informational,
            reason: '只是开放时间通知',
            items: [fakeItem('看开放时间')],
          ),
        )
        ..returns(
          'Pizza coupon',
          const AnalysisResult(
            category: MailCategory.lowValue,
            reason: '广告',
            items: [],
          ),
        );
      await importAndAnalyze([
        mail('Library hours', at: '2026-10-18T08:00:00Z'),
        mail('Pizza coupon', sender: 'Pizza Shop'),
      ]);

      expect(await candidateTitles(), isEmpty);
      final entries = await filtered();
      expect(
        [for (final e in entries) e.title],
        ['Pizza coupon', 'Library hours'],
      );
      final coupon = entries.first;
      expect(coupon.kind, FilteredKind.lowValue);
      expect(coupon.sender, 'Pizza Shop');
      expect(coupon.receivedAt, DateTime.utc(2026, 10, 19, 14, 30));
      expect(coupon.reason, '广告');
      expect(entries.last.reason, '只是开放时间通知');
    });

    test('需要行动的邮件不在已过滤的邮件里', () async {
      h.analyzer.returns(
        'Report due',
        AnalysisResult(
          category: MailCategory.actionRequired,
          reason: '有截止时间',
          items: [fakeItem('交周报')],
        ),
      );
      await importAndAnalyze([mail('Report due')]);

      expect(await filtered(), isEmpty);
    });
  });

  group('被忽略的事项（M-18）', () {
    Future<String> ignoredItem() async {
      h.analyzer.returns(
        'Report due',
        AnalysisResult(
          category: MailCategory.actionRequired,
          reason: '有截止时间',
          items: [fakeItem('交周报')],
        ),
      );
      await importAndAnalyze([mail('Report due', sender: '李明')]);
      final id = (await h.mail.watchCandidates().first).single.id;
      await h.mail.ignoreItem(id);
      return id;
    }

    test('出现在已过滤的邮件里，带来源邮件的发件人和日期', () async {
      final id = await ignoredItem();

      final entry = (await filtered()).single;
      expect(entry.kind, FilteredKind.ignoredItem);
      expect(entry.id, id);
      expect(entry.title, '交周报');
      expect(entry.sender, '李明');
      expect(entry.receivedAt, DateTime.utc(2026, 10, 19, 14, 30));
      expect(entry.reason, '你忽略了这个事项');
    });

    test('[恢复] 后回到栏里，不再在已过滤的邮件里', () async {
      final id = await ignoredItem();

      await h.mail.restoreItem(id);

      expect(await candidateTitles(), ['交周报']);
      expect(await filtered(), isEmpty);
    });

    test('列表跟着变：忽略、恢复以后马上发出新的列表', () async {
      h.analyzer.returns(
        'Report due',
        AnalysisResult(
          category: MailCategory.actionRequired,
          reason: '有截止时间',
          items: [fakeItem('交周报')],
        ),
      );
      await importAndAnalyze([mail('Report due')]);
      final id = (await h.mail.watchCandidates().first).single.id;
      final lists = <List<String>>[];
      final subscription = h.mail.watchFiltered().listen(
        (entries) => lists.add([for (final e in entries) e.title]),
      );
      await pumpEventQueue();

      await h.mail.ignoreItem(id);
      await pumpEventQueue();
      await h.mail.restoreItem(id);
      await pumpEventQueue();
      await subscription.cancel();

      expect(lists, [
        <String>[],
        ['交周报'],
        <String>[],
      ]);
    });

    test('不是被忽略的事项不能 [恢复]', () async {
      final id = await ignoredItem();
      await h.mail.restoreItem(id);

      expect(h.mail.restoreItem(id), throwsA(isA<InvalidState>()));
    });
  });

  group('没有分析的邮件（M-21）', () {
    test('首次设置之前 14 天以外的邮件在已过滤的邮件里', () async {
      // 首次设置时间是第一次导入的时候：2026-10-20 09:00。
      await importAndAnalyze([mail('Old notice', at: '2026-10-05T14:00:00Z')]);

      final entry = (await filtered()).single;
      expect(entry.kind, FilteredKind.notAnalyzed);
      expect(entry.title, 'Old notice');
      expect(entry.reason, '较早的邮件，没有自动分析');
    });

    test('分析失败的邮件在已过滤的邮件里', () async {
      h.analyzer.fails('Broken', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('Broken')]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();

      final entry = (await filtered()).single;
      expect(entry.kind, FilteredKind.analysisFailed);
      expect(entry.reason, '分析失败');
    });

    test('还在待分析的邮件不在已过滤的邮件里', () async {
      h.analyzer.fails('Later', AnalysisFailureType.temporary);
      await importAndAnalyze([mail('Later')]);

      expect(await filtered(), isEmpty);
    });
  });

  group('[这封有用]（M-19）', () {
    const informational = AnalysisResult(
      category: MailCategory.informational,
      reason: '只是通知',
      items: [],
    );

    /// 已过滤的邮件里主题为 [subject] 的那一条的邮件 id。
    Future<String> filteredMailId(String subject) async =>
        (await filtered()).singleWhere((e) => e.title == subject).mailId;

    test('重新分析并要求按需要行动处理，事项进栏，邮件离开已过滤的邮件', () async {
      await importAndAnalyze([mail('Lab safety')]);
      final id = await filteredMailId('Lab safety');
      h.analyzer.returns(
        'Lab safety',
        AnalysisResult(
          category: MailCategory.actionRequired,
          reason: '要完成培训',
          items: [fakeItem('完成实验室安全培训')],
        ),
      );

      await h.mail.markUseful(id);

      expect(h.analyzer.analyzedSubjects, ['Lab safety', 'Lab safety']);
      expect(h.analyzer.requests.first.markedUseful, isFalse);
      expect(h.analyzer.requests.last.markedUseful, isTrue);
      expect(await candidateTitles(), ['完成实验室安全培训']);
      expect(await filtered(), isEmpty);
    });

    test('实在提取不出事项时，生成一个以邮件主题为标题的候选', () async {
      await importAndAnalyze([mail('Lab safety')]);

      await h.mail.markUseful(await filteredMailId('Lab safety'));

      expect(await candidateTitles(), ['Lab safety']);
      expect(await filtered(), isEmpty);
    });

    test('较早的未分析邮件和分析失败的邮件也可以点', () async {
      h.analyzer.fails('Broken', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([
        mail('Old notice', at: '2026-10-05T14:00:00Z'),
        mail('Broken'),
      ]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();
      h.analyzer.returns('Broken', informational);

      await h.mail.markUseful(await filteredMailId('Old notice'));
      await h.mail.markUseful(await filteredMailId('Broken'));

      expect(
        await candidateTitles()
          ..sort(),
        ['Broken', 'Old notice'],
      );
      expect(await filtered(), isEmpty);
    });

    test('这封邮件正在分析时点 [这封有用]，结果也按有用处理', () async {
      h.analyzer.fails('Broken', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('Broken')]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();
      final id = await filteredMailId('Broken');
      h.analyzer
        ..returns('Broken', informational)
        ..hold('Broken');
      final retry = h.mail.retryAnalysis();
      await pumpEventQueue();

      final useful = h.mail.markUseful(id);
      await pumpEventQueue();
      h.analyzer.release('Broken');
      await Future.wait([retry, useful]);

      expect(await candidateTitles(), ['Broken']);
      expect(await filtered(), isEmpty);
    });

    test('不计入每天自动分析的上限', () async {
      const limit = MailService.dailyAutoAnalysisLimit;
      List<Map<String, Object?>> many(int count, String prefix) => [
        for (var i = 0; i < count; i++)
          mail(
            '$prefix$i',
            at: DateTime.utc(
              2026,
              10,
              19,
              12,
            ).subtract(Duration(minutes: i)).toIso8601String(),
          ),
      ];
      // 自动分析了 limit - 1 封，今天还能自动分析一封。
      await importAndAnalyze(many(limit - 1, 'M'));
      await h.mail.markUseful(await filteredMailId('M0'));
      h.analyzer.requests.clear();

      await importAndAnalyze(many(2, 'N'));

      expect(h.analyzer.analyzedSubjects, ['N0']);
    });

    test('自动分析暂停时也马上分析', () async {
      const limit = MailService.dailyAutoAnalysisLimit;
      await importAndAnalyze([
        for (var i = 0; i <= limit; i++)
          mail(
            'M$i',
            at: DateTime.utc(
              2026,
              10,
              19,
              12,
            ).subtract(Duration(minutes: i)).toIso8601String(),
          ),
      ]);
      h.analyzer.requests.clear();

      await h.mail.markUseful(await filteredMailId('M0'));

      expect(h.analyzer.analyzedSubjects, ['M0']);
      expect(await candidateTitles(), ['M0']);
    });

    test('正文已清除时不可用，提示在 Outlook 中查看，邮件不变', () async {
      await importAndAnalyze([mail('Lab safety')]);
      final id = await filteredMailId('Lab safety');
      await h.clearBody(id);

      await expectLater(
        h.mail.markUseful(id),
        throwsA(
          isA<InvalidState>().having(
            (e) => e.message,
            'message',
            '原文已清理，请在 Outlook 中查看',
          ),
        ),
      );
      expect(h.analyzer.analyzedSubjects, ['Lab safety']);
      expect(await filtered(), hasLength(1));
    });

    test('已过滤的邮件里的每一封邮件都标着正文是否已清除', () async {
      await importAndAnalyze([mail('Lab safety')]);
      final id = await filteredMailId('Lab safety');
      expect((await filtered()).single.bodyCleared, isFalse);

      await h.clearBody(id);

      expect((await filtered()).single.bodyCleared, isTrue);
    });
  });
}
