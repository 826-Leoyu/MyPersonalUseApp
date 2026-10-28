/// 正文保留规则里的计算。纯函数，不碰数据库。时间都是 UTC 毫秒。
///
/// 规则见 spec 0002 的"正文保留规则"。
library;

import 'dart:math';

import '../planner/card_time.dart';
import '../storage/planner_database.dart';

/// 有明确时间的邮件，正文保留到最晚的那个时间以后多久。
const _keepTimedBodyFor = Duration(days: 7);

/// 没有明确时间的邮件，正文保留到收件（没有收件时间时为导入）以后多久。
const _keepUntimedBodyFor = Duration(days: 30);

/// 邮件 [mail] 按收件算时的时间：收件时间，没有时用导入时间。同一讨论
/// 延后到期时，也按这个时间找讨论里最晚的邮件。
int _untimedKeepFrom(MailRow mail) => mail.receivedAt ?? mail.importedAt;

/// 邮件 [mail] 的正文到期时间：[times] 是它分析出的事项的时间，有明确
/// 时间时取最晚的那个之后 [_keepTimedBodyFor]；没有时为 [_untimedKeepFrom]
/// 以后 [_keepUntimedBodyFor]，同一讨论有更晚的邮件（[latestInConversation]）
/// 时从那封算起。
int bodyExpiresAt(
  MailRow mail,
  List<CardTimes> times, {
  required int? latestInConversation,
}) {
  final keepFrom = [
    for (final (:event, :due) in times)
      for (final time in [event, due]) ?_timedKeepFrom(time),
  ];
  if (keepFrom.isNotEmpty) {
    return keepFrom.reduce(max) + _keepTimedBodyFor.inMilliseconds;
  }
  final own = _untimedKeepFrom(mail);
  return max(own, latestInConversation ?? own) +
      _keepUntimedBodyFor.inMilliseconds;
}

/// 事项时间 [time] 从什么时候算起：有时刻时就是那个时刻，只有日期时是那一天
/// 结束。没有值时为 null。
int? _timedKeepFrom(CardTime? time) =>
    (time?.time ?? time?.day?.endsAt)?.millisecondsSinceEpoch;
