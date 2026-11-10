import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:voges_click/painting/psd_reader.dart';
import 'package:voges_click/painting/psd_writer.dart';
import 'package:voges_click/painting/rgba_image.dart';

RgbaImage _filled(int width, int height, int Function(int x, int y) argb) {
  final image = RgbaImage(width, height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final color = argb(x, y), i = (y * width + x) * 4;
      image.pixels[i] = color >> 16 & 0xFF;
      image.pixels[i + 1] = color >> 8 & 0xFF;
      image.pixels[i + 2] = color & 0xFF;
      image.pixels[i + 3] = color >> 24 & 0xFF;
    }
  }
  return image;
}

/// The color of a layer at a place of the document, 0 outside the layer.
int _at(PsdLayer layer, int x, int y) {
  final lx = x - layer.left, ly = y - layer.top;
  if (lx < 0 || ly < 0 || lx >= layer.width || ly >= layer.height) return 0;
  return RgbaImage(layer.width, layer.height, layer.pixels).colorAt(lx, ly);
}

PsdLayerSource _plain(String name, RgbaImage image) => PsdLayerSource(
  name: name,
  left: 0,
  top: 0,
  image: image,
  opacity: 255,
  blendKey: 'norm',
  visible: true,
);

Uint8List _sample() {
  final background = _filled(
    40,
    30,
    (x, y) => 0xFF000000 | (x * 6) << 16 | (y * 8) << 8 | 0x40,
  );
  final dot = _filled(
    10,
    10,
    (x, y) => x >= 2 && x < 8 && y >= 3 && y < 9 ? 0x80FF0000 : 0,
  );
  return writePsd(background, [
    _plain('Background', background),
    PsdLayerSource(
      name: 'Ação ✓',
      left: 25,
      top: -4,
      image: dot,
      opacity: 128,
      blendKey: 'mul ',
      visible: false,
    ),
  ]);
}

void main() {
  test('PackBits packs runs and literals', () {
    expect(packBits(Uint8List.fromList([7, 7, 7, 7, 7])), [0xFC, 7]);
    expect(packBits(Uint8List.fromList([1, 2, 3])), [2, 1, 2, 3]);
    expect(packBits(Uint8List(0)), isEmpty);
  });

  test('what is written is read back layer by layer', () {
    final file = readPsd(_sample(), premultiply: false);
    expect((file.width, file.height), (40, 30));
    expect(file.simplified, isFalse);
    expect(file.layers, hasLength(2));

    final background = file.layers.first;
    expect(background.name, 'Background');
    expect(background.opacity, 255);
    expect(background.visible, isTrue);
    expect(_at(background, 0, 0), 0xFF000040);
    expect(
      _at(background, 39, 29),
      0xFF000040 | (39 * 6) << 16 | (29 * 8) << 8,
    );

    final dot = file.layers.last;
    expect(dot.name, 'Ação ✓');
    expect(dot.opacity, 128);
    expect(dot.blendKey, 'mul ');
    expect(dot.visible, isFalse);
    expect(_at(dot, 27, -1), 0x80FF0000);
    expect(_at(dot, 32, 4), 0x80FF0000);
    expect(_at(dot, 26, -1), 0);
    expect(_at(dot, 33, 4), 0);
  });

  test('pixels come premultiplied when asked', () {
    final dot = readPsd(_sample(), premultiply: true).layers.last;
    expect(_at(dot, 27, -1), 0x80800000);
  });

  test('another reader sees the same finished picture', () {
    final decoded = img.PsdDecoder().decode(_sample())!;
    expect((decoded.width, decoded.height), (40, 30));
    for (final (x, y) in [(0, 0), (39, 29), (17, 5), (3, 22)]) {
      final pixel = decoded.getPixel(x, y);
      expect(
        (pixel.r, pixel.g, pixel.b),
        (x * 6, y * 8, 0x40),
        reason: '$x,$y',
      );
    }
  });

  test('a layer with nothing in it survives', () {
    final merged = _filled(8, 8, (x, y) => 0xFFFFFFFF);
    final bytes = writePsd(merged, [
      _plain('Paper', merged),
      _plain('Empty', RgbaImage(8, 8)),
    ]);
    final file = readPsd(bytes, premultiply: false);
    expect(file.layers.map((layer) => layer.name), ['Paper', 'Empty']);
    expect(_at(file.layers.last, 4, 4), 0);
  });

  test('a file cut short never reads past its end', () {
    final bytes = _sample();
    var refused = 0;
    for (var length = 0; length < bytes.length; length += 7) {
      try {
        // only the finished picture may be missing: the layers come whole
        final file = readPsd(
          Uint8List.sublistView(bytes, 0, length),
          premultiply: false,
        );
        expect(file.layers, hasLength(2), reason: 'cut at $length');
      } on FormatException {
        refused++;
      } on PsdUnsupported {
        refused++;
      }
    }
    expect(refused, greaterThan(100));
  });

  test('what is not a PSD is refused', () {
    expect(
      () => readPsd(Uint8List.fromList(List.filled(64, 1)), premultiply: false),
      throwsFormatException,
    );
  });

  test('a PSD larger than the app allows is refused before any pixel', () {
    final bytes = _sample();
    // the height sits at byte 14 of the header, big endian
    ByteData.sublistView(bytes).setUint32(14, maxImageSide + 1);
    expect(
      () => readPsd(bytes, premultiply: false),
      throwsA(isA<PsdTooLarge>()),
    );
  });
}
