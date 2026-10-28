/// 邮件、事项和卡片行上的读法，以及卡片备注里来自事项的那几段。
/// `MailService` 和 `ItemUpdates` 共用。
library;

import 'dart:convert';

import 'package:characters/characters.dart';

import '../planner/card_time.dart';
import '../planner/task_card.dart';
import '../storage/planner_database.dart';
import 'item_changes.dart';

extension MailRowLinks on MailRow {
  /// 邮件的链接列表。链接列存成 URL 的 JSON 数组，没有链接时为 null。
  List<String> get linkList => switch (links) {
    final json? => (jsonDecode(json) as List<Object?>).cast<String>(),
    null => const [],
  };
}

extension MailItemRowFields on MailItemRow {
  /// 事项本身的可更新字段；[mailLinks] 是它的来源邮件的链接列表。
  ItemFields fields(List<String> mailLinks) => ItemFields(
    title: title,
    summary: summary,
    actions: actionList,
    location: location,
    links: linksFrom(mailLinks),
    eventTime: times.event,
    dueTime: times.due,
  );

  /// 事项要做的事。
  List<String> get actionList => switch (actions) {
    final json? => (jsonDecode(json) as List<Object?>).cast<String>(),
    null => const [],
  };

  /// 事项引用的链接，按引用的顺序；[mailLinks] 是邮件的链接列表。
  List<String> linksFrom(List<String> mailLinks) {
    final refs = switch (linkRefs) {
      final json? => (jsonDecode(json) as List<Object?>).cast<int>(),
      null => const <int>[],
    };
    return [
      for (final ref in refs)
        if (ref >= 1 && ref <= mailLinks.length) mailLinks[ref - 1],
    ];
  }

  /// 事项的活动时间和截止时间。
  CardTimes get times => (
    event: cardTimeFromColumns(eventTime, eventTimePrecision, eventTimePending),
    due: cardTimeFromColumns(dueTime, dueTimePrecision, dueTimePending),
  );
}

extension TaskCardRowState on TaskCardRow {
  /// 卡片的活动时间和截止时间。
  CardTimes get times => (
    event: cardTimeFromColumns(eventTime, eventTimePrecision, eventTimePending),
    due: cardTimeFromColumns(dueTime, dueTimePrecision, dueTimePending),
  );

  /// 卡片在画布上、没完成、不在回收站。
  bool get isOpen => status == CardStatus.active && deletedAt == null;
}

extension ItemFieldsNote on ItemFields {
  /// 卡片备注里来自各个字段的那一段，按备注里的顺序；没有时为 null。
  /// [采用] 时按它找到备注里要换掉的部分。
  Map<ItemField, String?> get noteParts => {
    ItemField.summary: summary,
    ItemField.actions: actions.isEmpty
        ? null
        : [for (final action in actions) '- $action'].join('\n'),
    ItemField.location: switch (location) {
      final location? => '地点：$location',
      null => null,
    },
    ItemField.links: links.firstOrNull,
  };

  /// 卡片的备注：依次是摘要、要做的事、地点、第一个链接；都没有时为 null。
  /// 最多 [maxLength] 个字符。
  String? cardNote(int maxLength) {
    final parts = [...noteParts.values.nonNulls];
    if (parts.isEmpty) return null;
    return truncateCharacters(parts.join('\n'), maxLength);
  }
}

/// [text] 的前 [maxCharacters] 个字符（按用户看到的字符算）。
String truncateCharacters(String text, int maxCharacters) {
  final characters = text.characters;
  return characters.length <= maxCharacters
      ? text
      : characters.take(maxCharacters).toString();
}
