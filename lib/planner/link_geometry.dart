import 'dart:math' as math;

/// 画布上的一个点（画布坐标）。
typedef CanvasPoint = ({double x, double y});

/// 一张卡片在画布上占的矩形。
typedef CardBox = ({double x, double y, double width, double height});

/// 一条连线的三次贝塞尔曲线：[start] 在起点卡片上，[end] 在终点卡片上。
typedef LinkCurve = ({
  CanvasPoint start,
  CanvasPoint control1,
  CanvasPoint control2,
  CanvasPoint end,
});

/// 控制点偏移量的上限。
const maxControlOffset = 120.0;

/// 卡片的一条边。距离一样时按这里的顺序取第一个，所以结果是稳定的。
enum _Side { top, right, bottom, left }

/// 这条边向外的法线方向（单位向量）。
CanvasPoint _outward(_Side side) => switch (side) {
  _Side.top => (x: 0, y: -1),
  _Side.right => (x: 1, y: 0),
  _Side.bottom => (x: 0, y: 1),
  _Side.left => (x: -1, y: 0),
};

CanvasPoint _midpoint(CardBox box, _Side side) => switch (side) {
  _Side.top => (x: box.x + box.width / 2, y: box.y),
  _Side.right => (x: box.x + box.width, y: box.y + box.height / 2),
  _Side.bottom => (x: box.x + box.width / 2, y: box.y + box.height),
  _Side.left => (x: box.x, y: box.y + box.height / 2),
};

double _distance(CanvasPoint a, CanvasPoint b) =>
    math.sqrt(_squaredDistance(a, b));

double _squaredDistance(CanvasPoint a, CanvasPoint b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return dx * dx + dy * dy;
}

/// 从 [from] 连到 [to] 的连线曲线。
///
/// 起点和终点取两张卡片距离最近的那一对边的中点。控制点从起点、终点沿各自那条边
/// 向外的法线方向偏移，偏移量是两点距离的 40%，不超过 [maxControlOffset]。
LinkCurve linkCurve(CardBox from, CardBox to) {
  var best = (from: _Side.top, to: _Side.top);
  var bestDistance = double.infinity;
  for (final fromSide in _Side.values) {
    for (final toSide in _Side.values) {
      final d = _squaredDistance(
        _midpoint(from, fromSide),
        _midpoint(to, toSide),
      );
      if (d < bestDistance) {
        best = (from: fromSide, to: toSide);
        bestDistance = d;
      }
    }
  }
  final start = _midpoint(from, best.from);
  final end = _midpoint(to, best.to);
  final offset = math.min(_distance(start, end) * 0.4, maxControlOffset);
  CanvasPoint push(CanvasPoint p, _Side side) {
    final n = _outward(side);
    return (x: p.x + n.x * offset, y: p.y + n.y * offset);
  }

  return (
    start: start,
    control1: push(start, best.from),
    control2: push(end, best.to),
    end: end,
  );
}

/// 曲线上参数为 [t]（0 到 1）的点。
CanvasPoint _pointAt(LinkCurve curve, double t) {
  final u = 1 - t;
  final a = u * u * u;
  final b = 3 * u * u * t;
  final c = 3 * u * t * t;
  final d = t * t * t;
  return (
    x:
        a * curve.start.x +
        b * curve.control1.x +
        c * curve.control2.x +
        d * curve.end.x,
    y:
        a * curve.start.y +
        b * curve.control1.y +
        c * curve.control2.y +
        d * curve.end.y,
  );
}

/// 求距离时先在曲线上等分取这么多段，找到最近的采样点。
const _samples = 64;

/// 然后在最近的采样点两侧各一段的范围里，用三分法细化这么多次。
/// 每次范围缩小到 2/3，细化后参数的误差约 (2/64)·(2/3)^40 ≈ 3×10⁻⁹。
const _refinements = 40;

/// [point] 到 [curve] 的最短距离（画布坐标）。
///
/// 结果的误差远小于 0.0001 逻辑像素，见测试。
double distanceToLinkCurve(LinkCurve curve, CanvasPoint point) {
  double at(double t) => _distance(_pointAt(curve, t), point);
  var nearest = 0;
  for (var i = 1; i <= _samples; i++) {
    if (at(i / _samples) < at(nearest / _samples)) nearest = i;
  }
  var low = math.max(0, nearest - 1) / _samples;
  var high = math.min(_samples, nearest + 1) / _samples;
  for (var i = 0; i < _refinements; i++) {
    final a = low + (high - low) / 3;
    final b = high - (high - low) / 3;
    if (at(a) < at(b)) {
      high = b;
    } else {
      low = a;
    }
  }
  return math.min(at(nearest / _samples), at((low + high) / 2));
}

/// 点击连线的判定范围：屏幕上的逻辑像素，不随缩放变化。
const linkHitRadius = 12.0;

/// 画布上的 [point] 算不算点中了 [curve]。
///
/// [scale] 是画布当前的缩放比例：判定范围是屏幕上的 [linkHitRadius]，
/// 换算成画布上的距离是 [linkHitRadius] / [scale]。
bool isNearLinkCurve(
  LinkCurve curve,
  CanvasPoint point, {
  required double scale,
}) => distanceToLinkCurve(curve, point) <= linkHitRadius / scale;
