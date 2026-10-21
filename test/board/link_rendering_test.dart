import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/app/providers.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/link_layer.dart';
import 'package:my_personal_use_app/planner/planner_service.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 动画在时长到了之后的下一帧才算结束。
const _nextFrame = Duration(milliseconds: 16);

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在今天的画布上准备一张卡片（默认 180 × 88）。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    required String title,
    required double x,
    double y = 60,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  /// 在启动 App 之前连一条 [from] → [to] 的线，返回连线 ID。
  Future<String> seedLink(WidgetTester tester, TaskCard from, TaskCard to) =>
      harness.seed(
        tester,
        (service) async => (await service.toggleLink(from.id, to.id)).linkId,
      );

  /// 连线层现在画着的连线。
  List<PaintedLink> shownLinks(WidgetTester tester) {
    final layer = tester.widget<CustomPaint>(find.byKey(LinkLayer.paintKey));
    return (layer.painter! as LinkPainter).links;
  }

  /// 连线层画着的那条 ID 为 [linkId] 的连线。
  PaintedLink shownLink(WidgetTester tester, String linkId) =>
      shownLinks(tester).singleWhere((l) => l.id == linkId);

  testWidgets('两张卡片之间的连线画在最近的那一对边中点之间', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    final linkId = await seedLink(tester, a, b);
    await harness.launch(tester);

    final link = shownLink(tester, linkId);
    expect(shownLinks(tester), hasLength(1));
    expect(link.curve.start, (x: 220.0, y: 104.0));
    expect(link.curve.end, (x: 400.0, y: 104.0));

    await harness.dispose(tester);
  });

  testWidgets('一张卡片同时有多条连入和连出的连线，都画出来（AC-18）', (tester) async {
    // C 在中间：A 在左边、B 在右边、D 在上面。
    final c = await seedCard(tester, title: 'C', x: 400, y: 300);
    final a = await seedCard(tester, title: 'A', x: 40, y: 300);
    final b = await seedCard(tester, title: 'B', x: 800, y: 300);
    final d = await seedCard(tester, title: 'D', x: 400, y: 40);
    final aToC = await seedLink(tester, a, c);
    final cToB = await seedLink(tester, c, b);
    final dToC = await seedLink(tester, d, c);
    await harness.launch(tester);

    expect(shownLinks(tester), hasLength(3));
    final first = shownLink(tester, aToC).curve;
    expect(
      (first.start, first.end),
      ((x: 220.0, y: 344.0), (x: 400.0, y: 344.0)),
    );
    final second = shownLink(tester, cToB).curve;
    expect(
      (second.start, second.end),
      ((x: 580.0, y: 344.0), (x: 800.0, y: 344.0)),
    );
    final third = shownLink(tester, dToC).curve;
    expect(
      (third.start, third.end),
      ((x: 490.0, y: 128.0), (x: 490.0, y: 300.0)),
    );

    await harness.dispose(tester);
  });

  group('只画满足显示规则的连线', () {
    testWidgets('一端已完成的连线不画，另一条照常画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40, y: 300);
      await seedLink(tester, a, b);
      final kept = await seedLink(tester, a, c);
      await harness.seed(tester, (service) => service.completeCard(b.id));
      await harness.launch(tester);

      expect(shownLinks(tester).map((l) => l.id), [kept]);

      await harness.dispose(tester);
    });

    testWidgets('一端在回收站里的连线不画，另一条照常画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40, y: 300);
      await seedLink(tester, a, b);
      final kept = await seedLink(tester, a, c);
      await harness.seed(tester, (service) => service.deleteCard(b.id));
      await harness.launch(tester);

      expect(shownLinks(tester).map((l) => l.id), [kept]);

      await harness.dispose(tester);
    });

    testWidgets('两端不在同一天的连线不画，另一条照常画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40, y: 300);
      await seedLink(tester, a, b);
      final kept = await seedLink(tester, a, c);
      await harness.moveCardToDay(tester, b.id, harness.today.addDays(1));
      await harness.launch(tester);

      expect(shownLinks(tester).map((l) => l.id), [kept]);

      await harness.dispose(tester);
    });

    testWidgets('断开的连线不画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await seedLink(tester, a, b);
      await harness.seed(tester, (service) => service.removeLink(linkId));
      await harness.launch(tester);

      expect(shownLinks(tester), isEmpty);

      await harness.dispose(tester);
    });
  });

  group('连线实时跟着卡片', () {
    Finder cardFinder(TaskCard card) =>
        find.byKey(BoardCanvas.cardKey(card.id));

    testWidgets('拖动过程中连线跟着卡片的临时位置，松手后停在新位置', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await seedLink(tester, a, b);
      await harness.launch(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(cardFinder(a)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();

      expect(shownLink(tester, linkId).curve.start, (x: 220.0, y: 164.0));

      await gesture.up();
      await harness.settle(tester);

      expect(shownLink(tester, linkId).curve.start, (x: 220.0, y: 164.0));

      await harness.dispose(tester);
    });

    testWidgets('拖动后保存失败，连线跟着卡片回到原来的位置', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await seedLink(tester, a, b);
      await harness.launch(tester);
      harness.failWrites = true;

      await tester.drag(cardFinder(a), const Offset(0, 60));
      await harness.settle(tester);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(shownLink(tester, linkId).curve.start, (x: 220.0, y: 104.0));

      await harness.dispose(tester);
    });

    /// 单击卡片选中它，显示右下角的手柄。
    Future<void> select(WidgetTester tester, TaskCard card) async {
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }

    Finder handleFinder(TaskCard card) =>
        find.byKey(BoardCanvas.resizeHandleKey(card.id));

    testWidgets('调整大小过程中连线跟着新的大小，松手后停在新位置', (tester) async {
      // A 在 B 上面：连线从 A 的下边中点连到 B 的上边中点。
      final a = await seedCard(tester, title: 'A', x: 40, y: 40);
      final b = await seedCard(tester, title: 'B', x: 40, y: 400);
      final linkId = await seedLink(tester, a, b);
      await harness.launch(tester);
      expect(shownLink(tester, linkId).curve.start, (x: 130.0, y: 128.0));
      await select(tester, a);

      final gesture = await tester.startGesture(
        tester.getCenter(handleFinder(a)),
      );
      await gesture.moveBy(const Offset(20, 20));
      await gesture.moveBy(const Offset(20, 20));
      await tester.pump();

      // 宽 180 → 220、高 88 → 128，下边中点从 (130, 128) 移到 (150, 168)。
      expect(shownLink(tester, linkId).curve.start, (x: 150.0, y: 168.0));

      await gesture.up();
      await harness.settle(tester);

      expect(shownLink(tester, linkId).curve.start, (x: 150.0, y: 168.0));

      await harness.dispose(tester);
    });

    testWidgets('调整大小后保存失败，连线跟着卡片回到原来的大小', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40, y: 40);
      final b = await seedCard(tester, title: 'B', x: 40, y: 400);
      final linkId = await seedLink(tester, a, b);
      await harness.launch(tester);
      await select(tester, a);
      harness.failWrites = true;

      await tester.drag(handleFinder(a), const Offset(40, 40));
      await harness.settle(tester);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(tester.getSize(cardFinder(a)), const Size(180, 88));
      expect(shownLink(tester, linkId).curve.start, (x: 130.0, y: 128.0));

      await harness.dispose(tester);
    });
  });

  group('连线动画', () {
    /// App 运行中通过它自己的 service 写入，然后只让新的画布内容显示出来，
    /// 不推进动画的时间。
    Future<T> write<T>(
      WidgetTester tester,
      Future<T> Function(PlannerService service) action,
    ) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BoardCanvas)),
      );
      final result = await tester.runAsync(() async {
        final service = await container.read(plannerServiceProvider.future);
        return action(service);
      });
      await harness.pumpData(tester);
      return result as T;
    }

    testWidgets('打开 App 时已经有的连线直接画好，不播动画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await seedLink(tester, a, b);

      await harness.launch(tester, settleAnimations: false);

      expect(shownLink(tester, linkId).progress, 1);
      expect(shownLink(tester, linkId).opacity, 1);
      expect(tester.hasRunningAnimations, isFalse);

      await harness.dispose(tester);
    });

    testWidgets('新连线用 300ms 从起点画到终点', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      await harness.launch(tester);

      final linkId = await write(
        tester,
        (service) async => (await service.toggleLink(a.id, b.id)).linkId,
      );

      expect(shownLink(tester, linkId).progress, 0);
      expect(shownLink(tester, linkId).curve.end, (x: 400.0, y: 104.0));
      await tester.pump(const Duration(milliseconds: 150));
      expect(shownLink(tester, linkId).progress, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(shownLink(tester, linkId).progress, 1);
      expect(shownLink(tester, linkId).opacity, 1);

      await harness.dispose(tester);
    });

    testWidgets('断开的连线用 200ms 淡出，然后不再画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await seedLink(tester, a, b);
      await harness.launch(tester);

      await write(tester, (service) => service.removeLink(linkId));

      expect(shownLink(tester, linkId).opacity, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownLink(tester, linkId).opacity, inExclusiveRange(0, 1));
      expect(shownLink(tester, linkId).curve.end, (x: 400.0, y: 104.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownLink(tester, linkId).opacity, 0);
      await tester.pump(_nextFrame);
      expect(shownLinks(tester), isEmpty);

      await harness.dispose(tester);
    });

    for (final (name, hide) in [
      ('完成', (PlannerService s, String id) => s.completeCard(id)),
      ('删除', (PlannerService s, String id) => s.deleteCard(id)),
    ]) {
      testWidgets('$name卡片后，它的连线停在最后的位置淡出', (tester) async {
        final a = await seedCard(tester, title: 'A', x: 40);
        final b = await seedCard(tester, title: 'B', x: 400);
        final linkId = await seedLink(tester, a, b);
        await harness.launch(tester);

        await write(tester, (service) => hide(service, b.id));

        expect(find.byKey(BoardCanvas.cardKey(b.id)), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        final fading = shownLink(tester, linkId);
        expect(fading.opacity, inExclusiveRange(0, 1));
        expect(fading.curve.start, (x: 220.0, y: 104.0));
        expect(fading.curve.end, (x: 400.0, y: 104.0));
        await tester.pump(const Duration(milliseconds: 100));
        expect(shownLink(tester, linkId).opacity, 0);
        await tester.pump(_nextFrame);
        expect(shownLinks(tester), isEmpty);

        await harness.dispose(tester);
      });
    }

    testWidgets('画布内容重复推送、连线没有增减时，已画好的连线不重播动画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40, y: 300);
      final linkId = await seedLink(tester, a, b);
      await harness.launch(tester);

      await write(tester, (service) => service.moveCard(c.id, x: 60, y: 320));
      await write(tester, (service) => service.setCardColor(c.id, 0xFFCCE4FF));

      expect(shownLink(tester, linkId).progress, 1);
      expect(shownLink(tester, linkId).opacity, 1);
      expect(tester.hasRunningAnimations, isFalse);

      await harness.dispose(tester);
    });

    testWidgets('画到一半时画布内容又推送一次，动画接着画，不从头开始', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40, y: 300);
      await harness.launch(tester);
      final linkId = await write(
        tester,
        (service) async => (await service.toggleLink(a.id, b.id)).linkId,
      );
      await tester.pump(const Duration(milliseconds: 150));
      final halfway = shownLink(tester, linkId).progress;

      await write(tester, (service) => service.moveCard(c.id, x: 60, y: 320));

      expect(shownLink(tester, linkId).progress, halfway);
      await tester.pump(const Duration(milliseconds: 150));
      expect(shownLink(tester, linkId).progress, 1);

      await harness.dispose(tester);
    });

    testWidgets('淡出到一半时连线又回来了：只画一条，重新画出来', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await seedLink(tester, a, b);
      await harness.launch(tester);
      await write(tester, (service) => service.removeLink(linkId));
      await tester.pump(const Duration(milliseconds: 100));

      await write(tester, (service) => service.restoreLink(linkId));

      expect(shownLinks(tester).where((l) => l.id == linkId), hasLength(1));
      expect(shownLink(tester, linkId).opacity, 1);
      expect(shownLink(tester, linkId).progress, 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(shownLinks(tester).where((l) => l.id == linkId), hasLength(1));
      expect(shownLink(tester, linkId).progress, 1);
      expect(shownLink(tester, linkId).opacity, 1);

      await harness.dispose(tester);
    });

    testWidgets('画到一半时被断开：停在画到的地方淡出，然后不再画', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      await harness.launch(tester);
      final linkId = await write(
        tester,
        (service) async => (await service.toggleLink(a.id, b.id)).linkId,
      );
      await tester.pump(const Duration(milliseconds: 150));
      final halfway = shownLink(tester, linkId).progress;

      await write(tester, (service) => service.removeLink(linkId));

      expect(shownLinks(tester).where((l) => l.id == linkId), hasLength(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(shownLink(tester, linkId).progress, halfway);
      expect(shownLink(tester, linkId).opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(_nextFrame);
      expect(shownLinks(tester), isEmpty);
      expect(tester.hasRunningAnimations, isFalse);

      await harness.dispose(tester);
    });

    testWidgets('动画进行中关掉画布，不报错', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40, y: 300);
      final fading = await seedLink(tester, a, b);
      await harness.launch(tester);
      await write(tester, (service) => service.removeLink(fading));
      await write(tester, (service) => service.toggleLink(a.id, c.id));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await harness.dispose(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('切换日期：前一天正在淡出的连线不会留在新的一天，新的一天的连线直接画好', (tester) async {
      final tomorrow = harness.today.addDays(1);
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40);
      final d = await seedCard(tester, title: 'D', x: 400);
      await harness.moveCardToDay(tester, c.id, tomorrow);
      await harness.moveCardToDay(tester, d.id, tomorrow);
      final todayLink = await seedLink(tester, a, b);
      final tomorrowLink = await seedLink(tester, c, d);
      await harness.launch(tester);
      await write(tester, (service) => service.removeLink(todayLink));
      await tester.pump(const Duration(milliseconds: 50));

      await harness.showDay(tester, tomorrow);

      expect(find.byKey(BoardCanvas.cardKey(c.id)), findsOneWidget);
      expect(shownLinks(tester).map((l) => l.id), [tomorrowLink]);
      expect(shownLink(tester, tomorrowLink).progress, 1);
      expect(tester.hasRunningAnimations, isFalse);

      await harness.dispose(tester);
    });

    testWidgets('切回已经看过的日期：另一天正在淡出的连线不会留下，这一天的连线不重播动画', (tester) async {
      final tomorrow = harness.today.addDays(1);
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final c = await seedCard(tester, title: 'C', x: 40);
      final d = await seedCard(tester, title: 'D', x: 400);
      await harness.moveCardToDay(tester, c.id, tomorrow);
      await harness.moveCardToDay(tester, d.id, tomorrow);
      final todayLink = await seedLink(tester, a, b);
      final tomorrowLink = await seedLink(tester, c, d);
      await harness.launch(tester);
      await harness.showDay(tester, tomorrow);
      await write(tester, (service) => service.removeLink(tomorrowLink));
      await tester.pump(const Duration(milliseconds: 50));

      await harness.showDay(tester, harness.today);

      expect(find.byKey(BoardCanvas.cardKey(a.id)), findsOneWidget);
      expect(shownLinks(tester).map((l) => l.id), [todayLink]);
      expect(shownLink(tester, todayLink).progress, 1);
      expect(tester.hasRunningAnimations, isFalse);

      await harness.dispose(tester);
    });
  });
}
