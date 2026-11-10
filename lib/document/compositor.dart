import 'dart:typed_data';
import 'dart:ui';

import '../canvas/marks.dart';
import 'image_document.dart';
import 'layer.dart';
import 'tiled_image.dart';

/// Pixels lifted off a layer while they are being transformed.
class FloatingPiece {
  const FloatingPiece({
    required this.pixels,
    required this.part,
    required this.matrix,
    required this.smooth,
    this.rest,
  });

  /// The image the piece is a part of, never copied to be shown.
  final TiledImage pixels;

  /// The part of [pixels] that floats.
  final Rect part;

  /// Takes the pixels of [part], counted from its top left corner, to
  /// where they show on the document.
  final Float64List matrix;

  /// Scaled or turned pixels are blended; moved ones stay as they are.
  final bool smooth;

  /// What stays of the layer under the piece; null when all of it floats.
  final TiledImage? rest;
}

/// What is still being done to one layer and shows before it is committed:
/// a stroke, a drag of the move tool, an adjustment being tuned.
class LivePreview {
  const LivePreview({
    required this.layerId,
    this.mark,
    this.clip,
    this.shift = Offset.zero,
    this.filter,
    this.floating,
  });

  final int layerId;
  final Mark? mark;

  /// The selection: marks and filters stay inside it.
  final Path? clip;
  final Offset shift;
  final ColorFilter? filter;
  final FloatingPiece? floating;
}

/// Paints the visible layers, bottom first, in document pixels.
void paintLayers(
  Canvas canvas,
  DocumentState state, {
  LivePreview? live,
  FilterQuality quality = FilterQuality.none,
}) {
  final bounds = state.rect;
  // blend modes must mix with the layers below, not with whatever is
  // behind the image (the checkerboard, the page)
  final isolated = state.layers.any(
    (layer) => layer.visible && layer.blend != LayerBlend.normal,
  );
  if (isolated) canvas.saveLayer(bounds, Paint());
  for (final layer in state.layers) {
    if (!layer.visible) continue;
    final paint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, layer.opacity)
      ..blendMode = layer.blend.mode
      ..filterQuality = quality;
    if (live == null || live.layerId != layer.id) {
      layer.pixels.paint(canvas, layer.offset, paint);
      continue;
    }
    final plain = Paint()..filterQuality = quality;
    if (live.floating case final floating?) {
      canvas.saveLayer(bounds, paint);
      if (floating.rest case final rest?) {
        rest.paint(canvas, layer.offset, plain);
      }
      canvas
        ..transform(floating.matrix)
        // tiles are drawn with hard edges: the clip softens the outline
        ..clipRect(
          Offset.zero & floating.part.size,
          doAntiAlias: floating.smooth,
        );
      floating.pixels.paint(
        canvas,
        -floating.part.topLeft,
        floating.smooth
            ? (Paint()..filterQuality = FilterQuality.medium)
            : plain,
      );
      canvas.restore();
      continue;
    }
    final at = layer.offset + live.shift;
    canvas.saveLayer(bounds, paint);
    layer.pixels.paint(canvas, at, plain);
    canvas
      ..save()
      ..clipRect(bounds);
    if (live.clip case final clip?) canvas.clipPath(clip);
    if (live.filter case final filter?) {
      layer.pixels.paint(
        canvas,
        at,
        Paint()
          ..filterQuality = quality
          ..colorFilter = filter
          ..blendMode = BlendMode.src,
      );
    }
    live.mark?.paint(canvas);
    canvas
      ..restore()
      ..restore();
  }
  if (isolated) canvas.restore();
}
