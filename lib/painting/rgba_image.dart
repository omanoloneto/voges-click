import 'dart:typed_data';

/// The largest side an image may have. Bigger textures fail on some
/// graphics cards, and every undo step keeps a full copy.
const maxImageSide = 8192;

/// Straight (not premultiplied) RGBA pixels, row by row from the top left.
class RgbaImage {
  RgbaImage(this.width, this.height, [Uint8List? pixels])
    : pixels = pixels ?? Uint8List(width * height * 4) {
    if (this.pixels.length != width * height * 4) {
      throw ArgumentError('Expected ${width * height * 4} bytes');
    }
  }

  final int width;
  final int height;
  final Uint8List pixels;

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  /// The color at (x, y) as 0xAARRGGBB.
  int colorAt(int x, int y) {
    final i = (y * width + x) * 4;
    return pixels[i + 3] << 24 |
        pixels[i] << 16 |
        pixels[i + 1] << 8 |
        pixels[i + 2];
  }

  bool get hasTransparency {
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] != 255) return true;
    }
    return false;
  }
}
