import 'rgba_image.dart';

/// The smallest box that holds every pixel that is not fully transparent,
/// as left, top, right and bottom, the last two just outside. Null when
/// there is nothing to see.
(int, int, int, int)? opaqueBounds(RgbaImage image) {
  final width = image.width, height = image.height;
  final pixels = image.pixels;

  bool rowIsEmpty(int y) {
    final end = (y + 1) * width * 4;
    for (var i = y * width * 4 + 3; i < end; i += 4) {
      if (pixels[i] != 0) return false;
    }
    return true;
  }

  var top = 0;
  while (top < height && rowIsEmpty(top)) {
    top++;
  }
  if (top == height) return null;
  var bottom = height;
  while (rowIsEmpty(bottom - 1)) {
    bottom--;
  }

  var left = width, right = 0;
  for (var y = top; y < bottom; y++) {
    final row = y * width * 4 + 3;
    for (var x = 0; x < left; x++) {
      if (pixels[row + x * 4] != 0) {
        left = x;
        break;
      }
    }
    for (var x = width - 1; x >= right; x--) {
      if (pixels[row + x * 4] != 0) {
        right = x + 1;
        break;
      }
    }
  }
  return (left, top, right, bottom);
}
