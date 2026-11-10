import 'dart:ui' as ui;

import 'package:voges_click/canvas/image_ops.dart';
import 'package:voges_click/document/compositor.dart';
import 'package:voges_click/document/image_document.dart';
import 'package:voges_click/painting/rgba_image.dart';

const white = ui.Color(0xFFFFFFFF);
const red = ui.Color(0xFFFF0000);
const blue = ui.Color(0xFF0000FF);

/// What the layers of [state] look like together.
Future<RgbaImage> composite(DocumentState state) async {
  final image = renderImage(
    state.width,
    state.height,
    (canvas) => paintLayers(canvas, state),
  );
  final pixels = await readPixels(image);
  image.dispose();
  return pixels;
}
