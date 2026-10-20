import 'package:flutter_test/flutter_test.dart';
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

  group('删除', () {
    test('删除后卡片从画布上消失，出现在回收站里', () async {
      final kept = await newCard('留下');
      final trashed = await newCard('删除');

      await harness.service.deleteCard(trashed.id);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((c) => c.id), [kept.id]);
      final trash = await harness.service.watchTrash().first;
      expect(trash.single.card.id, trashed.id);
      expect(trash.single.card.deletedAt, harness.now.toUtc());
    });
  });

  group('回收站列表', () {
    test('按删除时间倒序排列，包含各个日期的未完成和已完成卡片', () async {
      final a = await newCard('A');
      final b = await harness.service.createCard(
        harness.today.addDays(3),
        x: 0,
        y: 0,
        title: 'B',
      );
      final c = await newCard('C');
      await harness.service.completeCard(c.id);

      for (final card in [b, c, a]) {
        harness.now = harness.now.add(const Duration(hours: 1));
        await harness.service.deleteCard(card.id);
      }

      final trash = await harness.service.watchTrash().first;
      expect(trash.map((t) => t.card.title), ['A', 'C', 'B']);
    });

    test('删除和恢复时持续推送新的列表', () async {
      final card = await newCard();
      final ids = harness.service.watchTrash().map(
        (trash) => trash.map((t) => t.card.id).toList(),
      );
      final expectation = expectLater(
        ids,
        emitsInOrder([
          isEmpty,
          emitsThrough([card.id]),
          emitsThrough(isEmpty),
        ]),
      );
      await pumpEventQueue();

      await harness.service.deleteCard(card.id);
      await pumpEventQueue();
      await harness.service.restoreCard(card.id);
      await expectation;
    });
  });

  group('重复操作', () {
    test('已经在回收站里的卡片再删除，删除时间不变，剩余天数不重新计算', () async {
      final card = await newCard();
      await harness.service.deleteCard(card.id);
      final firstDeletedAt = harness.now.toUtc();
      harness.now = harness.now.add(const Duration(days: 3));

      await harness.service.deleteCard(card.id);

      final trash = await harness.service.watchTrash().first;
      expect(trash.single.card.deletedAt, firstDeletedAt);
      expect(trash.single.daysLeft, 7);
    });

    test('不在回收站里的卡片恢复时静默成功，卡片不变', () async {
      final card = await newCard();
      harness.now = harness.now.add(const Duration(hours: 1));

      await harness.service.restoreCard(card.id);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.updatedAt, card.updatedAt);
    });
  });

  group('恢复（今天和未来）', () {
    test('恢复后卡片回到原日期的画布上原来的位置，离开回收站', () async {
      final nextWeek = harness.today.addDays(7);
      final card = await harness.service.createCard(
        nextWeek,
        x: 120,
        y: 80,
        title: '体检',
      );
      await harness.service.deleteCard(card.id);

      await harness.service.restoreCard(card.id);

      final restored =
          (await harness.service.watchDay(nextWeek).first).cards.single;
      expect(restored.id, card.id);
      expect(restored.dayKey, nextWeek);
      expect((restored.x, restored.y), (120, 80));
      expect(restored.deletedAt, isNull);
      expect(await harness.service.watchTrash().first, isEmpty);
    });

    test('另一端仍然有效时连线一起回来，另一端在回收站里时不回来', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final c = await newCard('C');
      final ab = await harness.service.toggleLink(a.id, b.id);
      await harness.service.toggleLink(b.id, c.id);
      await harness.service.deleteCard(b.id);
      await harness.service.deleteCard(c.id);
      var board = await harness.service.watchDay(harness.today).first;
      expect(board.links, isEmpty);

      await harness.service.restoreCard(b.id);

      board = await harness.service.watchDay(harness.today).first;
      expect(board.links.map((l) => l.id), [ab.linkId]);
    });
  });

  group('恢复（过去日期）', () {
    /// 在今天建一张卡片并删除，再把时钟拨到 [days] 天后并维护。
    Future<TaskCard> trashedDaysAgo(int days, {bool completed = false}) async {
      final card = await harness.service.createCard(
        harness.today,
        x: 300,
        y: 200,
        title: '卡片',
      );
      if (completed) await harness.service.completeCard(card.id);
      await harness.service.deleteCard(card.id);
      harness.now = harness.now.add(Duration(days: days));
      await harness.service.runDailyMaintenance();
      return card;
    }

    test('未完成的卡片恢复后立即顺延到今天左上角，原日期留下历史记录', () async {
      final card = await trashedDaysAgo(2);

      await harness.service.restoreCard(card.id);

      final today = await harness.service.watchDay(harness.today).first;
      final moved = today.cards.single;
      expect(moved.id, card.id);
      expect((moved.x, moved.y), (24.0, 24.0));
      expect(moved.deletedAt, isNull);
      expect(moved.carriedOver, isTrue);
      final past = await harness.service.watchDay(card.dayKey).first;
      expect(past.cards, isEmpty);
      final record = past.carryOverRecords.single;
      expect((record.cardId, record.x, record.y), (card.id, 300.0, 200.0));
      expect(await harness.service.watchTrash().first, isEmpty);
    });

    test('已完成的卡片恢复后回到原日期的已完成列表，不顺延', () async {
      final card = await trashedDaysAgo(2, completed: true);

      await harness.service.restoreCard(card.id);

      final completed = await harness.service.watchCompleted(card.dayKey).first;
      expect(completed.single.id, card.id);
      expect(completed.single.carriedOver, isFalse);
      final past = await harness.service.watchDay(card.dayKey).first;
      expect(past.carryOverRecords, isEmpty);
    });

    test('时钟回拨时顺延到上次维护的日期，而不是时钟的今天', () async {
      final card = await trashedDaysAgo(2); // 维护日期 10-22
      final maintenanceDay = harness.today;
      harness.now = harness.now.subtract(const Duration(days: 1));

      await harness.service.restoreCard(card.id);

      expect((await harness.service.findCard(card.id)).dayKey, maintenanceDay);
    });

    test('同一张卡片先后恢复两次，只顺延一次', () async {
      final card = await trashedDaysAgo(1);

      await harness.service.restoreCard(card.id);
      await harness.service.restoreCard(card.id);

      final today = await harness.service.watchDay(harness.today).first;
      expect(today.cards.single.id, card.id);
      expect(today.carryOverRecords, isEmpty);
      final past = await harness.service.watchDay(card.dayKey).first;
      expect(past.carryOverRecords, hasLength(1));
    });

    // 今天已有一张卡片时，依次写入：清除删除时间、右移今天的卡片、历史记录、
    // 卡片新位置，共 4 次写入。在每一步失败都应该整体回滚。
    // 改动 PlannerService._carryOver 的写入次数或顺序时要同步修改这里。
    for (final step in [1, 2, 3, 4]) {
      test('第 $step 步写入失败时整体回滚，卡片仍在回收站里', () async {
        final card = await trashedDaysAgo(1);
        final existing = await harness.service.createCard(
          harness.today,
          x: 100,
          y: 100,
          title: '今天',
        );
        harness.failWritesAfter(step - 1);

        await expectLater(
          harness.service.restoreCard(card.id),
          throwsA(isA<StorageFailure>()),
        );

        harness.failWrites = false;
        final trash = await harness.service.watchTrash().first;
        expect(trash.single.card.id, card.id);
        expect(trash.single.card.dayKey, card.dayKey);
        expect(trash.single.card.carriedOver, isFalse);
        final past = await harness.service.watchDay(card.dayKey).first;
        expect(past.carryOverRecords, isEmpty);
        final board = await harness.service.watchDay(harness.today).first;
        expect(board.cards.map((c) => (c.id, c.x)), [(existing.id, 100.0)]);
        // 回滚后可以重新恢复。
        await harness.service.restoreCard(card.id);
        expect((await harness.service.findCard(card.id)).dayKey, harness.today);
      });
    }

    test('同样的场景允许 4 次写入时恢复成功，上面的步骤覆盖了每一次写入', () async {
      final card = await trashedDaysAgo(1);
      await harness.service.createCard(
        harness.today,
        x: 100,
        y: 100,
        title: '今天',
      );
      harness.failWritesAfter(4);

      await harness.service.restoreCard(card.id);

      expect((await harness.service.findCard(card.id)).dayKey, harness.today);
    });
  });

  group('永久删除', () {
    test('物理删除卡片和它的连线、历史记录，别的卡片不受影响', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final c = await newCard('C');
      final ab = await harness.service.toggleLink(a.id, b.id);
      final bc = await harness.service.toggleLink(b.id, c.id);
      final ac = await harness.service.toggleLink(a.id, c.id);
      // 用夹具直接留一条历史记录（走真实顺延的版本见 carry_over_test.dart）；
      // 卡片表有外键约束，历史记录没删掉时卡片也删不掉。
      await harness.addCarryOverRecord(b.id);
      await harness.service.deleteCard(b.id);

      await harness.service.deleteForever(b.id);

      expect(await harness.service.watchTrash().first, isEmpty);
      await expectLater(
        harness.service.findCard(b.id),
        throwsA(isA<NotFound>()),
      );
      for (final link in [ab, bc]) {
        await expectLater(
          harness.service.restoreLink(link.linkId),
          throwsA(isA<NotFound>()),
        );
      }
      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((c) => c.id), [a.id, c.id]);
      expect(board.links.map((l) => l.id), [ac.linkId]);
    });

    test('不在回收站里的卡片不能永久删除', () async {
      final card = await newCard();

      await expectLater(
        harness.service.deleteForever(card.id),
        throwsA(isA<InvalidState>()),
      );

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.id, card.id);
    });

    test('卡片不存在时报 NotFound', () async {
      await expectLater(
        harness.service.deleteForever('不存在'),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('清空回收站', () {
    test('物理删除回收站里所有卡片和它们的连线、历史记录，画布上的卡片不受影响', () async {
      final kept = await newCard('留下');
      final done = await newCard('删除的已完成');
      final active = await newCard('删除的未完成');
      final link = await harness.service.toggleLink(kept.id, active.id);
      await harness.addCarryOverRecord(done.id);
      await harness.addCarryOverRecord(active.id);
      await harness.service.completeCard(done.id);
      await harness.service.deleteCard(done.id);
      await harness.service.deleteCard(active.id);

      await harness.service.emptyTrash();

      expect(await harness.service.watchTrash().first, isEmpty);
      for (final card in [done, active]) {
        await expectLater(
          harness.service.findCard(card.id),
          throwsA(isA<NotFound>()),
        );
      }
      await expectLater(
        harness.service.restoreLink(link.linkId),
        throwsA(isA<NotFound>()),
      );
      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.id, kept.id);
    });

    test('回收站是空的时静默成功', () async {
      await harness.service.emptyTrash();

      expect(await harness.service.watchTrash().first, isEmpty);
    });
  });

  group('每日维护自动清理', () {
    test('删除超过 10 天的卡片被永久删除，连线和历史记录一起删掉', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final link = await harness.service.toggleLink(a.id, b.id);
      // 走真实顺延给 B 留一条历史记录。
      final yesterday = harness.today;
      harness.now = harness.now.add(const Duration(days: 1));
      await harness.service.runDailyMaintenance();
      await harness.service.deleteCard(b.id);
      harness.now = harness.now.add(const Duration(days: 10, milliseconds: 1));

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.cleanedCount, 1);
      expect(await harness.service.watchTrash().first, isEmpty);
      await expectLater(
        harness.service.findCard(b.id),
        throwsA(isA<NotFound>()),
      );
      await expectLater(
        harness.service.restoreLink(link.linkId),
        throwsA(isA<NotFound>()),
      );
      final past = await harness.service.watchDay(yesterday).first;
      expect(past.carryOverRecords.map((r) => r.cardId), [a.id]);
      expect((await harness.service.findCard(a.id)).dayKey, harness.today);
    });

    test('恰好满 10 天时还在回收站里，剩余 0 天', () async {
      final card = await newCard();
      await harness.service.deleteCard(card.id);
      harness.now = harness.now.add(const Duration(days: 10));

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.cleanedCount, 0);
      final trash = await harness.service.watchTrash().first;
      expect((trash.single.card.id, trash.single.daysLeft), (card.id, 0));
    });

    test('同一天已经维护过，再次维护时仍然清理', () async {
      final card = await newCard();
      await harness.service.deleteCard(card.id);
      harness.now = harness.now.add(const Duration(days: 10));
      await harness.service.runDailyMaintenance();
      harness.now = harness.now.add(const Duration(hours: 1));

      final summary = await harness.service.runDailyMaintenance();

      expect((summary.carriedCount, summary.cleanedCount), (0, 1));
      expect(await harness.service.watchTrash().first, isEmpty);
    });

    test('时钟被调到删除时间以前时不误删', () async {
      final card = await newCard();
      await harness.service.deleteCard(card.id);
      harness.now = harness.now.subtract(const Duration(days: 5));

      final summary = await harness.service.runDailyMaintenance();

      expect(summary.cleanedCount, 0);
      final trash = await harness.service.watchTrash().first;
      expect((trash.single.card.id, trash.single.daysLeft), (card.id, 10));
    });

    test('维护日期比时钟还晚（时钟回拨）时，仍然按实际经过的时间清理', () async {
      harness.now = DateTime(2026, 11, 20, 9);
      await harness.service.runDailyMaintenance(); // 维护日期 11-20
      harness.now = DateTime(2026, 10, 20, 9);
      final card = await newCard();
      await harness.service.deleteCard(card.id);
      harness.now = DateTime(2026, 10, 31, 9); // 删除后 11 天，仍早于 11-20

      final summary = await harness.service.runDailyMaintenance();

      expect((summary.carriedCount, summary.cleanedCount), (0, 1));
      expect(await harness.service.watchTrash().first, isEmpty);
    });

    // 只有清理、没有顺延时，依次删除连线、历史记录、卡片，共 3 次写入；
    // 之后还要写维护日期（第 4 次）。在每一步失败都应该整体回滚。
    // 卡片放在未来的日期上，恢复时不会触发顺延。
    for (final step in [1, 2, 3, 4]) {
      test('第 $step 步写入失败时整体回滚，过期卡片和连线都还在', () async {
        final future = harness.today.addDays(30);
        final a = await harness.service.createCard(
          future,
          x: 0,
          y: 0,
          title: 'A',
        );
        final b = await harness.service.createCard(
          future,
          x: 0,
          y: 0,
          title: 'B',
        );
        final link = await harness.service.toggleLink(a.id, b.id);
        await harness.addCarryOverRecord(b.id);
        await harness.service.deleteCard(a.id);
        await harness.service.deleteCard(b.id);
        harness.now = harness.now.add(const Duration(days: 11));
        harness.failWritesAfter(step - 1);

        await expectLater(
          harness.service.runDailyMaintenance(),
          throwsA(isA<StorageFailure>()),
        );

        harness.failWrites = false;
        final trash = await harness.service.watchTrash().first;
        expect(trash.map((t) => t.card.id), unorderedEquals([a.id, b.id]));
        await harness.service.restoreCard(a.id);
        await harness.service.restoreCard(b.id);
        final board = await harness.service.watchDay(a.dayKey).first;
        expect(board.links.single.id, link.linkId);
      });
    }
  });

  group('删除和恢复不改变卡片的其他状态', () {
    test('已完成的卡片删除后再恢复，回到已完成列表', () async {
      final card = await newCard();
      await harness.service.completeCard(card.id);
      await harness.service.deleteCard(card.id);
      expect(
        await harness.service.watchCompleted(harness.today).first,
        isEmpty,
      );

      await harness.service.restoreCard(card.id);

      final completed = await harness.service
          .watchCompleted(harness.today)
          .first;
      expect(completed.single.id, card.id);
      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards, isEmpty);
    });

    test('顺延过的卡片删除、恢复后仍然是顺延过的', () async {
      final card = await newCard();
      await harness.markCarriedOver(card.id);

      await harness.service.deleteCard(card.id);
      final trash = await harness.service.watchTrash().first;
      expect(trash.single.card.carriedOver, isTrue);

      await harness.service.restoreCard(card.id);
      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.carriedOver, isTrue);
    });

    test('没顺延过的卡片删除、恢复后仍然没顺延过', () async {
      final card = await newCard();

      await harness.service.deleteCard(card.id);
      await harness.service.restoreCard(card.id);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.carriedOver, isFalse);
    });
  });

  group('错误', () {
    test('卡片不存在时删除和恢复都报 NotFound', () async {
      await expectLater(
        harness.service.deleteCard('不存在'),
        throwsA(isA<NotFound>()),
      );
      await expectLater(
        harness.service.restoreCard('不存在'),
        throwsA(isA<NotFound>()),
      );
    });

    test('删除时写入失败抛出 StorageFailure，卡片仍在画布上', () async {
      final card = await newCard();
      harness.failWrites = true;

      await expectLater(
        harness.service.deleteCard(card.id),
        throwsA(isA<StorageFailure>()),
      );

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.single.id, card.id);
    });

    // 永久删除依次删除连线、历史记录、卡片，共 3 次写入。
    // 在每一步失败都应该整体回滚。
    for (final step in [1, 2, 3]) {
      test('永久删除在第 $step 步写入失败时整体回滚，卡片和连线都还在', () async {
        final a = await newCard('A');
        final b = await newCard('B');
        final link = await harness.service.toggleLink(a.id, b.id);
        await harness.addCarryOverRecord(b.id);
        await harness.service.deleteCard(b.id);
        harness.failWritesAfter(step - 1);

        await expectLater(
          harness.service.deleteForever(b.id),
          throwsA(isA<StorageFailure>()),
        );

        harness.failWrites = false;
        final trash = await harness.service.watchTrash().first;
        expect(trash.single.card.id, b.id);
        await harness.service.restoreCard(b.id);
        final board = await harness.service.watchDay(harness.today).first;
        expect(board.links.single.id, link.linkId);
      });

      test('清空回收站在第 $step 步写入失败时整体回滚，回收站里的卡片和连线都还在', () async {
        final a = await newCard('A');
        final b = await newCard('B');
        final c = await newCard('C');
        final ab = await harness.service.toggleLink(a.id, b.id);
        final ac = await harness.service.toggleLink(a.id, c.id);
        await harness.addCarryOverRecord(b.id);
        await harness.service.deleteCard(b.id);
        await harness.service.deleteCard(c.id);
        harness.failWritesAfter(step - 1);

        await expectLater(
          harness.service.emptyTrash(),
          throwsA(isA<StorageFailure>()),
        );

        harness.failWrites = false;
        final trash = await harness.service.watchTrash().first;
        expect(trash.map((t) => t.card.id), unorderedEquals([b.id, c.id]));
        await harness.service.restoreCard(b.id);
        await harness.service.restoreCard(c.id);
        final board = await harness.service.watchDay(harness.today).first;
        expect(
          board.links.map((l) => l.id),
          unorderedEquals([ab.linkId, ac.linkId]),
        );
      });
    }

    test('回滚后可以再次永久删除，连线和历史记录一起删掉', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final link = await harness.service.toggleLink(a.id, b.id);
      // 历史记录没有删掉时，外键约束会让删除卡片失败。
      await harness.addCarryOverRecord(b.id);
      await harness.service.deleteCard(b.id);
      harness.failWritesAfter(2);
      await expectLater(
        harness.service.deleteForever(b.id),
        throwsA(isA<StorageFailure>()),
      );
      harness.failWrites = false;

      await harness.service.deleteForever(b.id);

      expect(await harness.service.watchTrash().first, isEmpty);
      await expectLater(
        harness.service.restoreLink(link.linkId),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('剩余天数', () {
    /// 删除一张卡片，过了 [elapsed] 之后它在回收站里的剩余天数。
    Future<int> daysLeftAfter(Duration elapsed) async {
      final card = await newCard();
      await harness.service.deleteCard(card.id);
      harness.now = harness.now.add(elapsed);
      final trash = await harness.service.watchTrash().first;
      return trash.single.daysLeft;
    }

    test('刚删除时还剩 10 天', () async {
      expect(await daysLeftAfter(Duration.zero), 10);
    });

    test('不满整天的部分向上取整', () async {
      expect(await daysLeftAfter(const Duration(hours: 1)), 10);
    });

    test('过了 3 天还剩 7 天', () async {
      expect(await daysLeftAfter(const Duration(days: 3)), 7);
    });

    test('第 10 天里还剩 1 天', () async {
      expect(await daysLeftAfter(const Duration(days: 9, hours: 23)), 1);
    });

    test('差 1 毫秒满 10 天时仍然还剩 1 天', () async {
      final justBefore =
          const Duration(days: 10) - const Duration(milliseconds: 1);
      expect(await daysLeftAfter(justBefore), 1);
    });

    test('满 10 天时是 0，超过以后也不会变成负数', () async {
      expect(await daysLeftAfter(const Duration(days: 10)), 0);
      harness.now = harness.now.add(const Duration(days: 2));
      final trash = await harness.service.watchTrash().first;
      expect(trash.single.daysLeft, 0);
    });

    test('时钟被调到删除时间以前时最多显示 10 天', () async {
      expect(await daysLeftAfter(const Duration(days: -3)), 10);
    });
  });
}
