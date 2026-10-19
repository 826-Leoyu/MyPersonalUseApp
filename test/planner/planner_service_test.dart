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
  Future<TaskCard> newCard({String title = '卡片', double x = 0, double y = 0}) =>
      harness.service.createCard(harness.today, x: x, y: y, title: title);

  /// 从今天的画布上读回这张卡片。
  Future<TaskCard> cardOnBoard(String id) async {
    final board = await harness.service.watchDay(harness.today).first;
    return board.cards.singleWhere((c) => c.id == id);
  }

  group('新建卡片', () {
    test('新建的卡片出现在当天的画布上，默认淡黄色、180×88', () async {
      final service = harness.service;

      await service.createCard(harness.today, x: 40, y: 60, title: '买菜');

      final board = await service.watchDay(harness.today).first;
      expect(board.cards, hasLength(1));
      final card = board.cards.single;
      expect(card.title, '买菜');
      expect((card.x, card.y), (40, 60));
      expect(card.colorArgb, 0xFFFFF3B0);
      expect((card.width, card.height), (180, 88));
    });

    test('新建时可以指定颜色', () async {
      final card = await harness.service.createCard(
        harness.today,
        x: 0,
        y: 0,
        title: '买菜',
        colorArgb: 0xFFCDEBC5,
      );

      expect((await cardOnBoard(card.id)).colorArgb, 0xFFCDEBC5);
    });

    test('标题去掉首尾空格后为空时拒绝新建，画布上没有新卡片', () async {
      final service = harness.service;

      for (final title in ['', '   ', '\n\t ']) {
        await expectLater(
          service.createCard(harness.today, x: 0, y: 0, title: title),
          throwsA(isA<InvalidInput>()),
          reason: '标题：${title.codeUnits}',
        );
      }

      final board = await service.watchDay(harness.today).first;
      expect(board.cards, isEmpty);
    });

    test('保存的标题去掉了首尾空格', () async {
      final card = await harness.service.createCard(
        harness.today,
        x: 0,
        y: 0,
        title: '  买菜 \n',
      );

      expect(card.title, '买菜');
    });

    test('标题最多 200 个字：200 个字可以新建，201 个字被拒绝', () async {
      final service = harness.service;

      final card = await service.createCard(
        harness.today,
        x: 0,
        y: 0,
        title: '字' * 200,
      );
      expect(card.title, hasLength(200));

      await expectLater(
        service.createCard(harness.today, x: 0, y: 0, title: '字' * 201),
        throwsA(isA<InvalidInput>()),
      );
    });

    test('标题按字符计数，一个表情算一个字', () async {
      final card = await harness.service.createCard(
        harness.today,
        x: 0,
        y: 0,
        title: '😀' * 200,
      );

      expect(card.title, '😀' * 200);
    });

    test('在过去的日期新建卡片被拒绝，那天的画布上没有新卡片', () async {
      final service = harness.service;
      final yesterday = harness.today.addDays(-1);

      await expectLater(
        service.createCard(yesterday, x: 0, y: 0, title: '补记'),
        throwsA(isA<InvalidState>()),
      );

      final board = await service.watchDay(yesterday).first;
      expect(board.cards, isEmpty);
    });

    test('今天快结束时仍然可以在今天新建卡片', () async {
      harness.now = DateTime(2026, 10, 20, 23, 59, 59);

      await harness.service.createCard(
        DayKey(2026, 10, 20),
        x: 0,
        y: 0,
        title: '睡前读书',
      );

      final board = await harness.service.watchDay(DayKey(2026, 10, 20)).first;
      expect(board.cards.single.title, '睡前读书');
    });

    test('可以在未来的日期新建卡片', () async {
      final nextWeek = harness.today.addDays(7);

      await harness.service.createCard(nextWeek, x: 0, y: 0, title: '体检');

      final board = await harness.service.watchDay(nextWeek).first;
      expect(board.cards.single.title, '体检');
    });

    test('新建的卡片显示在当天已有卡片的上层', () async {
      final a = await newCard(title: 'A');
      await harness.service.moveCard(a.id, x: 50, y: 50);

      await newCard(title: 'B');

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((card) => card.title), ['A', 'B']);
    });

    test('跨过午夜后，昨天变成过去的日期，不能再新建卡片', () async {
      harness.now = DateTime(2026, 10, 21, 0, 0, 1);

      await expectLater(
        harness.service.createCard(
          DayKey(2026, 10, 20),
          x: 0,
          y: 0,
          title: '迟到的计划',
        ),
        throwsA(isA<InvalidState>()),
      );
    });
  });

  group('查找卡片', () {
    test('返回卡片当前所在的日期和状态，并且不在回收站', () async {
      final tomorrow = harness.today.addDays(1);
      final card = await harness.service.createCard(
        tomorrow,
        x: 0,
        y: 0,
        title: '交作业',
      );

      final location = await harness.service.findCard(card.id);

      expect(location.dayKey, tomorrow);
      expect(location.status, CardStatus.active);
      expect(location.inTrash, isFalse);
    });

    test('找不到卡片时报 NotFound', () async {
      await expectLater(
        harness.service.findCard('00000000-0000-4000-8000-000000000000'),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('修改卡片内容', () {
    test('修改后画布上的卡片显示新的标题和备注，标题去掉首尾空格', () async {
      final card = await newCard(title: '买菜');

      await harness.service.updateCardContent(
        card.id,
        title: ' 买菜和水果 ',
        note: '牛奶\n苹果',
      );

      final updated = await cardOnBoard(card.id);
      expect(updated.title, '买菜和水果');
      expect(updated.note, '牛奶\n苹果');
    });

    test('可以清空备注', () async {
      final card = await newCard();
      await harness.service.updateCardContent(
        card.id,
        title: '卡片',
        note: '旧备注',
      );

      await harness.service.updateCardContent(card.id, title: '卡片', note: null);

      expect((await cardOnBoard(card.id)).note, isNull);
    });

    test('标题为空时拒绝修改，卡片内容不变', () async {
      final card = await newCard(title: '买菜');

      await expectLater(
        harness.service.updateCardContent(card.id, title: '  ', note: '备注'),
        throwsA(isA<InvalidInput>()),
      );

      final unchanged = await cardOnBoard(card.id);
      expect(unchanged.title, '买菜');
      expect(unchanged.note, isNull);
    });

    test('标题超过 200 个字时拒绝修改', () async {
      final card = await newCard();

      await expectLater(
        harness.service.updateCardContent(
          card.id,
          title: '字' * 201,
          note: null,
        ),
        throwsA(isA<InvalidInput>()),
      );
    });

    test('备注最多 5000 个字：5000 个字可以保存，5001 个字被拒绝', () async {
      final card = await newCard();

      await harness.service.updateCardContent(
        card.id,
        title: '卡片',
        note: '字' * 5000,
      );
      expect((await cardOnBoard(card.id)).note, hasLength(5000));

      await expectLater(
        harness.service.updateCardContent(
          card.id,
          title: '卡片',
          note: '字' * 5001,
        ),
        throwsA(isA<InvalidInput>()),
      );
      expect((await cardOnBoard(card.id)).note, hasLength(5000));
    });

    test('卡片不存在时报 NotFound', () async {
      await expectLater(
        harness.service.updateCardContent('不存在', title: '标题', note: null),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('移动卡片', () {
    test('移动后卡片在新位置，并且显示在当天所有卡片的最上层', () async {
      final a = await newCard(title: 'A');
      final b = await newCard(title: 'B');
      final c = await newCard(title: 'C');

      await harness.service.moveCard(a.id, x: 300, y: 120);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((card) => card.title), ['B', 'C', 'A']);
      final moved = board.cards.last;
      expect((moved.x, moved.y), (300, 120));
      expect(moved.zIndex, greaterThan(b.zIndex));
      expect(moved.zIndex, greaterThan(c.zIndex));
    });

    test('依次移动几张卡片，最后移动的那张总在最上层', () async {
      final a = await newCard(title: 'A');
      final b = await newCard(title: 'B');

      await harness.service.moveCard(a.id, x: 10, y: 10);
      await harness.service.moveCard(b.id, x: 20, y: 20);
      await harness.service.moveCard(a.id, x: 30, y: 30);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((card) => card.title), ['B', 'A']);
    });

    test('卡片不存在时报 NotFound', () async {
      await expectLater(
        harness.service.moveCard('不存在', x: 0, y: 0),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('调整卡片大小', () {
    test('范围内的尺寸原样保存', () async {
      final card = await newCard();

      await harness.service.resizeCard(card.id, width: 250.5, height: 140);

      final resized = await cardOnBoard(card.id);
      expect((resized.width, resized.height), (250.5, 140));
    });

    test('小于下限时截断到 120×60，不报错', () async {
      final card = await newCard();

      await harness.service.resizeCard(card.id, width: 10, height: -5);

      final resized = await cardOnBoard(card.id);
      expect((resized.width, resized.height), (120, 60));
    });

    test('大于上限时截断到 600×400，不报错', () async {
      final card = await newCard();

      await harness.service.resizeCard(card.id, width: 1000, height: 401);

      final resized = await cardOnBoard(card.id);
      expect((resized.width, resized.height), (600, 400));
    });

    test('宽和高分别截断', () async {
      final card = await newCard();

      await harness.service.resizeCard(card.id, width: 119, height: 999);

      final resized = await cardOnBoard(card.id);
      expect((resized.width, resized.height), (120, 400));
    });

    test('卡片不存在时报 NotFound', () async {
      await expectLater(
        harness.service.resizeCard('不存在', width: 200, height: 100),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('修改卡片颜色', () {
    test('保存选中的 ARGB 颜色', () async {
      final card = await newCard();

      await harness.service.setCardColor(card.id, 0xFFB8D8F8);

      expect((await cardOnBoard(card.id)).colorArgb, 0xFFB8D8F8);
    });

    test('自定义的半透明颜色也原样保存', () async {
      final card = await newCard();

      await harness.service.setCardColor(card.id, 0x80123456);

      expect((await cardOnBoard(card.id)).colorArgb, 0x80123456);
    });

    test('卡片不存在时报 NotFound', () async {
      await expectLater(
        harness.service.setCardColor('不存在', 0xFFB8D8F8),
        throwsA(isA<NotFound>()),
      );
    });
  });

  group('画布数据流', () {
    test('数据变化时推送新的画布内容', () async {
      final titles = harness.service
          .watchDay(harness.today)
          .map((board) => board.cards.map((card) => card.title).toList());
      final expectation = expectLater(
        titles,
        emitsInOrder([
          <String>[],
          ['买菜'],
          ['买菜和水果'],
        ]),
      );
      await pumpEventQueue();

      final card = await newCard(title: '买菜');
      await pumpEventQueue();
      await harness.service.updateCardContent(
        card.id,
        title: '买菜和水果',
        note: null,
      );

      await expectation;
    });

    test('只包含这一天的卡片', () async {
      await newCard(title: '今天的');
      await harness.service.createCard(
        harness.today.addDays(1),
        x: 0,
        y: 0,
        title: '明天的',
      );

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((card) => card.title), ['今天的']);
    });
  });

  group('数据持久化', () {
    test('重建 service 后，新建和修改过的卡片都还在', () async {
      final card = await newCard(title: '买菜');
      await harness.service.updateCardContent(
        card.id,
        title: '买菜和水果',
        note: '牛奶',
      );
      await harness.service.moveCard(card.id, x: 320, y: 140);
      await harness.service.resizeCard(card.id, width: 240, height: 120);
      await harness.service.setCardColor(card.id, 0xFFB8D8F8);

      await harness.reopen();

      final restored = await cardOnBoard(card.id);
      expect(restored.title, '买菜和水果');
      expect(restored.note, '牛奶');
      expect((restored.x, restored.y), (320, 140));
      expect((restored.width, restored.height), (240, 120));
      expect(restored.colorArgb, 0xFFB8D8F8);
      expect(restored.dayKey, harness.today);
      expect(restored.status, CardStatus.active);
    });

    test('重建 service 后可以继续新建和修改卡片', () async {
      final first = await newCard(title: 'A');

      await harness.reopen();
      final second = await newCard(title: 'B');
      await harness.service.moveCard(first.id, x: 10, y: 10);

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((card) => card.id), [second.id, first.id]);
    });
  });

  group('存储失败', () {
    test('写入失败时新建卡片抛出 StorageFailure，画布上没有新卡片', () async {
      harness.failWrites = true;

      await expectLater(newCard(title: '买菜'), throwsA(isA<StorageFailure>()));

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards, isEmpty);
    });

    test('写入失败时修改卡片的操作都抛出 StorageFailure，卡片保持原样', () async {
      final card = await newCard(title: '买菜');
      final service = harness.service;
      harness.failWrites = true;

      final writes = <String, Future<void> Function()>{
        'updateCardContent': () =>
            service.updateCardContent(card.id, title: '新标题', note: '备注'),
        'moveCard': () => service.moveCard(card.id, x: 500, y: 500),
        'resizeCard': () =>
            service.resizeCard(card.id, width: 300, height: 200),
        'setCardColor': () => service.setCardColor(card.id, 0xFFB8D8F8),
      };
      for (final MapEntry(key: name, value: write) in writes.entries) {
        await expectLater(
          write(),
          throwsA(isA<StorageFailure>()),
          reason: name,
        );
      }

      final unchanged = await cardOnBoard(card.id);
      expect(unchanged.title, '买菜');
      expect(unchanged.note, isNull);
      expect((unchanged.x, unchanged.y), (0, 0));
      expect(unchanged.zIndex, card.zIndex);
      expect((unchanged.width, unchanged.height), (180, 88));
      expect(unchanged.colorArgb, 0xFFFFF3B0);
    });

    test('存储恢复正常后可以继续写入', () async {
      harness.failWrites = true;
      await expectLater(newCard(title: '买菜'), throwsA(isA<StorageFailure>()));

      harness.failWrites = false;
      await newCard(title: '买菜');

      final board = await harness.service.watchDay(harness.today).first;
      expect(board.cards.map((card) => card.title), ['买菜']);
    });

    test('输入不合法时仍然报 InvalidInput，而不是 StorageFailure', () async {
      harness.failWrites = true;

      await expectLater(newCard(title: ' '), throwsA(isA<InvalidInput>()));
    });

    test('卡片不存在时仍然报 NotFound，而不是 StorageFailure', () async {
      harness.failWrites = true;

      await expectLater(
        harness.service.moveCard('不存在', x: 0, y: 0),
        throwsA(isA<NotFound>()),
      );
    });
  });
}
