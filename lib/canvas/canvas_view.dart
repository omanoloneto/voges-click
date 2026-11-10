import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../document/compositor.dart';
import '../document/tile.dart';
import 'editor_controller.dart';
import 'free_transform.dart';
import 'image_ops.dart';
import 'tool_settings.dart';
import 'zoom.dart';

/// The image on a desk, scrollable, with the tools working on it.
class CanvasView extends StatefulWidget {
  const CanvasView({
    required this.controller,
    required this.zoom,
    required this.onZoom,
    required this.onText,
    super.key,
  });

  static const margin = 24.0;

  final EditorController controller;
  final double zoom;
  final ValueChanged<double> onZoom;

  /// The text tool was clicked at this point of the image.
  final ValueChanged<Offset> onText;

  @override
  State<CanvasView> createState() => CanvasViewState();
}

class CanvasViewState extends State<CanvasView> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  final _surface = GlobalKey();
  final _brushAt = ValueNotifier<Offset?>(null);
  final _gripCursor = ValueNotifier<MouseCursor?>(null);
  final _outline = _OutlineCache();
  late final ui.Image _checker = renderImage(16, 16, (canvas) {
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    final gray = Paint()..color = const Color(0xFFDDDDDD);
    canvas
      ..drawRect(const Rect.fromLTWH(0, 0, 8, 8), gray)
      ..drawRect(const Rect.fromLTWH(8, 8, 8, 8), gray);
  });
  Size _viewport = Size.zero;
  int? _pointer;
  var _panning = false;
  double _pinchStart = 1;

  EditorController get controller => widget.controller;

  /// How far from a handle of the free transform a click still grabs it.
  static const _handleReach = 8.0;

  /// Top left of the visible part of the image, in image pixels.
  Offset get visibleOrigin {
    double origin(ScrollController scroll) => math.max(
      0,
      ((scroll.hasClients ? scroll.offset : 0) - CanvasView.margin) /
          widget.zoom,
    );
    return Offset(origin(_horizontal), origin(_vertical));
  }

  double get fittingZoom => fitZoom(
    _viewport,
    controller.document.width,
    controller.document.height,
    CanvasView.margin,
  );

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    _brushAt.dispose();
    _gripCursor.dispose();
    _checker.dispose();
    super.dispose();
  }

  /// A point of the window in image pixels, also outside the image.
  Offset? _toImage(Offset global) {
    final box = _surface.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global) / widget.zoom;
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || event.buttons & kPrimaryButton == 0) return;
    final point = _toImage(event.position);
    if (point == null) return;
    final keys = HardwareKeyboard.instance;
    final tool = controller.settings.tool;
    _pointer = event.pointer;
    if (tool == EditTool.hand ||
        keys.isLogicalKeyPressed(LogicalKeyboardKey.space)) {
      _panning = true;
      return;
    }
    if (controller.isTransforming) {
      controller.pointerDown(point, reach: _handleReach / widget.zoom);
      return;
    }
    switch (tool) {
      case EditTool.zoom:
        final next = nextZoom(widget.zoom, keys.isAltPressed ? -1 : 1);
        if (next != null) widget.onZoom(next);
      case EditTool.text:
        if (controller.imageRect.contains(point)) widget.onText(point);
      default:
        controller.pointerDown(
          point,
          add: keys.isShiftPressed,
          subtract: keys.isAltPressed,
        );
    }
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (_panning) {
      _scrollBy(_horizontal, -event.delta.dx);
      _scrollBy(_vertical, -event.delta.dy);
      return;
    }
    final point = _toImage(event.position);
    if (point == null) return;
    _brushAt.value = point;
    final keys = HardwareKeyboard.instance;
    controller.pointerMove(
      point,
      constrain: keys.isShiftPressed,
      fromCenter: keys.isAltPressed,
    );
  }

  void _scrollBy(ScrollController scroll, double delta) {
    if (!scroll.hasClients) return;
    final position = scroll.position;
    scroll.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_panning) {
      _panning = false;
    } else {
      controller.pointerUp();
    }
  }

  void _cancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_panning) {
      _panning = false;
    } else {
      controller.pointerCancel();
    }
  }

  void _hover(PointerHoverEvent event) {
    final point = _toImage(event.position);
    _brushAt.value = point;
    controller.hover(point);
    final box = controller.transform;
    _gripCursor.value = box == null || point == null
        ? null
        : _cursorOf(box, box.gripAt(point, _handleReach / widget.zoom));
  }

  static MouseCursor _cursorOf(FreeTransform box, TransformGrip grip) {
    final handle = grip.handle;
    if (handle == null) {
      return grip.kind == GripKind.move
          ? SystemMouseCursors.move
          : SystemMouseCursors.grab;
    }
    // the arrow follows the handle around as the box turns
    final direction = (box.pointOf(handle) - box.center).direction;
    return const [
      SystemMouseCursors.resizeLeftRight,
      SystemMouseCursors.resizeUpLeftDownRight,
      SystemMouseCursors.resizeUpDown,
      SystemMouseCursors.resizeUpRightDownLeft,
    ][(direction / (math.pi / 4)).round() % 4];
  }

  void _signal(PointerSignalEvent event) {
    final keys = HardwareKeyboard.instance;
    if (event is! PointerScrollEvent ||
        !(keys.isControlPressed || keys.isMetaPressed)) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final delta = (event as PointerScrollEvent).scrollDelta.dy;
      widget.onZoom(clampZoom(widget.zoom * math.pow(1.002, -delta)));
    });
  }

  MouseCursor get _cursor => switch (controller.settings.tool) {
    EditTool.move => SystemMouseCursors.move,
    EditTool.hand => SystemMouseCursors.grab,
    EditTool.zoom => SystemMouseCursors.zoomIn,
    EditTool.text => SystemMouseCursors.text,
    EditTool.fill || EditTool.picker => SystemMouseCursors.click,
    _ => SystemMouseCursors.precise,
  };

  @override
  Widget build(BuildContext context) {
    final desk = Theme.of(context).colorScheme.surfaceContainerHigh;
    return ColoredBox(
      color: desk,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          return Scrollbar(
            controller: _vertical,
            child: Scrollbar(
              controller: _horizontal,
              notificationPredicate: (notification) => notification.depth == 1,
              child: SingleChildScrollView(
                controller: _vertical,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      controller.settings,
                      _gripCursor,
                    ]),
                    builder: (context, child) => MouseRegion(
                      cursor: _gripCursor.value ?? _cursor,
                      onHover: _hover,
                      onExit: (_) {
                        _brushAt.value = null;
                        controller.hover(null);
                      },
                      child: child,
                    ),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      onPointerMove: _move,
                      onPointerUp: _up,
                      onPointerCancel: _cancel,
                      onPointerSignal: _signal,
                      onPointerPanZoomStart: (_) => _pinchStart = widget.zoom,
                      onPointerPanZoomUpdate: (event) {
                        if (event.scale != 1) {
                          widget.onZoom(clampZoom(_pinchStart * event.scale));
                        }
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(CanvasView.margin),
                            child: _image(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _image() {
    return ListenableBuilder(
      listenable: controller.document,
      builder: (context, _) {
        final size = Size(
          controller.document.width * widget.zoom,
          controller.document.height * widget.zoom,
        );
        return DecoratedBox(
          key: _surface,
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 8)],
          ),
          child: Stack(
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: _CanvasPainter(
                    controller,
                    widget.zoom,
                    _checker,
                    _outline,
                  ),
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _BrushPainter(controller, _brushAt, widget.zoom),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The dashed outline of the selection, kept until the selection or the
/// zoom changes: walking a long path is too slow to do on every frame.
class _OutlineCache {
  Path? _source;
  double _zoom = 0;
  Path? _solid;
  Path? _dashes;

  /// Longer outlines are drawn without dashes.
  static const _maxDashes = 6000;
  static const _dash = 4.0;

  (Path solid, Path? dashes) of(Path selection, double zoom) {
    if (!identical(selection, _source) || zoom != _zoom) {
      _source = selection;
      _zoom = zoom;
      final scale = Matrix4.diagonal3Values(zoom, zoom, 1);
      final solid = _solid = selection.transform(scale.storage);
      final metrics = solid.computeMetrics().toList();
      final length = metrics.fold(0.0, (sum, metric) => sum + metric.length);
      if (length / (_dash * 2) > _maxDashes) {
        _dashes = null;
      } else {
        final dashes = _dashes = Path();
        for (final metric in metrics) {
          for (var at = 0.0; at < metric.length; at += _dash * 2) {
            dashes.addPath(metric.extractPath(at, at + _dash), Offset.zero);
          }
        }
      }
    }
    return (_solid!, _dashes);
  }
}

class _CanvasPainter extends CustomPainter {
  // a tile that settled is another image: what was painted holds the old
  _CanvasPainter(this.controller, this.zoom, this.checker, this.outline)
    : super(repaint: Listenable.merge([controller, tileSettler]));

  final EditorController controller;
  final double zoom;
  final ui.Image checker;
  final _OutlineCache outline;

  static final _white = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFFFFFFFF);
  static final _black = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF1F1F1F);
  static final _halo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFFFFFFFF);
  static final _handleFill = Paint()..color = const Color(0xFFFFFFFF);
  static const _handleSide = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ImageShader(
          checker,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        ),
    );
    canvas
      ..save()
      ..clipRect(bounds)
      ..scale(zoom);
    paintLayers(
      canvas,
      controller.document.state,
      live: controller.live,
      // pixels stay sharp from 100% up, as in every paint program
      quality: zoom < 1 ? FilterQuality.medium : FilterQuality.none,
    );
    canvas.restore();

    // the outline would stay behind while its pixels are carried around
    if (controller.selection case final selection?
        when !controller.isTransforming) {
      final (solid, dashes) = outline.of(selection, zoom);
      canvas.drawPath(solid, _white);
      if (dashes != null) canvas.drawPath(dashes, _black);
    }
    if (controller.pendingSelection case final pending?) {
      final scaled = pending.transform(
        Matrix4.diagonal3Values(zoom, zoom, 1).storage,
      );
      canvas
        ..drawPath(scaled, _white)
        ..drawPath(scaled.shift(const Offset(1, 1)), _black);
    }
    if (controller.cropArea case final crop?) {
      final area = Rect.fromLTRB(
        crop.left * zoom,
        crop.top * zoom,
        crop.right * zoom,
        crop.bottom * zoom,
      );
      canvas
        ..drawPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(bounds)
            ..addRect(area),
          Paint()..color = const Color(0x99000000),
        )
        ..drawRect(area.deflate(0.5), _white);
    }
    if (controller.transform case final box?) {
      final outline = Path()
        ..addPolygon([for (final corner in box.corners) corner * zoom], true);
      canvas
        ..drawPath(outline, _halo)
        ..drawPath(outline, _black);
      for (final handle in TransformHandle.values) {
        final square = Rect.fromCenter(
          center: box.pointOf(handle) * zoom,
          width: _handleSide,
          height: _handleSide,
        );
        canvas
          ..drawRect(square, _handleFill)
          ..drawRect(square, _black);
      }
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter oldDelegate) =>
      oldDelegate.zoom != zoom || oldDelegate.checker != checker;
}

/// The circle that shows how big the brush is.
class _BrushPainter extends CustomPainter {
  _BrushPainter(this.controller, this.at, this.zoom)
    : super(repaint: Listenable.merge([at, controller.settings]));

  final EditorController controller;
  final ValueNotifier<Offset?> at;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final point = at.value;
    final settings = controller.settings;
    final diameter = settings.size * zoom;
    if (point == null || !settings.tool.isPen || diameter < 6) return;
    final center = point * zoom;
    canvas
      ..drawCircle(
        center,
        diameter / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xCCFFFFFF),
      )
      ..drawCircle(
        center,
        diameter / 2 + 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0x99000000),
      );
  }

  @override
  bool shouldRepaint(_BrushPainter oldDelegate) =>
      oldDelegate.zoom != zoom || oldDelegate.at != at;
}
