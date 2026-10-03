import 'dart:convert';

import 'package:flutter/services.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';

import '../support/workspace_harness.dart';
import '../support/theme_task_harness.dart' show ThemeTaskStorage;

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'period creation guards workspace and replacement; failure=$fail',
      (t) async {
        rootBundle.evict(defaultPeriodTimesAssetPath);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final source = encodePeriodTimesEnvelope(buildDefaultPeriodTimes());
        messenger.setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != defaultPeriodTimesAssetPath) return null;
          return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
        });
        addTearDown(
          () => messenger.setMockMessageHandler('flutter/assets', null),
        );
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1200, 850);
        addTearDown(t.view.reset);
        final storage = ThemeTaskStorage(
          buildInitialAppData(buildDefaultPeriodTimes()),
        );
        final p = await workspaceProvider(
          mode: AppMode.student,
          storage: storage,
        );
        addTearDown(() {
          if (storage.pending?.isCompleted == false) {
            storage.pending!.complete();
          }
          p.dispose();
        });
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPeriodTimeSetPickerDialog(
                    context,
                    provider: p,
                    selectedPeriodTimeSetId: p.periodTimeSets.first.id,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        final before = p.periodTimeSets.length;
        final backup = await p.exportAppDataJson();
        final gate = Completer<void>();
        storage.pending = gate;
        if (fail) storage.saveError = StateError('Expected create failure');
        final add = find.widgetWithIcon(IconButton, Icons.add);
        await t.tap(add);
        await t.pump();
        // The default-set loader reads its bundled asset outside fake async.
        for (var i = 0; i < 30 && storage.writes == 0; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump();
        }
        expect(storage.writes, 1);
        await p.setWorkspaceEnabled(AppMode.student, false);
        await expectLater(
          p.importAppDataJson(backup, mode: AppImportMode.replaceAll),
          throwsA(isA<WorkspaceChangeCancelledException>()),
        );
        expect(p.isWorkspaceEnabled(AppMode.student), isTrue);
        expect(storage.writes, 1);
        gate.complete();
        await t.pumpAndSettle();
        expect(p.periodTimeSets.length, before + (fail ? 0 : 1));
        if (fail) {
          expect(find.byType(PeriodTimesPage), findsNothing);
          expect(t.widget<IconButton>(add).onPressed, isNotNull);
        } else {
          expect(find.byType(PeriodTimesPage), findsOneWidget);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }
}
