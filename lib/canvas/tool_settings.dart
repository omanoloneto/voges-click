import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum EditTool {
  move,
  marquee,
  ellipseMarquee,
  lasso,
  crop,
  picker,
  brush,
  pencil,
  eraser,
  fill,
  gradient,
  text,
  line,
  rectangle,
  ellipse,
  hand,
  zoom;

  bool get isSelection =>
      this == marquee || this == ellipseMarquee || this == lasso;

  bool get isShape => this == line || this == rectangle || this == ellipse;

  bool get isPen => this == brush || this == pencil || this == eraser;

  bool get usesSize => isPen || isShape;

  /// Alt turns these into the color picker for one click.
  bool get picksWithAlt =>
      this == brush ||
      this == pencil ||
      this == fill ||
      this == gradient ||
      isShape;

  bool get usesOpacity => isPen || isShape || this == fill || this == gradient;
}

const minBrushSize = 1.0;
const maxBrushSize = 400.0;

/// Two rows, dark on top and light below.
const paletteColors = [
  Color(0xFF000000),
  Color(0xFF7F7F7F),
  Color(0xFF880015),
  Color(0xFFED1C24),
  Color(0xFFFF7F27),
  Color(0xFFFFF200),
  Color(0xFF22B14C),
  Color(0xFF00A2E8),
  Color(0xFF3F48CC),
  Color(0xFFA349A4),
  Color(0xFFFFFFFF),
  Color(0xFFC3C3C3),
  Color(0xFFB97A57),
  Color(0xFFFFAEC9),
  Color(0xFFFFC90E),
  Color(0xFFEFE4B0),
  Color(0xFFB5E61D),
  Color(0xFF99D9EA),
  Color(0xFF7092BE),
  Color(0xFFC8BFE7),
];

/// The chosen tool, its options and the two colors. The colors are always
/// opaque: how strong the paint goes on is the tool's opacity.
class ToolSettings extends ChangeNotifier {
  EditTool _tool = EditTool.brush;
  double _size = 12;
  double _opacity = 1;
  double _hardness = 0.8;
  int _tolerance = 32;
  Color _color1 = paletteColors.first;
  Color _color2 = const Color(0xFFFFFFFF);
  bool _filled = false;

  EditTool get tool => _tool;
  double get size => _size;
  double get opacity => _opacity;
  double get hardness => _hardness;

  /// How far a color may be from the clicked one and still be filled.
  int get tolerance => _tolerance;

  /// Foreground: what the tools paint with.
  Color get color1 => _color1;

  /// Background: the far end of gradients.
  Color get color2 => _color2;

  /// Shapes are filled with their color instead of only outlined.
  bool get filled => _filled;

  set tool(EditTool value) => _set(value != _tool, () => _tool = value);

  set size(double value) {
    final size = value.clamp(minBrushSize, maxBrushSize).roundToDouble();
    _set(size != _size, () => _size = size);
  }

  set opacity(double value) {
    final opacity = value.clamp(0.01, 1.0).toDouble();
    _set(opacity != _opacity, () => _opacity = opacity);
  }

  set hardness(double value) {
    final hardness = value.clamp(0.0, 1.0).toDouble();
    _set(hardness != _hardness, () => _hardness = hardness);
  }

  set tolerance(int value) {
    final tolerance = value.clamp(0, 255);
    _set(tolerance != _tolerance, () => _tolerance = tolerance);
  }

  set color1(Color value) => _set(true, () => _color1 = value.withAlpha(255));

  set color2(Color value) => _set(true, () => _color2 = value.withAlpha(255));

  set filled(bool value) => _set(value != _filled, () => _filled = value);

  void swapColors() => _set(true, () {
    final first = _color1;
    _color1 = _color2;
    _color2 = first;
  });

  void resetColors() => _set(true, () {
    _color1 = const Color(0xFF000000);
    _color2 = const Color(0xFFFFFFFF);
  });

  void _set(bool changed, VoidCallback apply) {
    if (!changed) return;
    apply();
    notifyListeners();
  }
}
