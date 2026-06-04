import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/theme/app_theme.dart';

class _BlockingTimetableStorage implements TimetableStorage {
  _BlockingTimetableStorage(this.data);

  AppData? data;
  Completer<void>? _blockedSave;
  var saveCount = 0;

  void blockNextSave() {
    _blockedSave = Completer<void>();
  }

  void completeSave() {
    final blockedSave = _blockedSave;
    _blockedSave = null;
    blockedSave?.complete();
  }

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
    final blockedSave = _blockedSave;
    if (blockedSave != null) {
      await blockedSave.future;
    }
  }

  @override
  Future<String?> filePath() async => 'memory://theme-settings-test';
}

Future<TimetableProvider> _createProvider(
  _BlockingTimetableStorage storage,
) async {
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

class _ThemeSettingsHost extends StatelessWidget {
  const _ThemeSettingsHost({required this.provider});

  final TimetableProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(
              seedColor: Color(provider.themeSeedColorValue),
              brightness: Brightness.light,
              themeColorMode: provider.themeColorMode,
              colorfulUiColorValues: provider.colorfulUiColorValues,
            ),
            home: const ThemeSettingsPage(),
          );
        },
      ),
    );
  }
}

void main() {
  testWidgets('theme settings page fits compact phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('theme-brightness-mode-segmented')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('theme-color-mode-segmented')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom color dialog fits compact phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    final customColor = find.text('Custom color').last;
    await tester.scrollUntilVisible(customColor, 200);
    await tester.pumpAndSettle();
    await tester.tap(customColor);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apply color'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course outline dialog fits compact phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    final outlineCard = find.byKey(
      const ValueKey('theme-outline-settings-card'),
    );
    await tester.scrollUntilVisible(outlineCard, 200);
    await tester.pumpAndSettle();
    expect(outlineCard, findsOneWidget);
    await tester.tap(outlineCard);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apply settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset seed color updates the app theme immediately', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        themeColorMode: themeColorModeSingle,
        themeSeedColorValue: 0xFF6750A4,
      ),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme!.colorScheme.primary, const Color(0xFF6750A4));

    await tester.tap(find.byKey(const ValueKey('theme-seed-color-#00897B')));
    await tester.pumpAndSettle();

    materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(provider.themeSeedColorValue, 0xFF00897B);
    expect(materialApp.theme!.colorScheme.primary, const Color(0xFF00897B));
    expect(
      materialApp.theme!.navigationBarTheme.indicatorColor,
      const Color(0xFF00897B).withValues(alpha: 0.12),
    );
  });

  testWidgets('colorful primary setting controls the app primary color', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        themeColorMode: themeColorModeColorful,
        colorfulUiColorValues: const {colorfulUiPrimaryKey: 0xFF112233},
      ),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme!.colorScheme.primary, const Color(0xFF112233));

    final primaryTile = find.byKey(const ValueKey('theme-ui-color-primary'));
    expect(primaryTile, findsOneWidget);
    expect(
      find.descendant(of: primaryTile, matching: find.text('#112233')),
      findsOneWidget,
    );
  });

  testWidgets('general colorful settings show calendar color slots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        activeMode: AppMode.general,
        themeColorMode: themeColorModeColorful,
        colorfulUiColorValues: const {
          colorfulGeneralCalendarColor2Key: 0xFF778899,
        },
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'life',
          schedules: [
            GeneralSchedule(
              id: 'life',
              name: 'Life',
              colorValue: generalCalendarColorSlot2Value,
              events: [],
            ),
          ],
        ),
      ),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    expect(find.text('Calendar colors'), findsOneWidget);
    expect(find.text('Calendar color 1'), findsOneWidget);
    expect(find.text('Calendar color 6'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('theme-general-calendar-slot-general_calendar_1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('theme-general-calendar-slot-general_calendar_6'),
      ),
      findsOneWidget,
    );

    final secondSlot = find.byKey(
      const ValueKey('theme-general-calendar-slot-general_calendar_2'),
    );
    expect(
      find.descendant(of: secondSlot, matching: find.text('#778899')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('theme-general-calendar-color-life')),
        matching: find.text('#778899'),
      ),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('theme-ui-color-primary')), findsNothing);
    expect(
      find.byKey(const ValueKey('theme-ui-color-secondary')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('theme-ui-color-tertiary')), findsNothing);
    expect(find.text('Primary'), findsNothing);
    expect(find.text('Secondary'), findsNothing);
    expect(find.text('Tertiary'), findsNothing);
  });

  testWidgets('custom color apply is disabled while save is in progress', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);
    storage.blockNextSave();

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final customColor = find.text('Custom color').last;
    await tester.scrollUntilVisible(customColor, 200);
    await tester.pumpAndSettle();
    await tester.tap(customColor);
    await tester.pumpAndSettle();

    final applyButton = find.widgetWithText(FilledButton, 'Apply color');
    expect(applyButton, findsOneWidget);

    await tester.tap(applyButton);
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNull);

    await tester.tap(applyButton, warnIfMissed: false);
    await tester.pump();

    expect(storage.saveCount, 1);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(applyButton, findsNothing);
    expect(storage.saveCount, 1);
  });
}
