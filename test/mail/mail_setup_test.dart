// 切入点 3：首次设置向导的进度（#91）：同意、选择文件夹、检查 Claude Code、
// 用内置示例邮件试分析；中途退出后从没做完的那一步继续。分析器是假的。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_setup.dart';

import 'mail_fixtures.dart';
import 'mail_harness.dart';

void main() {
  late MailHarness h;

  setUp(() => h = MailHarness());
  tearDown(() => h.dispose());

  const informational = AnalysisResult(
    category: MailCategory.informational,
    reason: '只是通知',
    items: [],
  );

  /// 走完前三步。
  Future<void> throughClaudeCheck() async {
    await h.mail.agreeToMailUse();
    await h.mail.setMailFolder(h.directory.path);
    await h.mail.completeClaudeCheck();
  }

  test('还没设置过时从第一步"同意"开始，没有同意时间', () async {
    expect(await h.mail.setupStep(), SetupStep.consent);
    expect(await h.mail.consentedAt(), isNull);
  });

  test('同意后记下同意时间；重启后从第二步继续', () async {
    await h.mail.agreeToMailUse();
    await h.reopen();

    expect(await h.mail.consentedAt(), DateTime(2026, 10, 20, 9).toUtc());
    expect(await h.mail.setupStep(), SetupStep.folder);
  });

  test('重新打开向导再同意一次，同意时间还是第一次的', () async {
    await h.mail.agreeToMailUse();
    h.now = DateTime(2026, 11, 1, 9);
    await h.mail.agreeToMailUse();

    expect(await h.mail.consentedAt(), DateTime(2026, 10, 20, 9).toUtc());
  });

  test('在设置页先选了文件夹也要先同意；同意后跳过已经选好的文件夹', () async {
    await h.mail.setMailFolder(h.directory.path);
    expect(await h.mail.setupStep(), SetupStep.consent);

    await h.mail.agreeToMailUse();
    expect(await h.mail.setupStep(), SetupStep.claude);
  });

  test('检查完 Claude Code 后从第四步继续；示例邮件分析成功后向导完成', () async {
    await throughClaudeCheck();
    await h.reopen();
    expect(await h.mail.setupStep(), SetupStep.trial);

    await h.mail.analyzeSample();
    await h.reopen();
    expect(await h.mail.setupStep(), SetupStep.done);
  });

  test('示例邮件分析失败时给出失败类型，下次还从第四步开始', () async {
    await throughClaudeCheck();
    h.analyzer.fails(sampleMailSubject, AnalysisFailureType.notLoggedIn);

    await expectLater(
      h.mail.analyzeSample(),
      throwsA(
        isA<AnalysisFailed>().having(
          (f) => f.type,
          'type',
          AnalysisFailureType.notLoggedIn,
        ),
      ),
    );
    await h.reopen();
    expect(await h.mail.setupStep(), SetupStep.trial);
  });

  test('示例邮件是内置的虚构邮件，返回分析结果，不进邮件列表', () async {
    await throughClaudeCheck();
    h.analyzer.returns(sampleMailSubject, informational);

    final result = await h.mail.analyzeSample();

    expect(result.category, MailCategory.informational);
    final request = h.analyzer.requests.single;
    expect(request.subject, sampleMailSubject);
    expect(request.senderAddress, endsWith('.example.edu'));
    expect(request.timeZone, 'Eastern Daylight Time');
    expect(await h.subjects(), isEmpty);
  });

  test('示例邮件分析成功后，等着登录的邮件接着分析', () async {
    await throughClaudeCheck();
    h.analyzer.fails('Waiting', AnalysisFailureType.notLoggedIn);
    await h.importJson(
      'mail-1.json',
      fakeEnvelope([
        fakeMessage(
          internetMessageId: '<waiting@example.com>',
          subject: 'Waiting',
          receivedDateTime: '2026-10-19T14:30:00Z',
        ),
      ]),
    );
    await h.mail.analyzePending();
    h.analyzer.returns('Waiting', informational);

    await h.mail.analyzeSample();
    await h.mail.waitForAnalysis();

    expect(h.analyzer.analyzedSubjects, [
      'Waiting',
      sampleMailSubject,
      'Waiting',
    ]);
  });

  test('完成向导不改首次设置时间（第一次选择文件夹的时间）', () async {
    await throughClaudeCheck();
    h.now = DateTime(2026, 11, 20, 9);
    await h.mail.analyzeSample();

    // 2026-10-20 09:00 往前 14 天以内：完成向导时另记的话就不会分析了。
    await h.importJson(
      'mail-1.json',
      fakeEnvelope([
        fakeMessage(
          internetMessageId: '<early@example.com>',
          subject: 'Early',
          receivedDateTime: '2026-10-07T14:00:00Z',
        ),
      ]),
    );
    await h.mail.analyzePending();

    expect(h.analyzer.analyzedSubjects, [sampleMailSubject, 'Early']);
  });
}
