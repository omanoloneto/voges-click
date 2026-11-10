import 'dart:ui' as ui;

import 'tiled_image.dart';

/// How a layer mixes with what is under it. The keys are the ones PSD
/// files use.
enum LayerBlend {
  normal('norm', ui.BlendMode.srcOver),
  darken('dark', ui.BlendMode.darken),
  multiply('mul ', ui.BlendMode.multiply),
  colorBurn('idiv', ui.BlendMode.colorBurn),
  lighten('lite', ui.BlendMode.lighten),
  screen('scrn', ui.BlendMode.screen),
  colorDodge('div ', ui.BlendMode.colorDodge),
  linearDodge('lddg', ui.BlendMode.plus),
  overlay('over', ui.BlendMode.overlay),
  softLight('sLit', ui.BlendMode.softLight),
  hardLight('hLit', ui.BlendMode.hardLight),
  difference('diff', ui.BlendMode.difference),
  exclusion('smud', ui.BlendMode.exclusion),
  hue('hue ', ui.BlendMode.hue),
  saturation('sat ', ui.BlendMode.saturation),
  color('colr', ui.BlendMode.color),
  luminosity('lum ', ui.BlendMode.luminosity);

  const LayerBlend(this.psdKey, this.mode);

  final String psdKey;
  final ui.BlendMode mode;

  /// Modes the app does not have open as normal.
  static LayerBlend ofPsd(String key) {
    for (final blend in values) {
      if (blend.psdKey == key) return blend;
    }
    return normal;
  }
}

/// One sheet of pixels in the stack. The image may be smaller or bigger
/// than the document: [offset] says where its top left corner sits.
class Layer {
  const Layer({
    required this.id,
    required this.name,
    required this.pixels,
    this.offset = ui.Offset.zero,
    this.visible = true,
    this.opacity = 1,
    this.blend = LayerBlend.normal,
  });

  final int id;
  final String name;
  final TiledImage pixels;
  final ui.Offset offset;
  final bool visible;
  final double opacity;
  final LayerBlend blend;

  ui.Rect get bounds =>
      offset & ui.Size(pixels.width.toDouble(), pixels.height.toDouble());

  Layer copyWith({
    int? id,
    String? name,
    TiledImage? pixels,
    ui.Offset? offset,
    bool? visible,
    double? opacity,
    LayerBlend? blend,
  }) => Layer(
    id: id ?? this.id,
    name: name ?? this.name,
    pixels: pixels ?? this.pixels,
    offset: offset ?? this.offset,
    visible: visible ?? this.visible,
    opacity: opacity ?? this.opacity,
    blend: blend ?? this.blend,
  );
}
