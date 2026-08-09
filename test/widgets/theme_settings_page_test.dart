import 'dart:async';
import 'dart:io';

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
  Object? _nextSaveError;
  var saveCount = 0;

  void blockNextSave() {
    _blockedSave = Completer<void>();
  }

  void completeSave() {
    final blockedSave = _blockedSave;
    _blockedSave = null;
    blockedSave?.complete();
  }

  void failNextSave([Object error = const FileSystemException('save failed')]) {
    _nextSaveError = error;
  }

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    final saveError = _nextSaveError;
    _nextSaveError = null;
    final blockedSave = _blockedSave;
    if (blockedSave != null) {
      await blockedSave.future;
    }
    if (saveError != null) throw saveError;
    this.data = data;
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
  const _ThemeSettingsHost({
    required this.provider,
    this.locale = const Locale('en'),
    this.textScaler = TextScaler.noScaling,
    this.viewPadding = EdgeInsets.zero,
  });

  final TimetableProvider provider;
  final Locale locale;
  final TextScaler textScaler;
  final EdgeInsets viewPadding;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: Consumer<TimetableProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: textScaler,
                padding: viewPadding,
                viewPadding: viewPadding,
              ),
              child: child!,
            ),
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

void _setTestViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

void _resetTestViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

Future<void> _openOutlineSettingsPage(WidgetTester tester) async {
  final outlineCard = find.byKey(const ValueKey('theme-outline-settings-card'));
  for (
    var attempt = 0;
    attempt < 12 && outlineCard.evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();
  }
  expect(outlineCard, findsOneWidget);
  await tester.scrollUntilVisible(outlineCard, 200);
  await tester.pumpAndSettle();
  final tapTarget = find.descendant(
    of: outlineCard,
    matching: find.byType(InkWell),
  );
  expect(tapTarget, findsOneWidget);
  tester.widget<InkWell>(tapTarget).onTap!();
  await tester.pumpAndSettle();
}

void _expectThemePersistenceDialogBlocked(WidgetTester tester) {
  final focusScope = tester.widget<FocusScope>(
    find.byKey(const ValueKey('theme-persistence-dialog-focus-scope')),
  );
  expect(focusScope.canRequestFocus, isFalse);
  expect(focusScope.descendantsAreFocusable, isFalse);
  expect(focusScope.descendantsAreTraversable, isFalse);
  expect(
    tester
        .widget<AbsorbPointer>(
          find.byKey(const ValueKey('theme-persistence-dialog-pointer-guard')),
        )
        .absorbing,
    isTrue,
  );
  expect(
    find.descendant(
      of: find.byKey(const ValueKey('theme-persistence-dialog-busy-indicator')),
      matching: find.byType(LinearProgressIndicator),
    ),
    findsOneWidget,
  );
}

void main() {
  testWidgets('caps theme content on Android tablets', (tester) async {
    _setTestViewport(tester, const Size(1024, 768));
    addTearDown(() => _resetTestViewport(tester));
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(
      _ThemeSettingsHost(
        provider: provider,
        viewPadding: const EdgeInsets.only(bottom: 48),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ListView);
    expect(tester.getSize(list).width, lessThanOrEqualTo(720));
    expect(tester.getRect(list).bottom, lessThanOrEqualTo(720));
    expect((tester.widget<ListView>(list).padding! as EdgeInsets).bottom, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme settings page fits compact phone width', (tester) async {
    _setTestViewport(tester, const Size(320, 640));
    addTearDown(() => _resetTestViewport(tester));

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

  testWidgets('compact layout supports 2x localized text', (tester) async {
    _setTestViewport(tester, const Size(320, 640));
    addTearDown(() => _resetTestViewport(tester));
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);

    for (final locale in const [Locale('de')]) {
      await tester.pumpWidget(
        _ThemeSettingsHost(
          provider: provider,
          locale: locale,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldContext = tester.element(find.byType(Scaffold));
      expect(Directionality.of(scaffoldContext), TextDirection.ltr);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('custom color dialog fits compact phone width', (tester) async {
    _setTestViewport(tester, const Size(320, 640));
    addTearDown(() => _resetTestViewport(tester));

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

  testWidgets('course outline opens as a compact responsive page', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 640));
    addTearDown(() => _resetTestViewport(tester));

    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    await _openOutlineSettingsPage(tester);

    expect(
      find.byKey(const ValueKey('theme-outline-settings-page')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Apply settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('theme-outline-page-scroll-view')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('course outline page cancel discards its draft', (tester) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);
    final initialEnabled = provider.liveCourseOutlineEnabled;

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();
    await _openOutlineSettingsPage(tester);

    await tester.tap(
      find.byKey(const ValueKey('live-course-outline-enabled-row')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Switch>(
            find.descendant(
              of: find.byKey(const ValueKey('live-course-outline-enabled-row')),
              matching: find.byType(Switch),
            ),
          )
          .value,
      !initialEnabled,
    );

    await tester.tap(find.byKey(const ValueKey('theme-outline-page-cancel')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('theme-outline-settings-page')),
      findsNothing,
    );
    expect(provider.liveCourseOutlineEnabled, initialEnabled);
    expect(storage.saveCount, 0);
  });

  testWidgets('course outline page cannot pop twice on rapid cancel', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();
    await _openOutlineSettingsPage(tester);

    final cancel = tester.widget<TextButton>(
      find.byKey(const ValueKey('theme-outline-page-cancel')),
    );
    cancel.onPressed!();
    cancel.onPressed!();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('theme-outline-settings-page')),
      findsNothing,
    );
    expect(find.byType(ThemeSettingsPage), findsOneWidget);
    expect(storage.saveCount, 0);
  });

  testWidgets('course outline page applies one atomic save and blocks exit', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);
    final derivedColor = deriveLiveCourseOutlineColorFromSeed(
      Color(provider.themeSeedColorValue),
    ).toARGB32();

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();
    await _openOutlineSettingsPage(tester);

    await tester.tap(
      find.byKey(const ValueKey('live-course-outline-follow-theme-row')),
    );
    await tester.pumpAndSettle();
    storage.blockNextSave();
    await tester.tap(find.byKey(const ValueKey('theme-outline-page-apply')));
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const ValueKey('theme-outline-page-pointer-guard')),
          )
          .absorbing,
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('theme-outline-page-busy-indicator')),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('theme-outline-page-apply')),
          )
          .onPressed,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('theme-outline-settings-page')),
      findsOneWidget,
    );
    expect(storage.saveCount, 1);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('theme-outline-settings-page')),
      findsNothing,
    );
    expect(provider.liveCourseOutlineFollowTheme, isFalse);
    expect(provider.liveCourseOutlineColorValue, derivedColor);
    expect(provider.liveCourseOutlineCustomColorInitialized, isTrue);
    expect(storage.data?.studentMode.liveCourseOutlineFollowTheme, isFalse);
    expect(storage.saveCount, 1);
  });

  testWidgets('failed course outline save preserves its draft for retry', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);
    final initialEnabled = provider.liveCourseOutlineEnabled;

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();
    await _openOutlineSettingsPage(tester);
    await tester.tap(
      find.byKey(const ValueKey('live-course-outline-enabled-row')),
    );
    await tester.pumpAndSettle();
    storage.failNextSave();

    await tester.tap(find.byKey(const ValueKey('theme-outline-page-apply')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('theme-outline-settings-page')),
      findsOneWidget,
    );
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(provider.liveCourseOutlineEnabled, initialEnabled);
    expect(
      tester
          .widget<Switch>(
            find.descendant(
              of: find.byKey(const ValueKey('live-course-outline-enabled-row')),
              matching: find.byType(Switch),
            ),
          )
          .value,
      !initialEnabled,
    );

    await tester.tap(find.byKey(const ValueKey('theme-outline-page-apply')));
    await tester.pumpAndSettle();

    expect(provider.liveCourseOutlineEnabled, !initialEnabled);
    expect(storage.saveCount, 2);
    expect(
      find.byKey(const ValueKey('theme-outline-settings-page')),
      findsNothing,
    );
  });

  testWidgets('course outline page supports large localized text', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));

    for (final locale in const [Locale('de')]) {
      final storage = _BlockingTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _createProvider(storage);
      await tester.pumpWidget(
        _ThemeSettingsHost(
          provider: provider,
          locale: locale,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      await _openOutlineSettingsPage(tester);

      expect(
        Directionality.of(
          tester.element(
            find.byKey(const ValueKey('theme-outline-settings-page')),
          ),
        ),
        TextDirection.ltr,
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(
        find.byKey(const ValueKey('theme-outline-page-apply')),
        findsOneWidget,
      );
      final followThemeRow = find.byKey(
        const ValueKey('live-course-outline-follow-theme-row'),
      );
      final followThemeLabel = find.descendant(
        of: followThemeRow,
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(followThemeLabel).maxLines, isNull);
      expect(
        tester
            .getRect(
              find.descendant(
                of: followThemeRow,
                matching: find.byType(Switch),
              ),
            )
            .top,
        greaterThanOrEqualTo(tester.getRect(followThemeLabel).bottom),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('theme-outline-page-cancel')));
      await tester.pumpAndSettle();
    }
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

  testWidgets('failed theme save rolls back and remains retryable', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _createProvider(storage);
    storage.failNextSave();

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(provider.themeMode, newUserDefaultThemeMode);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(provider.themeMode, 'dark');
    expect(storage.saveCount, 2);
  });

  testWidgets('theme color swatches expose value and selection semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
      ).copyWith(themeSeedColorValue: 0xFF6750A4),
    );
    final provider = await _createProvider(storage);

    await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
    await tester.pumpAndSettle();

    final swatch = find.byKey(const ValueKey('theme-seed-color-#6750A4'));
    expect(swatch, findsOneWidget);
    expect(
      tester.getSemantics(swatch),
      matchesSemantics(
        label: '#6750A4',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    final swatchSize = tester.getSize(swatch);
    expect(swatchSize.width, greaterThanOrEqualTo(48));
    expect(swatchSize.height, greaterThanOrEqualTo(48));
    semantics.dispose();
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

  testWidgets(
    'general colorful settings show calendars and month text colors',
    (tester) async {
      _setTestViewport(tester, const Size(800, 1200));
      addTearDown(() => _resetTestViewport(tester));

      final storage = _BlockingTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
          activeMode: AppMode.general,
          themeColorMode: themeColorModeColorful,
          colorfulUiColorValues: const {
            colorfulGeneralCalendarColor2Key: 0xFF778899,
            colorfulGeneralLunarTextColorKey: 0xFF223344,
            colorfulGeneralFestivalTextColorKey: 0xFFAA5500,
            colorfulGeneralSolarTermTextColorKey: 0xFF336600,
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

      expect(find.text('Calendar colors'), findsNothing);
      expect(find.text('Calendar color 1'), findsNothing);
      expect(find.text('Calendar color 6'), findsNothing);
      expect(find.text('Month view text'), findsOneWidget);
      expect(find.text('Lunar dates'), findsOneWidget);
      expect(find.text('Festivals and holidays'), findsOneWidget);
      expect(find.text('Solar terms'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('theme-general-calendar-slot-general_calendar_1'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('theme-general-calendar-slot-general_calendar_6'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('theme-general-calendar-color-life')),
          matching: find.text('#778899'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('theme-general-month-text-color-general_lunar_text'),
          ),
          matching: find.text('#223344'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey(
              'theme-general-month-text-color-general_festival_text',
            ),
          ),
          matching: find.text('#AA5500'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey(
              'theme-general-month-text-color-general_solar_term_text',
            ),
          ),
          matching: find.text('#336600'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const ValueKey('theme-ui-color-primary')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('theme-ui-color-secondary')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('theme-ui-color-tertiary')),
        findsNothing,
      );
      expect(find.text('Primary'), findsNothing);
      expect(find.text('Secondary'), findsNothing);
      expect(find.text('Tertiary'), findsNothing);
    },
  );

  testWidgets('custom color save freezes controls and blocks dismissal', (
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

    final hexField = find.byKey(
      const ValueKey('compact-color-picker-hex-field'),
    );
    await tester.enterText(hexField, '#123456');
    await tester.pump();

    final applyButton = find.widgetWithText(FilledButton, 'Apply color');
    expect(applyButton, findsOneWidget);

    await tester.tap(applyButton);
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNull);
    _expectThemePersistenceDialogBlocked(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(hexField, warnIfMissed: false);
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(of: hexField, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isFalse);
    expect(editable.controller.text, '#123456');

    expect(storage.saveCount, 1);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(applyButton, findsNothing);
    expect(storage.saveCount, 1);
    expect(provider.themeSeedColorValue, 0xFF123456);
    expect(storage.data?.themeSeedColorValue, 0xFF123456);
  });

  testWidgets('failed custom color save preserves draft for retry', (
    tester,
  ) async {
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

    final hexField = find.byKey(
      const ValueKey('compact-color-picker-hex-field'),
    );
    await tester.enterText(hexField, '#234567');
    await tester.pump();
    storage.blockNextSave();
    storage.failNextSave();

    await tester.tap(find.widgetWithText(FilledButton, 'Apply color'));
    await tester.pump();
    _expectThemePersistenceDialogBlocked(tester);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(
              const ValueKey('theme-persistence-dialog-pointer-guard'),
            ),
          )
          .absorbing,
      isFalse,
    );
    expect(tester.widget<TextField>(hexField).controller?.text, '#234567');

    await tester.enterText(hexField, '#345678');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply color'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(storage.saveCount, 2);
    expect(provider.themeSeedColorValue, 0xFF345678);
  });

  testWidgets('all theme persistence dialogs share the busy guard', (
    tester,
  ) async {
    Future<void> exerciseDialog({
      required AppData data,
      required Future<void> Function() open,
      Future<void> Function()? edit,
    }) async {
      final storage = _BlockingTimetableStorage(data);
      final provider = await _createProvider(storage);
      await tester.pumpWidget(_ThemeSettingsHost(provider: provider));
      await tester.pumpAndSettle();

      await open();
      await tester.pumpAndSettle();
      await edit?.call();
      await tester.pumpAndSettle();

      storage.blockNextSave();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply settings'));
      await tester.pump();

      expect(storage.saveCount, 1);
      _expectThemePersistenceDialogBlocked(tester);

      storage.completeSave();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }

    AppData colorfulData() => buildInitialAppData(
      buildDefaultPeriodTimes(),
    ).copyWith(themeColorMode: themeColorModeColorful);

    await exerciseDialog(
      data: colorfulData(),
      open: () async {
        final tile = find.byKey(const ValueKey('theme-ui-color-primary'));
        await tester.scrollUntilVisible(tile, 200);
        await tester.tap(tile);
      },
    );

    await exerciseDialog(
      data: colorfulData(),
      open: () async {
        final tile = find.byKey(
          const ValueKey('theme-ui-color-$colorfulCourseTextColorKey'),
        );
        await tester.scrollUntilVisible(tile, 200);
        await tester.tap(tile);
      },
      edit: () async {
        await tester.tap(find.byTooltip('Custom color'));
      },
    );
  });
}
