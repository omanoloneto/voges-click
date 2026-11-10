import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../painting/image_formats.dart';
import 'layer.dart';
import 'tile.dart';
import 'tiled_image.dart';

/// The size of the image and its layers, bottom first. Never changed in
/// place: every edit makes a new one, and the old one is an undo step.
class DocumentState {
  DocumentState(this.width, this.height, List<Layer> layers)
    : layers = List.unmodifiable(layers);

  final int width;
  final int height;
  final List<Layer> layers;

  ui.Rect get rect =>
      ui.Offset.zero & ui.Size(width.toDouble(), height.toDouble());

  /// More than one plain sheet of pixels: a flat file would lose something.
  bool get isLayered =>
      layers.length != 1 ||
      layers.single.opacity != 1 ||
      layers.single.blend != LayerBlend.normal ||
      !layers.single.visible;

  DocumentState withLayers(List<Layer> layers) =>
      DocumentState(width, height, layers);

  DocumentState replacing(Layer layer) => withLayers([
    for (final other in layers) other.id == layer.id ? layer : other,
  ]);
}

/// The image being edited, where it came from, and its undo history.
class ImageDocument extends ChangeNotifier {
  ImageDocument(DocumentState state, {this.historyBytes = defaultHistoryBytes})
    : _state = state,
      _saved = state,
      _activeId = state.layers.last.id {
    _nextId = _highestId(state) + 1;
  }

  /// Memory the undo steps may take on top of the image itself; the oldest
  /// go first, but one is kept.
  static const defaultHistoryBytes = 1024 << 20;

  final int historyBytes;

  DocumentState _state;
  DocumentState? _saved;
  final _undo = <DocumentState>[];
  final _redo = <DocumentState>[];
  int _activeId;
  int _nextId = 1;
  String? _mergeKey;

  /// File name, or null for a new image.
  String? name;

  /// Where Save writes; null until saved or for files that came as a copy.
  String? path;

  SaveFormat format = SaveFormat.psd;

  /// Grows with every change to the pixels, so slow work started on an
  /// older image can tell it is stale.
  int revision = 0;

  DocumentState get state => _state;
  int get width => _state.width;
  int get height => _state.height;
  List<Layer> get layers => _state.layers;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Undoing back to the saved state makes the image clean again.
  bool get dirty => !identical(_state, _saved);

  int get activeId => _activeId;

  int get activeIndex {
    final index = layers.indexWhere((layer) => layer.id == _activeId);
    return index < 0 ? layers.length - 1 : index;
  }

  Layer get activeLayer => layers[activeIndex];

  set activeId(int id) {
    if (id == _activeId || !layers.any((layer) => layer.id == id)) return;
    _activeId = id;
    _mergeKey = null;
    notifyListeners();
  }

  int newLayerId() => _nextId++;

  /// One undo step. Commits in a row with the same [mergeKey], like the
  /// ticks of a slider, count as a single step.
  void commit(DocumentState next, {String? mergeKey, int? activeId}) {
    final dropped = [..._redo];
    _redo.clear();
    if (mergeKey != null && mergeKey == _mergeKey && _undo.isNotEmpty) {
      dropped.add(_state);
    } else {
      _undo.add(_state);
    }
    _state = next;
    _mergeKey = mergeKey;
    if (activeId != null) _activeId = activeId;
    _trim(dropped);
    _disposeUnused(dropped);
    _changed();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_state);
    _state = _undo.removeLast();
    _changed(keepMerge: false);
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_state);
    _state = _redo.removeLast();
    _changed(keepMerge: false);
  }

  /// A new or opened image: the history of the old one goes away.
  void replace(
    DocumentState state, {
    String? name,
    String? path,
    SaveFormat format = SaveFormat.psd,
  }) {
    final dropped = [..._undo, ..._redo, _state];
    _undo.clear();
    _redo.clear();
    _state = state;
    _saved = state;
    _activeId = state.layers.last.id;
    _nextId = _highestId(state) + 1;
    this.name = name;
    this.path = path;
    this.format = format;
    _disposeUnused(dropped);
    _changed(keepMerge: false);
  }

  void markSaved({required String name, String? path, SaveFormat? format}) {
    _saved = _state;
    _mergeKey = null;
    this.name = name;
    this.path = path;
    if (format != null) this.format = format;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final tile in _tilesOf([..._undo, ..._redo, _state])) {
      tile.dispose();
    }
    super.dispose();
  }

  void _changed({bool keepMerge = true}) {
    if (!keepMerge) _mergeKey = null;
    if (!layers.any((layer) => layer.id == _activeId)) {
      _activeId = layers.last.id;
    }
    revision++;
    notifyListeners();
  }

  /// A step costs only the tiles the image no longer shows: the ones it
  /// shares with the image take no memory of their own.
  void _trim(List<DocumentState> dropped) {
    final shown = _tilesOf([_state]);
    int bytes() => _tilesOf(
      _undo,
    ).difference(shown).fold(0, (sum, tile) => sum + tile.bytes);
    while (_undo.length > 1 && bytes() > historyBytes) {
      dropped.add(_undo.removeAt(0));
    }
  }

  /// Steps share the tiles they did not touch, so a tile goes away only
  /// when no remaining step holds it.
  void _disposeUnused(List<DocumentState> dropped) {
    if (dropped.isEmpty) return;
    final kept = _tilesOf([..._undo, ..._redo, _state]);
    for (final tile in _tilesOf(dropped)) {
      if (!kept.contains(tile)) tile.dispose();
    }
  }

  static Set<Tile> _tilesOf(Iterable<DocumentState> states) {
    // most layers of most steps are the very same pixels
    final seen = Set<TiledImage>.identity();
    return {
      for (final state in states)
        for (final layer in state.layers)
          if (seen.add(layer.pixels)) ...layer.pixels.tiles,
    };
  }

  static int _highestId(DocumentState state) => state.layers.fold(
    0,
    (highest, layer) => layer.id > highest ? layer.id : highest,
  );
}
