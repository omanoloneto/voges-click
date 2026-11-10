import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../canvas/tool_settings.dart';
import '../l10n/l10n.dart';

/// The key that picks each tool. Tools that share a key take turns.
const toolKeys = {
  EditTool.move: 'V',
  EditTool.marquee: 'M',
  EditTool.ellipseMarquee: 'M',
  EditTool.lasso: 'L',
  EditTool.crop: 'C',
  EditTool.picker: 'I',
  EditTool.brush: 'B',
  EditTool.pencil: 'B',
  EditTool.eraser: 'E',
  EditTool.fill: 'G',
  EditTool.gradient: 'G',
  EditTool.text: 'T',
  EditTool.line: 'U',
  EditTool.rectangle: 'U',
  EditTool.ellipse: 'U',
  EditTool.hand: 'H',
  EditTool.zoom: 'Z',
};

/// The tool [key] picks when [current] is the chosen one.
EditTool? toolForKey(String key, EditTool current) {
  final sharing = [
    for (final entry in toolKeys.entries)
      if (entry.value == key) entry.key,
  ];
  if (sharing.isEmpty) return null;
  return sharing[(sharing.indexOf(current) + 1) % sharing.length];
}

String toolName(AppLocalizations l10n, EditTool tool) => switch (tool) {
  EditTool.move => l10n.toolMove,
  EditTool.marquee => l10n.toolMarquee,
  EditTool.ellipseMarquee => l10n.toolEllipseMarquee,
  EditTool.lasso => l10n.toolLasso,
  EditTool.crop => l10n.toolCrop,
  EditTool.picker => l10n.toolPicker,
  EditTool.brush => l10n.toolBrush,
  EditTool.pencil => l10n.toolPencil,
  EditTool.eraser => l10n.toolEraser,
  EditTool.fill => l10n.toolFill,
  EditTool.gradient => l10n.toolGradient,
  EditTool.text => l10n.toolText,
  EditTool.line => l10n.toolLine,
  EditTool.rectangle => l10n.toolRectangle,
  EditTool.ellipse => l10n.toolEllipse,
  EditTool.hand => l10n.toolHand,
  EditTool.zoom => l10n.toolZoom,
};

/// The picture of a tool, in the color of the surrounding icon theme.
class ToolIcon extends StatelessWidget {
  const ToolIcon(this.tool, {super.key});

  final EditTool tool;

  @override
  Widget build(BuildContext context) => switch (tool) {
    EditTool.move => const Icon(Icons.open_with),
    EditTool.marquee => const Icon(Icons.highlight_alt),
    EditTool.ellipseMarquee => const _DashedCircle(),
    EditTool.lasso => const Icon(Icons.gesture),
    EditTool.crop => const Icon(Icons.crop),
    EditTool.picker => const Icon(Icons.colorize),
    EditTool.brush => const Icon(Icons.brush),
    EditTool.pencil => const Icon(Icons.edit),
    EditTool.eraser => const _EraserIcon(),
    EditTool.fill => const Icon(Icons.format_color_fill),
    EditTool.gradient => const Icon(Icons.gradient),
    EditTool.text => const Icon(Icons.title),
    EditTool.line => Transform.rotate(
      angle: -math.pi / 4,
      child: const Icon(Icons.horizontal_rule),
    ),
    EditTool.rectangle => const Icon(Icons.crop_square),
    EditTool.ellipse => const Icon(Icons.circle_outlined),
    EditTool.hand => const Icon(Icons.pan_tool_outlined),
    EditTool.zoom => const Icon(Icons.search),
  };
}

/// Material Icons has no eraser: a tilted block, its tip filled.
class _EraserIcon extends StatelessWidget {
  const _EraserIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color!;
    return Transform.rotate(
      angle: -0.6,
      child: Container(
        width: 18,
        height: 10,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.6),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(children: [Container(width: 6, color: color)]),
      ),
    );
  }
}

class _DashedCircle extends StatelessWidget {
  const _DashedCircle();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(17),
    painter: _DashedCirclePainter(IconTheme.of(context).color!),
  );
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = color;
    final box = (Offset.zero & size).deflate(1);
    const dashes = 8;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        box,
        i * 2 * math.pi / dashes,
        math.pi / dashes * 1.1,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
