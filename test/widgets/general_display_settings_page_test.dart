import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://general-display-settings-test';
}

Future<TimetableProvider> _createProvider() async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(activeMode: AppMode.general),
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
        home: GeneralDisplaySettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows default view as a setting instead of page tabs', (
    tester,
  ) async {
    final provider = await _createProvider();

    await _pumpPage(tester, provider);

    expect(find.text('Startup'), findsOneWidget);
    expect(find.text('Default view'), findsOneWidget);
    expect(find.text('Schedule display'), findsOneWidget);
    expect(find.text('Time grid'), findsOneWidget);
    expect(find.text('Popup behavior'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.byType(SkedDropdownMenu<String>), findsOneWidget);

    await tester.tap(find.byType(SkedDropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();

    expect(provider.generalDefaultView, generalViewMonth);
  });

  testWidgets('default view dropdown opens with a full field-width menu', (
    tester,
  ) async {
    final provider = await _createProvider();

    await _pumpPage(tester, provider);

    final dropdown = find.byType(SkedDropdownMenu<String>);
    final dropdownRect = tester.getRect(dropdown);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final firstMenuItem = find
        .ancestor(of: find.text('Week').last, matching: find.byType(MenuItemButton))
        .first;
    final menuItemRect = tester.getRect(firstMenuItem);

    expect(menuItemRect.left, closeTo(dropdownRect.left, 1));
    expect(menuItemRect.width, greaterThanOrEqualTo(dropdownRect.width - 16));
  });
}
