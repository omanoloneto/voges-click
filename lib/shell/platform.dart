import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Command on Apple platforms, Ctrl elsewhere.
SingleActivator shortcut(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) => SingleActivator(
  key,
  control: !isApplePlatform,
  meta: isApplePlatform,
  shift: shift,
  alt: alt,
);

/// How a shortcut is written in tooltips: "⌘Z" or "Ctrl+Z". [command] is
/// false for the ones that go without Command or Ctrl.
String shortcutLabel(
  String key, {
  bool shift = false,
  bool alt = false,
  bool command = true,
}) => isApplePlatform
    ? '${alt ? '⌥' : ''}${shift ? '⇧' : ''}${command ? '⌘' : ''}$key'
    : '${command ? 'Ctrl+' : ''}${alt ? 'Alt+' : ''}${shift ? 'Shift+' : ''}$key';
