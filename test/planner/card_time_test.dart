import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'planner_harness.dart';

void main() {
  late PlannerHarness harness;

  setUp(() => harness = PlannerHarness());
  tearDown(() => harness.dispose());

  /// 在今天的画布上新建一张卡片。
  Future<TaskCard> newCard({String title = '交作业'}) =>
      harness.service.createCard(harness.today, x: 0, y: 0, title: title);

  /// 从 [day] 的画布上读回这张卡片。
  Future<TaskCard> cardOn(DayKey day, String id) async {
    final board = await harness.service.watchDay(day).first;
    return board.cards.singleWhere((c) => c.id == id);
  }

  /// 只改卡片的两个时间，标题和备注不变。
  Future<void> setTimes(TaskCard card, {CardTime? event, CardTime? due}) =>
      harness.service.updateCardContent(
        card.id,
        title: card.title,
        note: card.note,
        times: (event: event, due: due),
      );

  group('卡片的活动时间和截止时间', () {
    test('新建的卡片没有活动时间和截止时间', () async {
      final card = await newCard();

      final saved = await cardOn(harness.today, card.id);
      expect(saved.eventTime, isNull);
      expect(saved.dueTime, isNull);
    });

    test('三种状态都能保存，重新打开数据库后保持不变', () async {
      final withTime = await newCard(title: '讲座');
      final dateOnly = await newCard(title: '交表');
      final pending = await newCard(title: '面试');
      final lecture = CardTime.dateTime(DateTime.utc(2026, 10, 31, 18));
      final dueDay = CardTime.date(DayKey(2026, 10, 30));

      await setTimes(withTime, event: lecture);
      await setTimes(dateOnly, due: dueDay);
      await setTimes(pending, event: lecture, due: const CardTime.pending());
      await harness.reopen();

      final a = await cardOn(harness.today, withTime.id);
      expect(a.eventTime, CardTime.dateTime(DateTime.utc(2026, 10, 31, 18)));
      expect(a.dueTime, isNull);
      final b = await cardOn(harness.today, dateOnly.id);
      expect(b.eventTime, isNull);
      expect(b.dueTime, CardTime.date(DayKey(2026, 10, 30)));
      final c = await cardOn(harness.today, pending.id);
      expect(c.eventTime, lecture);
      expect(c.dueTime, const CardTime.pending());
    });

    test('待确认的时间可以带一个暂定的值', () async {
      final card = await newCard();
      final tentative = CardTime.date(DayKey(2026, 11, 2), pending: true);

      await setTimes(card, due: tentative);

      final saved = await cardOn(harness.today, card.id);
      expect(saved.dueTime, CardTime.date(DayKey(2026, 11, 2), pending: true));
      expect(saved.dueTime, isNot(CardTime.date(DayKey(2026, 11, 2))));
    });

    test('时刻按 UTC 保存，读回来的是同一个时间点', () async {
      final card = await newCard();
      // 本地时间传进去，存的是同一个时间点。
      final local = DateTime(2026, 10, 30, 23, 59);

      await setTimes(card, due: CardTime.dateTime(local));

      final saved = (await cardOn(harness.today, card.id)).dueTime!;
      expect(saved.time!.isUtc, isTrue);
      expect(saved.time, local.toUtc());
    });

    test('可以修改和清空', () async {
      final card = await newCard();
      await setTimes(
        card,
        event: CardTime.date(DayKey(2026, 10, 31)),
        due: CardTime.dateTime(DateTime.utc(2026, 10, 30, 12)),
      );

      await setTimes(
        card,
        event: null,
        due: CardTime.date(DayKey(2026, 11, 1)),
      );

      final saved = await cardOn(harness.today, card.id);
      expect(saved.eventTime, isNull);
      expect(saved.dueTime, CardTime.date(DayKey(2026, 11, 1)));
    });

    test('只改标题和备注时，两个时间保持不变', () async {
      final card = await newCard();
      final due = CardTime.date(DayKey(2026, 10, 30));
      await setTimes(card, due: due);

      await harness.service.updateCardContent(
        card.id,
        title: '交作业（第二版）',
        note: '记得附上代码',
      );

      final saved = await cardOn(harness.today, card.id);
      expect(saved.title, '交作业（第二版）');
      expect(saved.dueTime, due);
    });

    test('顺延时两个时间跟着卡片走，截止时间不影响顺延到哪天', () async {
      final card = await newCard();
      // 截止时间在后天，活动时间在昨天：都不影响顺延，卡片照常搬到今天。
      final event = CardTime.date(harness.today.addDays(-1));
      final due = CardTime.dateTime(DateTime.utc(2026, 10, 22, 15));
      await setTimes(card, event: event, due: due);
      await harness.service.runDailyMaintenance();

      harness.now = harness.now.add(const Duration(days: 1));
      await harness.service.runDailyMaintenance();

      final moved = await cardOn(harness.today, card.id);
      expect(moved.carriedOver, isTrue);
      expect(moved.eventTime, event);
      expect(moved.dueTime, due);
    });
  });
}
