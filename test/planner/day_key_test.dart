import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/planner/day_key.dart';

void main() {
  group('DayKey 文本转换', () {
    test('从 YYYY-MM-DD 文本解析后再输出得到同样的文本', () {
      expect(DayKey.parse('2026-10-20').toString(), '2026-10-20');
    });
  });

  group('DayKey 拒绝无效文本', () {
    test('不存在的日期抛出 FormatException', () {
      expect(() => DayKey.parse('2026-02-30'), throwsFormatException);
    });

    test('不存在的月份抛出 FormatException', () {
      expect(() => DayKey.parse('2026-13-01'), throwsFormatException);
      expect(() => DayKey.parse('2026-00-10'), throwsFormatException);
    });

    test('平年的 2 月 29 日抛出 FormatException', () {
      expect(() => DayKey.parse('2026-02-29'), throwsFormatException);
    });

    test('月份或日期没有补零时抛出 FormatException', () {
      expect(() => DayKey.parse('2026-1-05'), throwsFormatException);
      expect(() => DayKey.parse('2026-01-5'), throwsFormatException);
    });

    test('不是 YYYY-MM-DD 结构的文本抛出 FormatException', () {
      for (final text in [
        '',
        '20261020',
        '2026/10/20',
        '26-10-20',
        ' 2026-10-20',
        '2026-10-20T00:00',
        '2026-10-20-01',
        '+2026-10-20',
      ]) {
        expect(() => DayKey.parse(text), throwsFormatException, reason: text);
      }
    });

    test('闰年的 2 月 29 日可以正常解析', () {
      expect(DayKey.parse('2028-02-29').toString(), '2028-02-29');
    });
  });

  group('DayKey 从时间生成', () {
    test('本地时间的年月日就是 dayKey', () {
      expect(
        DayKey.fromDateTime(DateTime(2026, 10, 20, 23, 59)),
        DayKey.parse('2026-10-20'),
      );
    });

    test('同一时刻用 UTC 表示时仍按本地时区计算日期', () {
      final lateNight = DateTime(2026, 10, 20, 23, 59);
      final earlyMorning = DateTime(2026, 10, 20, 0, 1);

      expect(
        DayKey.fromDateTime(lateNight.toUtc()),
        DayKey.parse('2026-10-20'),
      );
      expect(
        DayKey.fromDateTime(earlyMorning.toUtc()),
        DayKey.parse('2026-10-20'),
      );
    });
  });

  group('DayKey 今天', () {
    test('今天由注入的时钟决定', () {
      final today = withClock(
        Clock.fixed(DateTime(2027, 1, 3, 8)),
        DayKey.today,
      );

      expect(today, DayKey.parse('2027-01-03'));
    });
  });

  group('DayKey 加减天数', () {
    test('月末加一天进入下个月 1 号', () {
      expect(DayKey.parse('2026-10-31').addDays(1), DayKey.parse('2026-11-01'));
    });

    test('年末加一天进入下一年 1 月 1 日', () {
      expect(DayKey.parse('2026-12-31').addDays(1), DayKey.parse('2027-01-01'));
    });

    test('年初减一天回到上一年 12 月 31 日', () {
      expect(
        DayKey.parse('2027-01-01').addDays(-1),
        DayKey.parse('2026-12-31'),
      );
    });

    test('闰年 2 月 28 日加一天是 2 月 29 日', () {
      expect(DayKey.parse('2028-02-28').addDays(1), DayKey.parse('2028-02-29'));
    });

    test('跨过夏令时切换的日子仍然只前进对应的天数', () {
      expect(
        DayKey.parse('2026-03-01').addDays(30),
        DayKey.parse('2026-03-31'),
      );
      expect(
        DayKey.parse('2026-10-20').addDays(30),
        DayKey.parse('2026-11-19'),
      );
    });
  });

  group('DayKey 比较', () {
    test('较早的日期小于较晚的日期', () {
      final oct31 = DayKey.parse('2026-10-31');
      final nov1 = DayKey.parse('2026-11-01');

      expect(oct31 < nov1, isTrue);
      expect(nov1 > oct31, isTrue);
      expect(nov1 <= oct31, isFalse);
    });

    test('同一天既大于等于又小于等于自己，但不严格大于或小于', () {
      final day = DayKey.parse('2026-10-20');
      final sameDay = DayKey.parse('2026-10-20');

      expect(day <= sameDay && day >= sameDay, isTrue);
      expect(day < sameDay || day > sameDay, isFalse);
    });

    test('排序后按时间先后排列，跨年也正确', () {
      final keys = [
        DayKey.parse('2027-01-03'),
        DayKey.parse('2026-12-31'),
        DayKey.parse('2026-02-15'),
      ]..sort();

      expect(keys.map((k) => k.toString()), [
        '2026-02-15',
        '2026-12-31',
        '2027-01-03',
      ]);
    });
  });
}
