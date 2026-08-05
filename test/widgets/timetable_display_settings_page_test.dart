import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/timetable_display_settings_page.dart';
import 'package:sked/widgets/settings_list.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData data;

  @override
  Future<String?> filePath() async =>
      'memory://timetable-display-settings-test';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }
}

Future<TimetableProvider> _createProvider() async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpPage(WidgetTester tester, TimetableProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TimetableDisplaySettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _toggleSetting(WidgetTester tester, String title) async {
  final titleFinder = find.text(title);
  await tester.scrollUntilVisible(titleFinder, 120);
  final tile = find.ancestor(
    of: titleFinder,
    matching: find.byType(SettingsSwitchTile),
  );
  await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('persists every timetable display and interaction toggle', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    expect(find.text('Timetable display and interaction'), findsOneWidget);

    await _toggleSetting(tester, 'Allow outside tap to close course popup');
    expect(provider.closeCoursePopupOnOutsideTap, isFalse);

    await _toggleSetting(tester, 'Preserve timetable gaps');
    expect(provider.preserveTimetableGaps, isTrue);

    await _toggleSetting(tester, 'Show past-ended courses');
    expect(provider.showPastEndedCourses, isTrue);

    await _toggleSetting(tester, 'Show future courses');
    expect(provider.showFutureCourses, isFalse);

    await _toggleSetting(tester, 'Show timetable grid lines');
    expect(provider.showTimetableGridLines, isFalse);
  });
}
