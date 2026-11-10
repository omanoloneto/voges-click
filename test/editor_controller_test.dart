import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/canvas/editor_controller.dart';
import 'package:voges_click/canvas/image_ops.dart';
import 'package:voges_click/canvas/tool_settings.dart';
import 'package:voges_click/document/document_io.dart';
import 'package:voges_click/document/image_document.dart';
import 'package:voges_click/document/layer.dart';
import 'package:voges_click/document/tiled_image.dart';
import 'package:voges_click/painting/image_formats.dart';

import 'support/pixels.dart';

EditorController _editor({int width = 40, int height = 30}) {
  final controller = EditorController(
    document: ImageDocument(
      DocumentState(width, height, [
        Layer(
          id: 1,
          name: 'Background',
          pixels: TiledImage.filled(width, height, white),
        ),
      ]),
    ),
    settings: ToolSettings(),
  )..layerName = (number) => 'Layer $number';
  addTearDown(controller.dispose);
  return controller;
}

void _drag(EditorController controller, Offset from, Offset to) {
  controller
    ..pointerDown(from)
    ..pointerMove(to)
    ..pointerUp();
}

void _selectRect(EditorController controller, Rect area) {
  controller.settings.tool = EditTool.marquee;
  _drag(controller, area.topLeft, area.bottomRight);
}

void main() {
  testWidgets('a pencil stroke paints the active layer and can be undone', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.settings
        ..tool = EditTool.pencil
        ..size = 4
        ..color1 = red;
      _drag(controller, const Offset(5, 15), const Offset(35, 15));

      expect(controller.document.dirty, isTrue);
      var pixels = await composite(controller.document.state);
      expect(pixels.colorAt(20, 15), 0xFFFF0000);
      expect(pixels.colorAt(20, 5), 0xFFFFFFFF);

      controller.undo();
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(20, 15), 0xFFFFFFFF);
      controller.redo();
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(20, 15), 0xFFFF0000);
    });
  });

  testWidgets('a long stroke makes again only the tiles it passes through', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor(width: 2048, height: 2048);
      final was = controller.activeLayer.pixels.tiles.toList();
      expect(was, hasLength(4));
      controller.settings
        ..tool = EditTool.pencil
        ..size = 4
        ..color1 = red;
      // along the top and down the right side
      controller
        ..pointerDown(const Offset(100, 100))
        ..pointerMove(const Offset(1900, 100))
        ..pointerMove(const Offset(1900, 1900))
        ..pointerUp();

      final now = controller.activeLayer.pixels.tiles.toList();
      expect(
        [for (var i = 0; i < 4; i++) identical(now[i], was[i])],
        [false, false, true, false],
      );
      final pixels = await composite(controller.document.state);
      expect(pixels.colorAt(1000, 100), 0xFFFF0000);
      expect(pixels.colorAt(1900, 1000), 0xFFFF0000);
      expect(pixels.colorAt(500, 1500), 0xFFFFFFFF);
    });
  });

  testWidgets('painting stays inside the selection', (tester) async {
    await tester.runAsync(() async {
      final controller = _editor();
      _selectRect(controller, const Rect.fromLTWH(10, 10, 10, 10));
      expect(controller.selectionBounds, const Rect.fromLTWH(10, 10, 10, 10));
      controller.settings.color1 = blue;
      controller.fillSelection();

      final pixels = await composite(controller.document.state);
      expect(pixels.colorAt(15, 15), 0xFF0000FF);
      expect(pixels.colorAt(5, 15), 0xFFFFFFFF);
      expect(pixels.colorAt(25, 15), 0xFFFFFFFF);
    });
  });

  testWidgets('paint that misses the picture leaves no undo step', (
    tester,
  ) async {
    final controller = _editor();
    controller.settings
      ..tool = EditTool.brush
      ..size = 10;
    controller
      ..pointerDown(const Offset(-30, 10))
      ..pointerUp();
    expect(controller.canUndo, isFalse);
    expect(controller.document.dirty, isFalse);

    // a stroke that starts outside and comes in still counts
    _drag(controller, const Offset(-30, 10), const Offset(5, 10));
    expect(controller.canUndo, isTrue);
    controller.undo();

    controller.settings.tool = EditTool.rectangle;
    _drag(controller, const Offset(-40, -40), const Offset(-20, -20));
    expect(controller.canUndo, isFalse);

    _selectRect(controller, const Rect.fromLTWH(0, 0, 10, 10));
    controller.settings
      ..tool = EditTool.pencil
      ..size = 4;
    controller
      ..pointerDown(const Offset(30, 20))
      ..pointerUp();
    expect(controller.canUndo, isFalse);
    controller
      ..pointerDown(const Offset(5, 5))
      ..pointerUp();
    expect(controller.canUndo, isTrue);
  });

  testWidgets('a new layer takes the paint and leaves the one below alone', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.addLayer();
      expect(controller.document.layers, hasLength(2));
      expect(controller.activeLayer.name, 'Layer 2');

      controller.selectAll();
      controller.settings.color1 = red;
      controller.fillSelection();
      var pixels = await composite(controller.document.state);
      expect(pixels.colorAt(3, 3), 0xFFFF0000);

      controller.setLayerVisible(controller.activeLayer.id, false);
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(3, 3), 0xFFFFFFFF);
      expect(controller.canPaint, isFalse);

      controller.setLayerVisible(controller.activeLayer.id, true);
      controller.setLayerOpacity(0.5);
      pixels = await composite(controller.document.state);
      final half = pixels.colorAt(3, 3);
      expect(half >> 16 & 0xFF, 255);
      expect(half >> 8 & 0xFF, closeTo(128, 2));
    });
  });

  testWidgets('merging down keeps the picture and leaves one layer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.addLayer();
      _selectRect(controller, const Rect.fromLTWH(0, 0, 20, 30));
      controller.settings.color1 = red;
      controller.fillSelection();
      controller.setLayerOpacity(0.5);
      final before = await composite(controller.document.state);

      expect(controller.canMergeDown, isTrue);
      controller.mergeDown();
      expect(controller.document.layers, hasLength(1));
      expect(controller.canMergeDown, isFalse);
      final after = await composite(controller.document.state);
      for (final (x, y) in [(5, 5), (19, 20), (30, 10)]) {
        final a = before.colorAt(x, y), b = after.colorAt(x, y);
        for (final shift in [0, 8, 16, 24]) {
          expect(b >> shift & 0xFF, closeTo(a >> shift & 0xFF, 1));
        }
      }

      controller.undo();
      expect(controller.document.layers, hasLength(2));
    });
  });

  testWidgets('layers go up, down, away and get a copy', (tester) async {
    final controller = _editor();
    controller.addLayer();
    controller.duplicateLayer();
    expect(controller.document.layers.map((layer) => layer.id), [1, 2, 3]);
    expect(controller.document.activeIndex, 2);

    controller.lowerLayer();
    expect(controller.document.layers.map((layer) => layer.id), [1, 3, 2]);
    controller.raiseLayer();
    expect(controller.document.layers.map((layer) => layer.id), [1, 2, 3]);

    controller.renameLayer(3, 'Sky');
    expect(controller.activeLayer.name, 'Sky');
    controller.deleteLayer();
    expect(controller.document.layers.map((layer) => layer.id), [1, 2]);
    controller.deleteLayer();
    controller.deleteLayer();
    expect(controller.document.layers, hasLength(1));

    controller.setLayerBlend(LayerBlend.multiply);
    expect(controller.document.state.isLayered, isTrue);
  });

  testWidgets('the move tool and the arrows shift only the active layer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.addLayer();
      _selectRect(controller, const Rect.fromLTWH(0, 0, 10, 10));
      controller.settings.color1 = red;
      controller.fillSelection();
      controller.deselect();

      controller.settings.tool = EditTool.move;
      _drag(controller, const Offset(5, 5), const Offset(25, 15));
      var pixels = await composite(controller.document.state);
      expect(pixels.colorAt(5, 5), 0xFFFFFFFF);
      expect(pixels.colorAt(25, 15), 0xFFFF0000);

      controller.nudge(-20, 0);
      controller.nudge(0, -10);
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(5, 5), 0xFFFF0000);
      controller.undo();
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(25, 15), 0xFFFF0000);
    });
  });

  testWidgets('crop, resize and turn change the size of every layer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.addLayer();
      _selectRect(controller, const Rect.fromLTWH(10, 10, 10, 10));
      controller.settings.color1 = red;
      controller.fillSelection();

      controller.cropToSelection();
      expect((controller.document.width, controller.document.height), (10, 10));
      var pixels = await composite(controller.document.state);
      expect(pixels.colorAt(0, 0), 0xFFFF0000);
      expect(pixels.colorAt(9, 9), 0xFFFF0000);

      controller.resize(20, 40, stretch: true);
      expect((controller.document.width, controller.document.height), (20, 40));
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(10, 20), 0xFFFF0000);

      controller.turn(Turn.right);
      expect((controller.document.width, controller.document.height), (40, 20));
      expect(controller.document.layers, hasLength(2));

      controller.undo();
      controller.undo();
      controller.undo();
      expect((controller.document.width, controller.document.height), (40, 30));
    });
  });

  testWidgets('the bucket fills what touches and the picker reads it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.settings.color1 = blue;
      await controller.fillAt(const Offset(3, 3));
      final pixels = await composite(controller.document.state);
      expect(pixels.colorAt(39, 29), 0xFF0000FF);

      controller.settings.color1 = red;
      await controller.pickAt(const Offset(10, 10));
      expect(controller.settings.color1.toARGB32(), 0xFF0000FF);
    });
  });

  testWidgets('the selection fills with either color and becomes a layer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.settings
        ..color1 = red
        ..color2 = blue;
      _selectRect(controller, const Rect.fromLTWH(0, 0, 10, 10));
      controller.fillSelection();
      _selectRect(controller, const Rect.fromLTWH(20, 0, 10, 10));
      controller.fillSelection(background: true);
      var pixels = await composite(controller.document.state);
      expect(pixels.colorAt(5, 5), 0xFFFF0000);
      expect(pixels.colorAt(25, 5), 0xFF0000FF);
      expect(pixels.colorAt(15, 5), 0xFFFFFFFF);

      _selectRect(controller, const Rect.fromLTWH(0, 0, 10, 10));
      controller.layerFromSelection();
      expect(controller.hasSelection, isFalse);
      expect(controller.document.layers, hasLength(2));
      expect(controller.activeLayer.bounds, const Rect.fromLTWH(0, 0, 10, 10));
      controller.setLayerVisible(1, false);
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(5, 5), 0xFFFF0000);
      expect(pixels.colorAt(25, 5) >>> 24, 0);

      controller.layerFromSelection();
      expect(controller.document.layers, hasLength(3));
    });
  });

  testWidgets('layers jump to the ends, take turns and hide', (tester) async {
    final controller = _editor();
    controller
      ..addLayer()
      ..addLayer();
    final top = controller.activeLayer.id;

    controller.lowerLayerToBottom();
    expect(controller.document.layers.first.id, top);
    controller.raiseLayerToTop();
    expect(controller.document.layers.last.id, top);

    controller.activateLayerBy(-1);
    expect(controller.document.activeIndex, 1);
    controller
      ..activateLayerBy(-1)
      ..activateLayerBy(-1);
    expect(controller.document.activeIndex, 0);

    controller.toggleLayerVisible();
    expect(controller.activeLayer.visible, isFalse);
    controller.toggleLayerVisible();
    expect(controller.activeLayer.visible, isTrue);
  });

  testWidgets('Alt makes a painting tool pick the color under it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.settings.color1 = red;
      controller.fillSelection();
      controller.settings
        ..color1 = blue
        ..tool = EditTool.brush;
      controller.pointerDown(const Offset(10, 10), subtract: true);
      controller.pointerUp();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.settings.color1, red);
      expect(controller.canUndo, isTrue);
      controller.undo();
      expect(controller.canUndo, isFalse);
    });
  });

  testWidgets('free transform moves, scales and turns what the layer has', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.addLayer();
      _selectRect(controller, const Rect.fromLTWH(4, 4, 10, 6));
      controller.settings.color1 = red;
      controller.fillSelection();
      controller.deselect();
      final before = controller.document.state;

      await controller.beginTransform();
      final box = controller.transform!;
      // the box hugs the paint, not the whole transparent layer
      expect(box.box, const Rect.fromLTWH(4, 4, 10, 6));
      // all of the layer floats: its own pixels are shown, none is copied
      final floating = controller.live!.floating!;
      expect(floating.pixels, same(controller.activeLayer.pixels));
      expect(floating.part.shift(controller.activeLayer.offset), box.box);

      _drag(controller, const Offset(8, 6), const Offset(18, 16));
      controller
        ..pointerDown(const Offset(24, 20), reach: 2)
        ..pointerMove(const Offset(34, 26))
        ..pointerUp();
      expect(box.box.shift(const Offset(10, 10)).topLeft, box.bounds.topLeft);
      expect(box.width, 20);
      expect(box.height, 12);
      // nothing is painted until it is applied
      expect(controller.document.state, same(before));

      controller.confirm();
      expect(controller.isTransforming, isFalse);
      expect(controller.document.state, isNot(same(before)));
      expect(
        controller.activeLayer.bounds,
        const Rect.fromLTWH(14, 14, 20, 12),
      );
      var pixels = await composite(controller.document.state);
      expect(pixels.colorAt(6, 6), 0xFFFFFFFF);
      expect(pixels.colorAt(15, 15), 0xFFFF0000);
      expect(pixels.colorAt(32, 24), 0xFFFF0000);
      expect(pixels.colorAt(36, 24), 0xFFFFFFFF);

      controller.undo();
      // one step, however many drags it took
      expect(controller.document.state, same(before));
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(6, 6), 0xFFFF0000);
      expect(pixels.colorAt(32, 24), 0xFFFFFFFF);

      await controller.beginTransform();
      controller.transform!.angle = math.pi / 2;
      controller.applyTransform();
      expect(controller.activeLayer.bounds, const Rect.fromLTWH(6, 2, 6, 10));
      pixels = await composite(controller.document.state);
      expect(pixels.colorAt(8, 3), 0xFFFF0000);
      expect(pixels.colorAt(5, 6), 0xFFFFFFFF);
    });
  });

  testWidgets('free transform takes only the selection and brings it along', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.settings.color1 = red;
      _selectRect(controller, const Rect.fromLTWH(0, 0, 10, 10));
      controller.fillSelection();

      await controller.beginTransform();
      controller.nudge(20, 5);
      controller.applyTransform();
      final pixels = await composite(controller.document.state);
      // the hole it left shows nothing: this is the only layer
      expect(pixels.colorAt(5, 2) >>> 24, 0);
      expect(pixels.colorAt(25, 10), 0xFFFF0000);
      expect(pixels.colorAt(15, 20), 0xFFFFFFFF);
      expect(
        controller.selection!.getBounds(),
        const Rect.fromLTWH(20, 5, 10, 10),
      );
    });
  });

  testWidgets('free transform is given up by Esc, undo or a new tool', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      final before = controller.document.state;

      await controller.beginTransform();
      controller.nudge(5, 5);
      controller.cancel();
      expect(controller.isTransforming, isFalse);
      expect(controller.document.state, same(before));

      await controller.beginTransform();
      controller.nudge(5, 5);
      controller.undo();
      expect(controller.isTransforming, isFalse);
      expect(controller.document.state, same(before));

      // left untouched, applying paints nothing
      await controller.beginTransform();
      controller.confirm();
      expect(controller.isTransforming, isFalse);
      expect(controller.document.state, same(before));

      await controller.beginTransform();
      controller.nudge(5, 5);
      controller.settings.tool = EditTool.move;
      expect(controller.isTransforming, isFalse);
      expect(controller.document.state, isNot(same(before)));
      final pixels = await composite(controller.document.state);
      expect(pixels.colorAt(2, 2) >>> 24, 0);
      expect(pixels.colorAt(20, 20), 0xFFFFFFFF);

      controller.setLayerVisible(controller.activeLayer.id, false);
      await controller.beginTransform();
      expect(controller.isTransforming, isFalse);
    });
  });

  testWidgets('a stroke makes again only the tiles under it', (tester) async {
    await tester.runAsync(() async {
      final controller = _editor(width: 2100, height: 1100);
      final document = controller.document;
      final before = document.state;
      final was = before.layers.single.pixels.tiles.toList();
      controller.settings
        ..tool = EditTool.pencil
        ..size = 4
        ..color1 = red;
      _drag(controller, const Offset(1100, 40), const Offset(1300, 40));

      final painted = document.state.layers.single.pixels.tiles.toList();
      expect(
        [for (var i = 0; i < 6; i++) identical(painted[i], was[i])],
        [true, false, true, true, true, true],
      );
      var pixels = await composite(document.state);
      expect(pixels.colorAt(1200, 40), 0xFFFF0000);
      expect(pixels.colorAt(1200, 60), 0xFFFFFFFF);
      expect(pixels.colorAt(500, 40), 0xFFFFFFFF);

      controller.undo();
      expect(document.state, same(before));
      expect(document.dirty, isFalse);
      // what was undone waits to be redone
      expect(painted[1].disposed, isFalse);
      controller.redo();
      pixels = await composite(document.state);
      expect(pixels.colorAt(1200, 40), 0xFFFF0000);

      controller.undo();
      _drag(controller, const Offset(40, 40), const Offset(60, 40));
      // another step in its place: nothing holds that tile any more
      expect(painted[1].disposed, isTrue);
      expect(was.where((tile) => tile.disposed), isEmpty);
      pixels = await composite(document.state);
      expect(pixels.colorAt(50, 40), 0xFFFF0000);
      expect(pixels.colorAt(1200, 40), 0xFFFFFFFF);
    });
  });

  testWidgets('the bucket makes again only the tiles around what it fills', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor(width: 2100, height: 1100);
      controller.settings.color1 = blue;
      _selectRect(controller, const Rect.fromLTWH(1100, 100, 50, 50));
      controller.fillSelection();
      controller.deselect();
      final was = controller.activeLayer.pixels.tiles.toList();

      controller.settings.color1 = red;
      await controller.fillAt(const Offset(1120, 120));
      final now = controller.activeLayer.pixels.tiles.toList();
      expect(
        [for (var i = 0; i < 6; i++) identical(now[i], was[i])],
        [true, false, true, true, true, true],
      );
      final pixels = await composite(controller.document.state);
      expect(pixels.colorAt(1100, 100), 0xFFFF0000);
      expect(pixels.colorAt(1149, 149), 0xFFFF0000);
      expect(pixels.colorAt(1099, 120), 0xFFFFFFFF);
      expect(pixels.colorAt(1150, 150), 0xFFFFFFFF);
    });
  });

  testWidgets('free transform across tiles leaves every step whole', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor(width: 2100, height: 1100);
      final document = controller.document;
      final states = [document.state];
      controller.settings.color1 = red;
      // on the corner four tiles share
      _selectRect(controller, const Rect.fromLTWH(1000, 1000, 100, 60));
      controller.fillSelection();
      states.add(document.state);

      // lifted from four tiles, it lands on one
      await controller.beginTransform();
      controller.nudge(-500, -400);
      controller.applyTransform();
      states.add(document.state);
      var pixels = await composite(document.state);
      expect(pixels.colorAt(1050, 1030) >>> 24, 0);
      expect(pixels.colorAt(550, 630), 0xFFFF0000);
      expect(pixels.colorAt(300, 300), 0xFFFFFFFF);

      await controller.beginTransform();
      controller.nudge(700, 300);
      controller.cancel();
      expect(document.state, same(states[2]));

      // lifted from one tile, it lands on two
      await controller.beginTransform();
      controller.nudge(1500, 0);
      controller.applyTransform();
      states.add(document.state);
      pixels = await composite(document.state);
      expect(pixels.colorAt(550, 630) >>> 24, 0);
      expect(pixels.colorAt(2040, 630), 0xFFFF0000);
      expect(pixels.colorAt(2060, 630), 0xFFFF0000);
      expect(pixels.colorAt(1050, 1030) >>> 24, 0);

      controller.undo();
      expect(document.state, same(states[2]));
      pixels = await composite(document.state);
      expect(pixels.colorAt(550, 630), 0xFFFF0000);
      expect(pixels.colorAt(2040, 630), 0xFFFFFFFF);
      controller.undo();
      expect(document.state, same(states[1]));
      pixels = await composite(document.state);
      expect(pixels.colorAt(1050, 1030), 0xFFFF0000);
      expect(pixels.colorAt(550, 630), 0xFFFFFFFF);

      for (final state in states) {
        expect(
          state.layers.single.pixels.tiles.where((tile) => tile.disposed),
          isEmpty,
        );
      }
      controller
        ..redo()
        ..redo();
      expect(document.state, same(states[3]));
      pixels = await composite(document.state);
      expect(pixels.colorAt(2060, 630), 0xFFFF0000);
      expect(pixels.colorAt(300, 300), 0xFFFFFFFF);
    });
  });

  testWidgets('a PSD saved comes back with its layers', (tester) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.addLayer();
      _selectRect(controller, const Rect.fromLTWH(4, 4, 8, 8));
      controller.settings.color1 = red;
      controller.fillSelection();
      controller.renameLayer(controller.activeLayer.id, 'Square');
      controller.setLayerOpacity(0.5);
      controller.setLayerBlend(LayerBlend.multiply);
      final before = await composite(controller.document.state);

      final bytes = await encodeDocument(
        controller.document.state,
        SaveFormat.psd,
      );
      final loaded = await loadDocument(bytes, layerName: 'Background');
      expect(loaded.loss, LoadLoss.none);
      expect(loaded.state.layers.map((layer) => layer.name), [
        'Background',
        'Square',
      ]);
      final square = loaded.state.layers.last;
      expect(square.blend, LayerBlend.multiply);
      expect(square.opacity, closeTo(0.5, 0.01));

      final after = await composite(loaded.state);
      for (final (x, y) in [(0, 0), (6, 6), (11, 11), (20, 20)]) {
        final a = before.colorAt(x, y), b = after.colorAt(x, y);
        for (final shift in [0, 8, 16, 24]) {
          expect(b >> shift & 0xFF, closeTo(a >> shift & 0xFF, 2));
        }
      }
    });
  });

  testWidgets('a flat format gets the picture and comes back as one layer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final controller = _editor();
      controller.addLayer();
      controller.selectAll();
      controller.settings.color1 = blue;
      controller.fillSelection();

      for (final format in [SaveFormat.png, SaveFormat.bmp, SaveFormat.jpeg]) {
        final bytes = await encodeDocument(controller.document.state, format);
        final loaded = await loadDocument(bytes, layerName: 'Background');
        expect(loaded.state.layers, hasLength(1), reason: format.name);
        final pixels = await composite(loaded.state);
        final color = pixels.colorAt(20, 15);
        expect(color & 0xFF, greaterThan(250), reason: format.name);
        expect(color >> 16 & 0xFF, lessThan(5), reason: format.name);
      }
    });
  });

  testWidgets('what is not an image is refused', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        loadDocument(
          Uint8List.fromList(List.filled(200, 7)),
          layerName: 'Background',
        ),
        throwsFormatException,
      );
    });
  });
}
