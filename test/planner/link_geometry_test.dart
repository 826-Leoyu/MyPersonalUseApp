import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/planner/link_geometry.dart';

void main() {
  group('起点和终点取距离最近的那一对边的中点', () {
    test('水平排列：从左卡片的右边中点连到右卡片的左边中点', () {
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 50),
        (x: 300, y: 0, width: 100, height: 50),
      );

      expect(curve.start, (x: 100.0, y: 25.0));
      expect(curve.end, (x: 300.0, y: 25.0));
    });

    test('垂直排列：从上卡片的下边中点连到下卡片的上边中点', () {
      final curve = linkCurve(
        (x: 0, y: 200, width: 100, height: 50),
        (x: 0, y: 0, width: 100, height: 50),
      );

      expect(curve.start, (x: 50.0, y: 200.0));
      expect(curve.end, (x: 50.0, y: 50.0));
    });

    test('斜对角时取真正最近的一对边，不按中心点的方向取', () {
      // 中心点水平方向差 200、垂直方向差 170，按方向会取左右两边（相距约 177.2）；
      // 真正最近的是起点右边中点和终点上边中点（相距约 122.1）。
      final curve = linkCurve(
        (x: 0, y: 0, width: 200, height: 60),
        (x: 150, y: 100, width: 300, height: 200),
      );

      expect(curve.start, (x: 200.0, y: 30.0));
      expect(curve.end, (x: 300.0, y: 100.0));
    });

    test('有几对边一样近时，按上、右、下、左的顺序取第一对，结果稳定', () {
      // 「起点右边 → 终点上边」和「起点下边 → 终点左边」都相距 150√2。
      final from = (x: 0.0, y: 0.0, width: 100.0, height: 100.0);
      final to = (x: 200.0, y: 200.0, width: 100.0, height: 100.0);

      final curve = linkCurve(from, to);

      expect(curve.start, (x: 100.0, y: 50.0));
      expect(curve.end, (x: 250.0, y: 200.0));
      expect(linkCurve(from, to), curve);
    });

    test('卡片重叠时取重合的那一对边中点，曲线缩成一个点', () {
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 100),
        (x: 50, y: 50, width: 100, height: 100),
      );

      expect(curve.start, (x: 100.0, y: 50.0));
      expect(curve.end, (x: 100.0, y: 50.0));
      expect(curve.control1, curve.start);
      expect(curve.control2, curve.end);
    });

    test('两张卡片完全叠在一起（中心点重合）时取两条上边的中点', () {
      const box = (x: 40.0, y: 60.0, width: 160.0, height: 100.0);

      final curve = linkCurve(box, box);

      expect(curve.start, (x: 120.0, y: 60.0));
      expect(curve.end, (x: 120.0, y: 60.0));
    });
  });

  group('控制点沿边的法线方向向外偏移，偏移量是两点距离的 40%，不超过 120', () {
    test('两点相距 200：控制点各向外偏移 80', () {
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 50),
        (x: 300, y: 0, width: 100, height: 50),
      );

      expect(curve.control1, (x: 180.0, y: 25.0));
      expect(curve.control2, (x: 220.0, y: 25.0));
    });

    test('两点相距 500：偏移量 200 超过上限，取 120', () {
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 50),
        (x: 600, y: 0, width: 100, height: 50),
      );

      expect(curve.control1, (x: 220.0, y: 25.0));
      expect(curve.control2, (x: 480.0, y: 25.0));
    });

    test('两点相距 300：偏移量正好 120', () {
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 50),
        (x: 400, y: 0, width: 100, height: 50),
      );

      expect(curve.control1, (x: 220.0, y: 25.0));
      expect(curve.control2, (x: 280.0, y: 25.0));
    });

    test('极短连线（相距 10）：控制点各偏移 4', () {
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 50),
        (x: 110, y: 0, width: 100, height: 50),
      );

      expect(curve.control1, (x: 104.0, y: 25.0));
      expect(curve.control2, (x: 106.0, y: 25.0));
    });

    test('垂直排列：控制点沿上下方向偏移', () {
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 50),
        (x: 0, y: 250, width: 100, height: 50),
      );

      expect(curve.control1, (x: 50.0, y: 130.0));
      expect(curve.control2, (x: 50.0, y: 170.0));
    });

    test('斜对角：起点沿右边法线向右，终点沿上边法线向上', () {
      // 两点 (200, 30) 和 (300, 100) 相距 √(100² + 70²) ≈ 122.066，偏移约 48.826。
      final curve = linkCurve(
        (x: 0, y: 0, width: 200, height: 60),
        (x: 150, y: 100, width: 300, height: 200),
      );

      expect(curve.control1.x, moreOrLessEquals(248.826, epsilon: 0.001));
      expect(curve.control1.y, 30.0);
      expect(curve.control2.x, 300.0);
      expect(curve.control2.y, moreOrLessEquals(51.174, epsilon: 0.001));
    });
  });

  group('点到连线曲线的距离', () {
    // 水平排列的两张卡片：曲线是 (100, 25) 到 (300, 25) 的直线段。
    final straight = linkCurve(
      (x: 0, y: 0, width: 100, height: 50),
      (x: 300, y: 0, width: 100, height: 50),
    );

    test('直线形状的曲线：中点正上方 50 的点距离 50', () {
      expect(
        distanceToLinkCurve(straight, (x: 200, y: -25)),
        moreOrLessEquals(50, epsilon: 1e-6),
      );
    });

    test('落在起点外侧的点：距离就是到起点的距离', () {
      expect(
        distanceToLinkCurve(straight, (x: 70, y: 65)),
        moreOrLessEquals(50, epsilon: 1e-6),
      );
    });

    test('落在终点外侧的点：距离就是到终点的距离', () {
      expect(
        distanceToLinkCurve(straight, (x: 330, y: -15)),
        moreOrLessEquals(50, epsilon: 1e-6),
      );
    });

    group('S 形曲线上的精度误差不超过 0.0001', () {
      // 上下错开的两张卡片：从 (50, 100) 连到 (270, 320)，两点相距约 311，
      // 偏移量取上限 120，控制点 (50, 220) 和 (270, 200)。
      final curve = linkCurve(
        (x: 0, y: 0, width: 100, height: 100),
        (x: 220, y: 320, width: 100, height: 100),
      );

      test('曲线是按 Spec 算出来的那一条', () {
        expect(curve.start, (x: 50.0, y: 100.0));
        expect(curve.control1, (x: 50.0, y: 220.0));
        expect(curve.control2, (x: 270.0, y: 200.0));
        expect(curve.end, (x: 270.0, y: 320.0));
      });

      // 用三次贝塞尔的定义独立算出 t = 1/3 处的点和切线，这个点不在等分采样点上。
      const t = 1 / 3;
      const u = 1 - t;
      final onCurve = (
        x:
            u * u * u * 50 +
            3 * u * u * t * 50 +
            3 * u * t * t * 270 +
            t * t * t * 270,
        y:
            u * u * u * 100 +
            3 * u * u * t * 220 +
            3 * u * t * t * 200 +
            t * t * t * 320,
      );
      // 导数 3[(1-t)²(P1-P0) + 2(1-t)t(P2-P1) + t²(P3-P2)]。
      final tangent = (
        x: 3 * (u * u * 0 + 2 * u * t * 220 + t * t * 0),
        y: 3 * (u * u * 120 + 2 * u * t * -20 + t * t * 120),
      );
      final length = math.sqrt(tangent.x * tangent.x + tangent.y * tangent.y);
      final normal = (x: -tangent.y / length, y: tangent.x / length);

      test('曲线上的点距离为 0', () {
        expect(
          distanceToLinkCurve(curve, onCurve),
          moreOrLessEquals(0, epsilon: 1e-4),
        );
      });

      test('沿法线离开曲线 10 的点距离为 10', () {
        final off = (
          x: onCurve.x + normal.x * 10,
          y: onCurve.y + normal.y * 10,
        );

        expect(
          distanceToLinkCurve(curve, off),
          moreOrLessEquals(10, epsilon: 1e-4),
        );
      });

      test('沿法线反方向离开曲线 12 的点距离为 12', () {
        final off = (
          x: onCurve.x - normal.x * 12,
          y: onCurve.y - normal.y * 12,
        );

        expect(
          distanceToLinkCurve(curve, off),
          moreOrLessEquals(12, epsilon: 1e-4),
        );
      });
    });

    test('缩成一个点的曲线：距离就是到那个点的距离', () {
      final point = linkCurve(
        (x: 0, y: 0, width: 100, height: 100),
        (x: 50, y: 50, width: 100, height: 100),
      );

      expect(
        distanceToLinkCurve(point, (x: 103, y: 54)),
        moreOrLessEquals(5, epsilon: 1e-6),
      );
    });
  });

  group('点击判定范围是屏幕上的 12 逻辑像素，按缩放比例换算成画布上的距离', () {
    // 曲线是 (100, 25) 到 (300, 25) 的直线段，点在中点正上方。
    final curve = linkCurve(
      (x: 0, y: 0, width: 100, height: 50),
      (x: 300, y: 0, width: 100, height: 50),
    );
    CanvasPoint above(double d) => (x: 200, y: 25 - d);

    test('不缩放：画布上相距 12 算点中，12.01 不算', () {
      expect(isNearLinkCurve(curve, above(12), scale: 1), isTrue);
      expect(isNearLinkCurve(curve, above(12.01), scale: 1), isFalse);
    });

    test('放大 2 倍：画布上相距 6 就是屏幕上 12，算点中；8 不算', () {
      expect(isNearLinkCurve(curve, above(6), scale: 2), isTrue);
      expect(isNearLinkCurve(curve, above(8), scale: 2), isFalse);
    });

    test('缩小到 0.5 倍：画布上相距 24 就是屏幕上 12，算点中；20 也算', () {
      expect(isNearLinkCurve(curve, above(24), scale: 0.5), isTrue);
      expect(isNearLinkCurve(curve, above(20), scale: 0.5), isTrue);
      expect(isNearLinkCurve(curve, above(24.1), scale: 0.5), isFalse);
    });
  });

  group('点中的连线：判定范围内离点击位置最近的那一条', () {
    // 三条水平直线段，都从 x = 100 到 x = 300：y = 25、y = 45、y = 65。
    LinkCurve horizontalAt(double y) => linkCurve(
      (x: 0, y: y - 25, width: 100, height: 50),
      (x: 300, y: y - 25, width: 100, height: 50),
    );
    final curves = {
      'top': horizontalAt(25),
      'middle': horizontalAt(45),
      'bottom': horizontalAt(65),
    };

    test('判定范围内有几条时取最近的', () {
      expect(linkAt(curves, (x: 200, y: 37), scale: 1), 'middle');
      expect(linkAt(curves, (x: 200, y: 33), scale: 1), 'top');
      expect(linkAt(curves, (x: 200, y: 58), scale: 1), 'bottom');
    });

    test('一条也不在判定范围内时没有点中', () {
      expect(linkAt(curves, (x: 200, y: 78), scale: 1), isNull);
      expect(linkAt(curves, (x: 330, y: 45), scale: 1), isNull);
      expect(linkAt(const {}, (x: 200, y: 45), scale: 1), isNull);
    });

    test('判定范围按缩放比例换算：3 倍时画布上相距 4 算点中，5 不算', () {
      expect(linkAt(curves, (x: 200, y: 69), scale: 3), 'bottom');
      expect(linkAt(curves, (x: 200, y: 70), scale: 3), isNull);
    });

    test('一样近时（曲线重叠）取后画的那条，也就是画在上面的，结果稳定', () {
      final overlapping = {
        'below': curves['middle']!,
        'above': curves['middle']!,
      };
      expect(linkAt(overlapping, (x: 200, y: 40), scale: 1), 'above');
      final swapped = {'above': curves['middle']!, 'below': curves['middle']!};
      expect(linkAt(swapped, (x: 200, y: 40), scale: 1), 'below');
    });
  });
}
