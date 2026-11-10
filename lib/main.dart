import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:voges_updater/voges_updater.dart'
    show UpdateCheck, UpdaterRequest, runUpdater, vogesClick;
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'canvas/tool_settings.dart';
import 'editor/open_pictures.dart';
import 'files/image_clipboard.dart';
import 'files/image_files.dart';
import 'files/system_open.dart';
import 'l10n/app_language.dart';
import 'l10n/l10n.dart';
import 'shell/platform.dart';
import 'shell/title_bar.dart';
import 'shell/window_buttons.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // On Windows and Linux a copy of the app itself is the updater; on macOS
  // the updater is a separate app, because this one is sandboxed.
  if (!kIsWeb &&
      UpdaterRequest.isUpdaterLaunch(arguments, defaultTargetPlatform.name)) {
    final language = AppLanguage();
    await language.load();
    return runUpdater(
      arguments: arguments,
      host: vogesClick,
      locale: language.locale,
    );
  }
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

  runApp(
    VogesClickApp(
      pictures: OpenPictures(
        settings: ToolSettings(),
        layerName: l10n.layerNamed,
      ),
      files: files,
      clipboard: ImageClipboard(),
      systemOpen: SystemOpen(files),
      language: language,
      launchArguments: arguments,
      windowButtons: await WindowButtonsLayout.forPlatform(),
      updates: isDesktopPlatform ? UpdateCheck.forPlatform(vogesClick) : null,
    ),
  );
}
