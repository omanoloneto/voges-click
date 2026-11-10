import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../canvas/editor_controller.dart';
import '../document/layer.dart';
import '../l10n/l10n.dart';
import 'panel_controls.dart';

String blendName(AppLocalizations l10n, LayerBlend blend) => switch (blend) {
  LayerBlend.normal => l10n.blendNormal,
  LayerBlend.darken => l10n.blendDarken,
  LayerBlend.multiply => l10n.blendMultiply,
  LayerBlend.colorBurn => l10n.blendColorBurn,
  LayerBlend.lighten => l10n.blendLighten,
  LayerBlend.screen => l10n.blendScreen,
  LayerBlend.colorDodge => l10n.blendColorDodge,
  LayerBlend.linearDodge => l10n.blendLinearDodge,
  LayerBlend.overlay => l10n.blendOverlay,
  LayerBlend.softLight => l10n.blendSoftLight,
  LayerBlend.hardLight => l10n.blendHardLight,
  LayerBlend.difference => l10n.blendDifference,
  LayerBlend.exclusion => l10n.blendExclusion,
  LayerBlend.hue => l10n.blendHue,
  LayerBlend.saturation => l10n.blendSaturation,
  LayerBlend.color => l10n.blendColor,
  LayerBlend.luminosity => l10n.blendLuminosity,
};

/// The stack of layers, the top one first, with what can be done to them.
class LayersPanel extends StatefulWidget {
  const LayersPanel({
    required this.controller,
    required this.onRename,
    super.key,
  });

  final EditorController controller;
  final ValueChanged<Layer> onRename;

  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  int? _tappedId;
  var _tappedAt = Duration.zero;
  final _clock = Stopwatch()..start();

  EditorController get controller => widget.controller;

  /// A second click on the same layer, soon after the first, renames it.
  void _tap(Layer layer) {
    final now = _clock.elapsed;
    final again =
        _tappedId == layer.id &&
        now - _tappedAt < const Duration(milliseconds: 400);
    _tappedId = again ? null : layer.id;
    _tappedAt = now;
    controller.document.activeId = layer.id;
    if (again) widget.onRename(layer);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller.document,
      builder: (context, _) {
        final document = controller.document;
        final layers = document.layers;
        final active = document.activeLayer;
        final index = document.activeIndex;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: l10n.blendMode,
                      child: DropdownButton<LayerBlend>(
                        value: active.blend,
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        style: theme.textTheme.bodyMedium,
                        items: [
                          for (final blend in LayerBlend.values)
                            DropdownMenuItem(
                              value: blend,
                              child: Text(blendName(l10n, blend)),
                            ),
                        ],
                        onChanged: (blend) {
                          if (blend != null) controller.setLayerBlend(blend);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Row(
                children: [
                  Text(l10n.opacity, style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Slider(
                      value: active.opacity,
                      semanticFormatterCallback: (value) =>
                          l10n.percent((value * 100).round()),
                      onChanged: controller.setLayerOpacity,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      l10n.percent((active.opacity * 100).round()),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: ListView.builder(
                itemCount: layers.length,
                itemExtent: _LayerRow.height,
                itemBuilder: (context, row) {
                  final layer = layers[layers.length - 1 - row];
                  return _LayerRow(
                    key: ValueKey(layer.id),
                    layer: layer,
                    frame: Size(
                      document.width.toDouble(),
                      document.height.toDouble(),
                    ),
                    active: layer.id == document.activeId,
                    onTap: () => _tap(layer),
                    onToggle: () =>
                        controller.setLayerVisible(layer.id, !layer.visible),
                  );
                },
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PanelIconButton(
                    icon: Icons.add,
                    tooltip: l10n.newLayer,
                    onPressed: controller.addLayer,
                  ),
                  PanelIconButton(
                    icon: Icons.copy_all_outlined,
                    tooltip: l10n.duplicateLayer,
                    onPressed: controller.duplicateLayer,
                  ),
                  PanelIconButton(
                    icon: Icons.arrow_upward,
                    tooltip: l10n.raiseLayer,
                    onPressed: index < layers.length - 1
                        ? controller.raiseLayer
                        : null,
                  ),
                  PanelIconButton(
                    icon: Icons.arrow_downward,
                    tooltip: l10n.lowerLayer,
                    onPressed: index > 0 ? controller.lowerLayer : null,
                  ),
                  PanelIconButton(
                    icon: Icons.vertical_align_bottom,
                    tooltip: l10n.mergeDown,
                    onPressed: controller.canMergeDown
                        ? controller.mergeDown
                        : null,
                  ),
                  PanelIconButton(
                    icon: Icons.delete_outline,
                    tooltip: l10n.deleteLayer,
                    onPressed: layers.length > 1
                        ? controller.deleteLayer
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.layer,
    required this.frame,
    required this.active,
    required this.onTap,
    required this.onToggle,
    super.key,
  });

  static const height = 46.0;

  final Layer layer;
  final Size frame;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: active ? colors.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 12),
          child: Row(
            children: [
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: layer.visible ? l10n.hideLayer : l10n.showLayer,
                onPressed: onToggle,
                icon: Icon(
                  layer.visible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: layer.visible
                      ? colors.onSurface
                      : colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 48,
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                ),
                child: RepaintBoundary(
                  child: CustomPaint(painter: _ThumbnailPainter(layer, frame)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  layer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: active ? colors.onPrimaryContainer : null,
                    fontWeight: active ? FontWeight.w600 : null,
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

/// The layer where it sits in the image, over the transparency checker.
class _ThumbnailPainter extends CustomPainter {
  const _ThumbnailPainter(this.layer, this.frame);

  final Layer layer;
  final Size frame;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / frame.width,
      size.height / frame.height,
    );
    final shown = Size(frame.width * scale, frame.height * scale);
    final box =
        Offset(
          (size.width - shown.width) / 2,
          (size.height - shown.height) / 2,
        ) &
        shown;
    canvas.clipRect(box);
    canvas.drawRect(box, Paint()..color = const Color(0xFFFFFFFF));
    const cell = 4.0;
    final dark = Paint()..color = const Color(0xFFCCCCCC);
    for (var y = 0; y * cell < shown.height; y++) {
      for (var x = y.isEven ? 0 : 1; x * cell < shown.width; x += 2) {
        canvas.drawRect(
          Rect.fromLTWH(box.left + x * cell, box.top + y * cell, cell, cell),
          dark,
        );
      }
    }
    final image = layer.image;
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        box.left + layer.offset.dx * scale,
        box.top + layer.offset.dy * scale,
        image.width * scale,
        image.height * scale,
      ),
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      !identical(oldDelegate.layer.image, layer.image) ||
      oldDelegate.layer.offset != layer.offset ||
      oldDelegate.frame != frame;
}
