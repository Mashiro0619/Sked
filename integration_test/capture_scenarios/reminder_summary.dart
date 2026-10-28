import '../support/capture_output_directory.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../../test/support/reminder_summary_harness.dart';
import '../../test/support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));

class _StartupLifecycleObservation extends WidgetsBindingObserver {
  _StartupLifecycleObservation(AppLifecycleState? initial) : states = [initial];

  final List<AppLifecycleState?> states;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => states.add(state);

  // Production permits null as well as resumed. Observe transitions instead of
  // pretending the native binding is resumed or overlooking an inactive frame.
  bool get eligible => states.every(
    (state) => state == null || state == AppLifecycleState.resumed,
  );
}

void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'grouped reminders with eligible startup, drag takeover and manual fallback',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      final output = createCaptureOutputDirectory(label: 'reminder-summary');
      await output.create(recursive: true);
      final captures = <String>[];
      final startupObservations = <Map<String, Object?>>[];
      addTearDown(t.view.reset);
      for (final locale in ['zh', 'en']) {
        for (final scale in [1.0, 1.5, 2.0]) {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(1366, 900);
          final p = await workspaceProvider(
            mode: AppMode.general,
            locale: locale,
            storage: reminderSummaryStorage(locale: locale),
          );
          final clock = ReminderSummaryClock();
          final boundary = GlobalKey();
          try {
            expect(p.generalView.reminderItems(now: clock.now()), hasLength(5));
            final binding = WidgetsBinding.instance;
            final lifecycle = _StartupLifecycleObservation(
              binding.lifecycleState,
            );
            binding.addObserver(lifecycle);
            try {
              await t.pumpWidget(
                RepaintBoundary(
                  key: boundary,
                  child: reminderSummaryHarness(
                    p,
                    clock,
                    session: GeneralReminderStartupSession(),
                    locale: locale,
                    scale: scale,
                    brightness: scale == 1.5
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                ),
              );
              await t.pumpAndSettle();
            } finally {
              binding.removeObserver(lifecycle);
            }
            final startupEligible = lifecycle.eligible;
            final l10n = AppLocalizations.of(
              t.element(find.byType(GeneralScheduleHomeScreen)),
            );
            final automaticHint = find.text(l10n.reminderAutoCloseHint);
            final observation = <String, Object?>{
              'locale': locale,
              'scale': scale,
              'automaticPreviewVisible': k('general-reminders-list')
                  .evaluate()
                  .isNotEmpty,
              'lifecycleDuringStartup': lifecycle.states
                  .map((state) => state?.name)
                  .toList(growable: false),
              'lifecycleAfterInitialSettle': binding.lifecycleState?.name,
              'startupEligible': startupEligible,
              'entryPath': startupEligible
                  ? 'automatic-drag-takeover'
                  : 'manual-after-ineligible-startup',
              'meaning': startupEligible
                  ? 'Eligible automatic preview is required and is kept open by a direct drag.'
                  : 'A non-resumed lifecycle was observed during mounting; startup visibility is observational and the public manual entry is used.',
            };
            startupObservations.add(observation);
            if (startupEligible) {
              expect(
                k('general-reminders-list'),
                findsOneWidget,
                reason:
                    '$locale-$scale eligible startup: ${observation['lifecycleDuringStartup']}',
              );
              expect(automaticHint, findsOneWidget);
            }

            Future<void> capture(String scene) async {
              await t.pumpAndSettle();
              expect(
                t.takeException(),
                isNull,
                reason: '$locale-$scale-$scene',
              );
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                final file = '$locale-$scale-$scene.png';
                await File('${output.path}/$file')
                    .writeAsBytes(bytes.buffer.asUint8List());
                captures.add(file);
              } finally {
                image.dispose();
              }
            }

            await capture('startup');

            // A lifecycle-suppressed startup may use the manual entry. Eligible
            // previews must reach the drag directly, without replacing the list.
            if (!startupEligible) {
              if (k('general-reminders-action')
                  .hitTestable()
                  .evaluate()
                  .isEmpty) {
                final more = k('general-desktop-toolbar-more').hitTestable();
                expect(
                  more,
                  findsOneWidget,
                  reason: '$locale-$scale manual entry',
                );
                await t.tap(more);
                await t.pumpAndSettle();
              }
              final entry = k('general-reminders-action').hitTestable();
              expect(
                entry,
                findsOneWidget,
                reason: '$locale-$scale reminder entry',
              );
              await t.tap(entry);
              await t.pumpAndSettle();
              expect(automaticHint, findsNothing);
            } else {
              expect(automaticHint, findsOneWidget);
            }
            expect(k('general-reminders-list'), findsOneWidget);
            final listBeforeDrag = t.element(k('general-reminders-list'));
            observation['automaticHintBeforeDrag'] = automaticHint
                .evaluate()
                .isNotEmpty;
            expect(
              k('workspace-view-drag-handle').hitTestable(),
              findsOneWidget,
            );
            await t.drag(
              k('workspace-view-drag-handle'),
              const Offset(-80, 25),
            );
            await t.pumpAndSettle();
            expect(k('general-reminders-list'), findsOneWidget);
            expect(
              t.element(k('general-reminders-list')),
              same(listBeforeDrag),
            );
            expect(automaticHint, findsNothing);
            observation.addAll({
              'dragPreservedListElement': true,
              'automaticHintAfterDrag': false,
              'dragTookOverAutomaticPreview': startupEligible,
            });
            await capture('grouped');
            final reminderElement = t.element(k('general-reminders-list'));
            final reminderRect = t.getRect(k('general-reminders-list'));
            await t.tap(
              find.descendant(
                of: k('general-reminders-list'),
                matching: find.text(locale == 'zh' ? '学习小组' : 'Study group'),
              ),
            );
            await t.pumpAndSettle();
            expect(
              t.element(k('general-reminders-list')),
              same(reminderElement),
            );
            expect(t.getRect(k('general-reminders-list')), reminderRect);
            expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
            await capture('companion-detail');
            await t.tap(
              find.descendant(
                of: find.byType(GeneralEventDetailsSheet),
                matching: k('workspace-inspector-close'),
              ),
            );
            await t.pumpAndSettle();
            expect(
              t.element(k('general-reminders-list')),
              same(reminderElement),
            );
            if (scale == 2) {
              t.view.physicalSize = const Size(920, 620);
              await t.pumpAndSettle();
              await t.drag(k('workspace-view-body'), const Offset(0, -280));
              await capture('short-window-scrolled');
            }
          } finally {
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
            p.dispose();
          }
        }
      }
      expect(captures, hasLength(20));
      await File('${output.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'captures': captures,
          'startupObservations': startupObservations,
          'source': 'integration_test/capture_scenarios/reminder_summary.dart',
          'captureValidation': 'Require automatic preview when observed startup lifecycle remains null/resumed, verify direct drag takeover, and use the public manual entry only after lifecycle-ineligible startup; retain grouped/detail/resize scenes.',
          'evidence': 'Actual Windows Flutter font rendering with in-memory data and recorded binding lifecycle; eligible startup and synthetic drag transitions are asserted. Ineligible startup snapshots are observations, not native mouse or operating-system lifecycle acceptance.',
        }),
      );
    },
  );
}
