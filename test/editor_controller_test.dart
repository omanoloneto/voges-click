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
import 'package:voges_click/painting/image_formats.dart';

import 'support/pixels.dart';

EditorController _editor({int width = 40, int height = 30}) {
  final controller = EditorController(
    document: ImageDocument(
      DocumentState(width, height, [
        Layer(
          id: 1,
          name: 'Background',
          image: blankImage(width, height, white),
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
