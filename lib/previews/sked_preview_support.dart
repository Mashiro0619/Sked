import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/material_ui_compatibility.dart';

const Size skedPhonePreviewSize = Size(360, 800);
const Size skedPhoneLargeTextPreviewSize = Size(360, 900);
const Size skedWidePreviewSize = Size(1100, 760);

/// Provides the same theme, localization, and compatibility bridge as Sked.
Widget skedPreviewWrapper(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    builder: bridgeLegacyMaterialUi,
    theme: buildAppTheme(
      seedColor: const Color(defaultThemeSeedColorValue),
      brightness: Brightness.light,
      themeColorMode: themeColorModeSingle,
      colorfulUiColorValues: const <String, int>{},
    ),
    home: Scaffold(body: SafeArea(child: child)),
  );
}
