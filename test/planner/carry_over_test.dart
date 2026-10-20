import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/planner/day_board.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_exceptions.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'planner_harness.dart';

void main() {
  late PlannerHarness harness;

  setUp(() => harness = PlannerHarness());
  tearDown(() => harness.dispose());

  /// 在今天的画布上新建一张卡片。
  Future<TaskCard> newCard(String title, {double x = 0, double y = 0}) =>
      harness.service.createCard(harness.today, x: x, y: y, title: title);

  /// 把假时钟往后拨 [days] 天。
  void advanceDays(int days) =>
      harness.now = harness.now.add(Duration(days: days));

  Future<DayBoard> boardOf(DayKey dayKey) =>
      harness.service.watchDay(dayKey).first;

  group('单天顺延', () {
    test('昨天没完成的卡片搬到今天画布左上角，带顺延标记', () async {
      final card = await newCard('A', x: 300, y: 200);
      final yesterday = harness.today;
      advanceDays(1);

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.carriedCount, 1);
      expect(summary.cleanedCount, 0);
      final moved = (await boardOf(harness.today)).cards.single;
      expect(moved.id, card.id);
      expect(moved.dayKey, harness.today);
      expect((moved.x, moved.y), (24.0, 24.0));
      expect(moved.carriedOver, isTrue);
      expect(moved.originalDayKey, yesterday);
      expect((await boardOf(yesterday)).cards, isEmpty);
    });

    test('同一天的多张卡片保持相对位置和大小，组内连线跟着显示', () async {
      final a = await newCard('A', x: 300, y: 200);
      final b = await newCard('B', x: 500, y: 150);
      await harness.service.resizeCard(b.id, width: 240, height: 120);
      final link = await harness.service.toggleLink(a.id, b.id);
      advanceDays(1);

      await harness.service.runDailyMaintenance();

      final board = await boardOf(harness.today);
      final byId = {for (final c in board.cards) c.id: c};
      // 外接矩形左上角是 (300, 150)，对齐到 (24, 24)。
      expect((byId[a.id]!.x, byId[a.id]!.y), (24.0, 74.0));
      expect((byId[b.id]!.x, byId[b.id]!.y), (224.0, 24.0));
      expect((byId[b.id]!.width, byId[b.id]!.height), (240.0, 120.0));
      expect(board.links.single.id, link.linkId);
    });
  });

  group('历史记录', () {
    test('原日期在原位置留下顺延前的快照，今天的画布上没有记录', () async {
      final card = await newCard('写周报', x: 300, y: 200);
      await harness.service.resizeCard(card.id, width: 220, height: 100);
      await harness.service.setCardColor(card.id, 0xFFB3E5FC);
      final yesterday = harness.today;
      advanceDays(1);
      harness.now = harness.now.add(const Duration(minutes: 7));

      await harness.service.runDailyMaintenance();

      final record = (await boardOf(yesterday)).carryOverRecords.single;
      expect(record.cardId, card.id);
      expect(record.fromDayKey, yesterday);
      expect(record.toDayKey, harness.today);
      expect(
        (record.x, record.y, record.width, record.height),
        (300.0, 200.0, 220.0, 100.0),
      );
      expect(record.titleSnapshot, '写周报');
      expect(record.colorArgb, 0xFFB3E5FC);
      expect(record.carriedAt, harness.now.toUtc());
      expect((await boardOf(harness.today)).carryOverRecords, isEmpty);
    });

    test('历史记录不计入数量，原日期的未完成数变成 0', () async {
      await newCard('A');
      await newCard('B');
      final yesterday = harness.today;
      advanceDays(1);

      await harness.service.runDailyMaintenance();

      final counts = await harness.service
          .watchDayCounts(yesterday, harness.today)
          .first;
      expect(counts[yesterday]!.activeCount, 0);
      expect(counts[yesterday]!.completedCount, 0);
      expect(counts[harness.today]!.activeCount, 2);
      final board = await boardOf(yesterday);
      expect(board.carryOverRecords, hasLength(2));
      expect(board.cards, isEmpty);
      expect(board.completedCount, 0);
    });

    test('只有历史记录变化时 watchDay 也会推送', () async {
      final card = await newCard('A');
      // 夹具把记录留在昨天。
      final records = harness.service
          .watchDay(harness.today.addDays(-1))
          .map((b) => b.carryOverRecords.map((r) => r.cardId).toList());
      final expectation = expectLater(
        records,
        emitsInOrder([
          isEmpty,
          emitsThrough([card.id]),
        ]),
      );
      await pumpEventQueue();

      await harness.addCarryOverRecord(card.id);
      await expectation;
    });
  });

  group('今天已有的卡片右移', () {
    test('今天的卡片离左边足够远时右移顺延区宽度 + 48，只改 x', () async {
      // 顺延区宽度 W = 180（一张默认宽度的卡片）。
      await newCard('昨天', x: 300, y: 300);
      advanceDays(1);
      final a = await newCard('今天 A', x: 500, y: 10);
      final b = await newCard('今天 B', x: 700, y: 400);

      await harness.service.runDailyMaintenance();

      final byId = {
        for (final c in (await boardOf(harness.today)).cards) c.id: c,
      };
      // dx = max(180 + 48, 24 + 180 + 48 - 500) = 228
      expect((byId[a.id]!.x, byId[a.id]!.y), (728.0, 10.0));
      expect((byId[b.id]!.x, byId[b.id]!.y), (928.0, 400.0));
    });

    test('今天的卡片靠近左边时多移一些，和顺延区之间仍隔 48', () async {
      final wide = await newCard('昨天', x: 300, y: 300);
      await harness.service.resizeCard(wide.id, width: 260, height: 88);
      advanceDays(1);
      final a = await newCard('今天 A', x: -40, y: 30);
      final b = await newCard('今天 B', x: 200, y: 30);

      await harness.service.runDailyMaintenance();

      final board = await boardOf(harness.today);
      final byId = {for (final c in board.cards) c.id: c};
      // dx = max(260 + 48, 24 + 260 + 48 - (-40)) = 372
      expect(byId[a.id]!.x, 332.0);
      expect(byId[b.id]!.x, 572.0);
      expect(_overlappingPairs(board.cards), isEmpty);
    });

    test('今天已完成和回收站里的卡片也一起右移，取消完成或恢复后不和顺延卡片重叠', () async {
      await newCard('昨天', x: 0, y: 0);
      advanceDays(1);
      final done = await newCard('今天已完成', x: 0, y: 0);
      final trashed = await newCard('今天回收站', x: 10, y: 10);
      await harness.service.completeCard(done.id);
      await harness.service.deleteCard(trashed.id);

      await harness.service.runDailyMaintenance();

      // minX = 0，dx = max(180 + 48, 24 + 180 + 48 - 0) = 252
      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.x, 252.0);
      final trash = await harness.service.watchTrash().first;
      expect(trash.single.card.x, 262.0);
      await harness.service.uncompleteCard(done.id);
      await harness.service.restoreCard(trashed.id);
      final board = await boardOf(harness.today);
      expect(board.cards, hasLength(3));
      // 今天这两张原来就互相重叠，保持不变；它们都不和顺延卡片重叠。
      final carried = board.cards.where((c) => c.carriedOver).single;
      for (final card in board.cards.where((c) => c.id != carried.id)) {
        expect(_overlaps(carried, card), isFalse, reason: card.title);
      }
    });

    test('没有要顺延的卡片时今天的卡片不动', () async {
      final card = await newCard('今天', x: 5, y: 6);
      advanceDays(1);
      final today = await newCard('新的一天', x: 0, y: 0);
      await harness.service.completeCard(card.id);

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.carriedCount, 0);
      final board = await boardOf(harness.today);
      expect((board.cards.single.id, board.cards.single.x), (today.id, 0.0));
    });
  });

  group('层级', () {
    test('顺延卡片按原日期、原 zIndex、卡片 ID 排序，接在今天最大 zIndex 后面', () async {
      // 10-20：Y（z2）、X（z3，拖动过）。
      final x = await newCard('X');
      final y = await newCard('Y');
      await harness.service.moveCard(x.id, x: 0, y: 0);
      advanceDays(1);
      // 10-21：P（z1）、T（z2），再从 10-22 放进来一张 z1 的 U，和 P 同层。
      final p = await newCard('P');
      final t = await newCard('T');
      advanceDays(1);
      final u = await newCard('U');
      await harness.markMovedToDay(u.id, harness.today.addDays(-1));
      advanceDays(1);
      // 今天 10-23：K（z1）、已完成的 L（z2）、回收站里的 M（z3）。
      final k = await newCard('K');
      final l = await newCard('L');
      final m = await newCard('M');
      await harness.service.completeCard(l.id);
      await harness.service.deleteCard(m.id);

      await harness.service.runDailyMaintenance();

      final board = await boardOf(harness.today);
      final zOf = {for (final c in board.cards) c.id: c.zIndex};
      final (pFirst, uFirst) = p.id.compareTo(u.id) < 0 ? (6, 7) : (7, 6);
      expect(zOf, {
        k.id: 1,
        y.id: 4,
        x.id: 5,
        p.id: pFirst,
        u.id: uFirst,
        t.id: 8,
      });
      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.zIndex, 2);
      final trash = await harness.service.watchTrash().first;
      expect(trash.single.card.zIndex, 3);
    });
  });

  group('幂等和时钟回拨', () {
    // 正常使用时，维护过的那天以前不会再出现未完成的卡片。下面通过拨回时钟
    // 在过去的日期上建卡片，用来区分"维护过所以不顺延"和"没有卡片可顺延"。

    /// 把时钟拨回 [days] 天，在那天建一张卡片，再拨回原来的时间。
    Future<TaskCard> cardMadeDaysAgo(int days, String title) async {
      final now = harness.now;
      advanceDays(-days);
      final card = await newCard(title);
      harness.now = now;
      return card;
    }

    test('同一天执行两次（中间重启 App），第二次不顺延也不产生新记录', () async {
      await newCard('A', x: 300, y: 200);
      final yesterday = harness.today;
      advanceDays(1);
      await harness.service.runDailyMaintenance();
      final lateCard = await cardMadeDaysAgo(1, '晚到');
      await harness.reopen();
      harness.now = harness.now.add(const Duration(hours: 5));

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.carriedCount, 0);
      final today = await boardOf(harness.today);
      expect((today.cards.single.x, today.cards.single.y), (24.0, 24.0));
      final past = await boardOf(yesterday);
      expect(past.carryOverRecords, hasLength(1));
      expect(past.cards.single.id, lateCard.id);
    });

    test('新的一天没有卡片可顺延也记下维护日期，同一天再执行不顺延', () async {
      advanceDays(1);
      final first = await harness.service.runDailyMaintenance();
      expect(first.carriedCount, 0);
      final lateCard = await cardMadeDaysAgo(1, '晚到');

      final second = await harness.service.runDailyMaintenance();

      expect(second.carriedCount, 0);
      expect(
        (await harness.service.findCard(lateCard.id)).dayKey,
        lateCard.dayKey,
      );
    });

    test('App 开着跨过午夜，再次维护时顺延', () async {
      harness.now = DateTime(2026, 10, 20, 23, 59);
      final card = await newCard('A');
      await harness.service.runDailyMaintenance();
      harness.now = DateTime(2026, 10, 21, 0, 1);

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.carriedCount, 1);
      expect((await harness.service.findCard(card.id)).dayKey, harness.today);
    });

    test('时钟回拨后不顺延，也不把维护日期改小', () async {
      advanceDays(2);
      await harness.service.runDailyMaintenance(); // 维护日期 10-22
      final early = await cardMadeDaysAgo(2, '10-20');
      advanceDays(-1); // 时钟回到 10-21

      final rolledBack = await harness.service.runDailyMaintenance();

      expect(rolledBack.carriedCount, 0);
      expect((await harness.service.findCard(early.id)).dayKey, early.dayKey);
      // 回到 10-22：维护日期还是 10-22，所以仍然不顺延。
      advanceDays(1);
      expect((await harness.service.runDailyMaintenance()).carriedCount, 0);
      // 到了 10-23 才顺延，只在卡片实际离开的 10-20 留一条记录。
      advanceDays(1);
      expect((await harness.service.runDailyMaintenance()).carriedCount, 1);
      expect((await harness.service.findCard(early.id)).dayKey, harness.today);
      for (var day = early.dayKey; day < harness.today; day = day.addDays(1)) {
        final records = (await boardOf(day)).carryOverRecords;
        expect(records, hasLength(day == early.dayKey ? 1 : 0), reason: '$day');
      }
    });
  });

  group('写入失败', () {
    // 两张卡片顺延、今天有一张卡片时，依次写入：右移今天的卡片、每张卡片的
    // 历史记录和新位置、维护日期，共 6 次写入。在每一步失败都应该整体回滚。
    // 改动 PlannerService._carryOver 的写入次数或顺序时要同步修改这里。
    for (final step in [1, 2, 3, 4, 5, 6]) {
      test('第 $step 步写入失败时整体回滚，之后可以重新维护', () async {
        final a = await newCard('A', x: 300, y: 200);
        final b = await newCard('B', x: 500, y: 200);
        final yesterday = harness.today;
        advanceDays(1);
        final today = await newCard('今天', x: 100, y: 100);
        harness.failWritesAfter(step - 1);

        await expectLater(
          harness.service.runDailyMaintenance(),
          throwsA(isA<StorageFailure>()),
        );

        harness.failWrites = false;
        final past = await boardOf(yesterday);
        expect(
          past.cards.map((c) => (c.id, c.x)),
          unorderedEquals([(a.id, 300.0), (b.id, 500.0)]),
        );
        expect(past.cards.any((c) => c.carriedOver), isFalse);
        expect(past.carryOverRecords, isEmpty);
        final board = await boardOf(harness.today);
        expect(board.cards.map((c) => (c.id, c.x)), [(today.id, 100.0)]);
        // 维护日期也没有写入，所以还能重新维护。
        final retry = await harness.service.runDailyMaintenance();
        expect(retry.carriedCount, 2);
        expect((await boardOf(yesterday)).carryOverRecords, hasLength(2));
      });
    }

    test('同样的场景允许 6 次写入时维护成功，上面的步骤覆盖了每一次写入', () async {
      await newCard('A', x: 300, y: 200);
      await newCard('B', x: 500, y: 200);
      advanceDays(1);
      await newCard('今天', x: 100, y: 100);
      harness.failWritesAfter(6);

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.carriedCount, 2);
    });
  });

  group('顺延范围', () {
    test('未来日期、过去已完成和回收站里的卡片都不顺延', () async {
      final future = await harness.service.createCard(
        harness.today.addDays(5),
        x: 0,
        y: 0,
        title: '未来',
      );
      final done = await newCard('已完成');
      final trashed = await newCard('回收站');
      await harness.service.completeCard(done.id);
      await harness.service.deleteCard(trashed.id);
      final yesterday = harness.today;
      advanceDays(1);

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.carriedCount, 0);
      expect((await harness.service.findCard(future.id)).dayKey, future.dayKey);
      expect((await harness.service.findCard(done.id)).dayKey, yesterday);
      expect((await harness.service.findCard(trashed.id)).dayKey, yesterday);
      expect((await boardOf(yesterday)).carryOverRecords, isEmpty);
    });

    test('顺延不复制卡片：所有日期上的有效卡片按 ID 不重复，总数不变', () async {
      final ids = {
        for (final title in ['A', 'B', 'C']) (await newCard(title)).id,
      };
      final start = harness.today;
      advanceDays(1);
      ids.add((await newCard('D')).id);
      advanceDays(2);

      await harness.service.runDailyMaintenance();

      final seen = <String>[];
      for (var day = start; day <= harness.today; day = day.addDays(1)) {
        seen.addAll((await boardOf(day)).cards.map((c) => c.id));
      }
      expect(seen, unorderedEquals(ids));
    });

    test('卡片在不同日期分别顺延时，每次在出发那天各留一条记录', () async {
      final card = await newCard('拖延');
      final first = harness.today;
      advanceDays(1);
      await harness.service.runDailyMaintenance();
      advanceDays(1);

      await harness.service.runDailyMaintenance();

      final firstRecord = (await boardOf(first)).carryOverRecords.single;
      expect(
        (firstRecord.fromDayKey, firstRecord.toDayKey),
        (first, first.addDays(1)),
      );
      final secondRecord = (await boardOf(first.addDays(1)))
          .carryOverRecords
          .single;
      expect(
        (secondRecord.fromDayKey, secondRecord.toDayKey),
        (first.addDays(1), harness.today),
      );
      expect(secondRecord.cardId, card.id);
      final moved = (await boardOf(harness.today)).cards.single;
      expect((moved.carriedOver, moved.originalDayKey), (true, first));
    });

    test('顺延过的卡片完成、取消完成后仍然带顺延标记', () async {
      final card = await newCard('A');
      advanceDays(1);
      await harness.service.runDailyMaintenance();

      await harness.service.completeCard(card.id);
      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.carriedOver, isTrue);
      await harness.service.uncompleteCard(card.id);
      expect((await boardOf(harness.today)).cards.single.carriedOver, isTrue);
    });

    test('永久删除顺延过的卡片时，原日期上它的历史记录一起删掉', () async {
      final gone = await newCard('删掉');
      final kept = await newCard('留下');
      final yesterday = harness.today;
      advanceDays(1);
      await harness.service.runDailyMaintenance();
      await harness.service.deleteCard(gone.id);

      await harness.service.deleteForever(gone.id);

      final records = (await boardOf(yesterday)).carryOverRecords;
      expect(records.map((r) => r.cardId), [kept.id]);
    });

    test('和留在原日期的卡片之间的连线不再显示', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      await harness.service.toggleLink(a.id, b.id);
      await harness.service.completeCard(b.id);
      advanceDays(1);

      await harness.service.runDailyMaintenance();

      final board = await boardOf(harness.today);
      expect(board.cards.single.id, a.id);
      expect(board.links, isEmpty);
    });
  });

  group('多天没打开', () {
    test('几天里没完成的卡片都到今天，按日期从上到下堆叠，组间距 48', () async {
      // 10-20：两张卡片，组高 40 + 88 = 128。
      final first1 = await newCard('20 日 1', x: 100, y: 0);
      final first2 = await newCard('20 日 2', x: 0, y: 40);
      advanceDays(1);
      // 10-21：一张宽 300 的卡片，组高 88。
      final second = await newCard('21 日', x: 500, y: 500);
      await harness.service.resizeCard(second.id, width: 300, height: 88);
      advanceDays(1);
      // 10-22：一张卡片。
      final third = await newCard('22 日', x: -50, y: 900);
      final start = first1.dayKey;
      advanceDays(3);
      // 今天 10-25 已有一张卡片。
      final today = await newCard('今天', x: 0, y: 0);

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.carriedCount, 4);
      final board = await boardOf(harness.today);
      final byId = {for (final c in board.cards) c.id: c};
      expect((byId[first1.id]!.x, byId[first1.id]!.y), (124.0, 24.0));
      expect((byId[first2.id]!.x, byId[first2.id]!.y), (24.0, 64.0));
      // 24 + 128 + 48 = 200
      expect((byId[second.id]!.x, byId[second.id]!.y), (24.0, 200.0));
      // 200 + 88 + 48 = 336
      expect((byId[third.id]!.x, byId[third.id]!.y), (24.0, 336.0));
      // W = 300，dx = max(300 + 48, 24 + 300 + 48 - 0) = 372
      expect(byId[today.id]!.x, 372.0);
      // 只有 20 日那两张原来就重叠的卡片还重叠。
      final sorted = [first1.id, first2.id]..sort();
      expect(_overlappingPairs(board.cards), [(sorted[0], sorted[1])]);

      // 每张卡片只在它实际离开的那天留一条记录，中间没打开的日子没有记录。
      final recordedCards = {
        for (var day = start; day <= harness.today; day = day.addDays(1))
          day: (await boardOf(day)).carryOverRecords.map((r) => r.cardId),
      };
      expect(recordedCards, {
        start: unorderedEquals([first1.id, first2.id]),
        start.addDays(1): [second.id],
        start.addDays(2): [third.id],
        start.addDays(3): isEmpty,
        start.addDays(4): isEmpty,
        harness.today: isEmpty,
      });
    });
  });
}

/// 互相重叠的卡片对（id 小的在前）。只是边挨着不算重叠。
List<(String, String)> _overlappingPairs(List<TaskCard> cards) => [
  for (var i = 0; i < cards.length; i++)
    for (var j = i + 1; j < cards.length; j++)
      if (_overlaps(cards[i], cards[j]))
        cards[i].id.compareTo(cards[j].id) < 0
            ? (cards[i].id, cards[j].id)
            : (cards[j].id, cards[i].id),
];

bool _overlaps(TaskCard a, TaskCard b) =>
    a.x < b.x + b.width &&
    b.x < a.x + a.width &&
    a.y < b.y + b.height &&
    b.y < a.y + a.height;
