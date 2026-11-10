import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

enum PenKind { pencil, brush, eraser }

enum ShapeKind { line, rectangle, ellipse }

/// Something drawn with one drag, painted the same way while it is drawn
/// and when it goes into the layer.
sealed class Mark {
  /// The area [paint] may reach, in image pixels.
  Rect get bounds;

  void paint(Canvas canvas);
}

/// Pencil: hard edges. Brush: round, as soft as [hardness] says. Eraser: a
/// brush that takes paint away instead of laying it.
final class PenMark extends Mark {
  PenMark(this.kind, this.color, this.width, this.hardness, Offset start)
    : _last = start,
      _points = Rect.fromPoints(start, start),
      _path = Path()..moveTo(start.dx, start.dy);

  final PenKind kind;

  /// Its alpha is the strength of the whole stroke.
  final Color color;
  final double width;

  /// From 0 (all blur) to 1 (sharp edge).
  final double hardness;
  final Path _path;
  Offset _last;
  Rect _points;
  var _moved = false;

  double get _blur => kind == PenKind.pencil ? 0 : width * (1 - hardness) / 4;

  /// The blur fades out about three times its radius away.
  @override
  Rect get bounds => _points.inflate(width / 2 + 3 * _blur + 1);

  void add(Offset point) {
    if (point == _last) return;
    _path.lineTo(point.dx, point.dy);
    _points = _points.expandToInclude(Rect.fromPoints(point, point));
    _last = point;
    _moved = true;
  }

  @override
  void paint(Canvas canvas) {
    final hard = kind == PenKind.pencil;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = !hard;
    if (kind == PenKind.eraser) paint.blendMode = BlendMode.dstOut;
    final blur = _blur;
    if (blur > 0.2) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    }
    if (!_moved) {
      final dot = Rect.fromCenter(center: _last, width: width, height: width);
      if (hard && width <= 2) {
        canvas.drawRect(dot, paint);
      } else {
        canvas.drawOval(dot, paint);
      }
      return;
    }
    canvas.drawPath(
      _path,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}

final class ShapeMark extends Mark {
  ShapeMark(this.kind, this.color, this.width, this.filled, this.start)
    : end = start;

  final ShapeKind kind;
  final Color color;
  final double width;
  final bool filled;
  final Offset start;
  Offset end;

  bool get isEmpty => start == end;

  bool get _fills => filled && kind != ShapeKind.line;

  @override
  Rect get bounds =>
      Rect.fromPoints(start, end).inflate(_fills ? 1 : width / 2 + 1);

  @override
  void paint(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = _fills ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;
    final box = Rect.fromPoints(start, end);
    switch (kind) {
      case ShapeKind.line:
        canvas.drawLine(start, end, paint);
      case ShapeKind.rectangle:
        canvas.drawRect(box, paint);
      case ShapeKind.ellipse:
        canvas.drawOval(box, paint);
    }
  }
}

/// From one color at the start of the drag to the other at its end, over
/// the whole [area].
final class GradientMark extends Mark {
  GradientMark(this.from, this.to, this.area, this.start) : end = start;

  final Color from;
  final Color to;
  final Rect area;
  final Offset start;
  Offset end;

  bool get isEmpty => start == end;

  @override
  Rect get bounds => area;

  @override
  void paint(Canvas canvas) {
    if (isEmpty) return;
    canvas.drawRect(
      area,
      Paint()..shader = ui.Gradient.linear(start, end, [from, to]),
    );
  }
}
