/// 日期格式化：所有日期显示都只走这里。
///
/// 固定使用 `en_US`，不跟随系统语言。
library;

import 'package:intl/intl.dart';

import '../planner/day_key.dart';

const _locale = 'en_US';

/// 完整格式，例如 `Tue, Oct 20, 2026`。
String formatFullDate(DayKey day) =>
    DateFormat('EEE, MMM d, yyyy', _locale).format(_toDateTime(day));

/// 短格式，例如 `Oct 20`；不是今年时加年份，例如 `Jan 3, 2027`。
/// 「今年」由注入的时钟决定。
String formatShortDate(DayKey day) {
  final pattern = day.year == DayKey.today().year ? 'MMM d' : 'MMM d, yyyy';
  return DateFormat(pattern, _locale).format(_toDateTime(day));
}

/// 日期抽屉每一行的日期和星期，例如 `Oct 20` / `Tue`。一律不显示年份。
({String date, String weekday}) formatDateDrawerLabel(DayKey day) {
  final time = _toDateTime(day);
  return (
    date: DateFormat('MMM d', _locale).format(time),
    weekday: DateFormat('EEE', _locale).format(time),
  );
}

/// 完成时间，24 小时制 `HH:mm`，按本地时区显示，例如 `14:30`。
String formatTimeOfDay(DateTime time) =>
    DateFormat('HH:mm', _locale).format(time.toLocal());

DateTime _toDateTime(DayKey day) => DateTime(day.year, day.month, day.day);
