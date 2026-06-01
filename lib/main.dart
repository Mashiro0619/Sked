import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'l10n/app_locale.dart';
import 'l10n/app_localizations.dart';
import 'providers/timetable_provider.dart';
import 'screens/app_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _registerLicenses();
  final provider = TimetableProvider();
  unawaited(provider.load());
  runApp(MyApp(provider: provider));
}

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString('NOTICE');
    yield LicenseEntryWithLineBreaks(['App icon assets'], notice);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.provider});

  final TimetableProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: Consumer<TimetableProvider>(
        builder: (context, timetableProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            locale: appLocaleFromCode(timetableProvider.localeCode),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            themeMode: themeModeFromValue(timetableProvider.themeMode),
            themeAnimationStyle: appThemeAnimationStyle,
            theme: buildAppTheme(
              seedColor: Color(timetableProvider.themeSeedColorValue),
              brightness: Brightness.light,
              themeColorMode: timetableProvider.themeColorMode,
              colorfulUiColorValues: timetableProvider.colorfulUiColorValues,
            ),
            darkTheme: buildAppTheme(
              seedColor: Color(timetableProvider.themeSeedColorValue),
              brightness: Brightness.dark,
              themeColorMode: timetableProvider.themeColorMode,
              colorfulUiColorValues: timetableProvider.colorfulUiColorValues,
            ),
            home: const AppHomeScreen(),
          );
        },
      ),
    );
  }
}
