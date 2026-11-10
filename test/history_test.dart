import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/document/image_document.dart';
import 'package:voges_click/document/layer.dart';
import 'package:voges_click/document/tile.dart';
import 'package:voges_click/document/tiled_image.dart';

const _width = 40, _height = 30;

/// What one tile of a picture of this size takes.
const _step = _width * _height * 4;

DocumentState _picture(int shade) => DocumentState(_width, _height, [
  Layer(
    id: 1,
    name: 'Background',
    pixels: TiledImage.filled(_width, _height, Color(0xFF000000 | shade)),
  ),
]);

Tile _tile(DocumentState state) => state.layers.single.pixels.tiles.single;

int _undoAll(ImageDocument document) {
  var steps = 0;
  for (; document.canUndo; steps++) {
    document.undo();
  }
  return steps;
}

void main() {
  testWidgets('the history keeps the steps that fit its memory', (
    tester,
  ) async {
    final states = [for (var shade = 0; shade < 6; shade++) _picture(shade)];
    final document = ImageDocument(states.first, historyBytes: 3 * _step);
    addTearDown(document.dispose);
    states.skip(1).forEach(document.commit);

    // the oldest went away, pixels and all
    expect(_tile(states[0]).disposed, isTrue);
    expect(_tile(states[1]).disposed, isTrue);
    expect(states.skip(2).every((state) => !_tile(state).disposed), isTrue);
    expect(_undoAll(document), 3);
    expect(document.state, same(states[2]));
  });

  testWidgets('one step is kept even when it does not fit', (tester) async {
    final states = [for (var shade = 0; shade < 4; shade++) _picture(shade)];
    final document = ImageDocument(states.first, historyBytes: 0);
    addTearDown(document.dispose);
    states.skip(1).forEach(document.commit);

    expect(_tile(states[1]).disposed, isTrue);
    expect(_tile(states[2]).disposed, isFalse);
    expect(_undoAll(document), 1);
    expect(document.state, same(states[2]));
  });

  testWidgets('steps that share the pixels of the picture take no memory', (
    tester,
  ) async {
    final document = ImageDocument(_picture(0), historyBytes: 0);
    addTearDown(document.dispose);
    final tile = _tile(document.state);
    for (var step = 1; step <= 8; step++) {
      document.commit(
        document.state.replacing(
          document.activeLayer.copyWith(opacity: 1 - step / 10),
        ),
      );
    }

    expect(tile.disposed, isFalse);
    expect(_undoAll(document), 8);
    expect(document.dirty, isFalse);
  });

  testWidgets('a tile goes away with the last step that holds it', (
    tester,
  ) async {
    final first = _picture(0), second = _picture(1), third = _picture(2);
    final document = ImageDocument(first);
    document
      ..commit(second)
      ..undo();
    expect(document.state, same(first));
    expect(document.dirty, isFalse);
    // still there to be redone
    expect(_tile(second).disposed, isFalse);

    document.commit(third);
    expect(document.canRedo, isFalse);
    expect(_tile(second).disposed, isTrue);
    expect(_tile(first).disposed, isFalse);
    expect(_tile(third).disposed, isFalse);

    document.dispose();
    expect(_tile(first).disposed, isTrue);
    expect(_tile(third).disposed, isTrue);
  });
}
