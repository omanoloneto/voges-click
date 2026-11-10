import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/painting/color_matrix.dart';

void _expectClose(List<double> actual, List<double> expected) {
  expect(actual, hasLength(expected.length));
  for (var i = 0; i < expected.length; i++) {
    expect(actual[i], closeTo(expected[i], 1e-6), reason: 'entry $i');
  }
}

void main() {
  test('no adjustment leaves the colors alone', () {
    _expectClose(adjustmentMatrix(), identityMatrix);
  });

  test('inverting twice gives the image back', () {
    _expectClose(combine(invertMatrix, invertMatrix), identityMatrix);
  });

  test('a full turn of hue changes nothing', () {
    _expectClose(hueMatrix(360), identityMatrix);
  });

  test('no saturation gives the same gray on the three channels', () {
    final gray = saturationMatrix(-1);
    expect(gray.sublist(0, 5), gray.sublist(5, 10));
    expect(gray.sublist(0, 5), gray.sublist(10, 15));
    expect(gray[0] + gray[1] + gray[2], closeTo(1, 1e-6));
  });

  test('brightness moves the three channels and keeps the alpha', () {
    final brighter = brightnessMatrix(0.5);
    expect(brighter[4], greaterThan(0));
    expect(brighter.sublist(15), [0, 0, 0, 1, 0]);
  });
}
