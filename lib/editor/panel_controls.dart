import 'package:flutter/material.dart';

/// Small icon button of the side panels, in the colors of the theme.
class PanelIconButton extends StatelessWidget {
  const PanelIconButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.child,
    this.selected = false,
    super.key,
  }) : assert(icon != null || child != null);

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Drawn instead of [icon], for the tools Material Icons does not have.
  final Widget? child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.onPrimary : colors.onSurface;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Material(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 32,
              height: 30,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: onPressed == null
                        ? color.withValues(alpha: 0.35)
                        : color,
                    size: 19,
                  ),
                  child: child ?? Icon(icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title strip of a side panel.
class PanelHeader extends StatelessWidget {
  const PanelHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 28,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
