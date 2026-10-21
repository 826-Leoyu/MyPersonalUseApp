import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/link_layer.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

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
}
