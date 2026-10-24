import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:my_personal_use_app/formatting/date_format.dart';
import 'package:my_personal_use_app/planner/day_key.dart';

void main() {
  group('完整格式', () {
    test('输出星期、月份缩写、日期和年份', () {
      expect(formatFullDate(DayKey.parse('2026-10-20')), 'Tue, Oct 20, 2026');
    });

    test('日期数字不补零', () {
      expect(formatFullDate(DayKey.parse('2026-11-01')), 'Sun, Nov 1, 2026');
    });
  });

  group('短格式', () {
    final inOct2026 = Clock.fixed(DateTime(2026, 10, 20, 9));

    test('今年的日期只显示月份缩写和日期', () {
      final text = withClock(
        inOct2026,
        () => formatShortDate(DayKey.parse('2026-10-20')),
      );

      expect(text, 'Oct 20');
    });

    test('日期数字不补零', () {
      final text = withClock(
        inOct2026,
        () => formatShortDate(DayKey.parse('2026-01-03')),
      );

      expect(text, 'Jan 3');
    });

    test('不是今年的日期后面加年份', () {
      final text = withClock(
        inOct2026,
        () => formatShortDate(DayKey.parse('2027-01-03')),
      );

      expect(text, 'Jan 3, 2027');
    });

    test('今年由注入的时钟决定：跨年后去年的日期加年份', () {
      final text = withClock(
        Clock.fixed(DateTime(2027, 1, 1, 0, 0)),
        () => formatShortDate(DayKey.parse('2026-12-31')),
      );

      expect(text, 'Dec 31, 2026');
    });
  });

  group('日期抽屉每一行的日期和星期', () {
    test('日期是月份缩写加日期，星期是星期缩写', () {
      final label = formatDateDrawerLabel(DayKey.parse('2026-10-20'));

      expect(label.date, 'Oct 20');
      expect(label.weekday, 'Tue');
    });

    test('不是今年的日期也不加年份', () {
      final label = withClock(
        Clock.fixed(DateTime(2026, 10, 20, 9)),
        () => formatDateDrawerLabel(DayKey.parse('2027-01-03')),
      );

      expect(label.date, 'Jan 3');
      expect(label.weekday, 'Sun');
    });
  });

  group('完成时间', () {
    test('下午用 24 小时制显示', () {
      expect(formatTimeOfDay(DateTime(2026, 10, 20, 14, 30)), '14:30');
    });

    test('小时和分钟不足两位时补零', () {
      expect(formatTimeOfDay(DateTime(2026, 10, 20, 9, 5)), '09:05');
      expect(formatTimeOfDay(DateTime(2026, 10, 20, 0, 0)), '00:00');
    });

    test('UTC 时间按本地时区显示', () {
      final completedAt = DateTime(2026, 10, 20, 23, 45).toUtc();

      expect(formatTimeOfDay(completedAt), '23:45');
    });
  });

  group('系统语言为中文时', () {
    setUp(() async {
      await initializeDateFormatting('zh_CN');
      Intl.defaultLocale = 'zh_CN';
    });

    tearDown(() => Intl.defaultLocale = null);

    test('完整格式仍输出英文缩写', () {
      expect(formatFullDate(DayKey.parse('2026-11-01')), 'Sun, Nov 1, 2026');
    });

    test('短格式仍输出英文缩写', () {
      final text = withClock(
        Clock.fixed(DateTime(2026, 10, 20, 9)),
        () => formatShortDate(DayKey.parse('2027-01-03')),
      );

      expect(text, 'Jan 3, 2027');
    });

    test('日期抽屉每一行仍输出英文缩写', () {
      final label = formatDateDrawerLabel(DayKey.parse('2026-11-01'));

      expect(label.date, 'Nov 1');
      expect(label.weekday, 'Sun');
    });
  });
}
