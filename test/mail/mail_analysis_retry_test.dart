// 切入点 3：分析失败的重试、每日上限和首次设置的 14 天（M-20、M-21、
// M-22）。分析器是按脚本返回结果或失败的假分析器。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/import_status.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';

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
  }) => fakeMessage(
    internetMessageId: '<$subject@example.com>',
    id: 'AAMk-$subject',
    subject: subject,
    receivedDateTime: at,
  );

  var files = 0;

  /// 导入这些邮件，并等自动分析结束。
  Future<void> importAndAnalyze(List<Map<String, Object?>> mails) async {
    await h.importJson('mail-${files++}.json', fakeEnvelope(mails));
    await h.mail.analyzePending();
  }

  const informational = AnalysisResult(
    category: MailCategory.informational,
    reason: '只是通知',
    items: [],
  );

  Future<List<ImportNotice>> notices() async =>
      (await h.mail.importStatus()).notices;

  group('输出格式不对（M-20）', () {
    test('自动重试，累计 3 次后标为失败，不再自动重试', () async {
      h.analyzer.fails('A', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('A')]);
      await h.mail.analyzePending();
      expect(await notices(), isNot(contains(const AnalysisFailures(1))));

      await h.mail.analyzePending();
      await h.mail.analyzePending();

      expect(h.analyzer.analyzedSubjects, ['A', 'A', 'A']);
      expect(await notices(), contains(const AnalysisFailures(1)));
    });

    test('点 [重试] 后再分析，成功后提示消失', () async {
      h.analyzer.fails('A', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('A')]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();
      h.analyzer.returns('A', informational);

      await h.mail.retryAnalysis();

      expect(h.analyzer.analyzedSubjects, ['A', 'A', 'A', 'A']);
      expect(await notices(), isEmpty);
    });

    test('重试以后又从头数 3 次', () async {
      h.analyzer.fails('A', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('A')]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();

      await h.mail.retryAnalysis();
      await h.mail.analyzePending();
      await h.mail.analyzePending();
      await h.mail.analyzePending();

      expect(h.analyzer.analyzedSubjects, hasLength(6));
      expect(await notices(), contains(const AnalysisFailures(1)));
    });
  });

  group('首次设置的 14 天（M-21）', () {
    // 首次设置时间是 setUp 里选择文件夹的时候：2026-10-20 09:00。
    test('首次设置时间之前 14 天以外的邮件不自动分析', () async {
      await importAndAnalyze([
        mail('Recent', at: '2026-10-06T14:00:00Z'),
        mail('Old', at: '2026-10-05T14:00:00Z'),
      ]);

      expect(h.analyzer.analyzedSubjects, ['Recent']);
    });

    test('以后再导入的旧邮件也不分析；换文件夹不会重新算首次设置时间', () async {
      h.now = DateTime(2026, 11, 20, 9);
      await h.mail.setMailFolder('${h.directory.path}-other');

      await importAndAnalyze([
        mail('Old', at: '2026-10-05T14:00:00Z'),
        mail('Later', at: '2026-10-07T14:00:00Z'),
      ]);

      expect(h.analyzer.analyzedSubjects, ['Later']);
    });

    test('还没选文件夹就手动导入时，第一次导入的时间算首次设置时间', () async {
      final fresh = MailHarness();
      addTearDown(fresh.dispose);

      await fresh.importJson(
        'mail-1.json',
        fakeEnvelope([
          mail('Recent', at: '2026-10-06T14:00:00Z'),
          mail('Old', at: '2026-10-05T14:00:00Z'),
        ]),
      );
      await fresh.mail.analyzePending();
      fresh.now = DateTime(2026, 11, 20, 9);
      await fresh.mail.setMailFolder(fresh.directory.path);
      await fresh.importJson(
        'mail-2.json',
        fakeEnvelope([mail('Later', at: '2026-10-07T14:00:00Z')]),
      );
      await fresh.mail.analyzePending();

      expect(fresh.analyzer.analyzedSubjects, ['Recent', 'Later']);
    });
  });

  group('每天自动分析的上限（M-22）', () {
    const limit = MailService.dailyAutoAnalysisLimit;

    /// [count] 封邮件，收件时间新的在前：M000 最新。
    List<Map<String, Object?>> many(int count, {String prefix = 'M'}) => [
      for (var i = 0; i < count; i++)
        mail(
          '$prefix${'$i'.padLeft(3, '0')}',
          at: DateTime.utc(
            2026,
            10,
            19,
            12,
          ).subtract(Duration(minutes: i)).toIso8601String(),
        ),
    ];

    test('一天里自动分析到上限时暂停，状态行提示', () async {
      await importAndAnalyze(many(limit + 2));
      await h.mail.analyzePending();

      expect(h.analyzer.requests, hasLength(limit));
      expect(await notices(), [const AnalysisPaused()]);
    });

    test('点 [继续分析] 后今天不再暂停', () async {
      await importAndAnalyze(many(limit + 2));

      await h.mail.resumeAnalysis();
      await importAndAnalyze(many(3, prefix: 'N'));

      expect(h.analyzer.requests, hasLength(limit + 5));
      expect(await notices(), isEmpty);
    });

    test('第二天自动恢复，又从 0 开始数', () async {
      await importAndAnalyze(many(limit * 2 + 1));
      h.now = DateTime(2026, 10, 21, 0, 1);

      await h.mail.analyzePending();

      expect(h.analyzer.requests, hasLength(limit * 2));
      expect(await notices(), [const AnalysisPaused()]);
    });

    test('第二天又会在上限暂停，前一天的 [继续分析] 不算', () async {
      await importAndAnalyze(many(limit + 1));
      await h.mail.resumeAnalysis();
      h.now = DateTime(2026, 10, 21, 9);

      await importAndAnalyze(many(limit + 1, prefix: 'N'));

      expect(h.analyzer.requests, hasLength(limit + 1 + limit));
    });

    test('Claude 给出了输出才算一次：格式不对算，临时错误不算', () async {
      final mails = many(limit + 1);
      for (final m in mails.skip(1)) {
        h.analyzer.fails(
          m['subject']! as String,
          AnalysisFailureType.temporary,
        );
      }
      h.analyzer.fails('M000', AnalysisFailureType.invalidOutput);
      await importAndAnalyze(mails);
      await h.mail.analyzePending();

      // 临时错误不算，所以没有暂停：两轮都把每一封试了一遍。
      expect(h.analyzer.requests, hasLength(2 * (limit + 1)));
      expect(await notices(), isNot(contains(const AnalysisPaused())));
    });

    test('暂停时点 [重试]，分析失败的邮件照样重试，不计入上限', () async {
      h.analyzer.fails('Broken', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('Broken', at: '2026-10-19T20:00:00Z')]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();
      await importAndAnalyze(many(limit + 1));
      h.analyzer.returns('Broken', informational);
      h.analyzer.requests.clear();

      await h.mail.retryAnalysis();

      expect(h.analyzer.analyzedSubjects, ['Broken']);
      expect(await notices(), [const AnalysisPaused()]);
    });

    test('分析进行中点 [重试]：失败的邮件在这一轮里接着分析，不计入上限', () async {
      // 格式不对的 3 次计入上限，再加 limit - 3 封新邮件正好到上限，最后
      // 一封留着。
      h.analyzer.fails('Broken', AnalysisFailureType.invalidOutput);
      await importAndAnalyze([mail('Broken', at: '2026-10-19T20:00:00Z')]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();
      h.analyzer.returns('Broken', informational);
      h.analyzer.requests.clear();
      h.analyzer.hold('M000');

      await h.importJson('mail-${files++}.json', fakeEnvelope(many(limit - 2)));
      final run = h.mail.analyzePending();
      await pumpEventQueue();
      expect(h.analyzer.analyzedSubjects, ['M000']);
      final retried = h.mail.retryAnalysis();
      await pumpEventQueue();
      h.analyzer.release('M000');
      await run;
      await retried;

      // Broken 收件时间最新，紧接着正在分析的 M000；它不计入上限，所以
      // 分析了 limit - 3 封新邮件才到上限。
      expect(h.analyzer.analyzedSubjects, [
        'M000',
        'Broken',
        for (final m in many(limit - 3).skip(1)) m['subject'],
      ]);
      expect(await notices(), [const AnalysisPaused()]);
    });

    test('上限按本地日算，重启以后还记得今天分析了多少', () async {
      await importAndAnalyze(many(limit - 1));
      await h.reopen();

      await importAndAnalyze(many(2, prefix: 'N'));

      expect(h.analyzer.requests, hasLength(limit));
    });
  });

  group('额度用完和临时错误（M-20）', () {
    test('额度用完：状态行提示稍后自动重试，下一轮（启动、导入、定时）接着分析', () async {
      h.analyzer.fails('A', AnalysisFailureType.quotaExhausted);
      await importAndAnalyze([mail('A')]);
      expect(await notices(), contains(const ClaudeQuotaExhausted()));
      h.analyzer.returns('A', informational);

      await h.reopen();
      await h.mail.analyzePending();

      expect(h.analyzer.analyzedSubjects, ['A', 'A']);
      expect(await notices(), isEmpty);
    });

    for (final type in [
      AnalysisFailureType.quotaExhausted,
      AnalysisFailureType.temporary,
    ]) {
      test('${type.name}：重试多少次都不会标为失败，点 [重试] 也会再试', () async {
        h.analyzer.fails('A', type);
        await importAndAnalyze([mail('A')]);
        for (var i = 0; i < 4; i++) {
          await h.mail.analyzePending();
        }
        await h.mail.retryAnalysis();

        expect(h.analyzer.analyzedSubjects, hasLength(6));
        expect(await notices(), isNot(contains(isA<AnalysisFailures>())));
      });
    }

    test('一封失败不影响其他邮件', () async {
      h.analyzer.fails('A', AnalysisFailureType.invalidOutput);
      h.analyzer.returns('B', informational);
      await importAndAnalyze([
        mail('A', at: '2026-10-19T08:00:00Z'),
        mail('B', at: '2026-10-18T08:00:00Z'),
      ]);
      await h.mail.analyzePending();
      await h.mail.analyzePending();

      expect(h.analyzer.analyzedSubjects, ['A', 'B', 'A', 'A']);
      expect(await notices(), [const AnalysisFailures(1)]);
    });
  });

  for (final (type, notice) in [
    (AnalysisFailureType.notInstalled, const ClaudeNotInstalled()),
    (AnalysisFailureType.notLoggedIn, const ClaudeNotLoggedIn()),
  ]) {
    group('${type.name}（M-20）', () {
      test('不自动重试，状态行给出提示', () async {
        h.analyzer.fails('A', type);
        await importAndAnalyze([mail('A')]);

        await h.mail.analyzePending();
        await h.reopen();
        await h.mail.analyzePending();

        expect(h.analyzer.analyzedSubjects, ['A']);
        expect(await notices(), contains(notice));
      });

      test('点 [重试] 时再试，成功后提示消失', () async {
        h.analyzer.fails('A', type);
        await importAndAnalyze([mail('A')]);
        h.analyzer.returns('A', informational);

        await h.mail.retryAnalysis();

        expect(h.analyzer.analyzedSubjects, ['A', 'A']);
        expect(await notices(), isEmpty);
      });

      test('之后有新邮件分析成功了，说明已经能用，等着的邮件接着分析', () async {
        h.analyzer.fails('A', type);
        await importAndAnalyze([mail('A')]);
        h.analyzer.returns('A', informational);

        await importAndAnalyze([mail('B')]);

        expect(h.analyzer.analyzedSubjects, ['A', 'B', 'A']);
        expect(await notices(), isEmpty);
      });
    });
  }
}
