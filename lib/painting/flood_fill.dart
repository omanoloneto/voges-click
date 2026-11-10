import 'dart:typed_data';

import 'rgba_image.dart';

/// How far each channel may be from the clicked color and still be filled.
/// High enough to cover most of the soft edge of a brush stroke, low enough
/// not to leak between the colors of the palette.
const fillTolerance = 64;

/// A layer with [argb] on the area connected to (x, y), in four directions,
/// whose colors are within [tolerance] of the color at (x, y), and
/// transparent elsewhere. Null when (x, y) is outside the image.
///
/// [argb] must be opaque: the layer is drawn as is over the image.
Uint8List? fillLayer(
  RgbaImage image,
  int x,
  int y,
  int argb, {
  int tolerance = fillTolerance,
}) {
  final mask = fillMask(image, x, y, tolerance: tolerance);
  if (mask == null) return null;
  final layer = Uint8List(mask.length * 4);
  final r = argb >> 16 & 0xFF, g = argb >> 8 & 0xFF, b = argb & 0xFF;
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] == 0) continue;
    final p = i * 4;
    layer[p] = r;
    layer[p + 1] = g;
    layer[p + 2] = b;
    layer[p + 3] = 255;
  }
  return layer;
}

/// One byte per pixel: 1 where the fill reaches.
Uint8List? fillMask(
  RgbaImage image,
  int x,
  int y, {
  int tolerance = fillTolerance,
}) {
  if (!image.contains(x, y)) return null;
  final width = image.width, height = image.height;
  final pixels = image.pixels;
  final start = (y * width + x) * 4;
  final tr = pixels[start], tg = pixels[start + 1], tb = pixels[start + 2];
  final ta = pixels[start + 3];
  final mask = Uint8List(width * height);

  bool matches(int index) {
    if (mask[index] != 0) return false;
    final p = index * 4;
    final a = pixels[p + 3];
    // transparent pixels match each other whatever color they keep
    if (ta == 0 && a == 0) return true;
    return (pixels[p] - tr).abs() <= tolerance &&
        (pixels[p + 1] - tg).abs() <= tolerance &&
        (pixels[p + 2] - tb).abs() <= tolerance &&
        (a - ta).abs() <= tolerance;
  }

  final seeds = <int>[y * width + x];
  while (seeds.isNotEmpty) {
    final seed = seeds.removeLast();
    if (!matches(seed)) continue;
    final row = seed ~/ width;
    final rowStart = row * width;
    var left = seed, right = seed;
    while (left > rowStart && matches(left - 1)) {
      left--;
    }
    while (right < rowStart + width - 1 && matches(right + 1)) {
      right++;
    }
    mask.fillRange(left, right + 1, 1);
    for (final next in [row - 1, row + 1]) {
      if (next < 0 || next >= height) continue;
      final offset = (next - row) * width;
      var inRun = false;
      for (var i = left; i <= right; i++) {
        final candidate = i + offset;
        final ok = matches(candidate);
        if (ok && !inRun) seeds.add(candidate);
        inRun = ok;
      }
    }
  }
  return mask;
}
