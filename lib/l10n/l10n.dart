import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension LayerNames on AppLocalizations {
  /// Name of the [number]-th layer of a picture.
  String layerNamed(int number) =>
      number == 1 ? backgroundLayer : layerNumber(number);
}
