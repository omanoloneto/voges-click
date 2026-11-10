import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voges_click/app.dart';
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

Future<EditorController> _pump(WidgetTester tester, {Locale? locale}) async {
  tester.view.physicalSize = const Size(1400, 900);
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the tool bar picks tools and drawing marks the image', (
    tester,
  ) async {
    final controller = await _pump(tester);
    expect(find.text('Untitled'), findsOneWidget);

    await tester.tap(find.byTooltip('Pencil (N)'));
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

  testWidgets('the interface follows the chosen language', (tester) async {
    await _pump(tester, locale: const Locale('pt'));
    expect(find.text('Arquivo'), findsOneWidget);
    expect(find.byTooltip('Balde de tinta (G)'), findsOneWidget);
    expect(find.text('Camadas'), findsOneWidget);
    expect(find.text('Sem título'), findsOneWidget);
  });
}
