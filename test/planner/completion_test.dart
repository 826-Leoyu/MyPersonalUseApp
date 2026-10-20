import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_exceptions.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'planner_harness.dart';

void main() {
  late PlannerHarness harness;

  setUp(() => harness = PlannerHarness());
  tearDown(() => harness.dispose());

  /// 在今天的画布上新建一张卡片。
  Future<TaskCard> newCard([String title = '卡片']) =>
      harness.service.createCard(harness.today, x: 0, y: 0, title: title);

  /// 在 [day] 那一天的画布上新建一张卡片。
  Future<TaskCard> cardOn(DayKey day, String title) =>
      harness.service.createCard(day, x: 0, y: 0, title: title);

  group('完成', () {
    test('完成后卡片从画布上消失，出现在当天的已完成列表里，带完成时间', () async {
      final card = await newCard('买菜');
      harness.now = DateTime(2026, 10, 20, 14, 30);

      await harness.service.completeCard(card.id);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards, isEmpty);
      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.id, card.id);
      expect(completed.single.status, CardStatus.completed);
      expect(
        completed.single.completedAt,
        DateTime(2026, 10, 20, 14, 30).toUtc(),
      );
    });

    test('已经完成的卡片再完成被拒绝，完成时间不变', () async {
      final card = await newCard();
      await harness.service.completeCard(card.id);
      final firstCompletedAt = harness.now.toUtc();
      harness.now = harness.now.add(const Duration(hours: 1));

      await expectLater(
        harness.service.completeCard(card.id),
        throwsA(isA<InvalidState>()),
      );

      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.completedAt, firstCompletedAt);
    });

    test('在回收站里的卡片不能完成', () async {
      final card = await newCard();
      await harness.service.deleteCard(card.id);

      await expectLater(
        harness.service.completeCard(card.id),
        throwsA(isA<InvalidState>()),
      );

      await harness.service.restoreCard(card.id);
      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.status, CardStatus.active);
    });

    test('卡片不存在时报 NotFound', () async {
      await expectLater(
        harness.service.completeCard('不存在'),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('已完成列表', () {
    test('按完成时间倒序排列，不管创建顺序', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final c = await newCard('C');

      for (final (card, hour) in [(b, 10), (c, 11), (a, 14)]) {
        harness.now = DateTime(2026, 10, 20, hour);
        await harness.service.completeCard(card.id);
      }

      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.map((card) => card.title), ['A', 'C', 'B']);
    });

    test('不包含回收站里的、未完成的和别的日期的卡片', () async {
      final kept = await newCard('留下');
      final trashed = await newCard('删除');
      await newCard('没完成');
      final tomorrow = await cardOn(harness.today.addDays(1), '明天');
      for (final card in [kept, trashed, tomorrow]) {
        await harness.service.completeCard(card.id);
      }
      await harness.service.deleteCard(trashed.id);

      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.map((card) => card.title), ['留下']);
    });

    test('完成和取消完成时持续推送新的列表', () async {
      final card = await newCard();
      final ids = harness.service
          .watchCompleted(harness.today)
          .map((cards) => cards.map((c) => c.id).toList());
      final expectation = expectLater(
        ids,
        emitsInOrder([
          isEmpty,
          emitsThrough([card.id]),
          emitsThrough(isEmpty),
        ]),
      );
      await pumpEventQueue();

      await harness.service.completeCard(card.id);
      await pumpEventQueue();
      await harness.service.uncompleteCard(card.id);
      await expectation;
    });
  });

  group('画布上的已完成数', () {
    test('画布带着当天已完成的卡片数，不算回收站里的和别的日期的', () async {
      final service = harness.service;
      final cards = [
        for (final t in ['A', 'B', 'C', 'D']) await newCard(t),
      ];
      final tomorrow = await cardOn(harness.today.addDays(1), '明天');
      expect((await service.watchDay(harness.today).first).completedCount, 0);

      for (final card in [...cards.take(3), tomorrow]) {
        await service.completeCard(card.id);
      }
      await harness.service.deleteCard(cards[2].id);

      final board = await service.watchDay(harness.today).first;
      expect(board.completedCount, 2);
      expect(board.cards.map((c) => c.id), [cards[3].id]);
    });

    test('完成和取消完成时，持续推送的画布更新已完成数', () async {
      final card = await newCard();
      final counts = harness.service
          .watchDay(harness.today)
          .map((board) => board.completedCount);
      final expectation = expectLater(
        counts,
        emitsInOrder([0, emitsThrough(1), emitsThrough(0)]),
      );
      await pumpEventQueue();

      await harness.service.completeCard(card.id);
      await pumpEventQueue();
      await harness.service.uncompleteCard(card.id);
      await expectation;
    });
  });

  group('每日计数', () {
    /// 把计数结果换成 (未完成数, 已完成数)，方便比较。
    Stream<Map<DayKey, (int, int)>> watchCounts(DayKey from, DayKey to) =>
        harness.service
            .watchDayCounts(from, to)
            .map(
              (counts) => counts.map(
                (day, c) => MapEntry(day, (c.activeCount, c.completedCount)),
              ),
            );

    test('范围内每天都有未完成数和已完成数，没有卡片的日子是 0', () async {
      final today = harness.today;
      final tomorrow = today.addDays(1);
      final service = harness.service;
      await cardOn(today, '未完成 1');
      await cardOn(today, '未完成 2');
      final done = await cardOn(today, '已完成');
      final trashedActive = await cardOn(today, '删除的未完成');
      final trashedDone = await cardOn(today, '删除的已完成');
      await cardOn(tomorrow, '明天');
      await cardOn(today.addDays(3), '范围外');
      await service.completeCard(done.id);
      await service.completeCard(trashedDone.id);
      await harness.service.deleteCard(trashedActive.id);
      await harness.service.deleteCard(trashedDone.id);

      final counts = await watchCounts(today, today.addDays(2)).first;

      expect(counts, {
        today: (2, 1),
        tomorrow: (1, 0),
        today.addDays(2): (0, 0),
      });
    });

    test('开始和结束是同一天时只返回这一天', () async {
      await cardOn(harness.today, 'A');

      final counts = await watchCounts(harness.today, harness.today).first;

      expect(counts, {harness.today: (1, 0)});
    });

    test('完成和取消完成时持续推送新的计数', () async {
      final card = await cardOn(harness.today, 'A');
      final todayCounts = watchCounts(
        harness.today,
        harness.today,
      ).map((counts) => counts[harness.today]);
      final expectation = expectLater(
        todayCounts,
        emitsInOrder([(1, 0), emitsThrough((0, 1)), emitsThrough((1, 0))]),
      );
      await pumpEventQueue();

      await harness.service.completeCard(card.id);
      await pumpEventQueue();
      await harness.service.uncompleteCard(card.id);
      await expectation;
    });

    test('开始日期晚于结束日期时报 InvalidInput', () {
      expect(
        () => harness.service.watchDayCounts(
          harness.today.addDays(1),
          harness.today,
        ),
        throwsA(isA<InvalidInput>()),
      );
    });
  });

  group('取消完成（今天和未来）', () {
    test('取消完成后卡片回到画布上原来的位置和层级，离开已完成列表', () async {
      final a = await harness.service.createCard(
        harness.today,
        x: 40,
        y: 60,
        title: 'A',
      );
      final b = await newCard('B');
      await harness.service.completeCard(a.id);

      await harness.service.uncompleteCard(a.id);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((c) => c.id), [a.id, b.id]);
      final restored = board.cards.first;
      expect((restored.x, restored.y), (40, 60));
      expect(restored.status, CardStatus.active);
      expect(restored.completedAt, isNull);
      expect(
        await harness.service.watchCompleted(harness.today).first,
        isEmpty,
      );
    });

    test('完成后相关连线不再显示，取消完成后重新显示', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final c = await newCard('C');
      final ab = await harness.service.toggleLink(a.id, b.id);
      final bc = await harness.service.toggleLink(b.id, c.id);
      final ac = await harness.service.toggleLink(a.id, c.id);

      await harness.service.completeCard(b.id);
      var board = await harness.service.watchDay(harness.today).first;
      expect(board.links.map((l) => l.id), [ac.linkId]);

      await harness.service.uncompleteCard(b.id);
      board = await harness.service.watchDay(harness.today).first;
      expect(
        board.links.map((l) => l.id),
        unorderedEquals([ab.linkId, bc.linkId, ac.linkId]),
      );
    });

    test('未来日期的卡片完成后再取消完成，回到那天画布上的原位', () async {
      final nextWeek = harness.today.addDays(7);
      final card = await harness.service.createCard(
        nextWeek,
        x: 120,
        y: 80,
        title: '体检',
      );

      await harness.service.completeCard(card.id);
      expect(
        (await harness.service.watchCompleted(nextWeek).first).single.id,
        card.id,
      );

      await harness.service.uncompleteCard(card.id);
      final restored =
          (await harness.service.watchDay(nextWeek).first).cards.single;
      expect(restored.id, card.id);
      expect(restored.dayKey, nextWeek);
      expect((restored.x, restored.y), (120, 80));
    });

    test('顺延过的卡片完成、取消完成后仍然是顺延过的', () async {
      final card = await newCard();
      await harness.markCarriedOver(card.id);

      await harness.service.completeCard(card.id);
      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.carriedOver, isTrue);

      await harness.service.uncompleteCard(card.id);
      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.carriedOver, isTrue);
    });

    test('没顺延过的卡片完成、取消完成后仍然没顺延过', () async {
      final card = await newCard();

      await harness.service.completeCard(card.id);
      await harness.service.uncompleteCard(card.id);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.carriedOver, isFalse);
    });

    test('未完成的卡片不能取消完成', () async {
      final card = await newCard();

      await expectLater(
        harness.service.uncompleteCard(card.id),
        throwsA(isA<InvalidState>()),
      );
    });

    test('在回收站里的已完成卡片不能取消完成', () async {
      final card = await newCard();
      await harness.service.completeCard(card.id);
      await harness.service.deleteCard(card.id);

      await expectLater(
        harness.service.uncompleteCard(card.id),
        throwsA(isA<InvalidState>()),
      );

      await harness.service.restoreCard(card.id);
      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.id, card.id);
    });

    test('卡片不存在时报 NotFound', () async {
      await expectLater(
        harness.service.uncompleteCard('不存在'),
        throwsA(isA<NotFound>()),
      );
    });

    test('写入失败时抛出 StorageFailure，卡片仍在已完成列表里', () async {
      final card = await newCard();
      await harness.service.completeCard(card.id);
      harness.failWrites = true;

      await expectLater(
        harness.service.uncompleteCard(card.id),
        throwsA(isA<StorageFailure>()),
      );

      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.id, card.id);
      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards, isEmpty);
    });
  });

  group('取消完成（过去日期）', () {
    /// 在今天建一张卡片并完成，再把时钟拨到 [days] 天后并维护。
    Future<TaskCard> completedDaysAgo(
      int days, {
      String title = '卡片',
      double x = 300,
      double y = 200,
    }) async {
      final card = await harness.service.createCard(
        harness.today,
        x: x,
        y: y,
        title: title,
      );
      await harness.service.completeCard(card.id);
      harness.now = harness.now.add(Duration(days: days));
      await harness.service.runDailyMaintenance();
      return card;
    }

    test('取消完成后卡片立即顺延到今天左上角，原日期留下历史记录', () async {
      final card = await completedDaysAgo(1);
      final yesterday = card.dayKey;

      await harness.service.uncompleteCard(card.id);

      final today = await harness.service.watchDay(harness.today).first;
      final moved = today.cards.single;
      expect(moved.id, card.id);
      expect((moved.x, moved.y), (24.0, 24.0));
      expect(moved.status, CardStatus.active);
      expect(moved.carriedOver, isTrue);
      final past = await harness.service.watchDay(yesterday).first;
      expect(past.cards, isEmpty);
      final record = past.carryOverRecords.single;
      expect(record.cardId, card.id);
      expect((record.x, record.y), (300.0, 200.0));
      expect(record.toDayKey, harness.today);
      expect(await harness.service.watchCompleted(yesterday).first, isEmpty);
    });

    test('今天已有的卡片右移，给顺延卡片腾出左上角', () async {
      final card = await completedDaysAgo(1);
      final existing = await harness.service.createCard(
        harness.today,
        x: 100,
        y: 100,
        title: '今天',
      );

      await harness.service.uncompleteCard(card.id);

      final board = await harness.service.watchDay(harness.today).first;
      // 顺延区宽 W = 180：dx = max(180 + 48, 24 + 180 + 48 - 100) = 228。
      expect(
        board.cards.map((c) => (c.id, c.x)),
        unorderedEquals([(card.id, 24.0), (existing.id, 328.0)]),
      );
    });

    test('没有维护过时按时钟的今天顺延', () async {
      final card = await newCard();
      await harness.service.completeCard(card.id);
      harness.now = harness.now.add(const Duration(days: 2));

      await harness.service.uncompleteCard(card.id);

      expect((await harness.service.findCard(card.id)).dayKey, harness.today);
    });

    test('时钟回拨时顺延到上次维护的日期，而不是时钟的今天', () async {
      final early = await completedDaysAgo(2, title: '10-20'); // 维护日期 10-22
      harness.now = harness.now.subtract(const Duration(days: 1)); // 时钟 10-21
      final maintenanceDay = harness.today.addDays(1);
      // 在 10-21（时钟的今天）上建一张卡片并完成：它也早于维护日期。
      final onClockToday = await newCard('10-21');
      await harness.service.completeCard(onClockToday.id);

      await harness.service.uncompleteCard(early.id);
      await harness.service.uncompleteCard(onClockToday.id);

      for (final card in [early, onClockToday]) {
        expect(
          (await harness.service.findCard(card.id)).dayKey,
          maintenanceDay,
          reason: card.title,
        );
      }
      // 回到维护日期再维护，不会再顺延。
      harness.now = harness.now.add(const Duration(days: 1));
      expect((await harness.service.runDailyMaintenance()).carriedCount, 0);
    });

    test('顺延后再完成、取消完成不再顺延，仍然带顺延标记，只有一条记录', () async {
      final card = await completedDaysAgo(1);
      final yesterday = card.dayKey;
      await harness.service.uncompleteCard(card.id);

      await harness.service.completeCard(card.id);
      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.carriedOver, isTrue);
      await harness.service.uncompleteCard(card.id);

      final today = await harness.service.watchDay(harness.today).first;
      expect(today.cards.single.id, card.id);
      expect(today.cards.single.carriedOver, isTrue);
      expect(today.carryOverRecords, isEmpty);
      final past = await harness.service.watchDay(yesterday).first;
      expect(past.carryOverRecords, hasLength(1));
    });

    test('顺延不复制卡片：之后几天的维护里卡片只有一张，没完成时继续顺延', () async {
      final card = await completedDaysAgo(3);
      final start = card.dayKey;
      await harness.service.uncompleteCard(card.id);
      harness.now = harness.now.add(const Duration(days: 1));

      expect((await harness.service.runDailyMaintenance()).carriedCount, 1);

      final ids = <String>[];
      for (var day = start; day <= harness.today; day = day.addDays(1)) {
        final board = await harness.service.watchDay(day).first;
        ids.addAll(board.cards.map((c) => c.id));
      }
      expect(ids, [card.id]);
      expect((await harness.service.findCard(card.id)).dayKey, harness.today);
    });

    // 今天已有一张卡片时，依次写入：卡片状态、右移今天的卡片、历史记录、
    // 卡片新位置，共 4 次写入。在每一步失败都应该整体回滚。
    // 改动 PlannerService._carryOver 的写入次数或顺序时要同步修改这里。
    for (final step in [1, 2, 3, 4]) {
      test('第 $step 步写入失败时整体回滚，卡片仍在原日期的已完成列表里', () async {
        final card = await completedDaysAgo(1);
        final yesterday = card.dayKey;
        final existing = await harness.service.createCard(
          harness.today,
          x: 100,
          y: 100,
          title: '今天',
        );
        harness.failWritesAfter(step - 1);

        await expectLater(
          harness.service.uncompleteCard(card.id),
          throwsA(isA<StorageFailure>()),
        );

        harness.failWrites = false;
        final completed = await harness.service.watchCompleted(yesterday).first;
        expect(completed.single.id, card.id);
        expect(completed.single.carriedOver, isFalse);
        final past = await harness.service.watchDay(yesterday).first;
        expect(past.carryOverRecords, isEmpty);
        final board = await harness.service.watchDay(harness.today).first;
        expect(board.cards.map((c) => (c.id, c.x)), [(existing.id, 100.0)]);
        // 回滚后可以重新取消完成。
        await harness.service.uncompleteCard(card.id);
        expect((await harness.service.findCard(card.id)).dayKey, harness.today);
      });
    }

    test('同样的场景允许 4 次写入时取消完成成功，上面的步骤覆盖了每一次写入', () async {
      final card = await completedDaysAgo(1);
      await harness.service.createCard(
        harness.today,
        x: 100,
        y: 100,
        title: '今天',
      );
      harness.failWritesAfter(4);

      await harness.service.uncompleteCard(card.id);

      expect((await harness.service.findCard(card.id)).dayKey, harness.today);
    });
  });
}
