import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';

/// Images on the system clipboard. Linux has no image writing in the
/// plugin, so there a copy only reaches this app.
class ImageClipboard {
  Uint8List? _local;

  bool get _writesSystem => !kIsWeb && !Platform.isLinux;

  Future<void> write(Uint8List png) async {
    if (_writesSystem) {
      await Pasteboard.writeImage(png);
    } else {
      _local = png;
    }
  }

  Future<Uint8List?> read() async {
    final image = await Pasteboard.image;
    if (image != null && image.isNotEmpty) return image;
    return _writesSystem ? null : _local;
  }
}
