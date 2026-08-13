import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/utils/general_schedule_colors.dart';

void main() {
  testWidgets('default general calendar color uses calendar slot fallback', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123456)),
        ),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const calendar = GeneralSchedule(
      id: 'default',
      name: 'Default',
      events: [],
    );

    expect(
      effectiveGeneralCalendarColor(capturedContext, calendar),
      const Color(defaultGeneralCalendarColorValue),
    );
  });

  testWidgets('calendar color slots use independent fallback palette', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123456)),
        ),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot2Value,
      ),
      const Color(0xFF64B5F6),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot3Value,
      ),
      const Color(0xFFFFB74D),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot4Value,
      ),
      const Color(0xFFBA68C8),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot5Value,
      ),
      const Color(0xFF81C784),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot6Value,
      ),
      const Color(0xFFE57373),
    );
  });

  testWidgets('custom calendar slot colors override generated colors', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          seedColor: const Color(0xFF123456),
          brightness: Brightness.light,
          themeColorMode: themeColorModeColorful,
          colorfulUiColorValues: const {
            colorfulGeneralCalendarColor2Key: 0xFF778899,
          },
        ),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot2Value,
      ),
      const Color(0xFF778899),
    );
  });

  testWidgets('custom month text colors are scoped to colorful mode', (
    tester,
  ) async {
    const values = {
      colorfulGeneralLunarTextColorKey: 0xFF223344,
      colorfulGeneralFestivalTextColorKey: 0xFFAA5500,
      colorfulGeneralSolarTermTextColorKey: 0xFF336600,
    };
    const lunarFallback = Color(0xFF010203);
    const festivalFallback = Color(0xFF040506);
    const solarTermFallback = Color(0xFF070809);
    late BuildContext capturedContext;

    Future<void> pumpWithMode(String themeColorMode) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            seedColor: const Color(0xFF123456),
            brightness: Brightness.light,
            themeColorMode: themeColorMode,
            colorfulUiColorValues: values,
          ),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWithMode(themeColorModeColorful);
    expect(
      effectiveGeneralLunarTextColor(capturedContext, lunarFallback),
      const Color(0xFF223344),
    );
    expect(
      effectiveGeneralFestivalTextColor(capturedContext, festivalFallback),
      const Color(0xFFAA5500),
    );
    expect(
      effectiveGeneralSolarTermTextColor(capturedContext, solarTermFallback),
      const Color(0xFF336600),
    );

    await pumpWithMode(themeColorModeSingle);
    expect(
      effectiveGeneralLunarTextColor(capturedContext, lunarFallback),
      lunarFallback,
    );
    expect(
      effectiveGeneralFestivalTextColor(capturedContext, festivalFallback),
      festivalFallback,
    );
    expect(
      effectiveGeneralSolarTermTextColor(capturedContext, solarTermFallback),
      solarTermFallback,
    );
  });

  testWidgets('legacy auto calendar colors resolve to calendar slots', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123456)),
        ),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        legacyAutoGeneralCalendarColorSecondaryValue,
      ),
      const Color(0xFF64B5F6),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        legacyAutoGeneralCalendarColorTertiaryValue,
      ),
      const Color(0xFFFFB74D),
    );
  });

  testWidgets('legacy UI color keys do not affect calendar slots', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          seedColor: const Color(0xFF123456),
          brightness: Brightness.light,
          themeColorMode: themeColorModeColorful,
          colorfulUiColorValues: const {
            colorfulUiPrimaryKey: 0xFF010203,
            colorfulUiSecondaryKey: 0xFF112233,
            colorfulUiTertiaryKey: 0xFF445566,
          },
        ),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        defaultGeneralCalendarColorValue,
      ),
      const Color(0xFF4DB6AC),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot2Value,
      ),
      const Color(0xFF64B5F6),
    );
    expect(
      effectiveGeneralCalendarColorValue(
        capturedContext,
        generalCalendarColorSlot3Value,
      ),
      const Color(0xFFFFB74D),
    );
  });

  testWidgets('custom calendar and event colors override theme primary', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF123456)),
        ),
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const calendar = GeneralSchedule(
      id: 'custom',
      name: 'Custom',
      colorValue: 0xFFABCDEF,
      events: [],
    );
    final event = GeneralEvent(
      id: 'event',
      calendarId: 'custom',
      title: 'Event',
      startDateTimeIso: '2026-06-04T09:00:00.000',
      endDateTimeIso: '2026-06-04T10:00:00.000',
      colorValue: 0xFF445566,
    );
    final occurrence = GeneralEventOccurrence(
      event: event,
      calendar: calendar,
      start: DateTime(2026, 6, 4, 9),
      end: DateTime(2026, 6, 4, 10),
      sequence: 0,
    );

    expect(
      effectiveGeneralCalendarColor(capturedContext, calendar),
      const Color(0xFFABCDEF),
    );
    expect(
      effectiveGeneralOccurrenceColor(capturedContext, occurrence),
      const Color(0xFF445566),
    );
  });
}
