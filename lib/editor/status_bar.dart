import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/editor_controller.dart';
import '../canvas/zoom.dart';
import '../l10n/l10n.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({
    required this.controller,
    required this.zoom,
    required this.onZoom,
    required this.onFit,
    this.trailing,
    super.key,
  });

  final EditorController controller;
  final double zoom;
  final ValueChanged<double> onZoom;
  final VoidCallback onFit;

  /// Shown before the zoom, such as the update status.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    // the slider moves on a log scale, so 100% sits near the middle
    final minLog = math.log(minZoom), maxLog = math.log(maxZoom);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SizedBox(
        height: 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.near_me_outlined, size: 14),
              const SizedBox(width: 4),
              SizedBox(
                width: 100,
                child: ValueListenableBuilder(
                  valueListenable: controller.cursor,
                  builder: (context, cursor, _) => Text(
                    cursor == null
                        ? ''
                        : l10n.cursorPosition(cursor.$1, cursor.$2),
                    style: style,
                  ),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final document = controller.document;
                    final selection = controller.selectionBounds;
                    return Row(
                      children: [
                        const Icon(Icons.aspect_ratio, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          l10n.imageSize(document.width, document.height),
                          style: style,
                        ),
                        if (selection != null) ...[
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              l10n.selectionSize(
                                selection.width.round(),
                                selection.height.round(),
                              ),
                              style: style,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              if (trailing case final trailing?) ...[
                Flexible(child: trailing),
                const SizedBox(width: 12),
              ],
              Text('${(zoom * 100).round()}%', style: style),
              IconButton(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                tooltip: l10n.zoomOut,
                onPressed: nextZoom(zoom, -1) == null
                    ? null
                    : () => onZoom(nextZoom(zoom, -1)!),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 140,
                child: Slider(
                  value: math.log(zoom).clamp(minLog, maxLog),
                  min: minLog,
                  max: maxLog,
                  semanticFormatterCallback: (_) => '${(zoom * 100).round()}%',
                  onChanged: (value) => onZoom(clampZoom(math.exp(value))),
                ),
              ),
              IconButton(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                tooltip: l10n.zoomIn,
                onPressed: nextZoom(zoom, 1) == null
                    ? null
                    : () => onZoom(nextZoom(zoom, 1)!),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                tooltip: l10n.fitToWindow,
                onPressed: onFit,
                icon: const Icon(Icons.fit_screen_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
