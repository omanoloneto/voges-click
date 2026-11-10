// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../canvas/canvas_view.dart';
import '../canvas/editor_controller.dart';
import '../canvas/tool_settings.dart';
import '../canvas/zoom.dart';
import '../document/document_io.dart';
import '../document/layer.dart';
import '../files/image_clipboard.dart';
import '../files/image_files.dart';
import '../files/system_open.dart';
import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../painting/image_formats.dart';
import '../painting/rgba_image.dart';
import '../shell/platform.dart';
import '../shell/ribbon_style.dart';
import '../shell/title_bar.dart';
import '../shell/window_buttons.dart';
import 'color_dialog.dart';
import 'color_panel.dart';
import 'dialogs.dart';
import 'file_panel.dart';
import 'layers_panel.dart';
import 'options_bar.dart';
import 'panel_controls.dart';
import 'status_bar.dart';
import 'tool_bar.dart';
import 'tool_catalog.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.controller,
    required this.files,
    required this.clipboard,
    required this.systemOpen,
    required this.language,
    required this.launchArguments,
    this.windowButtons = WindowButtonsLayout.right,
    super.key,
  });

  final EditorController controller;
  final ImageFiles files;
  final ImageClipboard clipboard;
  final SystemOpen systemOpen;
  final AppLanguage language;
  final List<String> launchArguments;
  final WindowButtonsLayout windowButtons;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WindowListener {
  final _focus = FocusNode(debugLabel: 'canvas');
  final _canvas = GlobalKey<CanvasViewState>();
  late final AppLifecycleListener _lifecycle;
  var _zoom = 1.0;
  var _closing = false;
  var _maximized = false;
  var _fullScreen = false;
  String? _title;

  EditorController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.document.addListener(_updateTitle);
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    if (isDesktopPlatform) windowManager.addListener(this);
    widget.systemOpen.listen(_openFromSystem);
    _fitAfterLoad();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _updateTitle();
      final pending = await widget.systemOpen.pending(widget.launchArguments);
      if (pending.isNotEmpty) _load(pending.first);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    widget.files.titles = FileDialogTitles(
      open: l10n.openImageTitle,
      save: l10n.saveImageTitle,
    );
    controller.layerName = (number) =>
        number == 1 ? l10n.backgroundLayer : l10n.layerNumber(number);
    _updateTitle();
  }

  @override
  void dispose() {
    controller.document.removeListener(_updateTitle);
    _lifecycle.dispose();
    if (isDesktopPlatform) windowManager.removeListener(this);
    _focus.dispose();
    super.dispose();
  }

  String get _name => controller.document.name ?? context.l10n.untitled;

  void _updateTitle() {
    if (!mounted) return;
    final dirty = controller.document.dirty;
    final title = '${dirty ? '• ' : ''}$_name — Voges Click';
    if (title == _title) return;
    _title = title;
    if (isDesktopPlatform) windowManager.setTitle(title).ignore();
  }

  Future<ui.AppExitResponse> _onExitRequested() async {
    if (_closing || await _confirmDiscard()) return ui.AppExitResponse.exit;
    return ui.AppExitResponse.cancel;
  }

  @override
  Future<void> onWindowClose() async {
    if (_closing || await _confirmDiscard()) {
      _closing = true;
      await windowManager.destroy();
    }
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowEnterFullScreen() => setState(() => _fullScreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _fullScreen = false);

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscard() async {
    if (!controller.document.dirty) return true;
    switch (await askToSave(context, _name)) {
      case UnsavedChoice.save:
        return _save();
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.cancel:
        return false;
    }
  }

  Future<void> _newImage() async {
    if (!await _confirmDiscard() || !mounted) return;
    final document = controller.document;
    final size = await askNewImageSize(
      context,
      Size(document.width.toDouble(), document.height.toDouble()),
    );
    if (size == null) return;
    controller.newImage(
      size.width,
      size.height,
      background: const Color(0xFFFFFFFF),
    );
    _fitAfterLoad();
  }

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    final OpenedFile? file;
    try {
      file = await widget.files.pick();
    } catch (_) {
      if (mounted) _tell(context.l10n.openFailed);
      return;
    }
    if (file != null) await _load(file);
  }

  Future<void> _openFromSystem(OpenedFile file) async {
    if (await _confirmDiscard()) await _load(file);
  }

  Future<void> _load(OpenedFile file) async {
    final l10n = context.l10n;
    final LoadedDocument loaded;
    try {
      loaded = await loadDocument(file.bytes, layerName: l10n.backgroundLayer);
    } on ImageTooLarge {
      return _tell(l10n.imageTooLarge(maxImageSide));
    } catch (_) {
      return _tell(l10n.openFailed);
    }
    if (!mounted) return;
    if (loaded.loss == LoadLoss.none) {
      final format = SaveFormat.of(file.name);
      controller.load(
        loaded.state,
        name: file.name,
        // a GIF or WebP is saved as a new file, never over the original
        path: format == null ? null : file.path,
        format: format ?? SaveFormat.png,
      );
    } else {
      // saving over a PSD that did not come whole would destroy the rest
      controller.load(loaded.state, name: file.name, format: SaveFormat.psd);
      _tell(
        loaded.loss == LoadLoss.simplified
            ? l10n.psdSimplified
            : l10n.psdOpenedFlat,
      );
    }
    _fitAfterLoad();
  }

  /// Big images open whole; small ones at 100%.
  void _fitAfterLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fitting = _canvas.currentState?.fittingZoom ?? 1;
      _setZoom(math.min(1.0, fitting));
    });
  }

  Future<bool> _save() {
    final document = controller.document;
    final path = document.path;
    if (path == null) return _saveAs(document.format);
    // a flat file cannot hold the layers added since it was opened
    if (!document.format.keepsLayers && document.state.isLayered) {
      return _saveAs(SaveFormat.psd);
    }
    return _write(path, document.format);
  }

  Future<bool> _saveAs(SaveFormat format) async {
    final name = _name;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final String? path;
    try {
      path = await widget.files.chooseSaveLocation(
        '$base.${format.extension}',
        format,
      );
    } catch (_) {
      if (mounted) _tell(context.l10n.saveFailed);
      return false;
    }
    if (path == null) return false;
    return _write(path, format);
  }

  Future<bool> _write(String path, SaveFormat format) async {
    final l10n = context.l10n;
    final document = controller.document;
    final state = document.state;
    try {
      await widget.files.write(path, await encodeDocument(state, format));
    } catch (_) {
      _tell(l10n.saveFailed);
      return false;
    }
    if (format.keepsLayers || !state.isLayered) {
      document.markSaved(
        name: path.split(RegExp(r'[/\\]')).last,
        path: path,
        format: format,
      );
    } else {
      // the layers live only here: the document stays unsaved
      _tell(l10n.exportedCopy(format.label));
    }
    return true;
  }

  Future<void> _copy() async {
    final l10n = context.l10n;
    try {
      final png = await controller.copyPng();
      if (png != null) await widget.clipboard.write(png);
    } catch (_) {
      _tell(l10n.copyFailed);
    }
  }

  Future<void> _cut() async {
    if (!controller.hasSelection) return;
    await _copy();
    controller.deleteSelection();
  }

  Future<void> _paste() async {
    final l10n = context.l10n;
    final bytes = await widget.clipboard.read().catchError((_) => null);
    if (bytes == null) return _tell(l10n.nothingToPaste);
    try {
      final fits = await controller.paste(
        bytes,
        origin: _canvas.currentState?.visibleOrigin ?? Offset.zero,
      );
      if (!fits) _tell(l10n.imageTooLarge(maxImageSide));
    } catch (_) {
      _tell(l10n.nothingToPaste);
    }
  }

  Future<void> _addText(Offset at) async {
    final request = await askText(context);
    if (request == null) return;
    controller.addText(
      request.text,
      at,
      fontSize: request.fontSize,
      bold: request.bold,
    );
  }

  Future<void> _renameLayer(Layer layer) async {
    final name = await askLayerName(context, layer.name);
    if (name != null) controller.renameLayer(layer.id, name);
  }

  Future<void> _adjust(Adjustment adjustment) async {
    final matrix = await askAdjustment(
      context,
      adjustment,
      onPreview: (matrix) =>
          controller.previewFilter = ColorFilter.matrix(matrix),
    );
    if (matrix == null) {
      controller.previewFilter = null;
    } else {
      controller.applyFilter(ColorFilter.matrix(matrix));
    }
  }

  Future<void> _resize() async {
    final document = controller.document;
    final size = await askResize(
      context,
      Size(document.width.toDouble(), document.height.toDouble()),
    );
    if (size != null) {
      controller.resize(size.width, size.height, stretch: size.stretch);
    }
  }

  Future<void> _editColor(bool second) async {
    final settings = controller.settings;
    final color = await askColor(
      context,
      second ? settings.color2 : settings.color1,
    );
    if (color == null) return;
    if (second) {
      settings.color2 = color;
    } else {
      settings.color1 = color;
    }
  }

  void _setZoom(double zoom) => setState(() => _zoom = clampZoom(zoom));

  void _stepZoom(int direction) {
    if (nextZoom(_zoom, direction) case final zoom?) _setZoom(zoom);
  }

  void _fit() {
    if (_canvas.currentState case final canvas?) _setZoom(canvas.fittingZoom);
  }

  void _showFilePanel() => showFilePanel(
    context,
    name: _name,
    language: widget.language,
    actions: FilePanelActions(
      newImage: _newImage,
      open: _open,
      save: _save,
      saveAs: _saveAs,
    ),
  );

  void _pickTool(String key) {
    final settings = controller.settings;
    if (toolForKey(key, settings.tool) case final tool?) settings.tool = tool;
  }

  void _nudge(int dx, int dy) {
    if (controller.settings.tool == EditTool.move) controller.nudge(dx, dy);
  }

  void _growBrush(int direction) {
    final settings = controller.settings;
    final step = math.max(1.0, (settings.size * 0.15).roundToDouble());
    settings.size += direction * step;
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    final settings = controller.settings;
    return {
      shortcut(LogicalKeyboardKey.keyN): _newImage,
      shortcut(LogicalKeyboardKey.keyO): _open,
      shortcut(LogicalKeyboardKey.keyS): _save,
      shortcut(LogicalKeyboardKey.keyS, shift: true): () =>
          _saveAs(controller.document.format),
      shortcut(LogicalKeyboardKey.keyZ): controller.undo,
      shortcut(LogicalKeyboardKey.keyZ, shift: true): controller.redo,
      shortcut(LogicalKeyboardKey.keyY): controller.redo,
      shortcut(LogicalKeyboardKey.keyC): _copy,
      shortcut(LogicalKeyboardKey.keyX): _cut,
      shortcut(LogicalKeyboardKey.keyV): _paste,
      shortcut(LogicalKeyboardKey.keyA): controller.selectAll,
      shortcut(LogicalKeyboardKey.keyD): controller.deselect,
      shortcut(LogicalKeyboardKey.equal): () => _stepZoom(1),
      shortcut(LogicalKeyboardKey.minus): () => _stepZoom(-1),
      shortcut(LogicalKeyboardKey.digit0): () => _setZoom(1),
      const SingleActivator(LogicalKeyboardKey.delete):
          controller.deleteSelection,
      const SingleActivator(LogicalKeyboardKey.backspace):
          controller.deleteSelection,
      const SingleActivator(LogicalKeyboardKey.enter): controller.applyCrop,
      const SingleActivator(LogicalKeyboardKey.escape): controller.deselect,
      for (final key in toolKeys.values.toSet())
        SingleActivator(_letters[key]!): () => _pickTool(key),
      const SingleActivator(LogicalKeyboardKey.keyX): settings.swapColors,
      const SingleActivator(LogicalKeyboardKey.keyD): settings.resetColors,
      const CharacterActivator('['): () => _growBrush(-1),
      const CharacterActivator(']'): () => _growBrush(1),
      for (final (key, dx, dy) in _arrows) ...{
        SingleActivator(key): () => _nudge(dx, dy),
        SingleActivator(key, shift: true): () => _nudge(dx * 10, dy * 10),
      },
    };
  }

  static final _letters = {
    for (final key in LogicalKeyboardKey.knownLogicalKeys)
      if (key.keyLabel.length == 1) key.keyLabel: key,
  };

  static const _arrows = [
    (LogicalKeyboardKey.arrowLeft, -1, 0),
    (LogicalKeyboardKey.arrowRight, 1, 0),
    (LogicalKeyboardKey.arrowUp, 0, -1),
    (LogicalKeyboardKey.arrowDown, 0, 1),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: _resizable(
          Scaffold(
            body: Column(
              children: [
                ColoredBox(
                  color: RibbonColors.background,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) => AppTitleBar(
                            name: _name,
                            dirty: controller.document.dirty,
                            onFile: _showFilePanel,
                            isMaximized: _maximized,
                            isFullScreen: _fullScreen,
                            windowButtons: widget.windowButtons,
                            actions: QuickActions(
                              undo: controller.canUndo ? controller.undo : null,
                              redo: controller.canRedo ? controller.redo : null,
                              copy: _copy,
                              cut: controller.hasSelection ? _cut : null,
                              paste: _paste,
                            ),
                          ),
                        ),
                        OptionsBar(
                          controller: controller,
                          actions: OptionsBarActions(
                            resize: _resize,
                            renameLayer: () =>
                                _renameLayer(controller.activeLayer),
                            adjust: _adjust,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ToolBar(
                        settings: controller.settings,
                        onEditColor: _editColor,
                      ),
                      Expanded(
                        child: Listener(
                          onPointerDown: (_) => _focus.requestFocus(),
                          child: CanvasView(
                            key: _canvas,
                            controller: controller,
                            zoom: _zoom,
                            onZoom: _setZoom,
                            onText: _addText,
                          ),
                        ),
                      ),
                      Container(
                        width: 280,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          border: Border(
                            left: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        child: Column(
                          children: [
                            PanelHeader(l10n.colorPanel),
                            ColorPanel(settings: controller.settings),
                            PanelHeader(l10n.layersPanel),
                            Expanded(
                              child: LayersPanel(
                                controller: controller,
                                onRename: _renameLayer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBar(
                  controller: controller,
                  zoom: _zoom,
                  onZoom: _setZoom,
                  onFit: _fit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Without the system title bar the window needs resize edges: on Windows
  /// only the top one is missing; on Linux, with no frame, all of them are.
  Widget _resizable(Widget child) {
    if (!isDesktopPlatform || defaultTargetPlatform == TargetPlatform.macOS) {
      return child;
    }
    return DragToResizeArea(
      enableResizeEdges: _maximized || _fullScreen
          ? const []
          : defaultTargetPlatform == TargetPlatform.windows
          ? const [ResizeEdge.topLeft, ResizeEdge.top, ResizeEdge.topRight]
          : null,
      child: child,
    );
  }
}
