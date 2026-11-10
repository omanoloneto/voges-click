import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../canvas/editor_controller.dart';
import '../canvas/tool_settings.dart';
import '../painting/color_matrix.dart';
import '../shell/platform.dart';
import 'dialogs.dart';
import 'tool_catalog.dart';

/// What the keyboard reaches that lives in the screen, not in the editor.
class ShortcutActions {
  const ShortcutActions({
    required this.newImage,
    required this.open,
    required this.save,
    required this.saveAs,
    required this.close,
    required this.nextPicture,
    required this.previousPicture,
    required this.copy,
    required this.cut,
    required this.paste,
    required this.stepZoom,
    required this.actualSize,
    required this.fit,
    required this.resize,
    required this.adjust,
  });

  final VoidCallback newImage;
  final VoidCallback open;
  final VoidCallback save;
  final VoidCallback saveAs;
  final VoidCallback close;
  final VoidCallback nextPicture;
  final VoidCallback previousPicture;
  final VoidCallback copy;
  final VoidCallback cut;
  final VoidCallback paste;
  final ValueChanged<int> stepZoom;
  final VoidCallback actualSize;
  final VoidCallback fit;
  final VoidCallback resize;
  final ValueChanged<Adjustment> adjust;
}

const hardnessStep = 0.25;

/// The keyboard of the editor, with the keys Photoshop uses for the same
/// things.
Map<ShortcutActivator, VoidCallback> editorShortcuts(
  EditorController controller,
  ShortcutActions actions,
) {
  final settings = controller.settings;

  void pickTool(String key) {
    if (toolForKey(key, settings.tool) case final tool?) settings.tool = tool;
  }

  void nudge(int dx, int dy) {
    if (settings.tool == EditTool.move || controller.isTransforming) {
      controller.nudge(dx, dy);
    }
  }

  void growBrush(int direction) {
    final step = math.max(1.0, (settings.size * 0.15).roundToDouble());
    settings.size += direction * step;
  }

  // the tool's opacity when the tool has one, the layer's otherwise
  void setOpacity(double opacity) {
    if (settings.tool.usesOpacity) {
      settings.opacity = opacity;
    } else {
      controller.setLayerOpacity(opacity);
    }
  }

  return {
    // File
    shortcut(LogicalKeyboardKey.keyN): actions.newImage,
    shortcut(LogicalKeyboardKey.keyO): actions.open,
    shortcut(LogicalKeyboardKey.keyS): actions.save,
    shortcut(LogicalKeyboardKey.keyS, shift: true): actions.saveAs,
    shortcut(LogicalKeyboardKey.keyW): actions.close,
    // Ctrl on every system, as in Photoshop
    const SingleActivator(LogicalKeyboardKey.tab, control: true):
        actions.nextPicture,
    const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
        actions.previousPicture,

    // Edit
    shortcut(LogicalKeyboardKey.keyZ): controller.undo,
    shortcut(LogicalKeyboardKey.keyZ, alt: true): controller.undo,
    shortcut(LogicalKeyboardKey.keyZ, shift: true): controller.redo,
    shortcut(LogicalKeyboardKey.keyY): controller.redo,
    shortcut(LogicalKeyboardKey.keyC): actions.copy,
    shortcut(LogicalKeyboardKey.keyX): actions.cut,
    shortcut(LogicalKeyboardKey.keyV): actions.paste,
    shortcut(LogicalKeyboardKey.keyT): controller.beginTransform,
    for (final key in _erasers) ...{
      SingleActivator(key): controller.deleteSelection,
      SingleActivator(key, alt: true): controller.fillSelection,
      shortcut(key): () => controller.fillSelection(background: true),
    },
    const SingleActivator(LogicalKeyboardKey.f5, shift: true):
        controller.fillSelection,

    // Select
    shortcut(LogicalKeyboardKey.keyA): controller.selectAll,
    shortcut(LogicalKeyboardKey.keyD): controller.deselect,
    shortcut(LogicalKeyboardKey.keyI, shift: true): controller.invertSelection,
    const SingleActivator(LogicalKeyboardKey.enter): controller.confirm,
    const SingleActivator(LogicalKeyboardKey.numpadEnter): controller.confirm,
    const SingleActivator(LogicalKeyboardKey.escape): controller.cancel,

    // Image
    shortcut(LogicalKeyboardKey.keyI, alt: true): actions.resize,
    shortcut(LogicalKeyboardKey.keyU): () =>
        actions.adjust(Adjustment.hueSaturation),
    shortcut(LogicalKeyboardKey.keyI): () =>
        controller.applyFilter(const ColorFilter.matrix(invertMatrix)),
    shortcut(LogicalKeyboardKey.keyU, shift: true): () =>
        controller.applyFilter(ColorFilter.matrix(saturationMatrix(-1))),

    // Layer
    shortcut(LogicalKeyboardKey.keyN, shift: true): controller.addLayer,
    shortcut(LogicalKeyboardKey.keyJ): controller.layerFromSelection,
    shortcut(LogicalKeyboardKey.keyE): controller.mergeDown,
    shortcut(LogicalKeyboardKey.bracketRight): controller.raiseLayer,
    shortcut(LogicalKeyboardKey.bracketLeft): controller.lowerLayer,
    shortcut(LogicalKeyboardKey.bracketRight, shift: true):
        controller.raiseLayerToTop,
    shortcut(LogicalKeyboardKey.bracketLeft, shift: true):
        controller.lowerLayerToBottom,
    const SingleActivator(LogicalKeyboardKey.bracketRight, alt: true): () =>
        controller.activateLayerBy(1),
    const SingleActivator(LogicalKeyboardKey.bracketLeft, alt: true): () =>
        controller.activateLayerBy(-1),
    shortcut(LogicalKeyboardKey.comma): controller.toggleLayerVisible,

    // View
    for (final key in _zoomIn) ...{
      shortcut(key): () => actions.stepZoom(1),
      shortcut(key, shift: true): () => actions.stepZoom(1),
    },
    for (final key in _zoomOut) shortcut(key): () => actions.stepZoom(-1),
    for (final key in _digits[0]) ...{
      shortcut(key): actions.fit,
      shortcut(key, alt: true): actions.actualSize,
    },
    for (final key in _digits[1]) shortcut(key): actions.actualSize,

    // Tools
    for (final key in toolKeys.values.toSet()) ...{
      SingleActivator(_letters[key]!): () => pickTool(key),
      SingleActivator(_letters[key]!, shift: true): () => pickTool(key),
    },
    const SingleActivator(LogicalKeyboardKey.keyX): settings.swapColors,
    const SingleActivator(LogicalKeyboardKey.keyD): settings.resetColors,
    const CharacterActivator('['): () => growBrush(-1),
    const CharacterActivator(']'): () => growBrush(1),
    const CharacterActivator('{'): () => settings.hardness -= hardnessStep,
    const CharacterActivator('}'): () => settings.hardness += hardnessStep,
    for (final (digit, keys) in _digits.indexed)
      for (final key in keys)
        SingleActivator(key): () => setOpacity(digit == 0 ? 1 : digit / 10),
    for (final (key, dx, dy) in _arrows) ...{
      SingleActivator(key): () => nudge(dx, dy),
      SingleActivator(key, shift: true): () => nudge(dx * 10, dy * 10),
    },
  };
}

final _letters = {
  for (final key in LogicalKeyboardKey.knownLogicalKeys)
    if (key.keyLabel.length == 1) key.keyLabel: key,
};

const _erasers = [LogicalKeyboardKey.delete, LogicalKeyboardKey.backspace];

const _zoomIn = [LogicalKeyboardKey.equal, LogicalKeyboardKey.numpadAdd];

const _zoomOut = [LogicalKeyboardKey.minus, LogicalKeyboardKey.numpadSubtract];

/// The keys of each digit, on the top row and on the number pad.
const _digits = [
  [LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0],
  [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
  [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
  [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
  [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
  [LogicalKeyboardKey.digit5, LogicalKeyboardKey.numpad5],
  [LogicalKeyboardKey.digit6, LogicalKeyboardKey.numpad6],
  [LogicalKeyboardKey.digit7, LogicalKeyboardKey.numpad7],
  [LogicalKeyboardKey.digit8, LogicalKeyboardKey.numpad8],
  [LogicalKeyboardKey.digit9, LogicalKeyboardKey.numpad9],
];

const _arrows = [
  (LogicalKeyboardKey.arrowLeft, -1, 0),
  (LogicalKeyboardKey.arrowRight, 1, 0),
  (LogicalKeyboardKey.arrowUp, 0, -1),
  (LogicalKeyboardKey.arrowDown, 0, 1),
];
