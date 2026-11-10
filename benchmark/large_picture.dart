// Measures how the editor copes with a large picture: the real window with
// the whole interface, driven one pointer move per frame.
//
//   flutter build macos --profile -t benchmark/large_picture.dart
//   "build/macos/Build/Products/Profile/Voges Click.app/Contents/MacOS/Voges Click"
//
// The BENCH environment variable takes options separated by commas: `plain`
// leaves the blend modes out and `quiet` leaves the window where the system
// put it, without taking the focus. The names of the groups of steps (`fit`,
// `actual`, `bucket`, `view`, `save`, `history`) run only those groups.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:voges_click/app.dart';
import 'package:voges_click/canvas/canvas_view.dart';
import 'package:voges_click/canvas/editor_controller.dart';
import 'package:voges_click/canvas/image_ops.dart';
import 'package:voges_click/canvas/tool_settings.dart';
import 'package:voges_click/document/document_io.dart';
import 'package:voges_click/document/image_document.dart';
import 'package:voges_click/document/layer.dart';
import 'package:voges_click/document/tile.dart';
import 'package:voges_click/document/tiled_image.dart';
import 'package:voges_click/editor/open_pictures.dart';
import 'package:voges_click/editor/status_bar.dart';
import 'package:voges_click/files/image_clipboard.dart';
import 'package:voges_click/files/image_files.dart';
import 'package:voges_click/files/system_open.dart';
import 'package:voges_click/l10n/app_language.dart';
import 'package:voges_click/painting/image_formats.dart';
import 'package:voges_click/shell/title_bar.dart';
import 'package:voges_click/shell/window_buttons.dart';
import 'package:window_manager/window_manager.dart';

const _side = 8192;
const _layerCount = 24;

const _groups = ['fit', 'actual', 'bucket', 'view', 'save', 'history'];

/// Keeps the frames coming while the window is covered, so a run never
/// stalls halfway.
class _BenchBinding extends WidgetsFlutterBinding {
  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) =>
      super.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> main() async {
  _BenchBinding();
  final options = (Platform.environment['BENCH'] ?? '').split(',');
  print('pid $pid options $options');
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Voges Click',
      size: Size(1280, 860),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    ),
    () async {
      await placeNativeWindowButtons(titleBarHeight);
      if (options.contains('quiet')) return;
      await windowManager.show();
      await windowManager.focus();
    },
  );
  final pictures = OpenPictures(settings: ToolSettings())
    ..open(
      _largePicture(blends: !options.contains('plain')),
      name: 'Large picture',
      format: SaveFormat.psd,
    );
  final files = ImageFiles();
  runApp(
    VogesClickApp(
      pictures: pictures,
      files: files,
      clipboard: ImageClipboard(),
      systemOpen: SystemOpen(files),
      language: AppLanguage(const Locale('en')),
      launchArguments: const [],
      windowButtons: await WindowButtonsLayout.forPlatform(),
    ),
  );
  final groups = options.where(_groups.contains).toSet();
  await _Bench(
    pictures.active.controller,
    groups.isEmpty ? _groups.toSet() : groups,
  ).run();
  exit(0);
}

/// A picture like a photo montage: a background, three layers a quarter of
/// its size and many smaller pieces.
DocumentState _largePicture({required bool blends}) {
  final random = math.Random(7);
  final layers = <Layer>[];
  for (var id = 1; id <= _layerCount; id++) {
    final size = switch (id) {
      1 => _side,
      <= 4 => _side ~/ 2,
      _ => 512 + random.nextInt(1536),
    };
    layers.add(
      Layer(
        id: id,
        name: id == 1 ? 'Background' : 'Layer $id',
        pixels: TiledImage.fromImage(_painted(size, random, opaque: id == 1)),
        offset: Offset(
          random.nextInt(_side - size + 1).toDouble(),
          random.nextInt(_side - size + 1).toDouble(),
        ),
        opacity: id % 5 == 0 ? 0.6 : 1,
        blend: blends && id % 8 == 0 ? LayerBlend.multiply : LayerBlend.normal,
      ),
    );
  }
  return DocumentState(_side, _side, layers);
}

ui.Image _painted(int size, math.Random random, {required bool opaque}) =>
    renderImage(size, size, (canvas) {
      final area = Offset.zero & Size.square(size.toDouble());
      if (opaque) {
        canvas.drawRect(
          area,
          Paint()
            ..shader = ui.Gradient.linear(area.topLeft, area.bottomRight, [
              const Color(0xFF2B4A6F),
              const Color(0xFFE8C28A),
            ]),
        );
      }
      for (var i = 0; i < 12; i++) {
        canvas.drawCircle(
          Offset(random.nextDouble() * size, random.nextDouble() * size),
          size * (0.05 + random.nextDouble() * 0.2),
          Paint()..color = Color(0x99000000 | random.nextInt(0xFFFFFF)),
        );
      }
    });

class _Bench {
  _Bench(this.controller, this.groups) {
    SchedulerBinding.instance.addTimingsCallback(_timings.addAll);
  }

  final EditorController controller;
  final Set<String> groups;
  final _timings = <FrameTiming>[];
  var _pumped = 0;
  var _zoomed = 0.0;

  ImageDocument get document => controller.document;
  ToolSettings get settings => controller.settings;

  static const _center = Offset(_side / 2, _side / 2);

  Future<void> run() async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final window = view.physicalSize;
    print(
      'window ${window.width.round()}x${window.height.round()} at '
      '${view.devicePixelRatio}x, ${view.display.refreshRate} Hz, '
      '${document.layers.length} layers, groups $groups',
    );
    await step('first frames', () => frame(5));
    await step('the tiles settle', () => tileSettler.done);
    final background = document.layers.first.id;
    final large = document.layers[2].id;
    final small = document.layers.last.id;
    final fit = _zoomed = _canvas.fittingZoom;

    final zooms = [
      if (groups.contains('fit')) fit,
      if (groups.contains('actual')) 1.0,
    ];
    for (final zoom in zooms) {
      final at = zoom == 1 ? '100%' : 'fit';
      // At fit the hand crosses the picture; at 100% it stays in the window.
      final span = zoom == 1 ? 600.0 : 5000.0;
      if (zoom == 1) {
        await step('zoom fit to 100% in 12 frames', () => _zoom(fit, 1, 12));
        await step('center the view', () => _scrollTo(0.5, 0.5));
      }
      await _strokes('$at brush 40 px soft, small layer', small, span, () {
        settings
          ..tool = EditTool.brush
          ..size = 40
          ..hardness = 0;
      });
      await _strokes('$at brush 400 px soft, large layer', large, span, () {
        settings
          ..tool = EditTool.brush
          ..size = 400
          ..hardness = 0;
      });
      await _strokes('$at pencil 12 px, background', background, span, () {
        settings
          ..tool = EditTool.pencil
          ..size = 12;
      });
      await _strokes('$at eraser 80 px hard, background', background, span, () {
        settings
          ..tool = EditTool.eraser
          ..size = 80
          ..hardness = 1;
      });
      await step('$at undo x4', () => _each(4, controller.undo));
      await step('$at redo x4', () => _each(4, controller.redo));

      document.activeId = large;
      await step('$at layer opacity slider, 30 frames', () async {
        for (var i = 0; i < 30; i++) {
          controller.setLayerOpacity(0.4 + i / 60);
          await frame();
        }
      });
      settings.tool = EditTool.move;
      await step('$at move the large layer, 30 frames', () async {
        controller.pointerDown(_center);
        for (var i = 1; i <= 30; i++) {
          controller.pointerMove(_center + Offset(i * span / 60, i * 2));
          await frame();
        }
      });
      await step('$at drop the moved layer', () async {
        controller.pointerUp();
        await frame(3);
      });

      document.activeId = background;
      await step('$at adjustment preview, 30 frames', () async {
        for (var i = 0; i < 30; i++) {
          controller.previewFilter = _brightness(i * 2);
          await frame();
        }
      });
      await step('$at apply the adjustment', () async {
        controller.applyFilter(_brightness(60));
        await frame(3);
      });

      document.activeId = large;
      await step('$at free transform: start', () async {
        await controller.beginTransform();
        await frame(2);
      });
      await step('$at free transform: 20 nudges', () async {
        for (var i = 0; i < 20; i++) {
          controller.nudge(3, 2);
          await frame();
        }
      });
      await step('$at free transform: apply', () async {
        controller.applyTransform();
        await frame(3);
      });
    }

    if (groups.contains('bucket')) {
      document.activeId = background;
      await step('bucket on the background', () async {
        await controller.fillAt(_center + const Offset(900, 900));
        await frame(3);
      });
      await step('undo the bucket', () => _each(1, controller.undo));
    }
    if (groups.contains('view')) await _view(fit);
    if (groups.contains('save')) await _save();
    if (groups.contains('history')) await _history(background);
    await step('idle after everything', () => frame(3));
  }

  Future<void> _view(double fit) async {
    if (_zoomed != 1) {
      await step('zoom fit to 100% in 12 frames', () => _zoom(_zoomed, 1, 12));
    }
    await step('pan at 100%, 60 frames', () async {
      for (var i = 0; i <= 60; i++) {
        await _scrollTo(0.3 + i / 150, 0.3 + i / 150);
      }
    });
    await step('zoom 100% to 800% in 12 frames', () => _zoom(1, 8, 12));
    await step('zoom 800% to fit in 24 frames', () => _zoom(8, fit, 24));
  }

  Future<void> _save() async {
    for (final format in [SaveFormat.png, SaveFormat.jpeg, SaveFormat.psd]) {
      var bytes = 0;
      await step('save as ${format.label}', () async {
        bytes = (await encodeDocument(document.state, format)).length;
      });
      print('  ${(bytes / (1 << 20)).toStringAsFixed(1)} MB written');
    }
  }

  Future<void> _history(int background) async {
    settings
      ..tool = EditTool.brush
      ..size = 40
      ..hardness = 1;
    await step('12 strokes on the background', () async {
      document.activeId = background;
      for (var i = 0; i < 12; i++) {
        await _stroke(_center + Offset(0, i * 60.0 - 360), 600, 8);
        controller.pointerUp();
        await frame(2);
      }
    });
    var steps = 0;
    while (controller.canUndo) {
      controller.undo();
      steps++;
    }
    for (var i = 0; i < steps; i++) {
      controller.redo();
    }
    print('  $steps undo steps kept');
    await step('a dot on each of 8 small layers', () async {
      for (final layer in document.layers.skip(8).take(8).toList()) {
        document.activeId = layer.id;
        controller.pointerDown(layer.bounds.center);
        controller.pointerUp();
        await frame(2);
      }
    });
  }

  /// Draws a stroke on [layerId] and commits it, as two measured steps.
  Future<void> _strokes(
    String name,
    int layerId,
    double span,
    VoidCallback pickTool,
  ) async {
    pickTool();
    document.activeId = layerId;
    await step('$name: stroke', () => _stroke(_center, span, 60));
    await step('$name: commit', () async {
      controller.pointerUp();
      await frame(3);
    });
  }

  /// A wavy line of [moves] pointer moves, one per frame, left unfinished.
  Future<void> _stroke(Offset center, double span, int moves) async {
    Offset at(int i) =>
        center +
        Offset(
          span * (i / moves - 0.5),
          span / 6 * math.sin(i / moves * math.pi * 4),
        );
    controller.pointerDown(at(0));
    await frame();
    for (var i = 1; i <= moves; i++) {
      controller.pointerMove(at(i));
      await frame();
    }
  }

  Future<void> _each(int times, VoidCallback action) async {
    for (var i = 0; i < times; i++) {
      action();
      await frame(2);
    }
  }

  Future<void> _zoom(double from, double to, int frames) async {
    for (var i = 1; i <= frames; i++) {
      final zoom = from * math.pow(to / from, i / frames);
      _widget<StatusBar>().onZoom(zoom);
      await frame();
    }
    _zoomed = to;
  }

  Future<void> _scrollTo(double down, double across) async {
    final positions = <ScrollPosition>[];
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        positions.add((element.state as ScrollableState).position);
      }
      element.visitChildren(visit);
    }

    _element<CanvasView>().visitChildren(visit);
    positions[0].jumpTo(positions[0].maxScrollExtent * down);
    positions[1].jumpTo(positions[1].maxScrollExtent * across);
    await frame();
  }

  static ColorFilter _brightness(double amount) => ColorFilter.matrix([
    1, 0, 0, 0, amount, //
    0, 1, 0, 0, amount, //
    0, 0, 1, 0, amount, //
    0, 0, 0, 1, 0, //
  ]);

  CanvasViewState get _canvas =>
      (_element<CanvasView>() as StatefulElement).state as CanvasViewState;

  T _widget<T extends Widget>() => _element<T>().widget as T;

  Element _element<T extends Widget>() {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget is T) {
        found = element;
      } else {
        element.visitChildren(visit);
      }
    }

    WidgetsBinding.instance.rootElement!.visitChildren(visit);
    return found!;
  }

  Future<void> frame([int count = 1]) async {
    for (var i = 0; i < count; i++) {
      await SchedulerBinding.instance.endOfFrame;
      _pumped++;
    }
  }

  /// Runs [run] and prints how its frames went and what it cost.
  Future<void> step(String name, Future<void> Function() run) async {
    await _drain();
    _timings.clear();
    _pumped = 0;
    var peak = ProcessInfo.currentRss;
    final sampler = Timer.periodic(const Duration(milliseconds: 50), (_) {
      peak = math.max(peak, ProcessInfo.currentRss);
    });
    final clock = Stopwatch()..start();
    await run();
    final took = clock.elapsedMicroseconds / 1000;
    await _drain();
    sampler.cancel();
    peak = math.max(peak, ProcessInfo.currentRss);

    final line = StringBuffer(name.padRight(46))
      ..write(' ${took.toStringAsFixed(0).padLeft(7)} ms');
    if (_timings.isNotEmpty) {
      final from = _timings.first.timestampInMicroseconds(
        ui.FramePhase.vsyncStart,
      );
      final to = _timings.last.timestampInMicroseconds(
        ui.FramePhase.rasterFinish,
      );
      line
        ..write(' | ${_timings.length.toString().padLeft(3)} frames')
        ..write(' ${_ms((to - from) / 1000 / _timings.length)} each')
        ..write(' | build ${_spread((t) => t.buildDuration)}')
        ..write(' | raster ${_spread((t) => t.rasterDuration)}');
    }
    line
      ..write(' | rss ${ProcessInfo.currentRss >> 20} MB, peak ${peak >> 20}')
      ..write(' | ${DateTime.now().millisecondsSinceEpoch}');
    print(line);
  }

  /// Average, 90th percentile and worst of a frame phase, in milliseconds.
  String _spread(Duration Function(FrameTiming timing) phase) {
    final times = [for (final t in _timings) phase(t).inMicroseconds / 1000]
      ..sort();
    final average = times.reduce((a, b) => a + b) / times.length;
    final high = times[((times.length - 1) * 0.9).round()];
    return '${_ms(average)} ${_ms(high)} ${_ms(times.last)}';
  }

  static String _ms(double value) => value.toStringAsFixed(1).padLeft(7);

  /// Waits for the timings of the frames asked for so far.
  Future<void> _drain() async {
    final clock = Stopwatch()..start();
    var seen = -1;
    while (clock.elapsed < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (_timings.length >= _pumped && _timings.length == seen) return;
      seen = _timings.length;
    }
  }
}
