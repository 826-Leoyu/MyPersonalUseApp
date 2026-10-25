import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import '../app/planner_theme.dart';
import '../planner/card_colors.dart';

/// 打开卡片的色板：8 种预设色和「自定义」。点预设色、或者在自定义色轮上
/// 点「确定」就调用 [onPick] 保存，保存成功（返回 true）才关闭色板；保存
/// 失败时色板留着，可以重选。「取消」关闭色板，颜色不变。
Future<void> showCardColorDialog(
  BuildContext context, {
  required int currentArgb,
  required Future<bool> Function(int argb) onPick,
}) => showDialog<void>(
  context: context,
  builder: (_) => _CardColorDialog(currentArgb: currentArgb, onPick: onPick),
);

class _CardColorDialog extends StatefulWidget {
  const _CardColorDialog({required this.currentArgb, required this.onPick});

  final int currentArgb;
  final Future<bool> Function(int argb) onPick;

  @override
  State<_CardColorDialog> createState() => _CardColorDialogState();
}

class _CardColorDialogState extends State<_CardColorDialog> {
  /// 正在保存选中的颜色；保存完之前不响应再次选择。
  bool _saving = false;

  /// 在自定义色轮上选的颜色；还在预设色板上时为 null。
  Color? _custom;

  Future<void> _pick(int argb) async {
    if (_saving) return;
    setState(() => _saving = true);
    final saved = await widget.onPick(argb);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancel = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('取消'),
    );
    if (_custom case final custom?) {
      return AlertDialog(
        title: const Text('自定义颜色'),
        content: ColorPicker(
          color: custom,
          onColorChanged: (color) => setState(() => _custom = color),
          pickersEnabled: const {
            ColorPickerType.primary: false,
            ColorPickerType.accent: false,
            ColorPickerType.wheel: true,
          },
          padding: EdgeInsets.zero,
        ),
        actions: [
          cancel,
          TextButton(
            onPressed: () => _pick(custom.toARGB32()),
            child: const Text('确定'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: const Text('卡片颜色'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (:name, :argb) in CardColors.presets)
            _Swatch(
              name: name,
              argb: argb,
              selected: argb == widget.currentArgb,
              onTap: () => _pick(argb),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _custom = Color(widget.currentArgb)),
          child: const Text('自定义…'),
        ),
        cancel,
      ],
    );
  }
}

/// 色板里的一个圆形色块；当前颜色上打勾。
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.argb,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int argb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(argb),
            shape: BoxShape.circle,
            border: Border.all(color: PlannerColors.of(context).swatchBorder),
          ),
          child: selected
              ? Icon(Icons.check, color: Color(cardTextColorArgb(argb)))
              : null,
        ),
      ),
    );
  }
}
