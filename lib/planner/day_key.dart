import 'package:clock/clock.dart';

/// 按本地时区计算的某一天，存储格式为 `YYYY-MM-DD`。
class DayKey implements Comparable<DayKey> {
  /// 创建某一天；日期不存在时抛出 [ArgumentError]。
  factory DayKey(int year, int month, int day) {
    if (!_exists(year, month, day)) {
      throw ArgumentError('不存在的日期：$year-$month-$day');
    }
    return DayKey._(year, month, day);
  }

  const DayKey._(this.year, this.month, this.day);

  /// 取 [time] 在本地时区的年月日；UTC 时间会先换算成本地时间。
  factory DayKey.fromDateTime(DateTime time) {
    final local = time.toLocal();
    return DayKey._(local.year, local.month, local.day);
  }

  /// 今天的 dayKey，由注入的 [clock] 决定，不直接读系统时间。
  factory DayKey.today() => DayKey.fromDateTime(clock.now());

  /// 解析 `YYYY-MM-DD` 文本；格式不对或日期不存在时抛出 [FormatException]。
  factory DayKey.parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('应为 YYYY-MM-DD 格式', text);
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (!_exists(year, month, day)) {
      throw FormatException('不存在的日期', text);
    }
    return DayKey._(year, month, day);
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// 年月日组合起来是否是日历上真实存在的一天。
  static bool _exists(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    return normalized.month == month && normalized.day == day;
  }

  final int year;
  final int month;
  final int day;

  /// 向后（[days] 为负时向前）移动若干天。用 UTC 计算以避开夏令时。
  DayKey addDays(int days) {
    final shifted = DateTime.utc(year, month, day + days);
    return DayKey._(shifted.year, shifted.month, shifted.day);
  }

  @override
  int compareTo(DayKey other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  bool operator <(DayKey other) => compareTo(other) < 0;
  bool operator <=(DayKey other) => compareTo(other) <= 0;
  bool operator >(DayKey other) => compareTo(other) > 0;
  bool operator >=(DayKey other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is DayKey &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
