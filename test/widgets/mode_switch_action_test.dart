import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/mode_switch_action.dart';

class _ControlledTimetableStorage implements TimetableStorage {
  _ControlledTimetableStorage(
    this.data, {
    this.block = false,
    this.fail = false,
  });

  AppData? data;
  bool block;
  bool fail;
  var saveCount = 0;
  final saveStarted = Completer<void>();
  final _allowSave = Completer<void>();

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData next) async {
    saveCount += 1;
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    if (block) {
      await _allowSave.future;
    }
    if (fail) {
      throw StateError('mode save failed');
    }
    data = next;
  }

  @override
  Future<String?> filePath() async => 'memory://mode-switch-action-test';

  void completeSave() {
    if (!_allowSave.isCompleted) {
      _allowSave.complete();
    }
  }
}

Future<TimetableProvider> _createProvider(
  _ControlledTimetableStorage storage,
) async {
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpModeSwitch(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: AppBar(actions: const [ModeSwitchAction()])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mode switch disables itself while the save is pending', (
    tester,
  ) async {
    final storage = _ControlledTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
      block: true,
    );
    final provider = await _createProvider(storage);
    await _pumpModeSwitch(tester, provider);
    final initialMode = provider.activeMode;
    final modeButton = find.descendant(
      of: find.byType(ModeSwitchAction),
      matching: find.byType(IconButton),
    );

    await tester.tap(modeButton);
    await storage.saveStarted.future;
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<IconButton>(modeButton.last);
    expect(button.onPressed, isNull);

    await tester.tap(modeButton.last, warnIfMissed: false);
    expect(storage.saveCount, 1);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(provider.activeMode, isNot(initialMode));
    expect(storage.saveCount, 1);
  });

  testWidgets('failed mode switch reports the error and restores the mode', (
    tester,
  ) async {
    final storage = _ControlledTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
      fail: true,
    );
    final provider = await _createProvider(storage);
    await _pumpModeSwitch(tester, provider);
    final initialMode = provider.activeMode;
    final modeButton = find.descendant(
      of: find.byType(ModeSwitchAction),
      matching: find.byType(IconButton),
    );

    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(provider.activeMode, initialMode);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
