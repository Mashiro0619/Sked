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

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.provider});

  final TimetableProvider provider;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      unawaited(oldWidget.provider.flushPendingUiStateSaves());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.provider.flushPendingUiStateSaves());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.provider.flushPendingUiStateSaves());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TimetableProvider>.value(
      value: widget.provider,
      child: Selector<TimetableProvider, _AppShellSnapshot>(
        selector: (_, provider) => _AppShellSnapshot.from(provider),
        builder: (context, snapshot, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            locale: appLocaleFromCode(snapshot.localeCode),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            themeMode: themeModeFromValue(snapshot.themeMode),
            themeAnimationStyle: appThemeAnimationStyle,
            theme: buildAppTheme(
              seedColor: Color(snapshot.themeSeedColorValue),
              brightness: Brightness.light,
              themeColorMode: snapshot.themeColorMode,
              colorfulUiColorValues: snapshot.colorfulUiColorValues,
            ),
            darkTheme: buildAppTheme(
              seedColor: Color(snapshot.themeSeedColorValue),
              brightness: Brightness.dark,
              themeColorMode: snapshot.themeColorMode,
              colorfulUiColorValues: snapshot.colorfulUiColorValues,
            ),
            home: const AppHomeScreen(),
          );
        },
      ),
    );
  }
}

class _AppShellSnapshot {
  const _AppShellSnapshot({
    required this.localeCode,
    required this.themeMode,
    required this.themeColorMode,
    required this.themeSeedColorValue,
    required this.colorfulUiColorValues,
  });

  factory _AppShellSnapshot.from(TimetableProvider provider) {
    return _AppShellSnapshot(
      localeCode: provider.localeCode,
      themeMode: provider.themeMode,
      themeColorMode: provider.themeColorMode,
      themeSeedColorValue: provider.themeSeedColorValue,
      colorfulUiColorValues: Map.unmodifiable(provider.colorfulUiColorValues),
    );
  }

  final String localeCode;
  final String themeMode;
  final String themeColorMode;
  final int themeSeedColorValue;
  final Map<String, int> colorfulUiColorValues;

  @override
  bool operator ==(Object other) {
    return other is _AppShellSnapshot &&
        other.localeCode == localeCode &&
        other.themeMode == themeMode &&
        other.themeColorMode == themeColorMode &&
        other.themeSeedColorValue == themeSeedColorValue &&
        mapEquals(other.colorfulUiColorValues, colorfulUiColorValues);
  }

  @override
  int get hashCode => Object.hash(
    localeCode,
    themeMode,
    themeColorMode,
    themeSeedColorValue,
    _stableMapHash(colorfulUiColorValues),
  );
}

int _stableMapHash(Map<String, int> values) {
  final keys = values.keys.toList()..sort();
  return Object.hashAll([
    for (final key in keys) Object.hash(key, values[key]),
  ]);
}
