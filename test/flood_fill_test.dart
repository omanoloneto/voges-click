import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/painting/flood_fill.dart';
import 'package:voges_click/painting/rgba_image.dart';

RgbaImage _image(int width, int height, int argb) {
  final image = RgbaImage(width, height);
  for (var i = 0; i < width * height; i++) {
    _set(image, i % width, i ~/ width, argb);
  }
  return image;
}

void _set(RgbaImage image, int x, int y, int argb) {
  final p = (y * image.width + x) * 4;
  image.pixels
    ..[p] = argb >> 16 & 0xFF
    ..[p + 1] = argb >> 8 & 0xFF
    ..[p + 2] = argb & 0xFF
    ..[p + 3] = argb >>> 24;
}

void main() {
  test('fills the inside of a closed outline and nothing outside', () {
    final image = _image(10, 10, 0xFFFFFFFF);
    for (var i = 2; i <= 7; i++) {
      _set(image, i, 2, 0xFF000000);
      _set(image, i, 7, 0xFF000000);
      _set(image, 2, i, 0xFF000000);
      _set(image, 7, i, 0xFF000000);
    }
    final mask = fillMask(image, 4, 4)!;
    int at(int x, int y) => mask[y * 10 + x];
    expect(at(3, 3), 1);
    expect(at(6, 6), 1);
    expect(at(2, 4), 0, reason: 'the outline stays');
    expect(at(0, 0), 0, reason: 'outside is another area');
    expect(mask.where((value) => value == 1).length, 16);
  });

  test('crosses a soft edge within the tolerance but not a hard one', () {
    final image = _image(5, 1, 0xFFFFFFFF);
    _set(image, 1, 0, 0xFFE0E0E0);
    _set(image, 3, 0, 0xFF404040);
    final mask = fillMask(image, 0, 0)!;
    expect(mask, [1, 1, 1, 0, 0]);
  });

  test('a diagonal gap does not leak, as fills go four ways', () {
    final image = _image(3, 3, 0xFFFFFFFF);
    _set(image, 1, 0, 0xFF000000);
    _set(image, 0, 1, 0xFF000000);
    final mask = fillMask(image, 0, 0)!;
    expect(mask.where((value) => value == 1).length, 1);
  });

  test('transparent pixels match whatever color they keep', () {
    final image = _image(3, 1, 0x00000000);
    _set(image, 1, 0, 0x00FF0000);
    expect(fillMask(image, 0, 0), [1, 1, 1]);
  });

  test('the layer has the color on the area and is clear elsewhere', () {
    final image = _image(2, 1, 0xFFFFFFFF);
    _set(image, 1, 0, 0xFF000000);
    final layer = fillLayer(image, 0, 0, 0xFFED1C24)!;
    expect(layer, [0xED, 0x1C, 0x24, 0xFF, 0, 0, 0, 0]);
  });

  test('outside the image there is nothing to fill', () {
    expect(fillMask(_image(2, 2, 0xFFFFFFFF), 2, 0), isNull);
    expect(fillMask(_image(2, 2, 0xFFFFFFFF), -1, 0), isNull);
  });
}
