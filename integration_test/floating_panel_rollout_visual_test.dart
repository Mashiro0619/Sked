import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';
import 'package:sked/l10n/app_localizations.dart';

import '../test/support/workspace_harness.dart';
import 'category_manager_visual_test.dart' as categories;
import 'desktop_view_panels_visual_test.dart' as views;

void main() {
  categories.main();
  views.main();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'desktop floating choices actual-font light dark locale and scale gallery',
    (t) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/floating-panel-rollout',
        ),
      );
      await output.create(recursive: true);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 900);
      addTearDown(t.view.reset);
      for (final locale in ['zh', 'en']) {
        for (final brightness in Brightness.values) {
          for (final scale in [1.0, 1.5, 2.0]) {
            final p = await workspaceProvider(locale: locale);
            final boundary = GlobalKey();
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: WorkspaceHarness(
                  provider: p,
                  seedColor: const Color(0xff008577),
                  locale: Locale(locale),
                  textScale: scale,
                  brightness: brightness,
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.fromLTRB(80, 110, 80, 0),
                      child: Builder(
                        builder: (context) {
                          final l = AppLocalizations.of(context);
                          return Wrap(
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              Builder(
                                builder: (anchor) => OutlinedButton(
                                  key: const ValueKey('gallery-date'),
                                  onPressed: () => unawaited(
                                    showSkedDatePicker(
                                      context: anchor,
                                      anchorContext: anchor,
                                      initialDate: DateTime(2026, 9, 30),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    ),
                                  ),
                                  child: Text(l.semesterStartDate),
                                ),
                              ),
                              Builder(
                                builder: (anchor) => OutlinedButton(
                                  key: const ValueKey('gallery-time'),
                                  onPressed: () => unawaited(
                                    showSkedTimePicker(
                                      context: anchor,
                                      anchorContext: anchor,
                                      initialTime: const TimeOfDay(
                                        hour: 15,
                                        minute: 30,
                                      ),
                                    ),
                                  ),
                                  child: Text(l.startTime),
                                ),
                              ),
                              Builder(
                                builder: (anchor) => OutlinedButton(
                                  key: const ValueKey('gallery-periods'),
                                  onPressed: () => unawaited(
                                    showPeriodTimeSetPickerDialog(
                                      anchor,
                                      provider: p,
                                      anchorContext: anchor,
                                      selectedPeriodTimeSetId:
                                          p.periodTimeSets.first.id,
                                    ),
                                  ),
                                  child: Text(l.periodTimeSets),
                                ),
                              ),
                              SkedPopupMenuButton<String>(
                                key: const ValueKey('gallery-menu'),
                                tooltip: l.more,
                                itemBuilder: (_) => [
                                  SkedPopupMenuItem(
                                    value: 'edit',
                                    child: Text(l.editTimetable),
                                  ),
                                  SkedPopupMenuItem(
                                    value: 'rename',
                                    child: Text(l.rename),
                                  ),
                                ],
                                icon: const Icon(Icons.more_horiz),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            for (final scene in ['date', 'time', 'periods', 'menu']) {
              await t.tap(find.byKey(ValueKey('gallery-$scene')));
              await t.pumpAndSettle();
              expect(
                t.takeException(),
                isNull,
                reason: '$locale-$brightness-$scale-$scene',
              );
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                '${output.path}/$locale-${brightness.name}-$scale-$scene.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
              await t.pumpAndSettle();
            }
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
            p.dispose();
          }
        }
      }
    },
  );
}
