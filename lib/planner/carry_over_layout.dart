import 'dart:math';

import 'day_key.dart';

/// 一张要顺延的卡片顺延前的样子。
typedef CarryOverSource = ({
  String id,
  DayKey dayKey,
  double x,
  double y,
  double width,
  double height,
  int zIndex,
});

/// 一张顺延卡片在今天画布上的新位置和层级。
typedef CarryOverPlacement = ({double x, double y, int zIndex});

/// 顺延排布的结果：每张顺延卡片的新位置，以及今天已有卡片要右移多少。
typedef CarryOverLayout = ({
  Map<String, CarryOverPlacement> placements,
  double todayShift,
});

/// 按 spec「顺延排布算法」计算顺延卡片在今天画布上的位置。
///
/// 每个原日期一组，每组按自己的外接矩形对齐，保留组内相对位置（组内原来
/// 就重叠的卡片不重新排）。各组按日期从早到晚、从上到下堆叠，组间距
/// [_gap]，整体从 ([_margin], [_margin]) 开始。
///
/// 今天已有的卡片统一右移，保证和顺延区之间至少隔 [_gap]。[todayMinX] 是
/// 今天已有卡片的最小 x，今天没有卡片时为 null。
///
/// 顺延卡片放在今天已有卡片上面：按原日期、原 zIndex、卡片 ID 排序，从
/// [todayMaxZIndex] + 1 开始依次编号。今天已有卡片的层级不变。
CarryOverLayout layoutCarryOver(
  Iterable<CarryOverSource> cards, {
  required double? todayMinX,
  required int todayMaxZIndex,
}) {
  final groups = <DayKey, List<CarryOverSource>>{};
  for (final card in cards) {
    groups.putIfAbsent(card.dayKey, () => []).add(card);
  }
  final days = groups.keys.toList()..sort();
  final stacking = cards.toList()
    ..sort(
      (a, b) => switch (a.dayKey.compareTo(b.dayKey)) {
        0 => switch (a.zIndex.compareTo(b.zIndex)) {
          0 => a.id.compareTo(b.id),
          final byZIndex => byZIndex,
        },
        final byDay => byDay,
      },
    );
  final zIndexOf = {
    for (final (i, card) in stacking.indexed) card.id: todayMaxZIndex + 1 + i,
  };
  final placements = <String, CarryOverPlacement>{};
  var groupTop = _margin;
  var regionWidth = 0.0;
  for (final day in days) {
    final group = groups[day]!;
    final left = group.map((c) => c.x).reduce(min);
    final top = group.map((c) => c.y).reduce(min);
    final right = group.map((c) => c.x + c.width).reduce(max);
    final bottom = group.map((c) => c.y + c.height).reduce(max);
    regionWidth = max(regionWidth, right - left);
    for (final card in group) {
      placements[card.id] = (
        x: _margin + card.x - left,
        y: groupTop + card.y - top,
        zIndex: zIndexOf[card.id]!,
      );
    }
    groupTop += bottom - top + _gap;
  }
  // spec 写的是右移"顺延区宽度 + 48"；今天的卡片在 x < 24 时这样不够，
  // 所以再保证移动后最左边的卡片离顺延区右边缘至少 48。
  final todayShift = todayMinX == null || placements.isEmpty
      ? 0.0
      : max(regionWidth + _gap, _margin + regionWidth + _gap - todayMinX);
  return (placements: placements, todayShift: todayShift);
}

/// 顺延区离今天画布左上角的边距。
const _margin = 24.0;

/// 顺延区里相邻两组之间的间距，也是顺延区和今天已有卡片之间的最小间距。
const _gap = 48.0;
