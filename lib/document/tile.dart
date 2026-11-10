import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// One square of the pixels of a layer. The steps of the history that did
/// not touch it share the same one.
///
/// A tile is born from a render, and a rendered image holds on to all that
/// was drawn into it (the tile it replaced, and the one before that) and
/// has no smaller copies to be drawn from when zoomed out. [settle] trades
/// it for a plain image with the same pixels.
class Tile {
  Tile(this._image, {TileSettler? settler}) {
    (settler ?? tileSettler).add(this);
  }

  ui.Image _image;
  bool _settled = false;
  bool _disposed = false;

  ui.Image get image => _image;
  int get bytes => _image.width * _image.height * 4;
  bool get settled => _settled;
  bool get disposed => _disposed;

  /// The pixels as premultiplied RGBA, row by row from the top left; null
  /// when the tile is thrown away before they come.
  Future<ByteData?> read() async {
    if (_disposed) return null;
    // a handle of its own: the tile may be disposed while this waits
    final source = _image.clone();
    try {
      final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      return _disposed ? null : data;
    } finally {
      source.dispose();
    }
  }

  Future<void> settle() async {
    if (_disposed || _settled) return;
    final rendered = _image;
    try {
      final data = await read();
      if (data == null) return;
      final loaded = await _load(data, rendered.width, rendered.height);
      if (_disposed || !identical(_image, rendered)) {
        loaded.dispose();
        return;
      }
      _image = loaded;
      _settled = true;
      rendered.dispose();
    } catch (_) {
      // it stays as rendered: heavier, but with the right pixels
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _image.dispose();
  }

  static Future<ui.Image> _load(ByteData data, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// Settles the new tiles one at a time, so that painting never waits for
/// it. Tells its listeners when none is left: what is on the screen still
/// holds the rendered images until it is painted again.
class TileSettler extends ChangeNotifier {
  final _waiting = Queue<Tile>();
  Future<void>? _work;

  /// Completes when no tile is waiting.
  Future<void> get done => _work ?? Future<void>.value();

  void add(Tile tile) {
    _waiting.add(tile);
    // the work belongs to no caller: it must not stop with the zone of
    // whoever happened to make the first tile
    _work ??= Zone.root.run(_run);
  }

  Future<void> _run() async {
    while (_waiting.isNotEmpty) {
      await _waiting.removeFirst().settle();
    }
    _work = null;
    notifyListeners();
  }
}

final tileSettler = TileSettler();
