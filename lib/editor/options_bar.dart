import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/editor_controller.dart';
import '../canvas/image_ops.dart';
import '../canvas/tool_settings.dart';
import '../l10n/l10n.dart';
import '../painting/color_matrix.dart';
import '../shell/platform.dart';
import '../shell/ribbon_controls.dart';
import '../shell/ribbon_style.dart';
import 'dialogs.dart';
import 'tool_catalog.dart';

/// What the menus ask of the screen, because it needs a dialog.
class OptionsBarActions {
  const OptionsBarActions({
    required this.resize,
    required this.renameLayer,
    required this.adjust,
  });

  final VoidCallback resize;
  final VoidCallback renameLayer;
  final ValueChanged<Adjustment> adjust;
}

/// The slim bar under the title: the menus and the options of the tool.
class OptionsBar extends StatelessWidget {
  const OptionsBar({
    required this.controller,
    required this.actions,
    super.key,
  });

  static const height = 40.0;

  final EditorController controller;
  final OptionsBarActions actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ..._menus(context.l10n),
                const _Divider(),
                ..._toolOptions(context.l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _menus(AppLocalizations l10n) {
    final c = controller;
    final layers = c.document.layers.length;
    final index = c.document.activeIndex;
    final selected = c.hasSelection;
    return [
      _Menu(l10n.menuImage, [
        _item(l10n.resizeImage, actions.resize),
        _item(l10n.cropToSelection, selected ? c.cropToSelection : null),
        const Divider(color: RibbonColors.divider),
        _item(l10n.rotateLeft, () => c.turn(Turn.left)),
        _item(l10n.rotateRight, () => c.turn(Turn.right)),
        _item(l10n.flipHorizontal, () => c.turn(Turn.flipHorizontal)),
        _item(l10n.flipVertical, () => c.turn(Turn.flipVertical)),
        const Divider(color: RibbonColors.divider),
        _item(l10n.flattenImage, layers > 1 ? c.flatten : null),
      ]),
      _Menu(l10n.menuLayer, [
        _item(l10n.newLayer, c.addLayer),
        _item(l10n.duplicateLayer, c.duplicateLayer),
        _item(l10n.deleteLayer, layers > 1 ? c.deleteLayer : null),
        _item(l10n.renameLayer, actions.renameLayer),
        const Divider(color: RibbonColors.divider),
        _item(l10n.mergeDown, c.canMergeDown ? c.mergeDown : null),
        _item(l10n.raiseLayer, index < layers - 1 ? c.raiseLayer : null),
        _item(l10n.lowerLayer, index > 0 ? c.lowerLayer : null),
      ]),
      _Menu(l10n.menuSelect, [
        _item(l10n.selectAll, c.selectAll, keys: shortcutLabel('A')),
        _item(
          l10n.deselect,
          selected ? c.deselect : null,
          keys: shortcutLabel('D'),
        ),
        _item(l10n.invertSelection, selected ? c.invertSelection : null),
        const Divider(color: RibbonColors.divider),
        _item(l10n.fillSelection, c.canPaint ? c.fillSelection : null),
        _item(l10n.deleteSelection, c.canPaint ? c.deleteSelection : null),
      ]),
      _Menu(l10n.menuAdjustments, [
        _item(
          l10n.brightnessContrast,
          () => actions.adjust(Adjustment.brightnessContrast),
        ),
        _item(
          l10n.hueSaturation,
          () => actions.adjust(Adjustment.hueSaturation),
        ),
        const Divider(color: RibbonColors.divider),
        _item(
          l10n.invertColors,
          () => c.applyFilter(const ColorFilter.matrix(invertMatrix)),
        ),
        _item(
          l10n.grayscale,
          () => c.applyFilter(ColorFilter.matrix(saturationMatrix(-1))),
        ),
      ]),
    ];
  }

  List<Widget> _toolOptions(AppLocalizations l10n) {
    final settings = controller.settings;
    final tool = settings.tool;
    final paints = tool.usesOpacity || tool == EditTool.text;
    return [
      IconTheme(
        data: const IconThemeData(color: RibbonColors.text, size: 18),
        child: ToolIcon(tool),
      ),
      const SizedBox(width: 8),
      Text(toolName(l10n, tool), style: RibbonText.activeTab),
      const SizedBox(width: 16),
      if (tool.usesSize)
        _Option(
          label: l10n.brushSize,
          value: l10n.sizePixels(settings.size.round()),
          // a log scale gives the small sizes room on the slider
          position:
              math.log(settings.size / minBrushSize) /
              math.log(maxBrushSize / minBrushSize),
          onChanged: (position) => settings.size =
              minBrushSize * math.pow(maxBrushSize / minBrushSize, position),
        ),
      if (tool.usesOpacity)
        _Option(
          label: l10n.opacity,
          value: l10n.percent((settings.opacity * 100).round()),
          position: settings.opacity,
          onChanged: (position) => settings.opacity = position,
        ),
      if (tool == EditTool.brush || tool == EditTool.eraser)
        _Option(
          label: l10n.hardness,
          value: l10n.percent((settings.hardness * 100).round()),
          position: settings.hardness,
          onChanged: (position) => settings.hardness = position,
        ),
      if (tool == EditTool.fill)
        _Option(
          label: l10n.tolerance,
          value: '${settings.tolerance}',
          position: settings.tolerance / 255,
          onChanged: (position) =>
              settings.tolerance = (position * 255).round(),
        ),
      if (tool == EditTool.rectangle || tool == EditTool.ellipse) ...[
        RibbonIconButton(
          icon: Icons.crop_square,
          tooltip: l10n.shapeOutline,
          selected: !settings.filled,
          onPressed: () => settings.filled = false,
        ),
        const SizedBox(width: 2),
        RibbonIconButton(
          icon: Icons.square,
          tooltip: l10n.shapeFilled,
          selected: settings.filled,
          onPressed: () => settings.filled = true,
        ),
        const SizedBox(width: 12),
      ],
      if (controller.cropArea != null) ...[
        _BandButton(
          label: l10n.applyCrop,
          filled: true,
          onPressed: controller.applyCrop,
        ),
        const SizedBox(width: 6),
        _BandButton(label: l10n.cancelCrop, onPressed: controller.deselect),
      ],
      if (paints && !controller.canPaint)
        Row(
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              size: 16,
              color: RibbonColors.muted,
            ),
            const SizedBox(width: 6),
            Text(l10n.hiddenLayerHint, style: RibbonText.label),
          ],
        ),
    ];
  }

  static Widget _item(String label, VoidCallback? onPressed, {String? keys}) {
    return MenuItemButton(
      style: ribbonMenuItemStyle().copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? RibbonColors.text.withValues(alpha: 0.4)
              : RibbonColors.text,
        ),
      ),
      onPressed: onPressed,
      trailingIcon: keys == null ? null : Text(keys, style: RibbonText.label),
      child: Text(label),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu(this.label, this.items);

  final String label;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    style: ribbonMenuStyle(),
    menuChildren: items,
    builder: (context, menu, _) => Semantics(
      button: true,
      child: InkWell(
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
        borderRadius: BorderRadius.circular(6),
        hoverColor: RibbonColors.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: RibbonText.control),
        ),
      ),
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 22,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: RibbonColors.divider,
  );
}

/// A labelled slider of the bar; [position] goes from 0 to 1.
class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.value,
    required this.position,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double position;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          Text(label, style: RibbonText.label),
          SizedBox(
            width: 110,
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                activeTrackColor: RibbonColors.text,
                inactiveTrackColor: RibbonColors.divider,
                thumbColor: RibbonColors.text,
                overlayColor: RibbonColors.hover,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: position.clamp(0.0, 1.0),
                semanticFormatterCallback: (_) => '$label: $value',
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(width: 46, child: Text(value, style: RibbonText.control)),
        ],
      ),
    );
  }
}

class _BandButton extends StatelessWidget {
  const _BandButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => Material(
    color: filled ? RibbonColors.selected : RibbonColors.field,
    borderRadius: BorderRadius.circular(6),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      hoverColor: RibbonColors.hover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(label, style: RibbonText.control),
      ),
    ),
  );
}
