import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/planner/card_time.dart';

/// 按脚本返回结果或失败的假分析器，按邮件主题决定返回什么；没写脚本的
/// 邮件返回"仅供参考"、没有事项。记下收到的每一个请求。
class FakeAnalyzer implements MailAnalyzer {
  final requests = <AnalysisRequest>[];
  final _results = <String, AnalysisResult>{};
  final _failures = <String, AnalysisFailureType>{};

  /// 主题为 [subject] 的邮件返回 [result]。
  void returns(String subject, AnalysisResult result) {
    _failures.remove(subject);
    _results[subject] = result;
  }

  /// 主题为 [subject] 的邮件分析失败，直到改成 [returns]。
  void fails(String subject, AnalysisFailureType type) =>
      _failures[subject] = type;

  /// 收到过的请求的主题，按顺序。
  List<String> get analyzedSubjects => [for (final r in requests) r.subject];

  @override
  Future<AnalysisResult> analyze(AnalysisRequest request) async {
    requests.add(request);
    if (_failures[request.subject] case final type?) {
      throw AnalysisFailed(type);
    }
    return _results[request.subject] ??
        const AnalysisResult(
          category: MailCategory.informational,
          reason: '只是通知',
          items: [],
        );
  }
}

/// 一个分析出的事项，没给的字段都是空的。
AnalyzedItem fakeItem(
  String title, {
  String? updates,
  String? summary,
  List<String> actions = const [],
  String? location,
  List<int> linkRefs = const [],
  CardTime? eventTime,
  CardTime? dueTime,
  bool optional = false,
}) => AnalyzedItem(
  updates: updates,
  title: title,
  summary: summary,
  actions: actions,
  location: location,
  linkRefs: linkRefs,
  eventTime: eventTime,
  dueTime: dueTime,
  optional: optional,
  unanalyzedAttachments: false,
);
