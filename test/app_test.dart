import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voges_click/app.dart';
import 'package:voges_click/canvas/canvas_view.dart';
import 'package:voges_click/canvas/image_ops.dart';
import 'package:voges_click/canvas/editor_controller.dart';
import 'package:voges_click/canvas/tool_settings.dart';
import 'package:voges_click/document/image_document.dart';
import 'package:voges_click/document/layer.dart';
import 'package:voges_click/editor/status_bar.dart';
import 'package:voges_click/files/image_clipboard.dart';
import 'package:voges_click/files/image_files.dart';
import 'package:voges_click/files/system_open.dart';
import 'package:voges_click/l10n/app_language.dart';

Future<EditorController> _pump(
  WidgetTester tester, {
  Locale? locale,
  Size window = const Size(1400, 900),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = EditorController(
    document: ImageDocument(
      DocumentState(200, 100, [
        Layer(
          id: 1,
          name: 'Background',
          image: blankImage(200, 100, const Color(0xFFFFFFFF)),
        ),
      ]),
    ),
    settings: ToolSettings(),
  );
  final files = ImageFiles();
  await tester.pumpWidget(
    VogesClickApp(
      controller: controller,
      files: files,
      clipboard: ImageClipboard(),
      systemOpen: SystemOpen(files),
      language: AppLanguage(locale),
      launchArguments: const [],
    ),
  );
  await tester.pumpAndSettle();
  return controller;
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the tool bar picks tools and drawing marks the image', (
    tester,
  ) async {
    final controller = await _pump(tester);
    expect(find.text('Untitled'), findsOneWidget);

    await tester.tap(find.byTooltip('Pencil (B)'));
    expect(controller.settings.tool, EditTool.pencil);

    final canvas = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.size == const Size(200, 100),
    );
    final center = tester.getCenter(canvas);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(30, 10));
    await gesture.up();
    await tester.pump();
    expect(controller.document.dirty, isTrue);
    expect(find.byTooltip('Unsaved changes'), findsOneWidget);
  });

  testWidgets('a brush click beside the picture leaves no undo step', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final canvas = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.size == const Size(200, 100),
    );
    final edge = tester.getTopLeft(canvas) + const Offset(0, 50);

    await tester.tapAt(edge - const Offset(15, 0));
    await tester.pump();
    expect(controller.canUndo, isFalse);
    expect(controller.document.dirty, isFalse);

    // close enough for the brush to reach the picture
    await tester.tapAt(edge - const Offset(3, 0));
    await tester.pump();
    expect(controller.canUndo, isTrue);
  });

  testWidgets('an adjustment keeps off the picture in the smallest window', (
    tester,
  ) async {
    await _pump(tester, window: const Size(900, 600));
    await _chord(tester, [LogicalKeyboardKey.control], LogicalKeyboardKey.keyU);
    await tester.pumpAndSettle();
    expect(find.text('Hue'), findsOneWidget);

    final dialog = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );
    expect(dialog.overlaps(tester.getRect(find.byType(CanvasView))), isFalse);
  });

  testWidgets('the status bar shows the size and the zoom', (tester) async {
    await _pump(tester);
    expect(find.text('200 × 100 px'), findsOneWidget);
    Finder zoom(String text) =>
        find.descendant(of: find.byType(StatusBar), matching: find.text(text));
    expect(zoom('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    expect(zoom('150%'), findsOneWidget);
  });

  testWidgets('the layers panel adds, hides and names layers', (tester) async {
    final controller = await _pump(tester);
    expect(find.text('Layers'), findsOneWidget);
    expect(find.text('Background'), findsOneWidget);

    await tester.tap(find.byTooltip('New layer'));
    await tester.pump();
    expect(controller.document.layers, hasLength(2));
    expect(find.text('Layer 2'), findsOneWidget);
    expect(controller.activeLayer.name, 'Layer 2');

    await tester.tap(find.byTooltip('Hide layer').first);
    await tester.pump();
    expect(controller.document.layers.last.visible, isFalse);
    expect(find.byTooltip('Show layer'), findsOneWidget);

    await tester.tap(find.text('Background'));
    await tester.pump();
    expect(controller.activeLayer.name, 'Background');
  });

  testWidgets('letters pick tools and X swaps the colors', (tester) async {
    final controller = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    expect(controller.settings.tool, EditTool.move);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    expect(controller.settings.tool, EditTool.marquee);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    expect(controller.settings.tool, EditTool.ellipseMarquee);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    expect(controller.settings.color1, const Color(0xFFFFFFFF));
  });

  testWidgets('B and Shift+B take turns between the brush and the pencil', (
    tester,
  ) async {
    final controller = await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    expect(controller.settings.tool, EditTool.brush);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    expect(controller.settings.tool, EditTool.pencil);
    await _chord(tester, [LogicalKeyboardKey.shift], LogicalKeyboardKey.keyB);
    expect(controller.settings.tool, EditTool.brush);
  });

  testWidgets('the layer keys add, copy, pick, hide and merge layers', (
    tester,
  ) async {
    final controller = await _pump(tester);
    const control = LogicalKeyboardKey.control;
    const shift = LogicalKeyboardKey.shift;
    const alt = LogicalKeyboardKey.alt;

    await _chord(tester, [control, shift], LogicalKeyboardKey.keyN);
    expect(controller.document.layers, hasLength(2));
    await _chord(tester, [control], LogicalKeyboardKey.keyJ);
    expect(controller.document.layers, hasLength(3));
    expect(controller.document.activeIndex, 2);

    await _chord(tester, [alt], LogicalKeyboardKey.bracketLeft);
    expect(controller.document.activeIndex, 1);
    await _chord(tester, [alt], LogicalKeyboardKey.bracketRight);
    expect(controller.document.activeIndex, 2);

    final top = controller.activeLayer.id;
    await _chord(tester, [control], LogicalKeyboardKey.bracketLeft);
    expect(controller.document.layers[1].id, top);
    await _chord(tester, [control, shift], LogicalKeyboardKey.bracketLeft);
    expect(controller.document.layers.first.id, top);
    await _chord(tester, [control, shift], LogicalKeyboardKey.bracketRight);
    expect(controller.document.layers.last.id, top);

    await _chord(tester, [control], LogicalKeyboardKey.comma);
    expect(controller.activeLayer.visible, isFalse);
    await _chord(tester, [control], LogicalKeyboardKey.comma);
    expect(controller.activeLayer.visible, isTrue);

    await _chord(tester, [control], LogicalKeyboardKey.keyE);
    expect(controller.document.layers, hasLength(2));
  });

  testWidgets('digits set the opacity of the tool, or of the layer', (
    tester,
  ) async {
    final controller = await _pump(tester);
    controller.settings.tool = EditTool.brush;
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    expect(controller.settings.opacity, 0.5);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    expect(controller.settings.opacity, 1);

    controller.settings.tool = EditTool.move;
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad3);
    expect(controller.activeLayer.opacity, closeTo(0.3, 1e-9));
    expect(controller.settings.opacity, 1);
  });

  testWidgets('the zoom keys fit the picture and show it at 100%', (
    tester,
  ) async {
    await _pump(tester);
    const control = LogicalKeyboardKey.control;
    Finder zoom(String text) =>
        find.descendant(of: find.byType(StatusBar), matching: find.text(text));
    await _chord(tester, [control], LogicalKeyboardKey.digit0);
    await tester.pump();
    expect(zoom('100%'), findsNothing);
    await _chord(tester, [control], LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(zoom('100%'), findsOneWidget);
    await _chord(tester, [control], LogicalKeyboardKey.numpadAdd);
    await tester.pump();
    expect(zoom('150%'), findsOneWidget);
  });

  testWidgets('the selection keys invert it and fill it', (tester) async {
    final controller = await _pump(tester);
    const control = LogicalKeyboardKey.control;
    await _chord(tester, [control], LogicalKeyboardKey.keyA);
    expect(controller.hasSelection, isTrue);
    await _chord(tester, [
      control,
      LogicalKeyboardKey.shift,
    ], LogicalKeyboardKey.keyI);
    // the opposite of everything is nothing
    expect(controller.hasSelection, isFalse);
    await _chord(tester, [control], LogicalKeyboardKey.keyA);
    await _chord(tester, [control], LogicalKeyboardKey.keyD);
    expect(controller.hasSelection, isFalse);

    expect(controller.canUndo, isFalse);
    await _chord(tester, [
      LogicalKeyboardKey.alt,
    ], LogicalKeyboardKey.backspace);
    expect(controller.canUndo, isTrue);
    await _chord(tester, [
      control,
      LogicalKeyboardKey.alt,
    ], LogicalKeyboardKey.keyZ);
    expect(controller.canUndo, isFalse);
    await _chord(tester, [control], LogicalKeyboardKey.backspace);
    expect(controller.canUndo, isTrue);
  });

  testWidgets('Ctrl+T opens the free transform, Enter and Esc close it', (
    tester,
  ) async {
    final controller = await _pump(tester);
    const control = LogicalKeyboardKey.control;
    await tester.runAsync(() async {
      await _chord(tester, [control], LogicalKeyboardKey.keyT);
      for (var tries = 0; !controller.isTransforming && tries < 200; tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(controller.isTransforming, isTrue);
    expect(find.text('Free transform'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.isTransforming, isFalse);
    expect(controller.canUndo, isTrue);
    expect(controller.activeLayer.offset, const Offset(1, 0));

    await tester.runAsync(() async {
      await _chord(tester, [control], LogicalKeyboardKey.keyT);
      for (var tries = 0; !controller.isTransforming && tries < 200; tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.isTransforming, isFalse);
  });

  testWidgets('the interface follows the chosen language', (tester) async {
    await _pump(tester, locale: const Locale('pt'));
    expect(find.text('Arquivo'), findsOneWidget);
    expect(find.byTooltip('Balde de tinta (G)'), findsOneWidget);
    expect(find.text('Camadas'), findsOneWidget);
    expect(find.text('Sem título'), findsOneWidget);
  });
}
