import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../document/compositor.dart';
import '../document/image_document.dart';
import '../document/layer.dart';
import '../painting/flood_fill.dart';
import '../painting/image_formats.dart';
import '../painting/opaque_bounds.dart';
import '../painting/rgba_image.dart';
import 'free_transform.dart';
import 'image_ops.dart';
import 'marks.dart';
import 'tool_settings.dart';

enum _Combine { replace, add, subtract }

/// The pixels a free transform took off the active layer.
class _Floating {
  _Floating(this.piece, this.rest, this.model, this.layerId, this.revision);

  final ui.Image piece;
  final ui.Image? rest;
  final FreeTransform model;
  final int layerId;
  final int revision;

  void dispose() {
    piece.dispose();
    rest?.dispose();
  }
}

/// What the tools and the menus do to the document, in image pixels. The
/// widgets only turn clicks and drags into these calls.
class EditorController extends ChangeNotifier {
  EditorController({required this.document, required this.settings})
    : _tool = settings.tool {
    document.addListener(_onDocument);
    settings.addListener(_onSettings);
    _size = (document.width, document.height);
    _layersAdded = document.layers.length;
  }

  final ImageDocument document;
  final ToolSettings settings;

  /// The pixel under the mouse, for the status bar.
  final cursor = ValueNotifier<(int, int)?>(null);

  /// Name of the n-th layer the user adds, in the user's language.
  String Function(int number) layerName = (number) => 'Layer $number';

  EditTool _tool;
  (int, int) _size = (0, 0);
  Mark? _mark;
  Path? _selection;
  Path? _pending;
  _Combine _combine = _Combine.replace;
  Offset? _start;
  List<Offset>? _lasso;
  Offset? _moveShift;
  Rect? _crop;
  ColorFilter? _filter;
  _Floating? _floating;
  Uint8List? _copied;
  Offset _copiedAt = Offset.zero;
  var _busy = false;

  /// Work that ends after the picture was closed is dropped.
  var _closed = false;
  var _layersAdded = 1;

  /// The selected area, in image pixels; null when nothing is selected.
  Path? get selection => _selection;

  /// The selection being dragged, before it joins [selection].
  Path? get pendingSelection => _pending;

  Rect? get selectionBounds => _selection?.getBounds();

  bool get hasSelection => _selection != null;

  /// The area the crop tool marked, waiting to be applied.
  Rect? get cropArea => _crop;

  Rect get imageRect => document.state.rect;

  Layer get activeLayer => document.activeLayer;

  /// Painting on a hidden layer would change what cannot be seen.
  bool get canPaint => activeLayer.visible;

  /// What is being done to the active layer and is not in the document yet.
  LivePreview? get live {
    if (_floating case final floating?) {
      return LivePreview(
        layerId: floating.layerId,
        floating: FloatingPiece(
          image: floating.piece,
          matrix: floating.model.matrix,
          smooth: !floating.model.keepsPixels,
          rest: floating.rest,
        ),
      );
    }
    if (_mark == null && _moveShift == null && _filter == null) return null;
    return LivePreview(
      layerId: document.activeId,
      mark: _mark,
      clip: _selection,
      shift: _moveShift ?? Offset.zero,
      filter: _filter,
    );
  }

  /// Shows an adjustment on the active layer before it is applied.
  set previewFilter(ColorFilter? filter) {
    _filter = filter;
    notifyListeners();
  }

  // Pointer ---------------------------------------------------------------

  /// [reach] is how far from a handle of the free transform a click still
  /// grabs it, in image pixels.
  void pointerDown(
    Offset point, {
    bool add = false,
    bool subtract = false,
    double reach = 4,
  }) {
    if (_floating case final floating?) {
      floating.model.startDrag(point, reach);
      notifyListeners();
      return;
    }
    final tool = settings.tool;
    final paints = tool.isPen || tool.isShape || tool == EditTool.gradient;
    if (paints && !canPaint) return;
    if (subtract && tool.picksWithAlt) {
      pickAt(point).ignore();
      return;
    }
    final color = settings.color1.withValues(alpha: settings.opacity);
    switch (tool) {
      case EditTool.move:
        _start = point;
        _moveShift = Offset.zero;
      case EditTool.marquee || EditTool.ellipseMarquee || EditTool.lasso:
        _start = _clamp(point);
        _lasso = [_start!];
        _combine = add
            ? _Combine.add
            : subtract
            ? _Combine.subtract
            : _Combine.replace;
      case EditTool.crop:
        _start = _clamp(point);
        _crop = null;
      case EditTool.picker:
        pickAt(point, background: subtract).ignore();
      case EditTool.brush:
        _mark = PenMark(
          PenKind.brush,
          color,
          settings.size,
          settings.hardness,
          point,
        );
      case EditTool.pencil:
        _mark = PenMark(PenKind.pencil, color, settings.size, 1, _snap(point));
      case EditTool.eraser:
        _mark = PenMark(
          PenKind.eraser,
          color,
          settings.size,
          settings.hardness,
          point,
        );
      case EditTool.line || EditTool.rectangle || EditTool.ellipse:
        _mark = ShapeMark(
          _shapeOf(tool),
          color,
          settings.size,
          settings.filled,
          _snap(point),
        );
      case EditTool.gradient:
        _mark = GradientMark(
          color,
          settings.color2.withValues(alpha: settings.opacity),
          imageRect,
          point,
        );
      case EditTool.fill:
        fillAt(point).ignore();
      case EditTool.text || EditTool.hand || EditTool.zoom:
        break;
    }
    notifyListeners();
  }

  /// [constrain] keeps lines at multiples of 45°, makes shapes square and
  /// moves along one axis. [fromCenter] makes a free transform scale around
  /// its middle.
  void pointerMove(
    Offset point, {
    bool constrain = false,
    bool fromCenter = false,
  }) {
    hover(point);
    if (_floating case final floating?) {
      if (!floating.model.isDragging) return;
      floating.model.drag(point, constrain: constrain, fromCenter: fromCenter);
      notifyListeners();
      return;
    }
    final start = _start;
    switch (_mark) {
      case final PenMark pen:
        pen.add(pen.kind == PenKind.pencil ? _snap(point) : point);
      case final ShapeMark shape:
        final end = _snap(point);
        shape.end = constrain ? _constrain(shape.start, end, shape.kind) : end;
      case final GradientMark gradient:
        gradient.end = constrain
            ? _constrain(gradient.start, point, ShapeKind.line)
            : point;
      case null when start == null:
        return;
      case null when _moveShift != null:
        var shift = point - start!;
        if (constrain) {
          shift = shift.dx.abs() > shift.dy.abs()
              ? Offset(shift.dx, 0)
              : Offset(0, shift.dy);
        }
        _moveShift = Offset(shift.dx.roundToDouble(), shift.dy.roundToDouble());
      case null when settings.tool == EditTool.crop:
        _crop = _box(start!, _clamp(point));
      case null:
        _pending = _dragged(start!, _clamp(point));
    }
    notifyListeners();
  }

  void pointerUp() {
    _floating?.model.endDrag();
    final mark = _mark;
    _mark = null;
    final drawn = switch (mark) {
      PenMark() => true,
      ShapeMark(:final isEmpty) || GradientMark(:final isEmpty) => !isEmpty,
      null => false,
    };
    if (drawn) _commitPaint(mark!.paint, bounds: mark.bounds);

    final shift = _moveShift;
    _moveShift = null;
    if (shift != null && shift != Offset.zero) {
      final layer = activeLayer;
      document.commit(
        document.state.replacing(layer.copyWith(offset: layer.offset + shift)),
      );
    }

    if (_lasso != null) {
      final pending = _pending;
      if (pending != null) {
        _select(pending, _combine);
      } else if (_combine == _Combine.replace) {
        _selection = null;
      }
    }
    if (_crop case final area? when area.isEmpty) _crop = null;
    _endDrag();
    notifyListeners();
  }

  void pointerCancel() {
    _floating?.model.endDrag();
    _mark = null;
    _moveShift = null;
    _endDrag();
    notifyListeners();
  }

  void hover(Offset? point) {
    cursor.value = point == null || !imageRect.contains(point)
        ? null
        : (point.dx.floor(), point.dy.floor());
  }

  // History ---------------------------------------------------------------

  bool get canUndo => document.canUndo;
  bool get canRedo => document.canRedo;

  void undo() {
    pointerCancel();
    if (isTransforming) return cancelTransform();
    document.undo();
  }

  void redo() {
    pointerCancel();
    if (isTransforming) return;
    document.redo();
  }

  // Free transform --------------------------------------------------------

  /// The box being moved, scaled and turned; null when none is.
  FreeTransform? get transform => _floating?.model;

  bool get isTransforming => _floating != null;

  /// Lifts what is selected on the active layer, or everything it has, so
  /// it can be moved, scaled and turned before going back.
  Future<void> beginTransform() async {
    if (_busy || isTransforming || !canPaint) return;
    _busy = true;
    try {
      final revision = document.revision;
      final layer = activeLayer;
      final selection = _selection;
      final area = selection == null
          ? layer.bounds
          : _wholePixels(selection.getBounds()).intersect(layer.bounds);
      if (area.isEmpty) return;
      final lifted = renderImage(area.width.toInt(), area.height.toInt(), (
        canvas,
      ) {
        canvas.translate(-area.left, -area.top);
        if (selection != null) canvas.clipPath(selection);
        canvas.drawImage(layer.image, layer.offset, Paint());
      });
      final ui.Image piece;
      final Rect box;
      try {
        final found = await compute(opaqueBounds, await readPixels(lifted));
        if (found == null || _closed || revision != document.revision) return;
        final (left, top, right, bottom) = found;
        final inside = Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          right.toDouble(),
          bottom.toDouble(),
        );
        piece = cropImage(lifted, inside);
        box = inside.shift(area.topLeft);
      } finally {
        lifted.dispose();
      }
      final rest = selection == null
          ? null
          : renderImage(layer.image.width, layer.image.height, (canvas) {
              canvas
                ..drawImage(
                  layer.image,
                  Offset.zero,
                  Paint()..blendMode = BlendMode.src,
                )
                ..translate(-layer.offset.dx, -layer.offset.dy)
                ..clipPath(selection)
                ..drawPaint(Paint()..blendMode = BlendMode.clear);
            });
      pointerCancel();
      _crop = null;
      _floating = _Floating(
        piece,
        rest,
        FreeTransform(box),
        layer.id,
        revision,
      );
    } finally {
      _busy = false;
    }
    notifyListeners();
  }

  /// One undo step: the layer with the box where it was left.
  void applyTransform() {
    final floating = _floating;
    if (floating == null) return;
    final model = floating.model;
    if (model.isIdentity) return cancelTransform();
    final layer = activeLayer;
    var area = _wholePixels(model.bounds);
    if (floating.rest != null) area = area.expandToInclude(layer.bounds);
    area = _roomFor(area);
    final image = renderImage(area.width.toInt(), area.height.toInt(), (
      canvas,
    ) {
      canvas.translate(-area.left, -area.top);
      if (floating.rest case final rest?) {
        canvas.drawImage(rest, layer.offset, Paint());
      }
      canvas
        ..transform(model.matrix)
        ..drawImage(
          floating.piece,
          Offset.zero,
          Paint()
            ..filterQuality = model.keepsPixels
                ? FilterQuality.none
                : FilterQuality.medium,
        );
    });
    _floating = null;
    if (_selection case final selection?) {
      _setSelection(selection.transform(model.imageMatrix));
    }
    document.commit(
      document.state.replacing(
        layer.copyWith(image: image, offset: area.topLeft),
      ),
    );
    floating.dispose();
  }

  void cancelTransform() {
    final floating = _floating;
    if (floating == null) return;
    _floating = null;
    floating.dispose();
    notifyListeners();
  }

  /// What Enter does: applies the free transform, or else the crop.
  void confirm() => isTransforming ? applyTransform() : applyCrop();

  /// What Esc does: gives up the free transform, or else the selection.
  void cancel() => isTransforming ? cancelTransform() : deselect();

  // Selection -------------------------------------------------------------

  void selectAll() {
    _selection = Path()..addRect(imageRect);
    notifyListeners();
  }

  void deselect() {
    if (_selection == null && _crop == null) return;
    _selection = null;
    _crop = null;
    notifyListeners();
  }

  void invertSelection() {
    final selection = _selection;
    if (selection == null) return selectAll();
    final all = Path()..addRect(imageRect);
    _setSelection(Path.combine(PathOperation.difference, all, selection));
    notifyListeners();
  }

  /// Takes the pixels of the selection off the active layer.
  void deleteSelection() {
    if (_selection == null) return;
    _commitPaint(
      (canvas) => canvas.drawPaint(Paint()..blendMode = BlendMode.clear),
    );
  }

  /// Covers the selection, or the whole layer, with the foreground color,
  /// or with the [background] one.
  void fillSelection({bool background = false}) {
    final color = background ? settings.color2 : settings.color1;
    _commitPaint((canvas) => canvas.drawPaint(Paint()..color = color));
  }

  /// The selected part of the active layer, or all of what the image shows
  /// of it, and where it sits. Null when there is nothing there.
  (ui.Image, Offset)? _selectedPiece() {
    final layer = activeLayer;
    final area = _wholePixels(
      selectionBounds ?? imageRect,
    ).intersect(imageRect);
    if (area.isEmpty) return null;
    final selection = _selection;
    final piece = renderImage(area.width.toInt(), area.height.toInt(), (
      canvas,
    ) {
      canvas.translate(-area.left, -area.top);
      if (selection != null) canvas.clipPath(selection);
      canvas.drawImage(layer.image, layer.offset, Paint());
    });
    return (piece, area.topLeft);
  }

  /// PNG of the selected part of the active layer, or of all of it.
  Future<Uint8List?> copyPng() async {
    final selected = _selectedPiece();
    if (selected == null) return null;
    final (piece, at) = selected;
    try {
      final png = await encodePng(piece);
      _copied = png;
      _copiedAt = at;
      return png;
    } finally {
      piece.dispose();
    }
  }

  /// Puts an image in a new layer above the active one. What was copied
  /// here goes back where it came from; anything else lands at [origin].
  /// False when the image is larger than the app allows.
  Future<bool> paste(Uint8List bytes, {Offset origin = Offset.zero}) async {
    final image = await decodeImageBytes(bytes);
    if (_closed) {
      image.dispose();
      return true;
    }
    if (image.width > maxImageSide || image.height > maxImageSide) {
      image.dispose();
      return false;
    }
    final own = listEquals(bytes, _copied);
    final at = own
        ? _copiedAt
        : Offset(origin.dx.floorToDouble(), origin.dy.floorToDouble());
    _insertAbove(_newLayer(image, offset: at));
    return true;
  }

  // Tools that read pixels ------------------------------------------------

  Future<void> fillAt(Offset point) async {
    final x = point.dx.floor(), y = point.dy.floor();
    if (_busy || !canPaint || !imageRect.contains(point)) return;
    if (!(_selection?.contains(point) ?? true)) return;
    _busy = true;
    try {
      final revision = document.revision;
      final layer = activeLayer;
      final flat = renderImage(
        document.width,
        document.height,
        (canvas) => canvas.drawImage(layer.image, layer.offset, Paint()),
      );
      final RgbaImage pixels;
      try {
        pixels = await readPixels(flat);
      } finally {
        flat.dispose();
      }
      final color = settings.color1.toARGB32();
      final fill = await compute(_fillLayer, (
        pixels,
        x,
        y,
        color,
        settings.tolerance,
      ));
      if (fill == null || _closed || revision != document.revision) return;
      final overlay = await imageFromPixels(fill, pixels.width, pixels.height);
      if (!_closed && revision == document.revision) {
        final paint = Paint()
          ..color = Color.fromRGBO(0, 0, 0, settings.opacity);
        _commitPaint((canvas) => canvas.drawImage(overlay, Offset.zero, paint));
      }
      overlay.dispose();
    } finally {
      _busy = false;
    }
  }

  /// Takes the color the image shows at [point], all layers together.
  Future<void> pickAt(Offset point, {bool background = false}) async {
    if (!imageRect.contains(point)) return;
    final state = document.state;
    final dot = renderImage(1, 1, (canvas) {
      canvas.translate(-point.dx.floorToDouble(), -point.dy.floorToDouble());
      paintLayers(canvas, state);
    });
    final RgbaImage pixel;
    try {
      pixel = await readPixels(dot);
    } finally {
      dot.dispose();
    }
    final argb = pixel.colorAt(0, 0);
    if (argb >>> 24 == 0) return;
    final color = Color(argb | 0xFF000000);
    if (background) {
      settings.color2 = color;
    } else {
      settings.color1 = color;
    }
  }

  // Image -----------------------------------------------------------------

  void load(
    DocumentState state, {
    required String name,
    String? path,
    required SaveFormat format,
  }) {
    _reset();
    document.replace(state, name: name, path: path, format: format);
    _layersAdded = state.layers.length;
  }

  /// Cuts the image down to [area]. The layers keep what falls outside.
  void crop(Rect area) {
    final box = _wholePixels(area).intersect(imageRect);
    if (box.isEmpty || box == imageRect) {
      _crop = null;
      notifyListeners();
      return;
    }
    _selection = null;
    _crop = null;
    document.commit(
      DocumentState(box.width.toInt(), box.height.toInt(), [
        for (final layer in document.layers)
          layer.copyWith(offset: layer.offset - box.topLeft),
      ]),
    );
  }

  void applyCrop() {
    if (_crop case final area?) crop(area);
  }

  void cropToSelection() {
    if (selectionBounds case final bounds?) crop(bounds);
  }

  /// [stretch] scales every layer to the new size; otherwise only the
  /// canvas changes, from the top left corner.
  void resize(int width, int height, {required bool stretch}) {
    if (width == document.width && height == document.height) return;
    _selection = null;
    _crop = null;
    if (!stretch) {
      document.commit(DocumentState(width, height, document.layers));
      return;
    }
    final sx = width / document.width, sy = height / document.height;
    document.commit(
      DocumentState(width, height, [
        for (final layer in document.layers)
          layer.copyWith(
            image: scaleImage(
              layer.image,
              math.max(1, (layer.image.width * sx).round()),
              math.max(1, (layer.image.height * sy).round()),
            ),
            offset: Offset(
              (layer.offset.dx * sx).roundToDouble(),
              (layer.offset.dy * sy).roundToDouble(),
            ),
          ),
      ]),
    );
  }

  void turn(Turn turn) {
    _selection = null;
    _crop = null;
    final width = document.width.toDouble(),
        height = document.height.toDouble();
    final sideways = turn == Turn.left || turn == Turn.right;
    document.commit(
      DocumentState(
        sideways ? document.height : document.width,
        sideways ? document.width : document.height,
        [
          for (final layer in document.layers)
            layer.copyWith(
              image: turnImage(layer.image, turn),
              offset: switch (turn) {
                Turn.right => Offset(
                  height - layer.bounds.bottom,
                  layer.bounds.left,
                ),
                Turn.left => Offset(
                  layer.bounds.top,
                  width - layer.bounds.right,
                ),
                Turn.flipHorizontal => Offset(
                  width - layer.bounds.right,
                  layer.bounds.top,
                ),
                Turn.flipVertical => Offset(
                  layer.bounds.left,
                  height - layer.bounds.bottom,
                ),
              },
            ),
        ],
      ),
    );
  }

  // Layers ----------------------------------------------------------------

  void addLayer() {
    _insertAbove(_newLayer(blankImage(1, 1, const Color(0x00000000))));
  }

  void duplicateLayer() {
    final layer = activeLayer;
    _insertAbove(
      layer.copyWith(id: document.newLayerId(), image: layer.image.clone()),
    );
  }

  /// A new layer with the selected part of the active one, or a copy of the
  /// whole layer when nothing is selected.
  void layerFromSelection() {
    if (_selection == null) return duplicateLayer();
    final selected = _selectedPiece();
    if (selected == null) return;
    final (piece, at) = selected;
    _selection = null;
    _insertAbove(_newLayer(piece, offset: at));
  }

  void deleteLayer() {
    if (document.layers.length < 2) return;
    final index = document.activeIndex;
    final layers = [...document.layers]..removeAt(index);
    document.commit(
      document.state.withLayers(layers),
      activeId: layers[math.max(0, index - 1)].id,
    );
  }

  bool get canMergeDown => document.activeIndex > 0;

  /// Joins the active layer with the one below, looking the same as before
  /// when that one blends normally.
  void mergeDown() {
    final index = document.activeIndex;
    if (index == 0) return;
    final upper = document.layers[index], lower = document.layers[index - 1];
    final area = _roomFor(upper.bounds.expandToInclude(lower.bounds));
    final image = renderImage(area.width.toInt(), area.height.toInt(), (
      canvas,
    ) {
      canvas.translate(-area.left, -area.top);
      for (final layer in [lower, upper]) {
        if (!layer.visible) continue;
        canvas.drawImage(
          layer.image,
          layer.offset,
          Paint()
            ..color = Color.fromRGBO(0, 0, 0, layer.opacity)
            ..blendMode = identical(layer, upper)
                ? layer.blend.mode
                : BlendMode.srcOver,
        );
      }
    });
    final merged = lower.copyWith(
      image: image,
      offset: area.topLeft,
      opacity: 1,
      visible: true,
    );
    final layers = [...document.layers]
      ..removeAt(index)
      ..[index - 1] = merged;
    document.commit(document.state.withLayers(layers), activeId: merged.id);
  }

  /// One layer with what the image shows.
  void flatten() {
    final state = document.state;
    if (!state.isLayered) return;
    final image = renderImage(
      state.width,
      state.height,
      (canvas) => paintLayers(canvas, state),
    );
    final bottom = state.layers.first;
    document.commit(
      state.withLayers([Layer(id: bottom.id, name: bottom.name, image: image)]),
      activeId: bottom.id,
    );
  }

  /// Moves the layer at [from] to [to], both counted from the bottom.
  void moveLayer(int from, int to) {
    final count = document.layers.length;
    if (from == to || from < 0 || to < 0 || from >= count || to >= count) {
      return;
    }
    final layers = [...document.layers];
    layers.insert(to, layers.removeAt(from));
    document.commit(document.state.withLayers(layers));
  }

  void raiseLayer() =>
      moveLayer(document.activeIndex, document.activeIndex + 1);

  void lowerLayer() =>
      moveLayer(document.activeIndex, document.activeIndex - 1);

  void raiseLayerToTop() =>
      moveLayer(document.activeIndex, document.layers.length - 1);

  void lowerLayerToBottom() => moveLayer(document.activeIndex, 0);

  /// Makes the layer [step] places above the active one the active one.
  void activateLayerBy(int step) {
    final index = document.activeIndex + step;
    if (index < 0 || index >= document.layers.length) return;
    document.activeId = document.layers[index].id;
  }

  void toggleLayerVisible() =>
      setLayerVisible(activeLayer.id, !activeLayer.visible);

  void renameLayer(int id, String name) {
    final layer = _layer(id);
    final trimmed = name.trim();
    if (layer == null || trimmed.isEmpty || trimmed == layer.name) return;
    document.commit(document.state.replacing(layer.copyWith(name: trimmed)));
  }

  void setLayerVisible(int id, bool visible) {
    final layer = _layer(id);
    if (layer == null || layer.visible == visible) return;
    document.commit(document.state.replacing(layer.copyWith(visible: visible)));
  }

  void setLayerOpacity(double opacity) {
    final layer = activeLayer;
    final value = opacity.clamp(0.0, 1.0).toDouble();
    if (value == layer.opacity) return;
    document.commit(
      document.state.replacing(layer.copyWith(opacity: value)),
      mergeKey: 'opacity ${layer.id}',
    );
  }

  void setLayerBlend(LayerBlend blend) {
    final layer = activeLayer;
    if (blend == layer.blend) return;
    document.commit(document.state.replacing(layer.copyWith(blend: blend)));
  }

  /// Moves the active layer by whole pixels, as the arrow keys do.
  void nudge(int dx, int dy) {
    if (_floating case final floating?) {
      floating.model.moveBy(Offset(dx.toDouble(), dy.toDouble()));
      notifyListeners();
      return;
    }
    final layer = activeLayer;
    document.commit(
      document.state.replacing(
        layer.copyWith(
          offset: layer.offset + Offset(dx.toDouble(), dy.toDouble()),
        ),
      ),
      mergeKey: 'nudge ${layer.id}',
    );
  }

  /// Changes the colors of the active layer, inside the selection if any.
  void applyFilter(ColorFilter filter) {
    _filter = null;
    final layer = activeLayer;
    _commitPaint(
      (canvas) => canvas.drawImage(
        layer.image,
        layer.offset,
        Paint()
          ..colorFilter = filter
          ..blendMode = BlendMode.src,
      ),
    );
  }

  /// Writes [text] in the foreground color on a new layer whose top left
  /// corner is [at].
  void addText(
    String text,
    Offset at, {
    required double fontSize,
    bool bold = false,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: clean,
        style: TextStyle(
          color: settings.color1,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxImageSide.toDouble());
    final width = painter.width.ceil().clamp(1, maxImageSide);
    final height = painter.height.ceil().clamp(1, maxImageSide);
    final image = renderImage(
      width,
      height,
      (canvas) => painter.paint(canvas, Offset.zero),
    );
    painter.dispose();
    final firstLine = clean.split('\n').first;
    _insertAbove(
      _newLayer(
        image,
        offset: Offset(at.dx.floorToDouble(), at.dy.floorToDouble()),
        name: firstLine.length > 30 ? firstLine.substring(0, 30) : firstLine,
      ),
    );
  }

  @override
  void dispose() {
    _closed = true;
    document.removeListener(_onDocument);
    settings.removeListener(_onSettings);
    _floating?.dispose();
    cursor.dispose();
    super.dispose();
  }

  // Helpers ---------------------------------------------------------------

  Layer? _layer(int id) {
    for (final layer in document.layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  Layer _newLayer(
    ui.Image image, {
    Offset offset = Offset.zero,
    String? name,
  }) => Layer(
    id: document.newLayerId(),
    name: name ?? layerName(++_layersAdded),
    image: image,
    offset: offset,
  );

  void _insertAbove(Layer layer) {
    final layers = [...document.layers]
      ..insert(document.activeIndex + 1, layer);
    document.commit(document.state.withLayers(layers), activeId: layer.id);
  }

  /// One undo step: the active layer with [draw] painted on it, inside the
  /// image and the selection. [bounds] is how far [draw] reaches, when that
  /// is not everywhere: paint that cannot show makes no step.
  void _commitPaint(void Function(Canvas canvas) draw, {Rect? bounds}) {
    if (!canPaint) return;
    final layer = activeLayer;
    final selection = _selection;
    var reach = imageRect;
    if (selection != null) reach = reach.intersect(selection.getBounds());
    if (bounds != null) reach = reach.intersect(bounds);
    if (reach.isEmpty) return;
    final area = _roomFor(layer.bounds.expandToInclude(imageRect));
    final image = renderImage(area.width.toInt(), area.height.toInt(), (
      canvas,
    ) {
      canvas
        ..translate(-area.left, -area.top)
        ..drawImage(
          layer.image,
          layer.offset,
          Paint()..blendMode = BlendMode.src,
        )
        ..clipRect(imageRect);
      if (selection != null) canvas.clipPath(selection);
      draw(canvas);
    });
    document.commit(
      document.state.replacing(
        layer.copyWith(image: image, offset: area.topLeft),
      ),
    );
  }

  /// A layer far outside the image would make too big a texture: then only
  /// the part inside the image is kept.
  Rect _roomFor(Rect area) =>
      area.width > maxImageSide || area.height > maxImageSide
      ? imageRect
      : area;

  void _select(Path path, _Combine how) {
    final current = _selection;
    _setSelection(switch (how) {
      _Combine.add when current != null => Path.combine(
        PathOperation.union,
        current,
        path,
      ),
      _Combine.subtract when current != null => Path.combine(
        PathOperation.difference,
        current,
        path,
      ),
      _Combine.subtract => null,
      _ => path,
    });
  }

  void _setSelection(Path? path) {
    final bounds = path?.getBounds();
    _selection = bounds == null || bounds.width < 1 || bounds.height < 1
        ? null
        : path;
  }

  Path? _dragged(Offset start, Offset end) {
    if (settings.tool == EditTool.lasso) {
      final points = _lasso!;
      if (end != points.last) points.add(end);
      return points.length < 3 ? null : (Path()..addPolygon(points, true));
    }
    final box = _box(start, end);
    if (box.isEmpty) return null;
    return settings.tool == EditTool.ellipseMarquee
        ? (Path()..addOval(box))
        : (Path()..addRect(box));
  }

  void _endDrag() {
    _start = null;
    _lasso = null;
    _pending = null;
  }

  void _reset() {
    _mark = null;
    _moveShift = null;
    _selection = null;
    _crop = null;
    _filter = null;
    _floating?.dispose();
    _floating = null;
    _layersAdded = 1;
    _endDrag();
  }

  static Rect _box(Offset a, Offset b) => _wholePixels(Rect.fromPoints(a, b));

  static Rect _wholePixels(Rect rect) => Rect.fromLTRB(
    rect.left.floorToDouble(),
    rect.top.floorToDouble(),
    rect.right.ceilToDouble(),
    rect.bottom.ceilToDouble(),
  );

  Offset _clamp(Offset point) => Offset(
    point.dx.clamp(0, document.width.toDouble()),
    point.dy.clamp(0, document.height.toDouble()),
  );

  /// Hard edges land on whole pixels: odd widths on pixel centers, even
  /// widths on pixel corners.
  Offset _snap(Offset point) {
    final odd = settings.size.round().isOdd;
    double snap(double value) =>
        odd ? value.floorToDouble() + 0.5 : value.roundToDouble();
    return Offset(snap(point.dx), snap(point.dy));
  }

  static ShapeKind _shapeOf(EditTool tool) => switch (tool) {
    EditTool.line => ShapeKind.line,
    EditTool.rectangle => ShapeKind.rectangle,
    _ => ShapeKind.ellipse,
  };

  static Offset _constrain(Offset start, Offset end, ShapeKind kind) {
    final delta = end - start;
    if (kind == ShapeKind.line) {
      const step = math.pi / 4;
      final angle = (delta.direction / step).round() * step;
      return start + Offset.fromDirection(angle, delta.distance);
    }
    final side = math.max(delta.dx.abs(), delta.dy.abs());
    return start +
        Offset(delta.dx < 0 ? -side : side, delta.dy < 0 ? -side : side);
  }

  void _onDocument() {
    // the layer changed under the box: what it lifted is no longer there
    if (_floating case final floating?
        when floating.revision != document.revision ||
            floating.layerId != document.activeId) {
      _floating = null;
      floating.dispose();
    }
    final size = (document.width, document.height);
    // undo or redo of a crop or a resize: the old areas no longer fit
    if (size != _size) {
      _size = size;
      _selection = null;
      _crop = null;
    }
    notifyListeners();
  }

  void _onSettings() {
    if (settings.tool != _tool) {
      _tool = settings.tool;
      applyTransform();
      _mark = null;
      _moveShift = null;
      _crop = null;
      _endDrag();
    }
    notifyListeners();
  }
}

Uint8List? _fillLayer((RgbaImage, int, int, int, int) request) {
  final (image, x, y, color, tolerance) = request;
  return fillLayer(image, x, y, color, tolerance: tolerance);
}
