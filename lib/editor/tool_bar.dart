import 'package:flutter/material.dart';

import '../canvas/tool_settings.dart';
import '../l10n/l10n.dart';
import 'panel_controls.dart';
import 'tool_catalog.dart';

/// The column of tools on the left, with the two colors at the bottom.
class ToolBar extends StatelessWidget {
  const ToolBar({required this.settings, required this.onEditColor, super.key});

  static const width = 80.0;

  final ToolSettings settings;

  /// Edits the foreground color, or the background one when true.
  final ValueChanged<bool> onEditColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      alignment: Alignment.topCenter,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              SizedBox(
                width: 66,
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (final tool in EditTool.values)
                      PanelIconButton(
                        tooltip: l10n.toolWithKey(
                          toolName(l10n, tool),
                          toolKeys[tool]!,
                        ),
                        selected: settings.tool == tool,
                        onPressed: () => settings.tool = tool,
                        child: ToolIcon(tool),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ColorPair(settings: settings, onEdit: onEditColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foreground square over the background one, as in Photoshop.
class _ColorPair extends StatelessWidget {
  const _ColorPair({required this.settings, required this.onEdit});

  final ToolSettings settings;
  final ValueChanged<bool> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        children: [
          Positioned(
            right: 4,
            bottom: 4,
            child: _ColorSquare(
              label: l10n.backgroundColor,
              color: settings.color2,
              onTap: () => onEdit(true),
            ),
          ),
          Positioned(
            left: 4,
            top: 4,
            child: _ColorSquare(
              label: l10n.foregroundColor,
              color: settings.color1,
              onTap: () => onEdit(false),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _MiniButton(
              icon: Icons.swap_calls,
              tooltip: l10n.toolWithKey(l10n.swapColors, 'X'),
              onTap: settings.swapColors,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: _MiniButton(
              icon: Icons.contrast,
              tooltip: l10n.toolWithKey(l10n.defaultColors, 'D'),
              onTap: settings.resetColors,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSquare extends StatelessWidget {
  const _ColorSquare({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.surface, width: 2),
                boxShadow: [BoxShadow(color: colors.outline, spreadRadius: 1)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(onTap: onTap, radius: 12, child: Icon(icon, size: 16)),
    ),
  );
}
