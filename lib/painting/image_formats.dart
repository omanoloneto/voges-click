import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'rgba_image.dart';

/// Formats the app saves.
enum SaveFormat {
  psd('PSD', ['psd']),
  png('PNG', ['png']),
  jpeg('JPEG', ['jpg', 'jpeg']),
  bmp('BMP', ['bmp']);

  const SaveFormat(this.label, this.extensions);

  final String label;
  final List<String> extensions;

  String get extension => extensions.first;

  bool get keepsTransparency => this == png || this == psd;

  bool get keepsLayers => this == psd;

  /// The format of a file name, or null for one the app does not save.
  static SaveFormat? of(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return null;
    final extension = name.substring(dot + 1).toLowerCase();
    for (final format in values) {
      if (format.extensions.contains(extension)) return format;
    }
    return null;
  }
}

/// Every extension the app opens.
const openableExtensions = [
  'psd',
  'png',
  'jpg',
  'jpeg',
  'bmp',
  'gif',
  'webp',
  'tif',
  'tiff',
  'ico',
  'tga',
];

/// Rewrites any image the `image` package reads as PNG, upright, for the
/// formats the graphics engine does not decode (TIFF, TGA). Null when the
/// bytes are not an image.
Uint8List? transcodeToPng(Uint8List bytes) {
  final decoded = img.decodeImage(bytes, frame: 0);
  if (decoded == null) return null;
  return img.encodePng(img.bakeOrientation(decoded));
}

/// JPEG or BMP of [image] laid over white, since neither keeps transparency.
Uint8List encodeOpaque(RgbaImage image, SaveFormat format) {
  assert(format == SaveFormat.jpeg || format == SaveFormat.bmp);
  final flat = img.Image(width: image.width, height: image.height);
  final pixels = image.pixels;
  var p = 0;
  for (final pixel in flat) {
    final a = pixels[p + 3];
    int over(int channel) => (channel * a + 255 * (255 - a)) ~/ 255;
    pixel
      ..r = over(pixels[p])
      ..g = over(pixels[p + 1])
      ..b = over(pixels[p + 2]);
    p += 4;
  }
  return switch (format) {
    SaveFormat.jpeg => img.encodeJpg(flat, quality: 92),
    SaveFormat.bmp => img.encodeBmp(flat),
    SaveFormat.png || SaveFormat.psd => img.encodePng(flat),
  };
}
