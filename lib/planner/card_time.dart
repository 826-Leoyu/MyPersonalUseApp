import 'day_key.dart';

/// 卡片时间的精度：日期加时刻，或者只有日期。
enum CardTimePrecision { dateTime, date }

/// 卡片上的活动时间或截止时间。卡片没有这个时间时用 null 表示。
///
/// 有三种状态：
/// - 日期加时刻：[time] 有值（UTC），[day] 为 null；
/// - 只有日期：[day] 有值（本地日期），[time] 为 null，不编出一个时刻；
/// - 待确认：[pending] 为 true，可以带一个暂定的值，也可以没有值。
class CardTime {
  /// 日期加时刻。[time] 换算成 UTC 保存。
  CardTime.dateTime(DateTime time, {this.pending = false})
    : time = time.toUtc(),
      day = null;

  /// 只有日期。
  const CardTime.date(DayKey this.day, {this.pending = false}) : time = null;

  /// 待确认，还没有值。
  const CardTime.pending() : time = null, day = null, pending = true;

  /// 精度为日期加时刻时的时间点，UTC。
  final DateTime? time;

  /// 精度为只有日期时的那一天，按本地时区。
  final DayKey? day;

  final bool pending;

  /// 有值时的精度；待确认且没有值时为 null。
  CardTimePrecision? get precision => time != null
      ? CardTimePrecision.dateTime
      : day != null
      ? CardTimePrecision.date
      : null;

  /// 有值时在本地时区的那一天（有时刻时换算成本地时间）；没有值时为 null。
  DayKey? get localDay => time != null ? DayKey.fromDateTime(time!) : day;

  @override
  bool operator ==(Object other) =>
      other is CardTime &&
      other.time == time &&
      other.day == day &&
      other.pending == pending;

  @override
  int get hashCode => Object.hash(time, day, pending);

  @override
  String toString() => 'CardTime(${time ?? day}${pending ? ', 待确认' : ''})';
}

/// 一张卡片的两个时间，为 null 的表示没有。
typedef CardTimes = ({CardTime? event, CardTime? due});

/// 卡片时间存进数据库三列（值、精度、待确认）的值，见 planner_database.dart
/// 开头的说明。邮件事项的两个时间也用它。
({String? value, CardTimePrecision? precision, bool pending}) cardTimeToColumns(
  CardTime? time,
) => (
  value: time?.time?.toIso8601String() ?? time?.day?.toString(),
  precision: time?.precision,
  pending: time?.pending ?? false,
);

/// 从三列读回卡片时间；没有值也不待确认时为 null。
CardTime? cardTimeFromColumns(
  String? value,
  CardTimePrecision? precision,
  bool pending,
) => switch ((value, precision)) {
  (final value?, CardTimePrecision.dateTime) => CardTime.dateTime(
    DateTime.parse(value),
    pending: pending,
  ),
  (final value?, CardTimePrecision.date) => CardTime.date(
    DayKey.parse(value),
    pending: pending,
  ),
  _ => pending ? const CardTime.pending() : null,
};
