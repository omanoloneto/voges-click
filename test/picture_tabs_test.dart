import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voges_click/app.dart';
import 'package:voges_click/canvas/canvas_view.dart';
import 'package:voges_click/canvas/image_ops.dart';
import 'package:voges_click/canvas/tool_settings.dart';
import 'package:voges_click/editor/open_pictures.dart';
import 'package:voges_click/editor/picture_tabs.dart';
import 'package:voges_click/editor/status_bar.dart';
import 'package:voges_click/files/image_clipboard.dart';
import 'package:voges_click/files/image_files.dart';
import 'package:voges_click/files/system_open.dart';
import 'package:voges_click/l10n/app_language.dart';

import 'support/pixels.dart';

const _control = LogicalKeyboardKey.control;
const _shift = LogicalKeyboardKey.shift;

/// A clipboard that lives in memory.
class _Clipboard extends ImageClipboard {
  Uint8List? png;

  @override
  Future<void> write(Uint8List png) async => this.png = png;

  @override
  Future<Uint8List?> read() async => png;
}

/// Files that live in memory; [picked] is what the Open dialog answers.
class _Files extends ImageFiles {
  final stored = <String, Uint8List>{};
  final reads = <String>[];
  var picked = <String>[];

  @override
  Future<List<String>> pick() async => picked;

  @override
  Future<OpenedFile> read(String path) async {
    reads.add(path);
    return OpenedFile(
      name: path.split('/').last,
      bytes: stored[path]!,
      path: path,
    );
  }
}

Future<OpenPictures> _pump(
  WidgetTester tester, {
  ImageFiles? files,
  ImageClipboard? clipboard,
  List<String> launchArguments = const [],
  Size window = const Size(1400, 900),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pictures = OpenPictures(
    settings: ToolSettings(),
    startWidth: 200,
    startHeight: 100,
  );
  addTearDown(pictures.dispose);
  files ??= ImageFiles();
  await tester.pumpWidget(
    VogesClickApp(
      pictures: pictures,
      files: files,
      clipboard: clipboard ?? ImageClipboard(),
      systemOpen: SystemOpen(files),
      language: AppLanguage(),
      launchArguments: launchArguments,
    ),
  );
  await tester.pumpAndSettle();
  return pictures;
}

/// Presses [key] with [modifiers] held.
Future<void> _chord(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey key,
) async {
  for (final modifier in modifiers) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(key);
  for (final modifier in modifiers.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
}

/// Waits in real time for work the engine does outside the test clock.
Future<void> _until(bool Function() done) async {
  for (var tries = 0; !done() && tries < 200; tries++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// A PNG file of one color.
Future<Uint8List> _png(int width, int height, Color color) async {
  final image = renderImage(
    width,
    height,
    (canvas) => canvas.drawColor(color, ui.BlendMode.src),
  );
  final png = await encodePng(image);
  image.dispose();
  return png;
}

Finder _inTabs(Finder matching) =>
    find.descendant(of: find.byType(PictureTabs), matching: matching);

Finder _tab(String name) => _inTabs(find.text(name));

/// The close button of the tab in front.
final _closeInFront = _inTabs(find.byTooltip('Close (Ctrl+W)'));

/// The close buttons of the tabs behind.
final _closeBehind = _inTabs(find.byTooltip('Close'));

Finder _zoom(String text) =>
    find.descendant(of: find.byType(StatusBar), matching: find.text(text));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a single picture already has its tab', (tester) async {
    final pictures = await _pump(tester);
    expect(pictures.pictures, hasLength(1));
    expect(_tab('Untitled'), findsOneWidget);
    expect(_closeInFront, findsOneWidget);
    expect(_closeBehind, findsNothing);
  });

  testWidgets('New adds a tab, and Ctrl+Tab goes around the pictures', (
    tester,
  ) async {
    final pictures = await _pump(tester);
    final first = pictures.active;
    await _chord(tester, [_control], LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(pictures.pictures, hasLength(2));
    expect(pictures.activeIndex, 1);
    expect(first.isUntouched, isTrue);
    expect(_tab('Untitled'), findsNWidgets(2));
    expect(_closeBehind, findsOneWidget);

    await _chord(tester, [_control], LogicalKeyboardKey.tab);
    expect(pictures.active, same(first));
    await _chord(tester, [_control], LogicalKeyboardKey.tab);
    expect(pictures.activeIndex, 1);
    await _chord(tester, [_control, _shift], LogicalKeyboardKey.tab);
    expect(pictures.active, same(first));
    await _chord(tester, [_control, _shift], LogicalKeyboardKey.tab);
    expect(pictures.activeIndex, 1);

    await tester.tap(_tab('Untitled').first);
    expect(pictures.active, same(first));
  });

  testWidgets('each picture keeps its own zoom', (tester) async {
    final pictures = await _pump(tester);
    pictures.addBlank(64, 48);
    await tester.pump();
    expect(find.text('64 × 48 px'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(_zoom('150%'), findsOneWidget);

    await _chord(tester, [_control], LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text('200 × 100 px'), findsOneWidget);
    expect(_zoom('100%'), findsOneWidget);
    await _chord(tester, [_control], LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_zoom('150%'), findsOneWidget);
  });

  testWidgets('Ctrl+W closes the picture in front; the last one leaves a '
      'fresh one', (tester) async {
    final pictures = await _pump(tester);
    final first = pictures.active;
    final second = pictures.addBlank(64, 48);
    await tester.pump();

    await _chord(tester, [_control], LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    expect(pictures.pictures, [first]);
    expect(second.document.layers.single.pixels.tiles.single.disposed, isTrue);
    expect(find.text('200 × 100 px'), findsOneWidget);

    await tester.tap(find.byTooltip('Zoom in'));
    await _chord(tester, [_control], LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    expect(pictures.pictures, hasLength(1));
    expect(pictures.active, isNot(same(first)));
    expect(pictures.active.isUntouched, isTrue);
    expect(_tab('Untitled'), findsOneWidget);
    expect(_zoom('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a picture with unsaved changes asks before it closes', (
    tester,
  ) async {
    final pictures = await _pump(tester);
    final first = pictures.active;
    final second = pictures.addBlank(64, 48);
    first.controller.addLayer();
    await tester.pump();
    expect(_inTabs(find.byTooltip('Unsaved changes')), findsOneWidget);

    // the one behind comes to the front, to be seen before the answer
    await tester.tap(_closeBehind);
    await tester.pumpAndSettle();
    expect(pictures.active, same(first));
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pictures.pictures, [first, second]);

    await _chord(tester, [_control], LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't save"));
    await tester.pumpAndSettle();
    expect(pictures.pictures, [second]);
    expect(find.text('Save changes?'), findsNothing);
  });

  testWidgets('the middle button of the mouse closes a tab', (tester) async {
    final pictures = await _pump(tester);
    final first = pictures.active;
    final second = pictures.addBlank(64, 48);
    final third = pictures.addBlank(32, 32);
    await tester.pump();

    await tester.tap(
      _tab('Untitled').at(1),
      buttons: kMiddleMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(pictures.pictures, [first, third]);
    expect(pictures.active, same(third));
    expect(second.document.layers.single.pixels.tiles.single.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving asks about every picture with unsaved changes', (
    tester,
  ) async {
    final pictures = await _pump(tester);
    final first = pictures.active;
    pictures.addBlank(64, 48);
    final third = pictures.addBlank(32, 32);
    first.controller.addLayer();
    third.controller.addLayer();
    await tester.pump();

    var leaving = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    expect(pictures.active, same(first));
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text("Don't save"));
    await tester.pumpAndSettle();
    // the clean one in the middle is not asked about
    expect(pictures.active, same(third));
    expect(find.text('Save changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await leaving, ui.AppExitResponse.cancel);
    expect(pictures.pictures, hasLength(3));

    leaving = tester.binding.handleRequestAppExit();
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't save"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't save"));
    await tester.pumpAndSettle();
    expect(await leaving, ui.AppExitResponse.exit);
  });

  testWidgets('what is copied in one picture is pasted in another', (
    tester,
  ) async {
    final clipboard = _Clipboard();
    final pictures = await _pump(tester, clipboard: clipboard);
    final from = pictures.active;
    from.controller.settings
      ..tool = EditTool.marquee
      ..color1 = red;
    from.controller
      ..pointerDown(const Offset(10, 10))
      ..pointerMove(const Offset(18, 16))
      ..pointerUp()
      ..fillSelection();
    await tester.runAsync(() async {
      await _chord(tester, [_control], LogicalKeyboardKey.keyC);
      await _until(() => clipboard.png != null);
    });
    expect(clipboard.png, isNotNull);

    final to = pictures.addBlank(120, 80);
    await tester.pump();
    await tester.runAsync(() async {
      await _chord(tester, [_control], LogicalKeyboardKey.keyV);
      await _until(() => to.document.layers.length == 2);
    });
    await tester.pump();
    // a new layer with those pixels, at the top left of what is in sight
    expect(to.document.layers, hasLength(2));
    expect(to.controller.activeLayer.offset, Offset.zero);
    expect(to.controller.activeLayer.pixels.width, 8);
    expect(to.controller.activeLayer.pixels.height, 6);
    final pixels = (await tester.runAsync(() => composite(to.document.state)))!;
    expect(pixels.colorAt(3, 3), 0xFFFF0000);
    expect(pixels.colorAt(12, 12), 0xFFFFFFFF);
    expect(from.document.layers, hasLength(1));

    // back in the picture it came from, it lands where it was
    await _chord(tester, [_control, _shift], LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.runAsync(() async {
      await _chord(tester, [_control], LogicalKeyboardKey.keyV);
      await _until(() => from.document.layers.length == 2);
    });
    await tester.pump();
    expect(from.controller.activeLayer.offset, const Offset(10, 10));
    expect(to.document.layers, hasLength(2));
  });

  testWidgets('a picture behind keeps its scroll, and a paste lands in sight', (
    tester,
  ) async {
    final clipboard = _Clipboard();
    final pictures = await _pump(tester, clipboard: clipboard);
    await tester.runAsync(() async => clipboard.png = await _png(8, 6, red));
    final big = pictures.addBlank(2000, 1500);
    await tester.pump();

    big.controller.settings.tool = EditTool.hand;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CanvasView)),
    );
    await gesture.moveBy(const Offset(-124, -84));
    await gesture.up();
    await tester.pump();

    await _chord(tester, [_control], LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text('200 × 100 px'), findsOneWidget);
    await _chord(tester, [_control], LogicalKeyboardKey.tab);
    await tester.pump();
    expect(pictures.active, same(big));

    await tester.runAsync(() async {
      await _chord(tester, [_control], LogicalKeyboardKey.keyV);
      await _until(() => big.document.layers.length == 2);
    });
    // the canvas keeps a margin of 24 around the picture
    expect(big.controller.activeLayer.offset, const Offset(100, 60));
  });

  testWidgets('Open shows every chosen file, each in its tab', (tester) async {
    final files = _Files();
    late final OpenPictures pictures;
    late final OpenPicture start;
    await tester.runAsync(() async {
      files.stored['/photos/cat.png'] = await _png(30, 20, red);
      files.stored['/photos/dog.png'] = await _png(50, 40, blue);
      // files are decoded outside the test clock, so the screen starts there
      pictures = await _pump(tester, files: files);
      start = pictures.active;
      files.picked = ['/photos/cat.png', '/photos/dog.png'];
      await _chord(tester, [_control], LogicalKeyboardKey.keyO);
      await _until(() => pictures.pictures.length == 2);
    });
    await tester.pumpAndSettle();

    // the first file takes the place of the untouched start picture
    expect(pictures.pictures.first, same(start));
    expect(start.document.name, 'cat.png');
    expect(start.document.width, 30);
    expect(pictures.active.document.name, 'dog.png');
    expect(pictures.active.document.dirty, isFalse);
    expect(_tab('cat.png'), findsOneWidget);
    expect(_tab('Untitled'), findsNothing);
    // the title bar follows the picture in front
    expect(find.text('dog.png'), findsNWidgets(2));
    expect(find.text('cat.png'), findsOneWidget);
    expect(find.text('50 × 40 px'), findsOneWidget);

    // a file that is already open is shown, without being read again
    files.picked = ['/photos/cat.png'];
    await tester.runAsync(() async {
      await _chord(tester, [_control], LogicalKeyboardKey.keyO);
      await _until(() => pictures.activeIndex == 0);
    });
    await tester.pump();
    expect(pictures.pictures, hasLength(2));
    expect(pictures.active, same(start));
    expect(files.reads, ['/photos/cat.png', '/photos/dog.png']);
    expect(find.text('cat.png'), findsNWidgets(2));
  });

  testWidgets('a file that is not an image does not stop the next ones', (
    tester,
  ) async {
    final files = _Files();
    late final OpenPictures pictures;
    await tester.runAsync(() async {
      files.stored['/photos/notes.png'] = Uint8List.fromList([1, 2, 3]);
      files.stored['/photos/dog.png'] = await _png(50, 40, blue);
      pictures = await _pump(tester, files: files);
      files.picked = [
        '/photos/missing.png',
        '/photos/notes.png',
        '/photos/dog.png',
      ];
      await _chord(tester, [_control], LogicalKeyboardKey.keyO);
      await _until(() => pictures.active.document.name == 'dog.png');
    });
    await tester.pump();

    expect(pictures.pictures, hasLength(1));
    expect(pictures.active.document.name, 'dog.png');
    expect(
      find.text('This file could not be opened as an image.'),
      findsOneWidget,
    );
  });

  testWidgets('the files the system hands over open, each in its tab', (
    tester,
  ) async {
    final files = _Files();
    late final OpenPictures pictures;
    await tester.runAsync(() async {
      files.stored['/photos/cat.png'] = await _png(30, 20, red);
      files.stored['/photos/dog.png'] = await _png(50, 40, blue);
      pictures = await _pump(
        tester,
        files: files,
        launchArguments: [
          '/photos/cat.png',
          '/photos/dog.png',
          '/photos/cat.png',
        ],
      );
      // the one asked for twice is open once, and ends up in front
      await _until(
        () => pictures.pictures.length == 2 && pictures.activeIndex == 0,
      );
    });
    await tester.pumpAndSettle();

    expect(
      [for (final picture in pictures.pictures) picture.document.name],
      ['cat.png', 'dog.png'],
    );
    expect(pictures.activeIndex, 0);
    expect(_tab('cat.png'), findsOneWidget);
    expect(_tab('dog.png'), findsOneWidget);
    expect(find.text('30 × 20 px'), findsOneWidget);
  });

  testWidgets('tabs that do not fit scroll sideways, and the one in front '
      'comes into sight', (tester) async {
    final pictures = await _pump(tester, window: const Size(900, 600));
    for (var added = 0; added < 12; added++) {
      pictures.addBlank(10, 10);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final strip = tester.getRect(find.byType(PictureTabs));
    double firstTabLeft() => tester.getRect(_tab('Untitled').first).left;
    expect(tester.getRect(_closeInFront).right, lessThanOrEqualTo(strip.right));
    expect(firstTabLeft(), lessThan(strip.left));

    // going around to the first picture brings its tab back
    await _chord(tester, [_control], LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(pictures.activeIndex, 0);
    final shown = firstTabLeft();
    expect(shown, greaterThanOrEqualTo(strip.left));

    // a plain mouse wheel, which only goes up and down, moves the strip
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: strip.center,
        scrollDelta: const Offset(0, 90),
      ),
    );
    await tester.pump();
    expect(firstTabLeft(), shown - 90);
  });
}
