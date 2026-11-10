import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'canvas/image_ops.dart';
import 'canvas/editor_controller.dart';
import 'canvas/tool_settings.dart';
import 'document/image_document.dart';
import 'document/layer.dart';
import 'files/image_clipboard.dart';
import 'files/image_files.dart';
import 'files/system_open.dart';
import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';
import 'shell/platform.dart';
import 'shell/title_bar.dart';
import 'shell/window_buttons.dart';

/// Size of the image the app starts with.
const _startWidth = 1280, _startHeight = 720;

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'Voges Click',
        size: Size(1280, 860),
        minimumSize: Size(900, 600),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: true,
      ),
      () async {
        await placeNativeWindowButtons(titleBarHeight);
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  final language = AppLanguage();
  await language.load();
  final files = ImageFiles();
  final l10n = lookupAppLocalizations(
    language.resolve(WidgetsBinding.instance.platformDispatcher.locales),
  );
  final controller = EditorController(
    document: ImageDocument(
      DocumentState(_startWidth, _startHeight, [
        Layer(
          id: 1,
          name: l10n.backgroundLayer,
          image: blankImage(_startWidth, _startHeight, const Color(0xFFFFFFFF)),
        ),
      ]),
    ),
    settings: ToolSettings(),
  );

  runApp(
    VogesClickApp(
      controller: controller,
      files: files,
      clipboard: ImageClipboard(),
      systemOpen: SystemOpen(files),
      language: language,
      launchArguments: arguments,
      windowButtons: await WindowButtonsLayout.forPlatform(),
    ),
  );
}
