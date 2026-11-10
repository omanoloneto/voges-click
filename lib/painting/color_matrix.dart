import 'dart:math' as math;

/// 5 × 4 color matrices, row by row, as `ColorFilter.matrix` takes them.
typedef ColorMatrix = List<double>;

const identityMatrix = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

const invertMatrix = <double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
];

const _red = 0.2126, _green = 0.7152, _blue = 0.0722;

/// [amount] from -1 (black) to 1 (white).
ColorMatrix brightnessMatrix(double amount) {
  final shift = 255 * amount;
  return [
    1,
    0,
    0,
    0,
    shift,
    0,
    1,
    0,
    0,
    shift,
    0,
    0,
    1,
    0,
    shift,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// [amount] from -1 (flat gray) to 1 (twice the contrast).
ColorMatrix contrastMatrix(double amount) {
  final scale = 1 + amount;
  final shift = 127.5 * (1 - scale);
  return [
    scale, 0, 0, 0, shift, //
    0, scale, 0, 0, shift, //
    0, 0, scale, 0, shift, //
    0, 0, 0, 1, 0, //
  ];
}

/// [amount] from -1 (grayscale) to 1 (twice as vivid).
ColorMatrix saturationMatrix(double amount) {
  final s = 1 + amount;
  final r = _red * (1 - s), g = _green * (1 - s), b = _blue * (1 - s);
  return [
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0, //
    r, g, b + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Turns every hue by [degrees] around the color wheel.
ColorMatrix hueMatrix(double degrees) {
  final angle = degrees * math.pi / 180;
  final c = math.cos(angle), s = math.sin(angle);
  return [
    _red + c * (1 - _red) - s * _red,
    _green - c * _green - s * _green,
    _blue - c * _blue + s * (1 - _blue),
    0,
    0,
    _red - c * _red + s * 0.143,
    _green + c * (1 - _green) + s * 0.140,
    _blue - c * _blue - s * 0.283,
    0,
    0,
    _red - c * _red - s * (1 - _red),
    _green - c * _green + s * _green,
    _blue + c * (1 - _blue) + s * _blue,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// The matrix that does [first] and then [second].
ColorMatrix combine(ColorMatrix first, ColorMatrix second) {
  final result = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var column = 0; column < 5; column++) {
      var sum = column == 4 ? second[row * 5 + 4] : 0.0;
      for (var k = 0; k < 4; k++) {
        sum += second[row * 5 + k] * first[k * 5 + column];
      }
      result[row * 5 + column] = sum;
    }
  }
  return result;
}

ColorMatrix adjustmentMatrix({
  double brightness = 0,
  double contrast = 0,
  double saturation = 0,
  double hue = 0,
}) => [
  hueMatrix(hue),
  saturationMatrix(saturation),
  contrastMatrix(contrast),
  brightnessMatrix(brightness),
].reduce(combine);
