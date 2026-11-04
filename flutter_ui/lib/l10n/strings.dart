// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
export 'app_localizations.dart';

// Background operations have no widget context and follow the device locale.
AppLocalizations get deviceStrings => lookupAppLocalizations(
  basicLocaleListResolution(
    WidgetsBinding.instance.platformDispatcher.locales,
    AppLocalizations.supportedLocales,
  ),
);

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
