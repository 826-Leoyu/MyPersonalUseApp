/// 邮件事项可以被后续邮件更新的字段，和一条更新建议里的改动。
///
/// 改动存进 `MailItemUpdates.changes`，是字段名到新值的 JSON 对象（spec
/// 0002"数据模型"）。链接存成网址，不存编号：编号只在它来自的那封邮件里
/// 有意义。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../planner/card_time.dart';

/// 可以被后续邮件更新的字段。名字就是存进 JSON 的键。
enum ItemField { title, summary, actions, location, links, eventTime, dueTime }

/// 一个事项的可更新字段的值。
@immutable
class ItemFields {
  const ItemFields({
    required this.title,
    required this.summary,
    required this.actions,
    required this.location,
    required this.links,
    required this.eventTime,
    required this.dueTime,
  });

  final String title;
  final String? summary;
  final List<String> actions;
  final String? location;

  /// 链接的网址，按引用的顺序。
  final List<String> links;
  final CardTime? eventTime;
  final CardTime? dueTime;

  /// [changes] 列出的字段换成新值，其他字段不变。
  ItemFields overlay(ItemChanges changes) {
    final f = changes.fields;
    final v = changes.values;
    return ItemFields(
      title: f.contains(ItemField.title) ? v.title : title,
      summary: f.contains(ItemField.summary) ? v.summary : summary,
      actions: f.contains(ItemField.actions) ? v.actions : actions,
      location: f.contains(ItemField.location) ? v.location : location,
      links: f.contains(ItemField.links) ? v.links : links,
      eventTime: f.contains(ItemField.eventTime) ? v.eventTime : eventTime,
      dueTime: f.contains(ItemField.dueTime) ? v.dueTime : dueTime,
    );
  }

  bool _same(ItemField field, ItemFields other) => switch (field) {
    ItemField.title => title == other.title,
    ItemField.summary => summary == other.summary,
    ItemField.actions => listEquals(actions, other.actions),
    ItemField.location => location == other.location,
    ItemField.links => listEquals(links, other.links),
    ItemField.eventTime => eventTime == other.eventTime,
    ItemField.dueTime => dueTime == other.dueTime,
  };

  Object? _toJson(ItemField field) => switch (field) {
    ItemField.title => title,
    ItemField.summary => summary,
    ItemField.actions => actions,
    ItemField.location => location,
    ItemField.links => links,
    ItemField.eventTime => _timeToJson(eventTime),
    ItemField.dueTime => _timeToJson(dueTime),
  };
}

/// 一条更新建议里的改动：[fields] 里的字段改成 [values] 里的值，其他
/// 字段不动。
@immutable
class ItemChanges {
  const ItemChanges(this.fields, this.values);

  /// [after] 里和 [before] 不一样的字段。
  factory ItemChanges.between(ItemFields before, ItemFields after) =>
      ItemChanges({
        for (final field in ItemField.values)
          if (!before._same(field, after)) field,
      }, after);

  /// 从存进数据库的 JSON 读回来。
  factory ItemChanges.decode(String json) {
    final map = (jsonDecode(json) as Map<String, Object?>);
    final fields = {
      for (final field in ItemField.values)
        if (map.containsKey(field.name)) field,
    };
    List<String> strings(Object? value) =>
        (value as List<Object?>? ?? const []).cast<String>();
    return ItemChanges(
      fields,
      ItemFields(
        title: map[ItemField.title.name] as String? ?? '',
        summary: map[ItemField.summary.name] as String?,
        actions: strings(map[ItemField.actions.name]),
        location: map[ItemField.location.name] as String?,
        links: strings(map[ItemField.links.name]),
        eventTime: _timeFromJson(map[ItemField.eventTime.name]),
        dueTime: _timeFromJson(map[ItemField.dueTime.name]),
      ),
    );
  }

  final Set<ItemField> fields;
  final ItemFields values;

  bool get isEmpty => fields.isEmpty;

  /// 存进数据库的 JSON：只有改了的字段。
  String encode() => jsonEncode({
    for (final field in ItemField.values)
      if (fields.contains(field)) field.name: values._toJson(field),
  });
}

Map<String, Object?>? _timeToJson(CardTime? time) {
  if (time == null) return null;
  final columns = cardTimeToColumns(time);
  return {
    'value': columns.value,
    'precision': columns.precision?.name,
    'pending': columns.pending,
  };
}

CardTime? _timeFromJson(Object? json) => switch (json) {
  {
    'value': final String? value,
    'precision': final String? precision,
    'pending': final bool pending,
  } =>
    cardTimeFromColumns(
      value,
      precision == null ? null : CardTimePrecision.values.byName(precision),
      pending,
    ),
  _ => null,
};
