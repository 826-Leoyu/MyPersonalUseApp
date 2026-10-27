/// 分析器的契约：一封邮件的分析请求、结构化的分析结果和有类型的失败。
///
/// 见 spec 0002 的"分析请求和结果（MailAnalyzer 的契约）"。`MailService` 只认
/// 这里的类型，不知道背后是 Claude Code 还是别的分析器。
library;

import '../planner/card_time.dart';
import 'mail_states.dart';

/// 分析一封邮件。成功时返回已经校验过的 [AnalysisResult]；失败时抛出
/// [AnalysisFailed]。
abstract interface class MailAnalyzer {
  Future<AnalysisResult> analyze(AnalysisRequest request);
}

/// 邮件的分类。只有前两类会生成候选事项。
enum MailCategory {
  actionRequired,
  optionalEvent,
  informational,
  lowValue;

  /// 这一类的事项会不会进"新邮件事项"栏。
  bool get producesCandidates => this == actionRequired || this == optionalEvent;
}

/// 分析失败的类型，决定之后怎么重试（重试规则在 #86）。
enum AnalysisFailureType {
  /// 没有安装 Claude Code。
  notInstalled,

  /// Claude Code 没有登录或登录过期。
  notLoggedIn,

  /// 额度用完。
  quotaExhausted,

  /// 输出不符合约定的结构。
  invalidOutput,

  /// 其他临时错误：超时、进程异常、网络。
  temporary,
}

/// 分析失败。
class AnalysisFailed implements Exception {
  const AnalysisFailed(this.type, [this.detail]);

  final AnalysisFailureType type;

  /// 给日志用的说明，不能包含邮件内容。
  final String? detail;

  @override
  String toString() =>
      'AnalysisFailed: ${type.name}${detail == null ? '' : ' ($detail)'}';
}

/// 发给分析器的一封邮件。只有分析需要的内容：不包括收件人列表、完整
/// 邮件头、附件和原始 HTML（M-27）。
class AnalysisRequest {
  const AnalysisRequest({
    required this.subject,
    required this.senderName,
    required this.senderAddress,
    required this.receivedAt,
    required this.importance,
    required this.bodyText,
    required this.links,
    required this.hasAttachments,
    required this.hasInlineImages,
    required this.bodyPossiblyIncomplete,
    required this.timeZone,
    required this.relatedItems,
    required this.markedUseful,
  });

  final String subject;
  final String? senderName;
  final String? senderAddress;

  /// 收件时间，本地时间；导出文件里没有时为 null。
  final DateTime? receivedAt;
  final String? importance;

  /// 清理后的正文文本，引用和签名带标记（见 spec"正文文本的格式"）。
  final String? bodyText;

  /// 正文里的链接，第 n 个对应文本里的 `[n]`。
  final List<String> links;
  final bool hasAttachments;
  final bool hasInlineImages;
  final bool bodyPossiblyIncomplete;

  /// 当前时区的名字，例如 `Eastern Daylight Time`。
  final String timeZone;

  /// 可能相关的现有事项，分析结果用 [RelatedItem.id] 引用。
  final List<RelatedItem> relatedItems;

  /// 用户点了 [这封有用]：要求按需要行动处理。
  final bool markedUseful;

  /// 交给分析器的 JSON。时间都带时区偏移。
  Map<String, Object?> toJson() => {
    'mail': {
      'subject': subject,
      'senderName': senderName,
      'senderAddress': senderAddress,
      'receivedAt': switch (receivedAt) {
        final at? => formatWithOffset(at),
        null => null,
      },
      'importance': importance,
      'bodyText': bodyText,
      'links': [
        for (var i = 0; i < links.length; i++) {'ref': i + 1, 'url': links[i]},
      ],
      'hasAttachments': hasAttachments,
      'hasInlineImages': hasInlineImages,
      'bodyPossiblyIncomplete': bodyPossiblyIncomplete,
    },
    'timeZone': timeZone,
    'relatedItems': [for (final item in relatedItems) item.toJson()],
    'markedUseful': markedUseful,
  };
}

/// "可能相关的现有事项"里的一项：只有编号、标题、时间和状态，不包含其他
/// 邮件的正文（M-27）。
class RelatedItem {
  const RelatedItem({
    required this.id,
    required this.title,
    required this.eventTime,
    required this.dueTime,
    required this.status,
  });

  final String id;
  final String title;
  final CardTime? eventTime;
  final CardTime? dueTime;
  final MailItemStatus status;

  Map<String, Object?> toJson() => {
    'itemId': id,
    'title': title,
    'eventTime': timeToJson(eventTime),
    'dueTime': timeToJson(dueTime),
    'status': status.name,
  };
}

/// 一封邮件的分析结果，已经校验过。
class AnalysisResult {
  const AnalysisResult({
    required this.category,
    required this.reason,
    required this.items,
  });

  final MailCategory category;

  /// 一句话理由，给"已过滤的邮件"用。
  final String reason;

  /// 分析出的事项；分类不生成候选时也可能有，但会被忽略。
  final List<AnalyzedItem> items;
}

/// 分析结果里的一件事。
class AnalyzedItem {
  const AnalyzedItem({
    required this.updates,
    required this.title,
    required this.summary,
    required this.actions,
    required this.location,
    required this.linkRefs,
    required this.eventTime,
    required this.dueTime,
    required this.optional,
    required this.unanalyzedAttachments,
  });

  /// 是对哪个现有事项的更新；新事项时为 null。
  final String? updates;
  final String title;
  final String? summary;
  final List<String> actions;
  final String? location;

  /// 引用的邮件链接编号，从 1 开始。
  final List<int> linkRefs;
  final CardTime? eventTime;
  final CardTime? dueTime;
  final bool optional;
  final bool unanalyzedAttachments;
}

/// 时间的 JSON 形式：`{value, precision, unconfirmed}`，没有时间时为 null。
/// 日期加时刻按本地时间带偏移写出，只有日期时是 `YYYY-MM-DD`。
Map<String, Object?>? timeToJson(CardTime? time) => switch (time) {
  null => null,
  final time => {
    'value': switch ((time.time, time.day)) {
      (final at?, _) => formatWithOffset(at),
      (_, final day?) => day.toString(),
      _ => null,
    },
    'precision': time.precision?.name,
    'unconfirmed': time.pending,
  },
};

/// [time] 换成本地时间，写成带偏移的 ISO 8601，例如 `2026-10-19T09:15:00-04:00`。
String formatWithOffset(DateTime time) {
  final local = time.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}:'
      '${two(local.second)}$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
