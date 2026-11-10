import 'dart:math' as math;

import 'package:flutter/painting.dart';

const minZoom = 0.05;
const maxZoom = 32.0;

/// Stops of the zoom buttons and shortcuts.
const zoomSteps = [
  0.125,
  0.25,
  0.5,
  0.75,
  1.0,
  1.5,
  2.0,
  3.0,
  4.0,
  6.0,
  8.0,
  12.0,
  16.0,
  24.0, //
  32.0,
];

double clampZoom(double zoom) => zoom.clamp(minZoom, maxZoom).toDouble();

/// The next stop up (direction > 0) or down, or null past the last one.
double? nextZoom(double zoom, int direction) {
  if (direction > 0) {
    for (final step in zoomSteps) {
      if (step > zoom + 1e-6) return step;
    }
    return null;
  }
  for (final step in zoomSteps.reversed) {
    if (step < zoom - 1e-6) return step;
  }
  return null;
}

/// The zoom that shows the whole image in [viewport], with [margin] around.
double fitZoom(Size viewport, int width, int height, double margin) {
  final room = Size(
    math.max(1, viewport.width - margin * 2),
    math.max(1, viewport.height - margin * 2),
  );
  return clampZoom(math.min(room.width / width, room.height / height));
}
