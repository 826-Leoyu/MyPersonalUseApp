import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/dot_grid.dart';

import 'board_harness.dart';

/// 画布背景的点阵：画布坐标上每隔 [DotGrid.spacing] 一个点，跟着画布平移和
/// 缩放，看起来点是画在画布上的（AC-5）。
void main() {
  group('点的位置', () {
    const size = Size(100, 60);

    test('没有平移和缩放时，从左上角起每隔 spacing 一个点', () {
      final dots = dotGridPositions(size, Matrix4.identity()).toList();

      expect(dots.first, Offset.zero);
      expect(dots, contains(const Offset(DotGrid.spacing, 0)));
      expect(dots, contains(const Offset(0, DotGrid.spacing)));
      expect(dots.every((d) => size.contains(d)), isTrue);
    });

    test('平移以后点跟着挪，铺满可视区域', () {
      final dots = dotGridPositions(
        size,
        Matrix4.translationValues(10, -5, 0),
      ).toList();

      expect(dots.first, const Offset(10, DotGrid.spacing - 5));
      expect(dots, contains(const Offset(10 + DotGrid.spacing, 19)));
      expect(dots.every((d) => size.contains(d)), isTrue);
    });

    test('往左上平移很远，点还是在可视区域里', () {
      final dots = dotGridPositions(
        size,
        Matrix4.translationValues(-1000, -1000, 0),
      ).toList();

      expect(dots, isNotEmpty);
      expect(dots.every((d) => size.contains(d)), isTrue);
    });

    test('放大两倍，点的间距也变成两倍', () {
      final dots = dotGridPositions(
        size,
        Matrix4.diagonal3Values(2, 2, 1),
      ).toList();

      expect(dots.first, Offset.zero);
      expect(dots[1], const Offset(2 * DotGrid.spacing, 0));
    });
  });

  testWidgets('画布下面铺着点阵，用画布的平移和缩放', (tester) async {
    final harness = BoardHarness();
    await harness.launch(tester);

    final grid = tester.widget<DotGrid>(find.byType(DotGrid));
    final canvas = tester.widget<BoardCanvas>(find.byType(BoardCanvas));
    expect(grid.transform, same(canvas.transform));

    await harness.dispose(tester);
  });
}
