import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/painting/opaque_bounds.dart';
import 'package:voges_click/painting/rgba_image.dart';

void main() {
  test('finds the box around what is not transparent', () {
    final image = RgbaImage(8, 6);
    for (final (x, y) in const [(2, 1), (5, 3), (3, 4)]) {
      image.pixels[(y * 8 + x) * 4 + 3] = 1;
    }
    expect(opaqueBounds(image), (2, 1, 6, 5));
  });

  test('an empty image has no box', () {
    expect(opaqueBounds(RgbaImage(4, 4)), isNull);
  });
}
