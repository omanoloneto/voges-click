import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/canvas/image_ops.dart';
import 'package:voges_click/canvas/tool_settings.dart';
import 'package:voges_click/document/image_document.dart';
import 'package:voges_click/document/layer.dart';
import 'package:voges_click/editor/open_pictures.dart';
import 'package:voges_click/painting/image_formats.dart';

import 'support/pixels.dart';

OpenPictures _pictures() {
  final pictures = OpenPictures(
    settings: ToolSettings(),
    startWidth: 40,
    startHeight: 30,
  );
  addTearDown(pictures.dispose);
  return pictures;
}

/// Opens a blue 20 × 10 picture as if it came from the file at [path].
OpenPicture _open(OpenPictures pictures, String path, {int layers = 1}) =>
    pictures.open(
      DocumentState(20, 10, [
        for (var id = 1; id <= layers; id++)
          Layer(id: id, name: 'Layer $id', image: blankImage(20, 10, blue)),
      ]),
      name: path.split('/').last,
      path: path,
      format: SaveFormat.png,
      source: path,
    );

void main() {
  testWidgets('the editor starts with one untitled picture', (tester) async {
    final pictures = _pictures();
    expect(pictures.pictures, hasLength(1));
    expect(pictures.activeIndex, 0);
    expect(pictures.active.document.name, isNull);
    expect(pictures.active.document.width, 40);
    expect(pictures.active.document.height, 30);
    expect(pictures.active.document.dirty, isFalse);
  });

  testWidgets('a new picture goes in front and shares the tools', (
    tester,
  ) async {
    final pictures = _pictures();
    var changes = 0;
    pictures.addListener(() => changes++);
    final first = pictures.active;
    final second = pictures.addBlank(64, 48);

    expect(pictures.pictures, [first, second]);
    expect(pictures.active, same(second));
    expect(changes, 1);
    expect(second.document.width, 64);
    expect(second.document.height, 48);
    expect(second.document.name, isNull);
    expect(second.controller, isNot(same(first.controller)));
    expect(second.controller.settings, same(first.controller.settings));
  });

  testWidgets('next and previous go around', (tester) async {
    final pictures = _pictures();
    final first = pictures.active;
    final second = pictures.addBlank(10, 10);
    final third = pictures.addBlank(10, 10);

    pictures.next();
    expect(pictures.active, same(first));
    pictures.previous();
    expect(pictures.active, same(third));
    pictures.previous();
    expect(pictures.active, same(second));
    pictures.activate(first);
    expect(pictures.activeIndex, 0);
  });

  testWidgets('an opened file takes the place of the untouched start picture', (
    tester,
  ) async {
    final pictures = _pictures();
    final start = pictures.active;
    final cat = _open(pictures, '/photos/cat.png');

    expect(cat, same(start));
    expect(pictures.pictures, hasLength(1));
    expect(cat.document.name, 'cat.png');
    expect(cat.document.path, '/photos/cat.png');
    expect(cat.document.width, 20);
    expect(cat.document.dirty, isFalse);

    final dog = _open(pictures, '/photos/dog.png');
    expect(pictures.pictures, [cat, dog]);
    expect(pictures.active, same(dog));
    expect(dog.document.name, 'dog.png');
    expect(dog.document.format, SaveFormat.png);
    expect(dog.document.dirty, isFalse);
  });

  testWidgets('a start picture that was used, or a new one, is kept', (
    tester,
  ) async {
    final pictures = _pictures();
    final start = pictures.active;
    // undone, the picture is clean again but it was worked on
    start.controller
      ..addLayer()
      ..undo();
    expect(start.document.dirty, isFalse);
    _open(pictures, '/photos/cat.png');
    expect(pictures.pictures, hasLength(2));
    expect(start.document.name, isNull);

    final blank = pictures.addBlank(64, 48);
    _open(pictures, '/photos/dog.png');
    expect(pictures.pictures, hasLength(4));
    expect(blank.document.width, 64);
  });

  testWidgets('a file that is already open is shown, not opened again', (
    tester,
  ) async {
    final pictures = _pictures();
    final cat = _open(pictures, '/photos/cat.png');
    final dog = _open(pictures, '/photos/dog.png');
    expect(pictures.active, same(dog));

    expect(pictures.showFile('/photos/cat.png'), isTrue);
    expect(pictures.active, same(cat));
    expect(pictures.showFile('/photos/bird.png'), isFalse);
    expect(pictures.active, same(cat));
    expect(pictures.pictures, hasLength(2));
  });

  testWidgets('closing shows the neighbour and frees the picture', (
    tester,
  ) async {
    final pictures = _pictures();
    final first = pictures.active;
    final second = pictures.addBlank(10, 10);
    final third = pictures.addBlank(10, 10);
    final fourth = pictures.addBlank(10, 10);
    final image = second.document.layers.single.image;

    pictures.activate(second);
    pictures.close(second);
    expect(pictures.pictures, [first, third, fourth]);
    expect(pictures.active, same(third));
    expect(image.debugDisposed, isTrue);
    expect(() => second.controller.addListener(() {}), throwsFlutterError);

    // one that is not in front goes away without changing what is shown
    pictures.close(first);
    expect(pictures.active, same(third));
    pictures.close(fourth);
    expect(pictures.active, same(third));

    pictures.addBlank(10, 10);
    final last = pictures.active;
    pictures.close(last);
    expect(pictures.pictures, [third]);
    expect(pictures.active, same(third));
  });

  testWidgets('closing the last picture leaves a fresh untitled one', (
    tester,
  ) async {
    final pictures = _pictures();
    final cat = _open(pictures, '/photos/cat.png');
    pictures.close(cat);

    expect(pictures.pictures, hasLength(1));
    expect(pictures.active, isNot(same(cat)));
    expect(pictures.active.document.name, isNull);
    expect(pictures.active.document.width, 40);
    expect(pictures.active.source, isNull);
    // and a file opened next takes its place, as at the start
    _open(pictures, '/photos/dog.png');
    expect(pictures.pictures, hasLength(1));
  });

  testWidgets('a picture left behind keeps nothing half done', (tester) async {
    await tester.runAsync(() async {
      final pictures = _pictures();
      final first = pictures.active;
      final before = first.document.state;
      await first.controller.beginTransform();
      first.controller.nudge(5, 5);
      final second = pictures.addBlank(40, 30);
      // the free transform is applied, in one undo step
      expect(first.controller.isTransforming, isFalse);
      expect(first.document.state, isNot(same(before)));
      first.controller.undo();
      expect(first.document.state, same(before));

      second.controller.settings.tool = EditTool.marquee;
      second.controller
        ..pointerDown(const Offset(2, 2))
        ..pointerMove(const Offset(12, 12));
      expect(second.controller.pendingSelection, isNotNull);
      pictures.previous();
      // the drag is dropped, and letting go later does nothing
      expect(second.controller.pendingSelection, isNull);
      second.controller.pointerUp();
      expect(second.controller.hasSelection, isFalse);

      first.controller.settings
        ..tool = EditTool.pencil
        ..color1 = red;
      first.controller
        ..pointerDown(const Offset(5, 5))
        ..pointerMove(const Offset(20, 5));
      pictures.next();
      first.controller.pointerUp();
      final pixels = await composite(first.document.state);
      expect(pixels.colorAt(10, 5), 0xFFFFFFFF);
    });
  });

  testWidgets('work that ends after its picture was closed is dropped', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pictures = _pictures();
      final filled = pictures.active;
      final lifted = pictures.addBlank(40, 30);
      final pasted = pictures.addBlank(40, 30);
      pictures.addBlank(40, 30);
      final png = (await pasted.controller.copyPng())!;

      final filling = filled.controller.fillAt(const Offset(5, 5));
      final lifting = lifted.controller.beginTransform();
      final pasting = pasted.controller.paste(png);
      pictures
        ..close(filled)
        ..close(lifted)
        ..close(pasted);

      await filling;
      await lifting;
      expect(await pasting, isTrue);
      expect(lifted.controller.isTransforming, isFalse);
    });
  });

  testWidgets('layers are named in the same language in every picture', (
    tester,
  ) async {
    final pictures = _pictures();
    final first = pictures.active;
    final second = pictures.addBlank(10, 10);
    pictures.layerName = (number) => 'Camada $number';

    first.controller.addLayer();
    second.controller.addLayer();
    expect(first.controller.activeLayer.name, 'Camada 2');
    expect(second.controller.activeLayer.name, 'Camada 2');
    final third = pictures.addBlank(10, 10);
    expect(third.document.layers.single.name, 'Camada 1');
  });

  testWidgets('an opened picture numbers new layers after the ones it has', (
    tester,
  ) async {
    final pictures = _pictures();
    final replaced = _open(pictures, '/photos/cat.psd', layers: 3);
    final added = _open(pictures, '/photos/dog.psd', layers: 3);
    expect(pictures.pictures, [replaced, added]);

    replaced.controller.addLayer();
    added.controller.addLayer();
    expect(replaced.controller.activeLayer.name, 'Layer 4');
    expect(added.controller.activeLayer.name, 'Layer 4');
  });

  testWidgets('what is copied in one picture is pasted in another', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pictures = _pictures();
      final from = pictures.active;
      from.controller.settings
        ..tool = EditTool.marquee
        ..color1 = red;
      from.controller
        ..pointerDown(const Offset(10, 10))
        ..pointerMove(const Offset(18, 16))
        ..pointerUp()
        ..fillSelection();
      final png = (await from.controller.copyPng())!;

      final to = pictures.addBlank(40, 30);
      expect(
        await to.controller.paste(png, origin: const Offset(3, 4)),
        isTrue,
      );
      // a new layer with those pixels, where the other picture asked for
      expect(to.document.layers, hasLength(2));
      expect(to.controller.activeLayer.offset, const Offset(3, 4));
      expect(to.controller.activeLayer.image.width, 8);
      expect(to.controller.activeLayer.image.height, 6);
      final pixels = await composite(to.document.state);
      expect(pixels.colorAt(4, 5), 0xFFFF0000);
      expect(pixels.colorAt(10, 9), 0xFFFF0000);
      expect(pixels.colorAt(12, 12), 0xFFFFFFFF);

      // in the picture it came from, it goes back to its place
      expect(await from.controller.paste(png), isTrue);
      expect(from.controller.activeLayer.offset, const Offset(10, 10));
    });
  });
}
