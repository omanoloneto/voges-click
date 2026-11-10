import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// The eight squares around the box; [x] and [y] say where each one sits,
/// from 0 (left, top) to 1 (right, bottom).
enum TransformHandle {
  topLeft(0, 0),
  top(0.5, 0),
  topRight(1, 0),
  right(1, 0.5),
  bottomRight(1, 1),
  bottom(0.5, 1),
  bottomLeft(0, 1),
  left(0, 0.5);

  const TransformHandle(this.x, this.y);

  final double x;
  final double y;

  bool get isCorner => x != 0.5 && y != 0.5;
}

enum GripKind { move, rotate, scale }

/// What a drag starting at some point does: [handle] is set when it scales.
typedef TransformGrip = ({GripKind kind, TransformHandle? handle});

/// A box of pixels being moved, scaled and turned around its center before
/// the result is painted. Works in image pixels.
class FreeTransform {
  FreeTransform(this.box) : center = box.center;

  /// Where the pixels sat before.
  final Rect box;

  /// Where the middle of the box is now.
  Offset center;
  double scaleX = 1;
  double scaleY = 1;

  /// Clockwise, in radians.
  double angle = 0;

  static const rotationStep = math.pi / 12;

  TransformGrip? _grip;
  Offset _from = Offset.zero;
  Offset _startCenter = Offset.zero;
  double _startScaleX = 1;
  double _startScaleY = 1;
  double _startAngle = 0;

  bool get isIdentity =>
      center == box.center && scaleX == 1 && scaleY == 1 && angle == 0;

  /// Only moved: the pixels can be copied as they are.
  bool get keepsPixels => scaleX == 1 && scaleY == 1 && angle == 0;

  bool get isDragging => _grip != null;

  double get width => (box.width * scaleX).abs();
  double get height => (box.height * scaleY).abs();

  /// Takes a point of the box, counted from its top left corner, to where
  /// it is now.
  Offset toImage(Offset local) => _place(local, center, scaleX, scaleY, angle);

  Offset pointOf(TransformHandle handle) =>
      toImage(Offset(handle.x * box.width, handle.y * box.height));

  List<Offset> get corners => [
    toImage(Offset.zero),
    toImage(Offset(box.width, 0)),
    toImage(Offset(box.width, box.height)),
    toImage(Offset(0, box.height)),
  ];

  /// The upright box that holds the turned one.
  Rect get bounds {
    final points = corners;
    var result = Rect.fromPoints(points[0], points[1]);
    for (final point in points.skip(2)) {
      result = result.expandToInclude(Rect.fromPoints(point, point));
    }
    return result;
  }

  /// Takes the pixels of the box, counted from its top left corner, to
  /// where they are now.
  Float64List get matrix => _matrix(Offset.zero);

  /// Takes anything that was on the image along with the box.
  Float64List get imageMatrix => _matrix(box.topLeft);

  /// What a drag from [point] would do. [reach] is how far from a handle
  /// still grabs it.
  TransformGrip gripAt(Offset point, double reach) {
    final turned = _turn(point - center, -angle);
    final inside =
        turned.dx.abs() <= width / 2 && turned.dy.abs() <= height / 2;
    TransformHandle? nearest;
    // the middle of a small box stays free to move it
    var best = inside ? math.min(reach, math.min(width, height) / 4) : reach;
    for (final handle in TransformHandle.values) {
      final distance = (pointOf(handle) - point).distance;
      if (distance <= best) {
        best = distance;
        nearest = handle;
      }
    }
    if (nearest != null) return (kind: GripKind.scale, handle: nearest);
    return (kind: inside ? GripKind.move : GripKind.rotate, handle: null);
  }

  void startDrag(Offset point, double reach) {
    _grip = gripAt(point, reach);
    _from = point;
    _startCenter = center;
    _startScaleX = scaleX;
    _startScaleY = scaleY;
    _startAngle = angle;
  }

  /// [constrain] moves along one axis, turns in steps of 15° and lets a
  /// corner change the proportions. [fromCenter] scales around the middle
  /// instead of the opposite handle.
  void drag(Offset point, {bool constrain = false, bool fromCenter = false}) {
    final grip = _grip;
    if (grip == null) return;
    switch (grip.kind) {
      case GripKind.move:
        var delta = point - _from;
        if (constrain) {
          delta = delta.dx.abs() > delta.dy.abs()
              ? Offset(delta.dx, 0)
              : Offset(0, delta.dy);
        }
        center =
            _startCenter +
            Offset(delta.dx.roundToDouble(), delta.dy.roundToDouble());
      case GripKind.rotate:
        final turn =
            (point - _startCenter).direction - (_from - _startCenter).direction;
        final next = _startAngle + turn;
        angle = constrain ? (next / rotationStep).round() * rotationStep : next;
      case GripKind.scale:
        _scale(grip.handle!, point, free: constrain, fromCenter: fromCenter);
    }
  }

  void endDrag() => _grip = null;

  void moveBy(Offset delta) => center += delta;

  void _scale(
    TransformHandle handle,
    Offset point, {
    required bool free,
    required bool fromCenter,
  }) {
    final anchorX = fromCenter ? 0.5 : 1 - handle.x;
    final anchorY = fromCenter ? 0.5 : 1 - handle.y;
    final anchor = _place(
      Offset(anchorX * box.width, anchorY * box.height),
      _startCenter,
      _startScaleX,
      _startScaleY,
      _startAngle,
    );
    final reach = _turn(point - anchor, -_startAngle);
    var nextX = handle.x == 0.5
        ? _startScaleX
        : reach.dx / (box.width * (handle.x - anchorX));
    var nextY = handle.y == 0.5
        ? _startScaleY
        : reach.dy / (box.height * (handle.y - anchorY));
    if (handle.isCorner && !free) {
      final factor = math.max(
        (nextX / _startScaleX).abs(),
        (nextY / _startScaleY).abs(),
      );
      nextX = _signed(_startScaleX.abs() * factor, nextX);
      nextY = _signed(_startScaleY.abs() * factor, nextY);
    }
    scaleX = _signed(math.max(nextX.abs(), 1 / box.width), nextX);
    scaleY = _signed(math.max(nextY.abs(), 1 / box.height), nextY);
    angle = _startAngle;
    center =
        anchor +
        _turn(
          Offset(
            scaleX * box.width * (0.5 - anchorX),
            scaleY * box.height * (0.5 - anchorY),
          ),
          angle,
        );
  }

  Offset _place(
    Offset local,
    Offset center,
    double scaleX,
    double scaleY,
    double angle,
  ) =>
      center +
      _turn(
        Offset(
          (local.dx - box.width / 2) * scaleX,
          (local.dy - box.height / 2) * scaleY,
        ),
        angle,
      );

  Float64List _matrix(Offset origin) {
    final cos = math.cos(angle), sin = math.sin(angle);
    final a = cos * scaleX, b = sin * scaleX;
    final c = -sin * scaleY, d = cos * scaleY;
    final middle = origin + Offset(box.width / 2, box.height / 2);
    return Float64List(16)
      ..[0] = a
      ..[1] = b
      ..[4] = c
      ..[5] = d
      ..[10] = 1
      ..[12] = center.dx - (a * middle.dx + c * middle.dy)
      ..[13] = center.dy - (b * middle.dx + d * middle.dy)
      ..[15] = 1;
  }

  static Offset _turn(Offset vector, double angle) {
    final cos = math.cos(angle), sin = math.sin(angle);
    return Offset(
      vector.dx * cos - vector.dy * sin,
      vector.dx * sin + vector.dy * cos,
    );
  }

  static double _signed(double size, double like) => like < 0 ? -size : size;
}
