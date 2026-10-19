import 'package:clock/clock.dart';

/// 按本地时区计算的某一天，存储格式为 `YYYY-MM-DD`。
class DayKey implements Comparable<DayKey> {
  const DayKey(this.year, this.month, this.day);

  /// 取 [time] 在本地时区的年月日；UTC 时间会先换算成本地时间。
  factory DayKey.fromDateTime(DateTime time) {
    final local = time.toLocal();
    return DayKey(local.year, local.month, local.day);
  }

  /// 今天的 dayKey，由注入的 [clock] 决定，不直接读系统时间。
  factory DayKey.today() => DayKey.fromDateTime(clock.now());

  factory DayKey.parse(String text) {
    final parts = text.split('-');
    return DayKey(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final int year;
  final int month;
  final int day;

  /// 向后（[days] 为负时向前）移动若干天。用 UTC 计算以避开夏令时。
  DayKey addDays(int days) {
    final shifted = DateTime.utc(year, month, day + days);
    return DayKey(shifted.year, shifted.month, shifted.day);
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
