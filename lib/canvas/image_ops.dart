import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../painting/image_formats.dart';
import '../painting/rgba_image.dart';

/// A new [width] × [height] image with what [draw] paints.
ui.Image renderImage(int width, int height, void Function(Canvas canvas) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    // lets what is drawn skip all that falls outside the image
    ..clipRect(
      Offset.zero & Size(width.toDouble(), height.toDouble()),
      doAntiAlias: false,
    );
  draw(canvas);
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, height);
  } finally {
    picture.dispose();
  }
}

Future<RgbaImage> readPixels(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return RgbaImage(
    image.width,
    image.height,
    data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

Future<Uint8List> encodePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// An image from premultiplied RGBA bytes.
Future<ui.Image> imageFromPixels(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Decodes an image file; the formats the engine does not read (TIFF, TGA)
/// go through PNG first. Throws [FormatException] for anything else.
Future<ui.Image> decodeImageBytes(Uint8List bytes) async {
  try {
    return await _engineDecode(bytes);
  } catch (_) {
    final png = await compute(transcodeToPng, bytes);
    if (png == null) throw const FormatException('Not an image');
    return _engineDecode(png);
  }
}

Future<ui.Image> _engineDecode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

enum Turn { left, right, flipHorizontal, flipVertical }

ui.Image turnImage(ui.Image image, Turn turn) {
  final w = image.width.toDouble(), h = image.height.toDouble();
  final sideways = turn == Turn.left || turn == Turn.right;
  return renderImage(
    sideways ? image.height : image.width,
    sideways ? image.width : image.height,
    (canvas) {
      switch (turn) {
        case Turn.right:
          canvas
            ..translate(h, 0)
            ..rotate(math.pi / 2);
        case Turn.left:
          canvas
            ..translate(0, w)
            ..rotate(-math.pi / 2);
        case Turn.flipHorizontal:
          canvas
            ..translate(w, 0)
            ..scale(-1, 1);
        case Turn.flipVertical:
          canvas
            ..translate(0, h)
            ..scale(1, -1);
      }
      canvas.drawImage(image, Offset.zero, Paint()..blendMode = BlendMode.src);
    },
  );
}

/// [image] stretched to a new size.
ui.Image scaleImage(ui.Image image, int width, int height) =>
    renderImage(width, height, (canvas) {
      canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Offset.zero & Size(width.toDouble(), height.toDouble()),
        Paint()
          ..blendMode = BlendMode.src
          ..filterQuality = FilterQuality.medium,
      );
    });
