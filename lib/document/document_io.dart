import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../canvas/image_ops.dart';
import '../painting/image_formats.dart';
import '../painting/psd_reader.dart';
import '../painting/psd_writer.dart';
import '../painting/rgba_image.dart';
import 'compositor.dart';
import 'image_document.dart';
import 'layer.dart';

class ImageTooLarge implements Exception {
  const ImageTooLarge();
}

/// How much of a file made it into the document.
enum LoadLoss {
  none,

  /// A PSD whose layers came, but not everything they had (groups, masks,
  /// effects, live text…).
  simplified,

  /// A PSD of a kind the app does not read layer by layer: only its
  /// finished picture came, as one layer.
  flattened,
}

class LoadedDocument {
  const LoadedDocument(this.state, this.loss);

  final DocumentState state;
  final LoadLoss loss;
}

bool _isPsd(Uint8List bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x38 &&
    bytes[1] == 0x42 &&
    bytes[2] == 0x50 &&
    bytes[3] == 0x53;

enum _PsdFailure { unreadable, tooLarge }

(PsdFile?, _PsdFailure?) _readPsd(Uint8List bytes) {
  try {
    return (readPsd(bytes, premultiply: true), null);
  } on PsdTooLarge {
    return (null, _PsdFailure.tooLarge);
  } catch (_) {
    return (null, _PsdFailure.unreadable);
  }
}

/// Reads an image file into layers. [layerName] names the only layer of a
/// flat image.
///
/// Throws [ImageTooLarge], or [FormatException] for what is not an image.
Future<LoadedDocument> loadDocument(
  Uint8List bytes, {
  required String layerName,
}) async {
  var loss = LoadLoss.none;
  if (_isPsd(bytes)) {
    final (file, failure) = await compute(_readPsd, bytes);
    if (failure == _PsdFailure.tooLarge) throw const ImageTooLarge();
    if (file != null) {
      final layers = <Layer>[];
      for (final (index, source) in file.layers.indexed) {
        final empty = source.width < 1 || source.height < 1;
        layers.add(
          Layer(
            id: index + 1,
            name: source.name.isEmpty ? layerName : source.name,
            image: empty
                ? blankImage(1, 1, const ui.Color(0x00000000))
                : await imageFromPixels(
                    source.pixels,
                    source.width,
                    source.height,
                  ),
            offset: ui.Offset(source.left.toDouble(), source.top.toDouble()),
            visible: source.visible,
            opacity: source.opacity / 255,
            blend: LayerBlend.ofPsd(source.blendKey),
          ),
        );
      }
      return LoadedDocument(
        DocumentState(file.width, file.height, layers),
        file.simplified ? LoadLoss.simplified : LoadLoss.none,
      );
    }
    loss = LoadLoss.flattened;
  }

  final ui.Image image;
  try {
    image = await decodeImageBytes(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Not an image');
  }
  if (image.width > maxImageSide || image.height > maxImageSide) {
    image.dispose();
    throw const ImageTooLarge();
  }
  return LoadedDocument(
    DocumentState(image.width, image.height, [
      Layer(id: 1, name: layerName, image: image),
    ]),
    loss,
  );
}

/// The bytes of [state] as a file of [format]. Only PSD keeps the layers;
/// the others get the picture the layers make together.
Future<Uint8List> encodeDocument(DocumentState state, SaveFormat format) async {
  final merged = renderImage(
    state.width,
    state.height,
    (canvas) => paintLayers(canvas, state),
  );
  try {
    if (format == SaveFormat.png) return await encodePng(merged);
    final pixels = await readPixels(merged);
    if (format != SaveFormat.psd) {
      return await compute(_encodeOpaque, (pixels, format));
    }
    final layers = <PsdLayerSource>[];
    for (final layer in state.layers) {
      layers.add(
        PsdLayerSource(
          name: layer.name,
          left: layer.offset.dx.round(),
          top: layer.offset.dy.round(),
          image: await readPixels(layer.image),
          opacity: (layer.opacity * 255).round(),
          blendKey: layer.blend.psdKey,
          visible: layer.visible,
        ),
      );
    }
    return await compute(_writePsd, (pixels, layers));
  } finally {
    merged.dispose();
  }
}

Uint8List _encodeOpaque((RgbaImage, SaveFormat) request) =>
    encodeOpaque(request.$1, request.$2);

Uint8List _writePsd((RgbaImage, List<PsdLayerSource>) request) =>
    writePsd(request.$1, request.$2);
