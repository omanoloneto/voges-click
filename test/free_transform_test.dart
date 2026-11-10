import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/canvas/free_transform.dart';

FreeTransform _box() => FreeTransform(const Rect.fromLTWH(10, 10, 20, 10));

void _drag(
  FreeTransform box,
  Offset from,
  Offset to, {
  bool constrain = false,
  bool fromCenter = false,
}) {
  box
    ..startDrag(from, 2)
    ..drag(to, constrain: constrain, fromCenter: fromCenter)
    ..endDrag();
}

Matcher _near(Offset point) => within<Offset>(distance: 1e-9, from: point);

void main() {
  test('a click grabs a handle, the inside or the outside of the box', () {
    final box = _box();
    expect(box.gripAt(const Offset(20, 15), 2).kind, GripKind.move);
    expect(box.gripAt(const Offset(50, 15), 2).kind, GripKind.rotate);
    final corner = box.gripAt(const Offset(31, 21), 2);
    expect(corner.kind, GripKind.scale);
    expect(corner.handle, TransformHandle.bottomRight);
    expect(box.gripAt(const Offset(20, 9), 2).handle, TransformHandle.top);
    // a handle does not take the middle of a small box
    expect(box.gripAt(const Offset(20, 14), 8).kind, GripKind.move);
    expect(box.gripAt(const Offset(20, 4), 8).handle, TransformHandle.top);
  });

  test('moving lands on whole pixels and can keep to one axis', () {
    final box = _box();
    _drag(box, const Offset(20, 15), const Offset(25.4, 12.6));
    expect(box.center, const Offset(25, 13));
    expect(box.keepsPixels, isTrue);
    expect(box.isIdentity, isFalse);

    _drag(box, const Offset(25, 13), const Offset(45, 16), constrain: true);
    expect(box.center, const Offset(45, 13));
  });

  test('a corner keeps the proportions unless told otherwise', () {
    final box = _box();
    _drag(box, const Offset(30, 20), const Offset(50, 20));
    expect(box.scaleX, 2);
    expect(box.scaleY, 2);
    expect(box.pointOf(TransformHandle.topLeft), _near(const Offset(10, 10)));
    expect(box.width, 40);
    expect(box.height, 20);

    final free = _box();
    _drag(free, const Offset(30, 20), const Offset(50, 20), constrain: true);
    expect(free.scaleX, 2);
    expect(free.scaleY, 1);
  });

  test('a side stretches one way, and past the other side it flips', () {
    final box = _box();
    _drag(box, const Offset(30, 15), const Offset(40, 15));
    expect(box.scaleX, 1.5);
    expect(box.scaleY, 1);
    expect(box.pointOf(TransformHandle.left), _near(const Offset(10, 15)));

    _drag(box, const Offset(40, 15), const Offset(0, 15));
    expect(box.scaleX, -0.5);
    expect(box.width, 10);
    expect(box.bounds.left, closeTo(0, 1e-9));
  });

  test('scaling from the middle leaves the middle where it was', () {
    final box = _box();
    _drag(box, const Offset(30, 15), const Offset(40, 15), fromCenter: true);
    expect(box.scaleX, 2);
    expect(box.center, _near(const Offset(20, 15)));
  });

  test('a box never gets thinner than one pixel', () {
    final box = _box();
    _drag(box, const Offset(30, 15), const Offset(10, 15));
    expect(box.width, closeTo(1, 1e-9));
  });

  test('turning follows the pointer and can go in steps of 15°', () {
    final box = _box();
    _drag(box, const Offset(50, 15), const Offset(20, 45));
    expect(box.angle, closeTo(math.pi / 2, 1e-9));
    expect(box.keepsPixels, isFalse);
    expect(box.pointOf(TransformHandle.topLeft), _near(const Offset(25, 5)));
    expect(box.bounds, const Rect.fromLTWH(15, 5, 10, 20));

    final stepped = _box();
    _drag(stepped, const Offset(50, 15), const Offset(50, 22), constrain: true);
    expect(stepped.angle, closeTo(FreeTransform.rotationStep, 1e-9));
  });

  test('a turned box still scales along its own sides', () {
    final box = _box()..angle = math.pi / 2;
    final right = box.pointOf(TransformHandle.right);
    expect(right, _near(const Offset(20, 25)));
    _drag(box, right, const Offset(20, 35));
    expect(box.scaleX, closeTo(1.5, 1e-9));
    expect(box.scaleY, 1);
    expect(box.pointOf(TransformHandle.left), _near(const Offset(20, 5)));
  });

  test('the matrices put pixels where the box says they are', () {
    final box = _box()
      ..center = const Offset(40, 30)
      ..scaleX = 2
      ..scaleY = 0.5
      ..angle = 0.7;
    Offset through(Float64List matrix, Offset point) => Offset(
      matrix[0] * point.dx + matrix[4] * point.dy + matrix[12],
      matrix[1] * point.dx + matrix[5] * point.dy + matrix[13],
    );
    for (final local in const [Offset.zero, Offset(20, 10), Offset(7, 3)]) {
      expect(through(box.matrix, local), _near(box.toImage(local)));
      expect(
        through(box.imageMatrix, local + box.box.topLeft),
        _near(box.toImage(local)),
      );
    }
  });
}
