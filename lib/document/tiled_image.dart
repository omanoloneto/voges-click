import 'dart:math' as math;
import 'dart:ui' as ui;

import '../canvas/image_ops.dart';
import '../painting/opaque_bounds.dart' as scan;
import '../painting/rgba_image.dart';
import 'tile.dart';

/// The side of the squares the pixels of a layer are kept in.
const tileSide = 1024;

/// The pixels of a layer, cut into tiles so that an edit replaces only the
/// tiles it touches and shares the others with the steps before it. A
/// missing tile is transparent. Never changed in place.
class TiledImage {
  TiledImage._(
    this.width,
    this.height,
    this._startX,
    this._startY,
    this._columns,
    this._tiles,
  );

  /// Nothing painted yet: takes no memory, whatever the size.
  factory TiledImage.transparent(int width, int height) {
    assert(width > 0 && height > 0);
    final columns = _count(width, 0);
    return TiledImage._(
      width,
      height,
      0,
      0,
      columns,
      List.filled(columns * _count(height, 0), null),
    );
  }

  /// One color all over. Tiles of the same size are one and the same.
  factory TiledImage.filled(int width, int height, ui.Color color) {
    final image = TiledImage.transparent(width, height);
    final shared = <ui.Size, Tile>{};
    for (var index = 0; index < image._tiles.length; index++) {
      final size = image
          ._areaAt(index % image._columns, index ~/ image._columns)
          .size;
      image._tiles[index] = shared[size] ??= Tile(
        renderImage(
          size.width.toInt(),
          size.height.toInt(),
          (canvas) => canvas.drawColor(color, ui.BlendMode.src),
        ),
      );
    }
    return image;
  }

  /// The pixels of [image], which ends here: only the tiles are kept.
  factory TiledImage.fromImage(ui.Image image) {
    final pixels = TiledImage.transparent(image.width, image.height).patched(
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      patch: image,
    );
    image.dispose();
    return pixels;
  }

  final int width;
  final int height;

  /// Where the first tile starts, zero or less. Tiles stay where they are
  /// on the picture when the image grows to the left or upwards, so they
  /// can be kept as they are.
  final int _startX;
  final int _startY;
  final int _columns;
  final List<Tile?> _tiles;

  int get _rows => _tiles.length ~/ _columns;

  Iterable<Tile> get tiles => _tiles.whereType<Tile>();

  /// The image that takes [bounds] of this one, measured in the pixels of
  /// this one, with [patch] at [at] in place of what was there. [changes]
  /// tells whether the patch differs from what was there inside an area of
  /// the new image, so that the tiles it leaves as they were are kept.
  TiledImage patched(
    ui.Rect bounds, {
    ui.Image? patch,
    ui.Offset at = ui.Offset.zero,
    bool Function(ui.Rect area)? changes,
  }) {
    final left = bounds.left.round(), top = bounds.top.round();
    final width = bounds.width.round(), height = bounds.height.round();
    final startX = _startOf(_startX - left), startY = _startOf(_startY - top);
    final shiftX = (_startX - left - startX) ~/ tileSide;
    final shiftY = (_startY - top - startY) ~/ tileSide;
    final columns = _count(width, startX), rows = _count(height, startY);
    final moved = ui.Offset(-left.toDouble(), -top.toDouble());
    final next = TiledImage._(
      width,
      height,
      startX,
      startY,
      columns,
      List.filled(columns * rows, null),
    );
    final placed = patch == null
        ? null
        : (at + moved) &
              ui.Size(patch.width.toDouble(), patch.height.toDouble());
    final source = ui.Paint()
      ..blendMode = ui.BlendMode.src
      ..isAntiAlias = false;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final area = next._areaAt(column, row);
        final old = _tileAt(column - shiftX, row - shiftY);
        final oldArea = old == null
            ? null
            : _areaAt(column - shiftX, row - shiftY).shift(moved);
        final touched =
            placed != null &&
            placed.overlaps(area) &&
            (changes == null || changes(area));
        if (!touched && old == null) continue;
        if (!touched && oldArea == area) {
          next._tiles[row * columns + column] = old;
          continue;
        }
        final covered = touched && placed.intersect(area) == area;
        next._tiles[row * columns + column] = Tile(
          renderImage(area.width.toInt(), area.height.toInt(), (canvas) {
            canvas.translate(-area.left, -area.top);
            if (old != null && oldArea != null && !covered) {
              canvas.drawImage(old.image, oldArea.topLeft, source);
            }
            if (patch != null && placed != null && touched) {
              canvas.drawImage(patch, placed.topLeft, source);
            }
          }),
        );
      }
    }
    return next;
  }

  /// Draws the tiles in sight with [paint], which loses its anti-aliasing:
  /// softened edges would show between the tiles.
  void paint(ui.Canvas canvas, ui.Offset offset, ui.Paint paint) {
    paint.isAntiAlias = false;
    final view = canvas.getLocalClipBounds().shift(-offset);
    final (firstColumn, lastColumn) = _span(
      view.left,
      view.right,
      _startX,
      _columns,
    );
    final (firstRow, lastRow) = _span(view.top, view.bottom, _startY, _rows);
    for (var row = firstRow; row <= lastRow; row++) {
      for (var column = firstColumn; column <= lastColumn; column++) {
        final tile = _tiles[row * _columns + column];
        if (tile == null) continue;
        canvas.drawImage(
          tile.image,
          offset + _areaAt(column, row).topLeft,
          paint,
        );
      }
    }
  }

  /// The smallest box that holds every pixel that is not fully transparent;
  /// null when there is nothing to see. Reads one tile at a time, and only
  /// the tiles that can still make the box bigger.
  Future<ui.Rect?> opaqueBounds() async {
    final cells = [
      for (var index = 0; index < _tiles.length; index++)
        if (_tiles[index] != null) index,
    ];
    ui.Rect? box;
    // from both ends inwards: an image full to its corners takes two tiles
    for (var low = 0, high = cells.length - 1; low <= high; low++, high--) {
      for (final index in {cells[low], cells[high]}) {
        final area = _areaAt(index % _columns, index ~/ _columns);
        if (box != null && box.expandToInclude(area) == box) continue;
        final data = await _tiles[index]!.read();
        if (data == null) continue;
        final found = scan.opaqueBounds(
          RgbaImage(
            area.width.toInt(),
            area.height.toInt(),
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ),
        );
        if (found == null) continue;
        final (left, top, right, bottom) = found;
        final inside = ui.Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          right.toDouble(),
          bottom.toDouble(),
        ).shift(area.topLeft);
        box = box?.expandToInclude(inside) ?? inside;
      }
    }
    return box;
  }

  /// A copy in one piece, for whoever asks to dispose.
  ui.Image toImage() => renderImage(
    width,
    height,
    (canvas) =>
        paint(canvas, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.src),
  );

  Tile? _tileAt(int column, int row) =>
      column < 0 || row < 0 || column >= _columns || row >= _rows
      ? null
      : _tiles[row * _columns + column];

  /// The part of the image the tile at [column], [row] holds.
  ui.Rect _areaAt(int column, int row) => ui.Rect.fromLTRB(
    math.max(0, _startX + column * tileSide).toDouble(),
    math.max(0, _startY + row * tileSide).toDouble(),
    math.min(width, _startX + (column + 1) * tileSide).toDouble(),
    math.min(height, _startY + (row + 1) * tileSide).toDouble(),
  );

  /// The first and the last cell a view from [from] to [to] reaches; the
  /// last comes before the first when it reaches none.
  static (int, int) _span(double from, double to, int start, int cells) {
    // no clip to measure: every tile is drawn
    if (from.isNaN || to.isNaN) return (0, cells - 1);
    final first = ((from - start) / tileSide).clamp(0, cells).floor();
    final last = ((to - start) / tileSide).clamp(-1, cells).ceil() - 1;
    return (first, math.min(last, cells - 1));
  }

  static int _count(int length, int start) =>
      (length - start + tileSide - 1) ~/ tileSide;

  static int _startOf(int position) {
    final rest = position % tileSide;
    return rest == 0 ? 0 : rest - tileSide;
  }
}
