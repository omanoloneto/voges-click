import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'rgba_image.dart';

/// A PSD the app cannot split into layers (CMYK, Lab, 32 bits per channel,
/// the large PSB format), though another decoder may still show it flat.
class PsdUnsupported implements Exception {
  const PsdUnsupported(this.reason);

  final String reason;

  @override
  String toString() => 'PsdUnsupported: $reason';
}

class PsdTooLarge implements Exception {
  const PsdTooLarge();
}

class PsdLayer {
  const PsdLayer({
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.opacity,
    required this.blendKey,
    required this.visible,
    required this.pixels,
  });

  final String name;
  final int left;
  final int top;

  /// Zero for a layer with no pixels.
  final int width;
  final int height;

  /// From 0 to 255.
  final int opacity;
  final String blendKey;
  final bool visible;

  /// Straight RGBA, or premultiplied when the reader was asked for it.
  final Uint8List pixels;
}

class PsdFile {
  const PsdFile({
    required this.width,
    required this.height,
    required this.layers,
    required this.simplified,
  });

  final int width;
  final int height;

  /// Bottom layer first.
  final List<PsdLayer> layers;

  /// The file had something that does not survive here: groups, masks,
  /// clipping, effects, live text, adjustment layers, smart objects, 16 bits
  /// per channel. The pixels of each layer are still the ones in the file.
  final bool simplified;
}

const _adjustmentKeys = {
  'SoCo', 'GdFl', 'PtFl', 'brit', 'levl', 'curv', 'expA', 'vibA', 'hue ', //
  'hue2', 'blnc', 'blwh', 'phfl', 'mixr', 'clrL', 'nvrt', 'post', 'thrs',
  'grdm', 'selc',
};

const _lossyKeys = {
  'TySh', 'lfx2', 'lrFX', 'SoLd', 'PlLd', 'SoLE', 'vmsk', 'vsms', //
};

/// Reads the layers of a PSD file. [premultiply] gives the pixels the way
/// the graphics engine wants them.
///
/// Throws [FormatException] for bytes that are not a sound PSD,
/// [PsdUnsupported] for kinds it does not read and [PsdTooLarge] for images
/// over [maxImageSide].
PsdFile readPsd(Uint8List bytes, {bool premultiply = false}) {
  final input = _Input(bytes);
  if (input.ascii(4) != '8BPS') throw const FormatException('Not a PSD');
  final version = input.u16();
  if (version == 2) throw const PsdUnsupported('PSB');
  if (version != 1) throw const FormatException('Unknown PSD version');
  input.skip(6);
  final channels = input.u16();
  final height = input.u32();
  final width = input.u32();
  final depth = input.u16();
  final mode = input.u16();
  if (width < 1 || height < 1) throw const FormatException('Empty PSD');
  if (width > maxImageSide || height > maxImageSide) throw const PsdTooLarge();
  if (depth != 8 && depth != 16) throw PsdUnsupported('$depth bits');
  if (mode != _rgb && mode != _grayscale) throw PsdUnsupported('mode $mode');
  final reader = _Reader(input, width, height, depth, mode, premultiply);

  input.skip(input.u32());
  input.skip(input.u32());

  final sectionLength = input.u32();
  final sectionEnd = input.position + sectionLength;
  input.need(sectionLength);
  if (sectionLength > 0) {
    final infoLength = input.u32();
    final infoEnd = input.position + infoLength;
    input.need(infoLength);
    if (infoLength > 0) reader.readLayers();
    input.position = infoEnd;
    if (sectionEnd - input.position >= 4) {
      input.skip(input.u32());
    }
    // 16 bit files keep their layers in a block after the usual place
    while (reader.records.isEmpty && sectionEnd - input.position >= 12) {
      final signature = input.ascii(4);
      if (signature != '8BIM' && signature != '8B64') break;
      final key = input.ascii(4);
      final length = input.u32();
      input.need(length);
      final next = input.position + (length + 3 & ~3);
      if (key == 'Lr16') {
        reader.readLayers();
        break;
      }
      if (key == 'Lr32') throw const PsdUnsupported('32 bits');
      if (next > sectionEnd) break;
      input.position = next;
    }
  }
  final layers = reader.layers();
  if (layers.isNotEmpty) {
    return PsdFile(
      width: width,
      height: height,
      layers: layers,
      simplified: reader.simplified || depth != 8,
    );
  }

  input.position = sectionEnd;
  return PsdFile(
    width: width,
    height: height,
    layers: [
      PsdLayer(
        name: '',
        left: 0,
        top: 0,
        width: width,
        height: height,
        opacity: 255,
        blendKey: 'norm',
        visible: true,
        pixels: reader.readMerged(channels),
      ),
    ],
    simplified: reader.simplified || reader.records.isNotEmpty || depth != 8,
  );
}

const _grayscale = 1, _rgb = 3;

/// Planes bigger than this are refused: the sizes come from the file and
/// would otherwise decide how much memory the app asks for.
const _maxPlanePixels = maxImageSide * maxImageSide;

class _Record {
  late int top, left, bottom, right;
  final channels = <(int id, int length)>[];
  late String blendKey;
  late int opacity;
  late bool visible;
  String name = '';
  int section = 0;
  bool adjustment = false;
  Uint8List? pixels;

  int get width => right - left;
  int get height => bottom - top;
}

class _Reader {
  _Reader(
    this.input,
    this.width,
    this.height,
    this.depth,
    this.mode,
    this.premultiply,
  );

  final _Input input;
  final int width;
  final int height;
  final int depth;
  final int mode;
  final bool premultiply;
  final records = <_Record>[];
  var simplified = false;

  int get _sampleBytes => depth ~/ 8;

  void readLayers() {
    final count = input.i16().abs();
    for (var i = 0; i < count; i++) {
      records.add(_readRecord());
    }
    for (final record in records) {
      _readPixels(record);
    }
  }

  _Record _readRecord() {
    final record = _Record()
      ..top = input.i32()
      ..left = input.i32()
      ..bottom = input.i32()
      ..right = input.i32();
    final channelCount = input.u16();
    for (var i = 0; i < channelCount; i++) {
      record.channels.add((input.i16(), input.u32()));
    }
    if (input.ascii(4) != '8BIM') throw const FormatException('Bad layer');
    record.blendKey = input.ascii(4);
    record.opacity = input.u8();
    if (input.u8() != 0) simplified = true;
    record.visible = input.u8() & 2 == 0;
    input.skip(1);
    final extraLength = input.u32();
    final extraEnd = input.position + extraLength;
    input.need(extraLength);

    final maskLength = input.u32();
    if (maskLength > 0) simplified = true;
    input.skip(maskLength);
    input.skip(input.u32());
    final nameLength = input.u8();
    record.name = latin1.decode(input.bytes(nameLength));
    input.skip(3 - nameLength % 4);

    while (extraEnd - input.position >= 12) {
      final signature = input.ascii(4);
      if (signature != '8BIM' && signature != '8B64') break;
      final key = input.ascii(4);
      final length = input.u32();
      final next = input.position + (length + 1 & ~1);
      if (next > extraEnd) break;
      switch (key) {
        case 'luni' when length >= 4:
          final units = input.u32();
          if (units * 2 <= length - 4) record.name = input.utf16(units);
        case 'lsct' || 'lsdk' when length >= 4:
          record.section = input.u32();
          simplified = true;
        default:
          if (_adjustmentKeys.contains(key)) {
            record.adjustment = true;
            simplified = true;
          } else if (_lossyKeys.contains(key)) {
            simplified = true;
          }
      }
      input.position = next;
    }
    input.position = extraEnd;
    return record;
  }

  void _readPixels(_Record record) {
    final width = record.width, height = record.height;
    final sound =
        width > 0 &&
        height > 0 &&
        width * height <= _maxPlanePixels &&
        record.section == 0;
    final planes = <int, Uint8List>{};
    for (final (id, length) in record.channels) {
      final end = input.position + length;
      input.need(length);
      if (sound && id >= -1 && id <= 2 && length >= 2) {
        planes[id] = _readPlane(width, height, end);
      }
      input.position = end;
    }
    if (sound) record.pixels = _assemble(planes, width * height);
  }

  /// One channel of 8 bit samples, whatever the file's depth.
  Uint8List _readPlane(int width, int height, int end) {
    final rowBytes = width * _sampleBytes;
    final raw = switch (input.u16()) {
      0 => input.bytes(rowBytes * height),
      1 => _unpackRows([
        for (var row = 0; row < height; row++) input.u16(),
      ], rowBytes),
      2 => _inflate(end, rowBytes * height),
      3 => _undoPrediction(_inflate(end, rowBytes * height), width, height),
      final other => throw PsdUnsupported('compression $other'),
    };
    return _toBytes(raw);
  }

  Uint8List _unpackRows(List<int> rowLengths, int rowBytes) {
    final plane = Uint8List(rowBytes * rowLengths.length);
    var at = 0;
    for (final length in rowLengths) {
      _unpack(input.bytes(length), plane, at, rowBytes);
      at += rowBytes;
    }
    return plane;
  }

  Uint8List _inflate(int end, int expected) {
    final List<int> data;
    try {
      data = zlib.decode(input.bytes(end - input.position));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Bad compressed channel');
    }
    if (data.length < expected) throw const FormatException('Short channel');
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  Uint8List _undoPrediction(Uint8List data, int width, int height) {
    if (depth == 8) {
      for (var row = 0; row < height; row++) {
        final start = row * width;
        for (var i = start + 1; i < start + width; i++) {
          data[i] = data[i] + data[i - 1] & 0xFF;
        }
      }
      return data;
    }
    for (var row = 0; row < height; row++) {
      final start = row * width * 2;
      for (var i = start + 2; i < start + width * 2; i += 2) {
        final value =
            (data[i] << 8 | data[i + 1]) + (data[i - 2] << 8 | data[i - 1]);
        data[i] = value >> 8 & 0xFF;
        data[i + 1] = value & 0xFF;
      }
    }
    return data;
  }

  Uint8List _toBytes(Uint8List samples) {
    if (depth == 8) return samples;
    final bytes = Uint8List(samples.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = samples[i * 2];
    }
    return bytes;
  }

  Uint8List _assemble(Map<int, Uint8List> planes, int count) {
    final pixels = Uint8List(count * 4);
    final red = planes[0];
    final green = mode == _grayscale ? red : planes[1];
    final blue = mode == _grayscale ? red : planes[2];
    final alpha = planes[-1];
    for (var i = 0, p = 0; i < count; i++, p += 4) {
      final a = alpha == null ? 255 : alpha[i];
      var r = red == null ? 0 : red[i];
      var g = green == null ? 0 : green[i];
      var b = blue == null ? 0 : blue[i];
      if (premultiply && a != 255) {
        r = (r * a + 127) ~/ 255;
        g = (g * a + 127) ~/ 255;
        b = (b * a + 127) ~/ 255;
      }
      pixels[p] = r;
      pixels[p + 1] = g;
      pixels[p + 2] = b;
      pixels[p + 3] = a;
    }
    return pixels;
  }

  /// The layers that hold pixels, bottom first. A group becomes its layers,
  /// hidden when the group is.
  List<PsdLayer> layers() {
    final result = <PsdLayer>[];
    final groups = <bool>[];
    for (final record in records.reversed) {
      switch (record.section) {
        case 1 || 2:
          groups.add(record.visible);
          continue;
        case 3:
          if (groups.isNotEmpty) groups.removeLast();
          continue;
      }
      final pixels = record.pixels;
      if (pixels == null && record.adjustment) continue;
      result.add(
        PsdLayer(
          name: record.name,
          left: record.left,
          top: record.top,
          width: pixels == null ? 0 : record.width,
          height: pixels == null ? 0 : record.height,
          opacity: record.opacity,
          blendKey: record.blendKey,
          visible: record.visible && !groups.contains(false),
          pixels: pixels ?? Uint8List(0),
        ),
      );
    }
    return result.reversed.toList();
  }

  /// The flat picture every PSD carries, for files with no layers. Any
  /// fourth channel there is a saved selection, not transparency.
  Uint8List readMerged(int channels) {
    final colors = mode == _grayscale ? 1 : 3;
    if (channels < colors) throw const FormatException('Missing channels');
    final rowBytes = width * _sampleBytes;
    final compression = input.u16();
    final planes = <int, Uint8List>{};
    switch (compression) {
      case 0:
        for (var channel = 0; channel < colors; channel++) {
          planes[channel] = _toBytes(input.bytes(rowBytes * height));
        }
      case 1:
        final rowLengths = [
          for (var i = 0; i < channels * height; i++) input.u16(),
        ];
        for (var channel = 0; channel < colors; channel++) {
          planes[channel] = _toBytes(
            _unpackRows(
              rowLengths.sublist(channel * height, (channel + 1) * height),
              rowBytes,
            ),
          );
        }
      default:
        throw PsdUnsupported('compression $compression');
    }
    return _assemble(planes, width * height);
  }
}

/// PackBits, the run length scheme of PSD rows.
void _unpack(Uint8List source, Uint8List target, int at, int length) {
  final end = at + length;
  var i = 0;
  while (i < source.length && at < end) {
    final header = source[i++];
    if (header == 128) continue;
    if (header > 128) {
      if (i >= source.length) return;
      final value = source[i++];
      final stop = at + 257 - header;
      target.fillRange(at, stop > end ? end : stop, value);
      at = stop;
    } else {
      for (var n = header + 1; n > 0 && i < source.length && at < end; n--) {
        target[at++] = source[i++];
      }
    }
  }
}

/// Reads big endian values, refusing to go past the end: the file is not
/// trusted.
class _Input {
  _Input(this._bytes) : _data = ByteData.sublistView(_bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int position = 0;

  void need(int count) {
    if (count < 0 || position < 0 || position + count > _bytes.length) {
      throw const FormatException('Truncated PSD');
    }
  }

  int _advance(int count) {
    need(count);
    final at = position;
    position += count;
    return at;
  }

  void skip(int count) => _advance(count);
  int u8() => _data.getUint8(_advance(1));
  int u16() => _data.getUint16(_advance(2));
  int i16() => _data.getInt16(_advance(2));
  int u32() => _data.getUint32(_advance(4));
  int i32() => _data.getInt32(_advance(4));

  Uint8List bytes(int count) {
    final at = _advance(count);
    return Uint8List.sublistView(_bytes, at, at + count);
  }

  String ascii(int count) => latin1.decode(bytes(count));

  String utf16(int units) {
    final at = _advance(units * 2);
    final codes = [for (var i = 0; i < units; i++) _data.getUint16(at + i * 2)];
    while (codes.isNotEmpty && codes.last == 0) {
      codes.removeLast();
    }
    return String.fromCharCodes(codes);
  }
}
