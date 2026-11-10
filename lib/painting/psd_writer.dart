import 'dart:typed_data';

import 'rgba_image.dart';

/// A layer to be written: straight RGBA pixels and where they sit.
class PsdLayerSource {
  const PsdLayerSource({
    required this.name,
    required this.left,
    required this.top,
    required this.image,
    required this.opacity,
    required this.blendKey,
    required this.visible,
  });

  final String name;
  final int left;
  final int top;
  final RgbaImage image;

  /// From 0 to 255.
  final int opacity;
  final String blendKey;
  final bool visible;
}

/// An 8 bit RGB PSD with [layers] (bottom first) and [merged], the picture
/// programs that do not read layers show.
Uint8List writePsd(RgbaImage merged, List<PsdLayerSource> layers) {
  final transparent = merged.hasTransparency;
  final out = _Output()
    ..ascii('8BPS')
    ..u16(1)
    ..zeros(6)
    ..u16(transparent ? 4 : 3)
    ..u32(merged.height)
    ..u32(merged.width)
    ..u16(8)
    ..u16(3)
    ..u32(0)
    ..u32(0);

  final info = _Output();
  // a negative count says the merged picture carries transparency
  info.i16(transparent ? -layers.length : layers.length);
  final channelData = <Uint8List>[];
  for (final layer in layers) {
    final box = _contentBox(layer.image);
    final planes = [
      for (final channel in const [3, 0, 1, 2])
        _packPlane(layer.image, box, channel),
    ];
    channelData.addAll(planes);
    info
      ..i32(layer.top + box.top)
      ..i32(layer.left + box.left)
      ..i32(layer.top + box.bottom)
      ..i32(layer.left + box.right)
      ..u16(4);
    for (var i = 0; i < 4; i++) {
      info
        ..i16(i - 1)
        ..u32(planes[i].length);
    }
    final extra = _Output()
      ..u32(0)
      ..u32(0)
      ..pascal(layer.name)
      ..ascii('8BIM')
      ..ascii('luni')
      ..unicode(layer.name);
    info
      ..ascii('8BIM')
      ..ascii(layer.blendKey)
      ..u8(layer.opacity)
      ..u8(0)
      ..u8(layer.visible ? 0 : 2)
      ..u8(0)
      ..u32(extra.length)
      ..add(extra.take());
  }
  channelData.forEach(info.add);
  info.zeros(-info.length & 3);

  out
    ..u32(4 + info.length + 4)
    ..u32(info.length)
    ..add(info.take())
    ..u32(0);

  _writeMerged(out, merged, transparent);
  return out.take();
}

typedef _Box = ({int left, int top, int right, int bottom});

/// The smallest box with every pixel that is not fully transparent, so
/// empty margins take no room in the file.
_Box _contentBox(RgbaImage image) {
  final pixels = image.pixels;
  final width = image.width, height = image.height;
  var left = width, top = height, right = 0, bottom = 0;
  for (var y = 0; y < height; y++) {
    var p = y * width * 4 + 3;
    for (var x = 0; x < width; x++, p += 4) {
      if (pixels[p] == 0) continue;
      if (x < left) left = x;
      if (x >= right) right = x + 1;
      if (y < top) top = y;
      bottom = y + 1;
    }
  }
  if (right == 0) return (left: 0, top: 0, right: 0, bottom: 0);
  return (left: left, top: top, right: right, bottom: bottom);
}

Uint8List _packPlane(RgbaImage image, _Box box, int channel) {
  final width = box.right - box.left, height = box.bottom - box.top;
  final rows = <Uint8List>[];
  final row = Uint8List(width);
  for (var y = box.top; y < box.bottom; y++) {
    var p = (y * image.width + box.left) * 4 + channel;
    for (var x = 0; x < width; x++, p += 4) {
      row[x] = image.pixels[p];
    }
    rows.add(packBits(row));
  }
  final out = _Output()..u16(1);
  for (final packed in rows) {
    out.u16(packed.length);
  }
  rows.forEach(out.add);
  assert(rows.length == height);
  return out.take();
}

/// Photoshop keeps the merged picture laid over white, with the
/// transparency as a fourth channel.
void _writeMerged(_Output out, RgbaImage merged, bool transparent) {
  final pixels = merged.pixels;
  final width = merged.width, height = merged.height;
  final rows = <Uint8List>[];
  final row = Uint8List(width);
  for (final channel in transparent ? const [0, 1, 2, 3] : const [0, 1, 2]) {
    for (var y = 0; y < height; y++) {
      var p = y * width * 4;
      for (var x = 0; x < width; x++, p += 4) {
        final a = pixels[p + 3];
        row[x] = channel == 3 || a == 255
            ? pixels[p + channel]
            : (pixels[p + channel] * a + 255 * (255 - a) + 127) ~/ 255;
      }
      rows.add(packBits(row));
    }
  }
  out.u16(1);
  for (final packed in rows) {
    out.u16(packed.length);
  }
  rows.forEach(out.add);
}

/// PackBits: runs of three or more equal bytes become two bytes, the rest
/// goes as it is in blocks of up to 128.
Uint8List packBits(Uint8List row) {
  final out = BytesBuilder(copy: false);
  final length = row.length;
  var i = 0;
  while (i < length) {
    var run = 1;
    while (i + run < length && run < 128 && row[i + run] == row[i]) {
      run++;
    }
    if (run >= 3) {
      out
        ..addByte(257 - run)
        ..addByte(row[i]);
      i += run;
      continue;
    }
    final start = i;
    while (i < length && i - start < 128) {
      if (i + 2 < length && row[i] == row[i + 1] && row[i] == row[i + 2]) {
        break;
      }
      i++;
    }
    out
      ..addByte(i - start - 1)
      ..add(Uint8List.sublistView(row, start, i));
  }
  return out.takeBytes();
}

class _Output {
  final _bytes = BytesBuilder(copy: false);

  int get length => _bytes.length;

  Uint8List take() => _bytes.takeBytes();

  void add(Uint8List bytes) => _bytes.add(bytes);

  void zeros(int count) => _bytes.add(Uint8List(count));

  void u8(int value) => _bytes.addByte(value & 0xFF);

  void u16(int value) => _bytes.add([value >> 8 & 0xFF, value & 0xFF]);

  void i16(int value) => u16(value & 0xFFFF);

  void u32(int value) => _bytes.add([
    value >> 24 & 0xFF,
    value >> 16 & 0xFF,
    value >> 8 & 0xFF,
    value & 0xFF,
  ]);

  void i32(int value) => u32(value & 0xFFFFFFFF);

  void ascii(String text) => _bytes.add(text.codeUnits);

  /// The old one byte name every layer still needs; the real one goes in
  /// the unicode block.
  void pascal(String text) {
    final codes = [
      for (final code in text.codeUnits.take(255)) code < 128 ? code : 0x3F,
    ];
    u8(codes.length);
    _bytes.add(codes);
    zeros(3 - codes.length % 4);
  }

  void unicode(String text) {
    final units = text.codeUnits;
    final padding = -(4 + units.length * 2) & 3;
    u32(4 + units.length * 2 + padding);
    u32(units.length);
    units.forEach(u16);
    zeros(padding);
  }
}
