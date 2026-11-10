import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:voges_click/painting/image_formats.dart';
import 'package:voges_click/painting/rgba_image.dart';

void main() {
  test('knows the format of a file name', () {
    expect(SaveFormat.of('drawing.PNG'), SaveFormat.png);
    expect(SaveFormat.of('photo.jpeg'), SaveFormat.jpeg);
    expect(SaveFormat.of('photo.jpg'), SaveFormat.jpeg);
    expect(SaveFormat.of('old.bmp'), SaveFormat.bmp);
    expect(SaveFormat.of('animation.gif'), isNull);
    expect(SaveFormat.of('no extension'), isNull);
  });

  test('JPEG and BMP lay transparent pixels over white', () {
    final image = RgbaImage(
      2,
      1,
      Uint8List.fromList([255, 0, 0, 255, 0, 0, 255, 0]),
    );
    expect(image.hasTransparency, isTrue);
    final bmp = img.decodeBmp(encodeOpaque(image, SaveFormat.bmp))!;
    expect(bmp.getPixel(0, 0).r, 255);
    expect(bmp.getPixel(0, 0).g, 0);
    final clear = bmp.getPixel(1, 0);
    expect([clear.r, clear.g, clear.b], [255, 255, 255]);
    final jpeg = img.decodeJpg(encodeOpaque(image, SaveFormat.jpeg))!;
    expect(jpeg.width, 2);
  });

  test('turns formats the engine does not read into PNG', () {
    final tga = img.encodeTga(img.Image(width: 3, height: 2));
    final png = transcodeToPng(tga)!;
    final decoded = img.decodePng(png)!;
    expect([decoded.width, decoded.height], [3, 2]);
    expect(transcodeToPng(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
