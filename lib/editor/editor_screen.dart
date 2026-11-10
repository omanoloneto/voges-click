// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voges_updater/voges_updater.dart'
    show LaunchResult, UpdateCheck, UpdateStatusChip, UpdaterLocalizations;
import 'package:window_manager/window_manager.dart';

import '../canvas/canvas_view.dart';
import '../canvas/editor_controller.dart';
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
import 'open_pictures.dart';
import 'options_bar.dart';
import 'panel_controls.dart';
import 'picture_tabs.dart';
import 'shortcuts.dart';
import 'status_bar.dart';
import 'tool_bar.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.pictures,
    required this.files,
    required this.clipboard,
    required this.systemOpen,
    required this.language,
    required this.launchArguments,
    this.windowButtons = WindowButtonsLayout.right,
    this.updates,
    super.key,
  });

  final OpenPictures pictures;
  final ImageFiles files;
  final ImageClipboard clipboard;
  final SystemOpen systemOpen;
  final AppLanguage language;
  final List<String> launchArguments;
  final WindowButtonsLayout windowButtons;

  /// Null off the desktop.
  final UpdateCheck? updates;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WindowListener {
  final _focus = FocusNode(debugLabel: 'canvas');
  late final AppLifecycleListener _lifecycle;
  late OpenPicture _titled;
  var _opening = Future<void>.value();
  var _closing = false;
  var _maximized = false;
  var _fullScreen = false;
  String? _title;

  OpenPictures get pictures => widget.pictures;

  /// The picture in front.
  OpenPicture get _picture => pictures.active;

  /// Of the picture in front. What waits for a dialog keeps the one it
  /// started with: a file opened meanwhile changes the picture in front.
  EditorController get controller => _picture.controller;

  @override
  void initState() {
    super.initState();
    pictures.addListener(_onPictures);
    _titled = _picture;
    _titled.document.addListener(_updateTitle);
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    if (isDesktopPlatform) windowManager.addListener(this);
    widget.systemOpen.listen((file) => _inTurn(() => _load(file)));
    _fitAfterLoad(_picture);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _updateTitle();
      if (widget.updates case final updates?) {
        updates.check().ignore();
        updates.cleanUp().ignore();
      }
      final pending = await widget.systemOpen.pending(widget.launchArguments);
      for (final file in pending) {
        _inTurn(() => _load(file));
      }
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
    pictures.layerName = l10n.layerNamed;
    _updateTitle();
  }

  @override
  void dispose() {
    pictures.removeListener(_onPictures);
    _titled.document.removeListener(_updateTitle);
    _lifecycle.dispose();
    if (isDesktopPlatform) windowManager.removeListener(this);
    _focus.dispose();
    super.dispose();
  }

  /// The title follows the picture in front.
  void _onPictures() {
    if (!identical(_picture, _titled)) {
      _titled.document.removeListener(_updateTitle);
      _titled = _picture;
      _titled.document.addListener(_updateTitle);
    }
    _updateTitle();
    setState(() {});
  }

  bool _isOpen(OpenPicture picture) =>
      mounted && pictures.pictures.contains(picture);

  String _nameOf(OpenPicture picture) =>
      picture.document.name ?? context.l10n.untitled;

  String get _name => _nameOf(_picture);

  void _updateTitle() {
    if (!mounted) return;
    final dirty = _picture.document.dirty;
    final title = '${dirty ? '• ' : ''}$_name — Voges Click';
    if (title == _title) return;
    _title = title;
    if (isDesktopPlatform) windowManager.setTitle(title).ignore();
  }

  /// Files open one after the other, in the order they were asked for.
  Future<void> _inTurn(Future<void> Function() open) =>
      _opening = _opening.whenComplete(() => mounted ? open() : null);

  Future<ui.AppExitResponse> _onExitRequested() async {
    if (_closing || await _confirmDiscardAll()) return ui.AppExitResponse.exit;
    return ui.AppExitResponse.cancel;
  }

  @override
  Future<void> onWindowClose() async {
    if (_closing || await _confirmDiscardAll()) {
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

  /// The app closes for the updater to replace it, so unsaved work is
  /// handled first, exactly as when closing the window.
  Future<void> _startUpdate() async {
    final updates = widget.updates;
    if (updates == null || !await _confirmDiscardAll()) return;
    final states = {
      for (final picture in pictures.pictures) picture: picture.document.state,
    };
    if (await updates.startUpdater() == LaunchResult.started) {
      // Windows copies the app for the updater first, and the pictures may
      // change meanwhile; if the user keeps one open, the updater waits
      if (!mounted) return;
      for (final picture in pictures.pictures.toList()) {
        if (!_isOpen(picture)) continue;
        if (identical(picture.document.state, states[picture])) continue;
        if (!await _confirmDiscard(picture)) return;
      }
      if (!mounted) return;
      _closing = true;
      await windowManager.destroy();
      return;
    }
    if (!mounted) return;
    final l10n = UpdaterLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.updateLaunchFailed),
        action: SnackBarAction(
          label: l10n.updateDownloadPage,
          onPressed: () => updates.openDownloadPage().ignore(),
        ),
      ),
    );
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Whether [picture] may go away: saved, or the user gave it up.
  Future<bool> _confirmDiscard(OpenPicture picture) async {
    // a free transform still open is part of what is asked about and saved
    picture.settle();
    if (!picture.document.dirty) return true;
    pictures.activate(picture);
    switch (await askToSave(context, _nameOf(picture))) {
      case UnsavedChoice.save:
        return _save(picture);
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.cancel:
        return false;
    }
  }

  /// Asks about every picture with unsaved changes, showing each one first.
  Future<bool> _confirmDiscardAll() async {
    for (final picture in pictures.pictures.toList()) {
      if (!_isOpen(picture)) continue;
      if (!await _confirmDiscard(picture)) return false;
    }
    return true;
  }

  Future<void> _newImage() async {
    final document = controller.document;
    final size = await askNewImageSize(
      context,
      Size(document.width.toDouble(), document.height.toDouble()),
    );
    if (size == null || !mounted) return;
    _fitAfterLoad(pictures.addBlank(size.width, size.height));
  }

  Future<void> _open() async {
    final List<String> paths;
    try {
      paths = await widget.files.pick();
    } catch (_) {
      if (mounted) _tell(context.l10n.openFailed);
      return;
    }
    for (final path in paths) {
      _inTurn(() => _openFile(path));
    }
  }

  Future<void> _openFile(String path) async {
    final l10n = context.l10n;
    if (pictures.showFile(path)) return;
    final OpenedFile file;
    try {
      file = await widget.files.read(path);
    } catch (_) {
      return _tell(l10n.openFailed);
    }
    if (mounted) await _load(file);
  }

  Future<void> _close(OpenPicture picture) async {
    if (!await _confirmDiscard(picture) || !_isOpen(picture)) return;
    final last = pictures.pictures.length == 1;
    pictures.close(picture);
    // the fresh picture that takes its place opens as the first one did
    if (last) _fitAfterLoad(_picture);
  }

  Future<void> _load(OpenedFile file) async {
    final l10n = context.l10n;
    final path = file.path;
    if (path != null && pictures.showFile(path)) return;
    final LoadedDocument loaded;
    try {
      loaded = await loadDocument(file.bytes, layerName: l10n.backgroundLayer);
    } on ImageTooLarge {
      return _tell(l10n.imageTooLarge(maxImageSide));
    } catch (_) {
      return _tell(l10n.openFailed);
    }
    if (!mounted) return;
    final OpenPicture picture;
    if (loaded.loss == LoadLoss.none) {
      final format = SaveFormat.of(file.name);
      picture = pictures.open(
        loaded.state,
        name: file.name,
        // a GIF or WebP is saved as a new file, never over the original
        path: format == null ? null : path,
        format: format ?? SaveFormat.png,
        source: path,
      );
    } else {
      // saving over a PSD that did not come whole would destroy the rest
      picture = pictures.open(
        loaded.state,
        name: file.name,
        format: SaveFormat.psd,
        source: path,
      );
      _tell(
        loaded.loss == LoadLoss.simplified
            ? l10n.psdSimplified
            : l10n.psdOpenedFlat,
      );
    }
    _fitAfterLoad(picture);
  }

  CanvasViewState? _canvasOf(OpenPicture picture) =>
      _CanvasKey(picture).currentState;

  /// Big images open whole; small ones at 100%.
  void _fitAfterLoad(OpenPicture picture) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isOpen(picture)) return;
      final fitting = _canvasOf(picture)?.fittingZoom ?? 1;
      _setZoom(picture, math.min(1.0, fitting));
    });
  }

  Future<bool> _save(OpenPicture picture) {
    final document = picture.document;
    final path = document.path;
    if (path == null) return _saveAs(picture, document.format);
    // a flat file cannot hold the layers added since it was opened
    if (!document.format.keepsLayers && document.state.isLayered) {
      return _saveAs(picture, SaveFormat.psd);
    }
    return _write(picture, path, document.format);
  }

  Future<bool> _saveAs(OpenPicture picture, SaveFormat format) async {
    final name = _nameOf(picture);
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
    return _write(picture, path, format);
  }

  Future<bool> _write(
    OpenPicture picture,
    String path,
    SaveFormat format,
  ) async {
    final l10n = context.l10n;
    final document = picture.document;
    final state = document.state;
    try {
      await widget.files.write(path, await encodeDocument(state, format));
    } catch (_) {
      _tell(l10n.saveFailed);
      return false;
    }
    // closed while the file was being written
    if (!_isOpen(picture)) return true;
    if (format.keepsLayers || !state.isLayered) {
      document.markSaved(
        name: path.split(RegExp(r'[/\\]')).last,
        path: path,
        format: format,
      );
      picture.source = path;
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
    final picture = _picture;
    if (!picture.controller.hasSelection) return;
    await _copy();
    if (_isOpen(picture)) picture.controller.deleteSelection();
  }

  /// Pastes into the picture that was in front when it was asked for.
  Future<void> _paste() async {
    final l10n = context.l10n;
    final picture = _picture;
    final bytes = await widget.clipboard.read().catchError((_) => null);
    if (bytes == null) return _tell(l10n.nothingToPaste);
    if (!_isOpen(picture)) return;
    try {
      final fits = await picture.controller.paste(
        bytes,
        origin: _canvasOf(picture)?.visibleOrigin ?? Offset.zero,
      );
      if (!fits) _tell(l10n.imageTooLarge(maxImageSide));
    } catch (_) {
      _tell(l10n.nothingToPaste);
    }
  }

  Future<void> _addText(Offset at) async {
    final controller = this.controller;
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
    final controller = this.controller;
    final name = await askLayerName(context, layer.name);
    if (name != null) controller.renameLayer(layer.id, name);
  }

  Future<void> _adjust(Adjustment adjustment) async {
    final controller = this.controller;
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
    final controller = this.controller;
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

  void _setZoom(OpenPicture picture, double zoom) =>
      setState(() => picture.zoom = clampZoom(zoom));

  void _stepZoom(int direction) {
    final picture = _picture;
    if (nextZoom(picture.zoom, direction) case final zoom?) {
      _setZoom(picture, zoom);
    }
  }

  void _fit() {
    final picture = _picture;
    if (_canvasOf(picture) case final canvas?) {
      _setZoom(picture, canvas.fittingZoom);
    }
  }

  void _showFilePanel() => showFilePanel(
    context,
    name: _name,
    language: widget.language,
    actions: FilePanelActions(
      newImage: _newImage,
      open: _open,
      save: () => _save(_picture),
      saveAs: (format) => _saveAs(_picture, format),
      close: () => _close(_picture),
    ),
  );

  Map<ShortcutActivator, VoidCallback> get _shortcuts => editorShortcuts(
    controller,
    ShortcutActions(
      newImage: _newImage,
      open: _open,
      save: () => _save(_picture),
      saveAs: () => _saveAs(_picture, _picture.document.format),
      close: () => _close(_picture),
      nextPicture: pictures.next,
      previousPicture: pictures.previous,
      copy: _copy,
      cut: _cut,
      paste: _paste,
      stepZoom: _stepZoom,
      actualSize: () => _setZoom(_picture, 1),
      fit: _fit,
      resize: _resize,
      adjust: _adjust,
    ),
  );

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
                        child: Column(
                          children: [
                            PictureTabs(pictures: pictures, onClose: _close),
                            Expanded(
                              child: Listener(
                                onPointerDown: (_) => _focus.requestFocus(),
                                // the pictures behind keep their scroll
                                child: IndexedStack(
                                  index: pictures.activeIndex,
                                  sizing: StackFit.expand,
                                  children: [
                                    for (final picture in pictures.pictures)
                                      CanvasView(
                                        key: _CanvasKey(picture),
                                        controller: picture.controller,
                                        zoom: picture.zoom,
                                        onZoom: (zoom) =>
                                            _setZoom(picture, zoom),
                                        onText: _addText,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: sidePanelWidth,
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
                  zoom: _picture.zoom,
                  onZoom: (zoom) => _setZoom(_picture, zoom),
                  onFit: _fit,
                  trailing: switch (widget.updates) {
                    final updates? => UpdateStatusChip(
                      check: updates,
                      onUpdate: _startUpdate,
                    ),
                    null => null,
                  },
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

/// Finds the canvas of a picture, wherever it is among the open ones.
class _CanvasKey extends GlobalObjectKey<CanvasViewState> {
  const _CanvasKey(OpenPicture super.picture);
}
