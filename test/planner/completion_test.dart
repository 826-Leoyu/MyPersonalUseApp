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
      await harness.markDeleted(card.id);

      await expectLater(
        harness.service.completeCard(card.id),
        throwsA(isA<InvalidState>()),
      );

      await harness.markRestored(card.id);
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
      final tomorrow = await harness.service.createCard(
        harness.today.addDays(1),
        x: 0,
        y: 0,
        title: '明天',
      );
      for (final card in [kept, trashed, tomorrow]) {
        await harness.service.completeCard(card.id);
      }
      await harness.markDeleted(trashed.id);

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
      final tomorrow = await service.createCard(
        harness.today.addDays(1),
        x: 0,
        y: 0,
        title: '明天',
      );
      expect((await service.watchDay(harness.today).first).completedCount, 0);

      for (final card in [...cards.take(3), tomorrow]) {
        await service.completeCard(card.id);
      }
      await harness.markDeleted(cards[2].id);

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

    Future<TaskCard> cardOn(DayKey day, String title) =>
        harness.service.createCard(day, x: 0, y: 0, title: title);

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
      await harness.markDeleted(trashedActive.id);
      await harness.markDeleted(trashedDone.id);

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
      await harness.markDeleted(card.id);

      await expectLater(
        harness.service.uncompleteCard(card.id),
        throwsA(isA<InvalidState>()),
      );

      await harness.markRestored(card.id);
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
}
