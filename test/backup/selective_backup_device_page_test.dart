import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_device_data.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/selective_backup_page.dart';
import 'package:sked/services/device_preferences_store.dart';
import 'package:sked/widgets/sked_confirmation_dialog.dart';

import '../support/workspace_harness.dart';

void main() {
  testWidgets(
    'unsupported platform groups are disabled and remain visible in restore review',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final runtime = (await tester.runAsync(() async {
        final runtime = await workspaceProvider(
          devicePreferences: DevicePreferencesStore.memory(
            platform: DevicePreferencePlatform.android,
          ),
        );
        await runtime.backups.selective.inventory();
        return runtime;
      }))!;
      addTearDown(runtime.dispose);
      final source = buildSelectiveBackupInventory(
        appData: runtime.session.committedData,
        devicePreferences: buildDeviceBackupRecords(
          DevicePreferencePlatform.windows,
          {
            DevicePreferenceGroup.desktopLayout: {
              'regions': {
                'assistant': {'width': 520.0},
              },
            },
            DevicePreferenceGroup.developerUi: {
              'assistantPreviewEnabled': true,
            },
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: SelectiveBackupPage(
            service: runtime.backups.selective,
            initialSource: source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SelectiveBackupPage)),
      );
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final unsupported = find.byKey(
        const ValueKey('backup-object-deviceSettings:windows.desktopLayout'),
      );
      final group = find.byKey(const ValueKey('backup-group-deviceSettings'));
      await tester.scrollUntilVisible(group, 450, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(find.text(l.selectiveBackupUnsupportedGroups(2)), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(
                const ValueKey('backup-group-selection-deviceSettings'),
              ),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(group);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(unsupported, 450, scrollable: scrollable);
      final row = tester.widget<CheckboxListTile>(unsupported);
      expect(row.value, isFalse);
      expect(row.onChanged, isNull);
      expect(
        find.text(l.selectiveBackupDeviceUnsupported('Windows')),
        findsWidgets,
      );
      final primary = find.byKey(const ValueKey('selective-backup-primary'));
      await tester.scrollUntilVisible(primary, 300, scrollable: scrollable);
      await tester.runAsync(() async {
        final prepared = Completer<void>();
        void observePreparation() {
          if (!runtime.backups.selective.isBusy && !prepared.isCompleted) {
            prepared.complete();
          }
        }

        runtime.backups.selective.addListener(observePreparation);
        try {
          await tester.tap(primary);
          await prepared.future.timeout(const Duration(seconds: 10));
        } finally {
          runtime.backups.selective.removeListener(observePreparation);
        }
      });
      await tester.pumpAndSettle();
      expect(find.text(l.selectiveBackupConfirmTitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SkedConfirmationDialog),
          matching: find.text(l.selectiveBackupUnsupportedGroups(2)),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(l.selectiveBackupDeviceUnsupported('Windows')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, l.cancel));
      await tester.pumpAndSettle();
      expect(await runtime.backups.selective.journal.read(), isNull);
    },
  );
}
