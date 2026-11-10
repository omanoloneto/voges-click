import 'dart:math' as math;
import 'dart:typed_data';

import 'rgba_image.dart';

/// How far each channel may be from the clicked color and still be filled.
/// High enough to cover most of the soft edge of a brush stroke, low enough
/// not to leak between the colors of the palette.
const fillTolerance = 64;

/// What a fill paints: [pixels] has the color on the filled area and is
/// transparent elsewhere. It is only the part of the image that holds the
/// area, [width] by [height] pixels from [left], [top].
typedef FillPatch = ({
  Uint8List pixels,
  int left,
  int top,
  int width,
  int height,
});

/// [argb] on the area connected to (x, y), in four directions, whose colors
/// are within [tolerance] of the color at (x, y). Null when (x, y) is
/// outside the image.
///
/// [argb] must be opaque: the patch is drawn as is over the image.
FillPatch? fillPatch(
  RgbaImage image,
  int x,
  int y,
  int argb, {
  int tolerance = fillTolerance,
}) {
  final area = _fill(image, x, y, tolerance);
  if (area == null) return null;
  final (mask, left, top, right, bottom) = area;
  final width = right - left + 1, height = bottom - top + 1;
  final pixels = Uint8List(width * height * 4);
  final r = argb >> 16 & 0xFF, g = argb >> 8 & 0xFF, b = argb & 0xFF;
  for (var row = 0; row < height; row++) {
    var m = (top + row) * image.width + left;
    var p = row * width * 4;
    for (var column = 0; column < width; column++, m++, p += 4) {
      if (mask[m] == 0) continue;
      pixels[p] = r;
      pixels[p + 1] = g;
      pixels[p + 2] = b;
      pixels[p + 3] = 255;
    }
  }
  return (pixels: pixels, left: left, top: top, width: width, height: height);
}

/// One byte per pixel: 1 where the fill reaches.
Uint8List? fillMask(
  RgbaImage image,
  int x,
  int y, {
  int tolerance = fillTolerance,
}) => _fill(image, x, y, tolerance)?.$1;

/// The mask of the fill and the first and last column and row it reaches.
(Uint8List, int, int, int, int)? _fill(
  RgbaImage image,
  int x,
  int y,
  int tolerance,
) {
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

  var first = x, last = x, top = y, bottom = y;
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
    first = math.min(first, left - rowStart);
    last = math.max(last, right - rowStart);
    top = math.min(top, row);
    bottom = math.max(bottom, row);
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
  return (mask, first, top, last, bottom);
}
