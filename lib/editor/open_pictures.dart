import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../canvas/editor_controller.dart';
import '../canvas/image_ops.dart';
import '../canvas/tool_settings.dart';
import '../document/image_document.dart';
import '../document/layer.dart';
import '../painting/image_formats.dart';

typedef LayerNamer = String Function(int number);

/// One picture open in the editor.
class OpenPicture {
  OpenPicture._(this.controller, {this.source, bool placeholder = false})
    : _placeholder = placeholder;

  final EditorController controller;

  /// Zoom of its own canvas.
  double zoom = 1;

  /// The file it shows, also when Save may not write over it.
  String? source;

  final bool _placeholder;

  ImageDocument get document => controller.document;

  /// The picture the app opened by itself and nobody touched: a file that
  /// is opened takes its place.
  bool get isUntouched =>
      _placeholder &&
      document.name == null &&
      !document.dirty &&
      !document.canUndo &&
      !document.canRedo;

  /// Leaves nothing half done: the drag in progress is dropped and the free
  /// transform is applied, as picking another tool does.
  void settle() => controller
    ..pointerCancel()
    ..applyTransform();
}

/// The pictures open in the editor, one of them in front. There is always
/// at least one.
class OpenPictures extends ChangeNotifier {
  OpenPictures({
    required this.settings,
    this.startWidth = 1280,
    this.startHeight = 720,
    LayerNamer layerName = _numbered,
  }) : _layerName = layerName {
    _pictures.add(_blank(startWidth, startHeight, placeholder: true));
  }

  /// Tools and colors, the same for every picture.
  final ToolSettings settings;

  /// Size of the picture the app opens by itself.
  final int startWidth;
  final int startHeight;

  final _pictures = <OpenPicture>[];
  var _active = 0;
  LayerNamer _layerName;

  late final List<OpenPicture> pictures = UnmodifiableListView(_pictures);

  /// The picture in front.
  OpenPicture get active => _pictures[_active];

  int get activeIndex => _active;

  /// Names the layers the user adds, in the user's language.
  set layerName(LayerNamer namer) {
    _layerName = namer;
    for (final picture in _pictures) {
      picture.controller.layerName = namer;
    }
  }

  /// A new white picture, in front.
  OpenPicture addBlank(int width, int height) => _add(_blank(width, height));

  /// Shows an opened file: in the place of the untouched start picture, or
  /// else as one more picture. [source] is the file it came from.
  OpenPicture open(
    DocumentState state, {
    required String name,
    String? path,
    required SaveFormat format,
    String? source,
  }) {
    final current = active;
    if (current.isUntouched) {
      current
        ..source = source
        ..zoom = 1;
      current.controller.load(state, name: name, path: path, format: format);
      notifyListeners();
      return current;
    }
    final document = ImageDocument(state)
      ..name = name
      ..path = path
      ..format = format;
    return _add(OpenPicture._(_controller(document), source: source));
  }

  /// Brings the picture of the file at [path] to the front. False when that
  /// file is not open.
  bool showFile(String path) {
    final index = _pictures.indexWhere((picture) => picture.source == path);
    if (index < 0) return false;
    _show(index);
    return true;
  }

  void activate(OpenPicture picture) => _show(_pictures.indexOf(picture));

  void next() => _show((_active + 1) % _pictures.length);

  void previous() => _show((_active - 1) % _pictures.length);

  /// Closes [picture] and frees its memory. The last one leaves a fresh
  /// untitled picture behind.
  void close(OpenPicture picture) {
    final index = _pictures.indexOf(picture);
    if (index < 0) return;
    _pictures.removeAt(index);
    if (_pictures.isEmpty) {
      _pictures.add(_blank(startWidth, startHeight, placeholder: true));
    }
    if (index < _active) {
      _active--;
    } else if (_active >= _pictures.length) {
      _active = _pictures.length - 1;
    }
    notifyListeners();
    picture.controller.dispose();
    picture.document.dispose();
  }

  @override
  void dispose() {
    for (final picture in _pictures) {
      picture.controller.dispose();
      picture.document.dispose();
    }
    super.dispose();
  }

  OpenPicture _add(OpenPicture picture) {
    active.settle();
    _pictures.add(picture);
    _active = _pictures.length - 1;
    notifyListeners();
    return picture;
  }

  void _show(int index) {
    if (index < 0 || index == _active) return;
    active.settle();
    _active = index;
    notifyListeners();
  }

  OpenPicture _blank(int width, int height, {bool placeholder = false}) =>
      OpenPicture._(
        _controller(
          ImageDocument(
            DocumentState(width, height, [
              Layer(
                id: 1,
                name: _layerName(1),
                image: blankImage(width, height, const Color(0xFFFFFFFF)),
              ),
            ]),
          ),
        ),
        placeholder: placeholder,
      );

  EditorController _controller(ImageDocument document) =>
      EditorController(document: document, settings: settings)
        ..layerName = _layerName;

  static String _numbered(int number) => 'Layer $number';
}
