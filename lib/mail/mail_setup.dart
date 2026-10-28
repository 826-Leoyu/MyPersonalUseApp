/// 首次设置向导（spec 0002"界面·向导"）的步骤和第 4 步用的内置示例邮件。
library;

import 'mail_analyzer.dart';

/// 向导的四步，按顺序；[done] 表示都做完了。
enum SetupStep {
  /// 同意把邮件内容交给她自己账号下的 Claude 分析。
  consent,

  /// 选择邮件文件夹。
  folder,

  /// 检查 Claude Code 装了没有、登录了没有。
  claude,

  /// 用内置的示例邮件试分析一次。
  trial,

  /// 四步都做完了。
  done,
}

/// 内置示例邮件的主题。
const sampleMailSubject = 'Reminder: Lab report 2 due this Friday';

/// 向导第 4 步试分析用的邮件：完全虚构，收件时间是 [now]。
AnalysisRequest sampleAnalysisRequest({
  required DateTime now,
  required String timeZone,
}) => AnalysisRequest(
  subject: sampleMailSubject,
  senderName: 'Course Office',
  senderAddress: 'course-office@university.example.edu',
  receivedAt: now,
  importance: 'normal',
  bodyText:
      'Hi all,\n\n'
      'This is a reminder that Lab report 2 is due this Friday at 11:59 PM. '
      'Please submit it on the course website [1].\n\n'
      'Best,\nCourse Office',
  links: const ['https://university.example.edu/course/lab-report-2'],
  hasAttachments: false,
  hasInlineImages: false,
  bodyPossiblyIncomplete: false,
  timeZone: timeZone,
  relatedItems: const [],
  markedUseful: false,
);
