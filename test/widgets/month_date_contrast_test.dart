import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/theme/color_contrast.dart';
import 'package:sked/theme/sked_surface.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final brightness in Brightness.values) {
      for (final lowContrastTheme in [false, true]) {
        testWidgets(
          'outside-month dates remain readable on $platform $brightness custom=$lowContrastTheme',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = platform == TargetPlatform.android
                ? const Size(390, 844)
                : const Size(1440, 900);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final initial = buildInitialAppData(buildDefaultPeriodTimes());
            final app = await workspaceProvider(
              mode: AppMode.general,
              storage: WorkspaceMemoryStorage(
                initial.copyWith(
                  activeMode: AppMode.general,
                  generalMode: initial.generalMode.copyWith(
                    selectedDateIso: '2026-09-08',
                    defaultView: generalViewMonth,
                    showLunarCalendar: true,
                  ),
                ),
              ),
            );
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              app.dispose();
            });
            await tester.pumpWidget(
              WorkspaceHarness(
                provider: app,
                brightness: brightness,
                home: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return Theme(
                      data: lowContrastTheme
                          ? theme.copyWith(
                              colorScheme: theme.colorScheme.copyWith(
                                onSurfaceVariant: theme.colorScheme.surface,
                              ),
                            )
                          : theme,
                      child: const GeneralScheduleHomeScreen(),
                    );
                  },
                ),
              ),
            );
            await tester.pumpAndSettle();
            final cell = find.byKey(
              const ValueKey('general-month-day-cell-2026-8-31'),
            );
            final number = find.descendant(of: cell, matching: find.text('31'));
            expect(number, findsOneWidget);
            final textColor = tester.widget<Text>(number).style!.color!;
            final surface = platform == TargetPlatform.windows
                ? tester
                      .widget<Material>(
                        find.descendant(
                          of: cell,
                          matching: find.byKey(
                            const ValueKey('desktop-month-day-surface'),
                          ),
                        ),
                      )
                      .color!
                : SkedSurface.colorOf(tester.element(number));
            expect(
              colorContrastRatio(Color.alphaBlend(textColor, surface), surface),
              greaterThanOrEqualTo(4.5),
            );
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
}
