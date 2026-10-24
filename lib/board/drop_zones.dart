/// 拖动卡片时屏幕底部的投放区：✅ 完成、🗑️ 回收站。
///
/// 投放区固定在屏幕上，不跟着画布平移和缩放，所以按屏幕坐标判断指针在不在
/// 里面（[DropZoneLocator]）；卡片之间的碰撞仍然按画布坐标判断。
library;

import 'package:flutter/material.dart';

import '../app/planner_theme.dart';
import 'card_drag.dart';

/// 找出屏幕上的一个点落在哪个投放区里。和它显示的 [DropZoneBar] 配对使用。
class DropZoneLocator {
  final _keys = {for (final zone in DropZone.values) zone: GlobalKey()};

  /// 屏幕上的 [global] 所在的投放区；投放区没有显示、或者不在里面时为 null。
  DropZone? zoneAt(Offset global) {
    for (final MapEntry(key: zone, value: key) in _keys.entries) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      if ((Offset.zero & box.size).contains(box.globalToLocal(global))) {
        return zone;
      }
    }
    return null;
  }
}

/// 底部的两个投放区，指针所在的那个高亮。只用来显示，不接收指针，不影响
/// 画布的平移和缩放。避开 Android 的手势导航条。
class DropZoneBar extends StatelessWidget {
  const DropZoneBar({super.key, required this.locator, required this.active});

  /// 投放区的 key。
  static Key zoneKey(DropZone zone) => ValueKey('drop-zone-${zone.name}');

  /// 投放区的高度（逻辑像素）。
  static const height = 72.0;

  final DropZoneLocator locator;

  /// 指针所在的投放区；不在投放区里时为 null。
  final DropZone? active;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(PlannerTheme.space4),
          child: Row(
            spacing: PlannerTheme.space4,
            children: [
              for (final zone in DropZone.values)
                Expanded(
                  child: KeyedSubtree(
                    key: zoneKey(zone),
                    child: _Zone(
                      key: locator._keys[zone],
                      zone: zone,
                      active: zone == active,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Zone extends StatelessWidget {
  const _Zone({super.key, required this.zone, required this.active});

  final DropZone zone;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, textColor) = switch (zone) {
      DropZone.complete => (
        Icons.check_circle,
        '完成',
        PlannerTheme.completeZone,
        PlannerTheme.completeZoneText,
      ),
      DropZone.trash => (
        Icons.delete,
        '回收站',
        PlannerTheme.trashZone,
        PlannerTheme.trashZoneText,
      ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: DropZoneBar.height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.85 : 0.25),
        borderRadius: PlannerTheme.zoneRadius,
        border: Border.all(color: color, width: active ? 3 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: PlannerTheme.space2,
        children: [
          Icon(icon, color: active ? PlannerTheme.onZone : color),
          Text(
            label,
            style: TextStyle(
              color: active ? PlannerTheme.onZone : textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
