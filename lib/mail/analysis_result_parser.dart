/// 分析结果校验：把分析器输出的 JSON 变成 [AnalysisResult]。纯函数。
///
/// 字段缺失、分类不认识、时间解析不了、引用了请求里没有的事项编号或链接
/// 编号时，抛出 [AnalysisFailureType.invalidOutput]，不产生任何事项（M-23）。
library;

import '../planner/card_time.dart';
import '../planner/day_key.dart';
import 'mail_analyzer.dart';

/// 校验 [json]（分析器输出、已经解码的 JSON）。[request] 是这次的请求，
/// 用来检查事项编号和链接编号。
AnalysisResult parseAnalysisResult(Object? json, AnalysisRequest request) {
  final root = _object(json, '顶层');
  final relatedIds = {for (final item in request.relatedItems) item.id};
  return AnalysisResult(
    category: _enum(MailCategory.values, root['category'], 'category'),
    reason: _string(root['reason'], 'reason'),
    items: [
      for (final (i, item) in _list(root['items'], 'items').indexed)
        _item(
          _object(item, 'items[$i]'),
          relatedIds: relatedIds,
          linkCount: request.links.length,
        ),
    ],
  );
}

AnalyzedItem _item(
  Map<String, Object?> json, {
  required Set<String> relatedIds,
  required int linkCount,
}) {
  final match = _object(json['match'], 'match');
  final updates = switch (match['kind']) {
    'new' => null,
    'update' => switch (match['itemId']) {
      final String id when relatedIds.contains(id) => id,
      _ => throw _invalid('match.itemId 不在请求里'),
    },
    _ => throw _invalid('match.kind'),
  };
  final title = _string(json['title'], 'title').trim();
  if (title.isEmpty) throw _invalid('title 为空');
  return AnalyzedItem(
    updates: updates,
    title: title,
    summary: _optionalString(json, 'summary'),
    actions: [
      for (final action in _list(json['actions'], 'actions'))
        _string(action, 'actions[]'),
    ],
    location: _optionalString(json, 'location'),
    linkRefs: [
      for (final ref in _list(json['linkRefs'], 'linkRefs'))
        switch (ref) {
          final int n when n >= 1 && n <= linkCount => n,
          _ => throw _invalid('linkRefs 超出范围'),
        },
    ],
    eventTime: _time(json, 'eventTime'),
    dueTime: _time(json, 'dueTime'),
    optional: _bool(json['optional'], 'optional'),
    unanalyzedAttachments: _bool(
      json['unanalyzedAttachments'],
      'unanalyzedAttachments',
    ),
  );
}

/// 时间：`null`，或 `{value, precision, unconfirmed}`。日期加时刻必须带时区
/// 偏移；没有值时必须是待确认。
CardTime? _time(Map<String, Object?> json, String field) {
  if (!json.containsKey(field)) throw _invalid('缺少 $field');
  final raw = json[field];
  if (raw == null) return null;
  final time = _object(raw, field);
  final pending = _bool(time['unconfirmed'], '$field.unconfirmed');
  final precision = _enum(
    CardTimePrecision.values,
    time['precision'],
    '$field.precision',
  );
  final value = time['value'];
  if (value == null) {
    if (!pending) throw _invalid('$field 没有值也不待确认');
    return const CardTime.pending();
  }
  if (value is! String) throw _invalid('$field.value');
  switch (precision) {
    case CardTimePrecision.dateTime:
      final parsed = _withOffset.hasMatch(value)
          ? DateTime.tryParse(value)
          : null;
      if (parsed == null) throw _invalid('$field.value 不是带偏移的时间');
      return CardTime.dateTime(parsed, pending: pending);
    case CardTimePrecision.date:
      try {
        return CardTime.date(DayKey.parse(value), pending: pending);
      } on FormatException {
        throw _invalid('$field.value 不是日期');
      }
  }
}

final _withOffset = RegExp(r'T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$');

Map<String, Object?> _object(Object? value, String field) => switch (value) {
  final Map<String, Object?> map => map,
  _ => throw _invalid('$field 不是对象'),
};

List<Object?> _list(Object? value, String field) => switch (value) {
  final List<Object?> list => list,
  _ => throw _invalid('$field 不是数组'),
};

String _string(Object? value, String field) => switch (value) {
  final String s => s,
  _ => throw _invalid('$field 不是字符串'),
};

/// 可以为 null 但必须出现的字符串；空白时当作 null。
String? _optionalString(Map<String, Object?> json, String field) {
  if (!json.containsKey(field)) throw _invalid('缺少 $field');
  return switch (json[field]) {
    null => null,
    final String s => s.trim().isEmpty ? null : s.trim(),
    _ => throw _invalid('$field 不是字符串'),
  };
}

bool _bool(Object? value, String field) => switch (value) {
  final bool b => b,
  _ => throw _invalid('$field 不是布尔值'),
};

T _enum<T extends Enum>(List<T> values, Object? value, String field) {
  for (final v in values) {
    if (v.name == value) return v;
  }
  throw _invalid('$field 不认识');
}

/// 字段说明只用字段名，不带输出内容，可以写进日志。
AnalysisFailed _invalid(String detail) =>
    AnalysisFailed(AnalysisFailureType.invalidOutput, detail);

/// 要求分析器输出的 JSON Schema，和 [parseAnalysisResult] 的规则一致。
/// `match` 是 `{kind: new}` 或 `{kind: update, itemId}`。
const analysisResultSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': ['category', 'reason', 'items'],
  'properties': {
    'category': {
      'type': 'string',
      'enum': ['actionRequired', 'optionalEvent', 'informational', 'lowValue'],
    },
    'reason': {'type': 'string'},
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': [
          'match',
          'title',
          'summary',
          'actions',
          'location',
          'linkRefs',
          'eventTime',
          'dueTime',
          'optional',
          'unanalyzedAttachments',
        ],
        'properties': {
          'match': {
            'type': 'object',
            'additionalProperties': false,
            'required': ['kind'],
            'properties': {
              'kind': {
                'type': 'string',
                'enum': ['new', 'update'],
              },
              'itemId': {'type': 'string'},
            },
          },
          'title': {'type': 'string'},
          'summary': {
            'type': ['string', 'null'],
          },
          'actions': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'location': {
            'type': ['string', 'null'],
          },
          'linkRefs': {
            'type': 'array',
            'items': {'type': 'integer', 'minimum': 1},
          },
          'eventTime': {r'$ref': r'#/$defs/time'},
          'dueTime': {r'$ref': r'#/$defs/time'},
          'optional': {'type': 'boolean'},
          'unanalyzedAttachments': {'type': 'boolean'},
        },
      },
    },
  },
  r'$defs': {
    'time': {
      'anyOf': [
        {'type': 'null'},
        {
          'type': 'object',
          'additionalProperties': false,
          'required': ['value', 'precision', 'unconfirmed'],
          'properties': {
            'value': {
              'type': ['string', 'null'],
            },
            'precision': {
              'type': 'string',
              'enum': ['dateTime', 'date'],
            },
            'unconfirmed': {'type': 'boolean'},
          },
        },
      ],
    },
  },
};
