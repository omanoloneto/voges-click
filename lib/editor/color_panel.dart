import 'package:flutter/material.dart';

import '../canvas/tool_settings.dart';
import '../l10n/l10n.dart';

/// The ready-made colors: a click takes one as the foreground color, a
/// right click as the background one.
class ColorPanel extends StatelessWidget {
  const ColorPanel({required this.settings, super.key});

  final ToolSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final color in paletteColors)
                Semantics(
                  button: true,
                  label: '#${_hex(color)}',
                  child: GestureDetector(
                    onTap: () => settings.color1 = color,
                    onSecondaryTap: () => settings.color2 = color,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 21,
                        height: 21,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.swatchHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _hex(Color color) => (color.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();
}
