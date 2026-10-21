import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/planner/link.dart';
import 'package:my_personal_use_app/planner/link_kind.dart';
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

  /// 今天画布上显示的连线。
  Future<List<Link>> linksOnBoard() async =>
      (await harness.service.watchDay(harness.today).first).links;

  group('碰撞连线', () {
    test('第一次碰撞新建一条从被拖卡片指向被碰卡片的连线', () async {
      final dragged = await newCard('A');
      final target = await newCard('B');

      final result = await harness.service.toggleLink(dragged.id, target.id);

      expect(result, isA<LinkCreated>());
      final link = (await linksOnBoard()).single;
      expect(link.id, result.linkId);
      expect((link.fromCardId, link.toCardId), (dragged.id, target.id));
      expect(link.kind, LinkKind.visual);
    });

    test('同一方向再碰一次就断开这条连线', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);

      final result = await harness.service.toggleLink(a.id, b.id);

      expect(result, isA<LinkRemoved>());
      expect(result.linkId, created.linkId);
      expect(await linksOnBoard(), isEmpty);
    });

    test('反方向再碰一次也会断开这条连线', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);

      final result = await harness.service.toggleLink(b.id, a.id);

      expect(result, isA<LinkRemoved>());
      expect(result.linkId, created.linkId);
      expect(await linksOnBoard(), isEmpty);
    });

    test('断开后再碰一次，重新新建一条连线，方向以这次为准', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final first = await harness.service.toggleLink(a.id, b.id);
      await harness.service.toggleLink(a.id, b.id);

      final result = await harness.service.toggleLink(b.id, a.id);

      expect(result, isA<LinkCreated>());
      expect(result.linkId, isNot(first.linkId));
      final link = (await linksOnBoard()).single;
      expect((link.fromCardId, link.toCardId), (b.id, a.id));
    });

    test('一张卡片可以同时有多条连入和连出的连线', () async {
      final hub = await newCard('中心');
      final in1 = await newCard('连入 1');
      final in2 = await newCard('连入 2');
      final out1 = await newCard('连出 1');
      final out2 = await newCard('连出 2');

      await harness.service.toggleLink(in1.id, hub.id);
      await harness.service.toggleLink(in2.id, hub.id);
      await harness.service.toggleLink(hub.id, out1.id);
      await harness.service.toggleLink(hub.id, out2.id);

      final pairs = (await linksOnBoard()).map(
        (link) => (link.fromCardId, link.toCardId),
      );
      expect(
        pairs,
        unorderedEquals([
          (in1.id, hub.id),
          (in2.id, hub.id),
          (hub.id, out1.id),
          (hub.id, out2.id),
        ]),
      );
    });
  });

  group('不能连线的情况', () {
    test('卡片不能连到自己', () async {
      final a = await newCard('A');

      await expectLater(
        harness.service.toggleLink(a.id, a.id),
        throwsA(isA<InvalidState>()),
      );
      expect(await linksOnBoard(), isEmpty);
    });

    test('不在同一天的两张卡片不能连线', () async {
      final today = await newCard('今天的');
      final tomorrow = await harness.service.createCard(
        harness.today.addDays(1),
        x: 0,
        y: 0,
        title: '明天的',
      );

      await expectLater(
        harness.service.toggleLink(today.id, tomorrow.id),
        throwsA(isA<InvalidState>()),
      );
      await expectLater(
        harness.service.toggleLink(tomorrow.id, today.id),
        throwsA(isA<InvalidState>()),
      );
      final tomorrowBoard = await harness.service
          .watchDay(harness.today.addDays(1))
          .first;
      expect(await linksOnBoard(), isEmpty);
      expect(tomorrowBoard.links, isEmpty);
    });

    /// 让一张卡片变成不能连线的状态，按名字列出，每个都单独生成测试。
    final unavailable = <String, Future<void> Function(String id)>{
      '已完成': (id) => harness.service.completeCard(id),
      '在回收站里': (id) => harness.service.deleteCard(id),
    };

    for (final MapEntry(key: state, value: makeUnavailable)
        in unavailable.entries) {
      test('被拖的卡片$state时不能连线', () async {
        final dragged = await newCard('A');
        final target = await newCard('B');
        await makeUnavailable(dragged.id);

        await expectLater(
          harness.service.toggleLink(dragged.id, target.id),
          throwsA(isA<InvalidState>()),
        );
      });

      test('被碰的卡片$state时不能连线', () async {
        final dragged = await newCard('A');
        final target = await newCard('B');
        await makeUnavailable(target.id);

        await expectLater(
          harness.service.toggleLink(dragged.id, target.id),
          throwsA(isA<InvalidState>()),
        );
      });

      test('一端$state时，再次碰撞也不能断开原有的连线', () async {
        final a = await newCard('A');
        final b = await newCard('B');
        await harness.service.toggleLink(a.id, b.id);
        await makeUnavailable(b.id);

        await expectLater(
          harness.service.toggleLink(a.id, b.id),
          throwsA(isA<InvalidState>()),
        );
      });
    }

    test('卡片不存在时报 NotFound', () async {
      final a = await newCard('A');

      await expectLater(
        harness.service.toggleLink(a.id, '不存在'),
        throwsA(isA<NotFound>()),
      );
      await expectLater(
        harness.service.toggleLink('不存在', a.id),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('画布上显示的连线', () {
    test('按建立时间排列（也是从下到上的绘制顺序），不随写入顺序和 ID 变化', () async {
      final a = await newCard('A');
      final others = [for (var i = 0; i < 5; i++) await newCard('B$i')];
      // 每建一条连线，系统时钟往回拨一小时：后建的连线建立时间更早。
      for (final other in others) {
        await harness.service.toggleLink(a.id, other.id);
        harness.now = harness.now.subtract(const Duration(hours: 1));
      }

      expect(
        (await linksOnBoard()).map((l) => l.toCardId),
        others.reversed.map((c) => c.id),
      );
    });

    test('一端完成后连线不显示，取消完成后重新显示', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      await harness.service.toggleLink(a.id, b.id);

      await harness.service.completeCard(b.id);
      expect(await linksOnBoard(), isEmpty);

      await harness.service.uncompleteCard(b.id);
      expect((await linksOnBoard()).single.toCardId, b.id);
    });

    test('一端在回收站里时连线不显示，从回收站恢复后重新显示', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      await harness.service.toggleLink(a.id, b.id);

      await harness.service.deleteCard(a.id);
      expect(await linksOnBoard(), isEmpty);

      await harness.service.restoreCard(a.id);
      expect((await linksOnBoard()).single.fromCardId, a.id);
    });

    test('两端不在同一天时，哪一天的画布上都不显示这条连线', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      await harness.service.toggleLink(a.id, b.id);
      final tomorrow = harness.today.addDays(1);

      await harness.markMovedToDay(b.id, tomorrow);

      final tomorrowBoard = await harness.service.watchDay(tomorrow).first;
      expect(await linksOnBoard(), isEmpty);
      expect(tomorrowBoard.links, isEmpty);
    });

    test('只包含这一天的连线', () async {
      final a = await newCard('今天 A');
      final b = await newCard('今天 B');
      final tomorrow = harness.today.addDays(1);
      Future<TaskCard> tomorrowCard(String title) =>
          harness.service.createCard(tomorrow, x: 0, y: 0, title: title);
      final c = await tomorrowCard('明天 C');
      final d = await tomorrowCard('明天 D');
      await harness.service.toggleLink(a.id, b.id);
      await harness.service.toggleLink(c.id, d.id);

      final tomorrowBoard = await harness.service.watchDay(tomorrow).first;
      expect((await linksOnBoard()).single.fromCardId, a.id);
      expect(tomorrowBoard.links.single.fromCardId, c.id);
    });

    test('连线或断开时推送新的画布内容', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final linkCounts = harness.service
          .watchDay(harness.today)
          .map((board) => board.links.length);
      final expectation = expectLater(linkCounts, emitsInOrder([0, 1, 0]));
      await pumpEventQueue();

      await harness.service.toggleLink(a.id, b.id);
      await pumpEventQueue();
      await harness.service.toggleLink(b.id, a.id);

      await expectation;
    });

    test('点击断开和撤销断开时推送新的画布内容', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);
      final linkCounts = harness.service
          .watchDay(harness.today)
          .map((board) => board.links.length);
      final expectation = expectLater(linkCounts, emitsInOrder([1, 0, 1]));
      await pumpEventQueue();

      await harness.service.removeLink(created.linkId);
      await pumpEventQueue();
      await harness.service.restoreLink(created.linkId);

      await expectation;
    });
  });

  group('点击断开连线', () {
    test('断开后连线不再显示', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);

      await harness.service.removeLink(created.linkId);

      expect(await linksOnBoard(), isEmpty);
    });

    test('已经断开的连线再断开一次静默成功', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);
      await harness.service.removeLink(created.linkId);

      await harness.service.removeLink(created.linkId);

      expect(await linksOnBoard(), isEmpty);
    });

    test('断开后再碰撞，重新新建一条连线', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);
      await harness.service.removeLink(created.linkId);

      final result = await harness.service.toggleLink(a.id, b.id);

      expect(result, isA<LinkCreated>());
      expect((await linksOnBoard()).single.id, result.linkId);
    });

    test('连线不存在时报 NotFound', () async {
      await expectLater(
        harness.service.removeLink('不存在'),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('恢复连线（撤销断开）', () {
    /// 新建 A → B 再断开，返回这条已断开的连线。
    Future<String> removedLink(TaskCard a, TaskCard b) async {
      final created = await harness.service.toggleLink(a.id, b.id);
      await harness.service.removeLink(created.linkId);
      return created.linkId;
    }

    test('恢复后原来的连线重新显示，方向不变', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final linkId = await removedLink(a, b);

      await harness.service.restoreLink(linkId);

      final link = (await linksOnBoard()).single;
      expect(link.id, linkId);
      expect((link.fromCardId, link.toCardId), (a.id, b.id));
    });

    test('碰撞断开的连线也能恢复', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      await harness.service.toggleLink(a.id, b.id);
      final removed = await harness.service.toggleLink(b.id, a.id);

      await harness.service.restoreLink(removed.linkId);

      expect((await linksOnBoard()).single.id, removed.linkId);
    });

    test('没有断开的连线恢复时静默成功', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);

      await harness.service.restoreLink(created.linkId);

      expect((await linksOnBoard()).single.id, created.linkId);
    });

    /// 断开后，两张卡片之间又新建了一条连线的两种方向。
    final reconnections = <String, (int, int)>{'同一方向': (0, 1), '反方向': (1, 0)};

    for (final MapEntry(key: direction, value: (from, to))
        in reconnections.entries) {
      test('两张卡片之间又按$direction连上了另一条线时拒绝恢复，保留新的连线', () async {
        final cards = [await newCard('A'), await newCard('B')];
        final oldLinkId = await removedLink(cards[0], cards[1]);
        final newer = await harness.service.toggleLink(
          cards[from].id,
          cards[to].id,
        );

        await expectLater(
          harness.service.restoreLink(oldLinkId),
          throwsA(isA<InvalidState>()),
        );
        expect((await linksOnBoard()).single.id, newer.linkId);
      });
    }

    /// 让一端卡片不满足显示条件，再在恢复失败后把它变回来，
    /// 用来确认被拒绝的连线确实没有恢复。
    final endpointChanges =
        <
          String,
          (Future<void> Function(String), Future<void> Function(String))
        >{
          '已完成': (
            (id) => harness.service.completeCard(id),
            (id) => harness.service.uncompleteCard(id),
          ),
          '在回收站里': (
            (id) => harness.service.deleteCard(id),
            (id) => harness.service.restoreCard(id),
          ),
          '搬到了另一天': (
            (id) => harness.markMovedToDay(id, harness.today.addDays(1)),
            (id) => harness.markMovedToDay(id, harness.today),
          ),
        };

    for (final MapEntry(key: state, value: (change, revert))
        in endpointChanges.entries) {
      test('一端卡片$state时拒绝恢复，连线保持断开', () async {
        final a = await newCard('A');
        final b = await newCard('B');
        final linkId = await removedLink(a, b);
        await change(b.id);

        await expectLater(
          harness.service.restoreLink(linkId),
          throwsA(isA<InvalidState>()),
        );

        await revert(b.id);
        expect(await linksOnBoard(), isEmpty);
      });
    }

    test('连线不存在时报 NotFound', () async {
      await expectLater(
        harness.service.restoreLink('不存在'),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('连线的持久化', () {
    test('重建 service 后，连线还在，断开的连线仍然不显示', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final c = await newCard('C');
      final kept = await harness.service.toggleLink(a.id, b.id);
      final removed = await harness.service.toggleLink(b.id, c.id);
      await harness.service.removeLink(removed.linkId);

      await harness.reopen();

      final link = (await linksOnBoard()).single;
      expect(link.id, kept.linkId);
      expect((link.fromCardId, link.toCardId), (a.id, b.id));
    });

    test('重建 service 后，之前断开的连线仍然可以恢复', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);
      await harness.service.removeLink(created.linkId);

      await harness.reopen();
      await harness.service.restoreLink(created.linkId);

      expect((await linksOnBoard()).single.id, created.linkId);
    });
  });

  group('连线写入失败', () {
    test('写入失败时新建连线抛出 StorageFailure，画布上没有新连线', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      harness.failWrites = true;

      await expectLater(
        harness.service.toggleLink(a.id, b.id),
        throwsA(isA<StorageFailure>()),
      );
      expect(await linksOnBoard(), isEmpty);
    });

    /// 断开已有连线的写操作，按名字列出，每个都单独生成测试。
    final linkRemovals = <String, Future<void> Function(Link link)>{
      'toggleLink': (link) =>
          harness.service.toggleLink(link.toCardId, link.fromCardId),
      'removeLink': (link) => harness.service.removeLink(link.id),
    };

    for (final MapEntry(key: name, value: remove) in linkRemovals.entries) {
      test('写入失败时 $name 抛出 StorageFailure，连线保持不变', () async {
        final a = await newCard('A');
        final b = await newCard('B');
        await harness.service.toggleLink(a.id, b.id);
        final link = (await linksOnBoard()).single;
        harness.failWrites = true;

        await expectLater(remove(link), throwsA(isA<StorageFailure>()));
        expect((await linksOnBoard()).single.id, link.id);
      });
    }

    test('写入失败时 restoreLink 抛出 StorageFailure，连线保持断开', () async {
      final a = await newCard('A');
      final b = await newCard('B');
      final created = await harness.service.toggleLink(a.id, b.id);
      await harness.service.removeLink(created.linkId);
      harness.failWrites = true;

      await expectLater(
        harness.service.restoreLink(created.linkId),
        throwsA(isA<StorageFailure>()),
      );
      expect(await linksOnBoard(), isEmpty);
    });

    test('写入失败时不能连线的情况仍然报 InvalidState', () async {
      final a = await newCard('A');
      harness.failWrites = true;

      await expectLater(
        harness.service.toggleLink(a.id, a.id),
        throwsA(isA<InvalidState>()),
      );
    });
  });
}
