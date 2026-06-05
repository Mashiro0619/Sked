import 'package:flutter/material.dart';

import '../models/timetable_models.dart';
import '../theme/general_calendar_color_theme.dart';

Color effectiveGeneralCalendarColor(
  BuildContext context,
  GeneralSchedule calendar,
) {
  return effectiveGeneralCalendarColorValue(context, calendar.colorValue);
}

Color effectiveGeneralCalendarColorValue(BuildContext context, int colorValue) {
  return switch (normalizeGeneralCalendarColorValue(colorValue)) {
    defaultGeneralCalendarColorValue => generalCalendarSlotColorOf(
      context,
      colorfulGeneralCalendarColor1Key,
    ),
    generalCalendarColorSlot2Value => generalCalendarSlotColorOf(
      context,
      colorfulGeneralCalendarColor2Key,
    ),
    generalCalendarColorSlot3Value => generalCalendarSlotColorOf(
      context,
      colorfulGeneralCalendarColor3Key,
    ),
    generalCalendarColorSlot4Value => generalCalendarSlotColorOf(
      context,
      colorfulGeneralCalendarColor4Key,
    ),
    generalCalendarColorSlot5Value => generalCalendarSlotColorOf(
      context,
      colorfulGeneralCalendarColor5Key,
    ),
    generalCalendarColorSlot6Value => generalCalendarSlotColorOf(
      context,
      colorfulGeneralCalendarColor6Key,
    ),
    _ =>
      colorValue >= 0
          ? Color(colorValue)
          : generalCalendarSlotColorOf(
              context,
              colorfulGeneralCalendarColor1Key,
            ),
  };
}

Color effectiveGeneralOccurrenceColor(
  BuildContext context,
  GeneralEventOccurrence occurrence,
) {
  final eventColorValue = occurrence.event.colorValue;
  if (eventColorValue != null) {
    return eventColorValue >= 0
        ? Color(eventColorValue)
        : effectiveGeneralCalendarColorValue(context, eventColorValue);
  }
  return effectiveGeneralCalendarColor(context, occurrence.calendar);
}

Color effectiveGeneralLunarTextColor(BuildContext context, Color fallback) {
  return generalCalendarColorThemeOf(context).lunarTextColor ?? fallback;
}

Color effectiveGeneralFestivalTextColor(BuildContext context, Color fallback) {
  return generalCalendarColorThemeOf(context).festivalTextColor ?? fallback;
}

Color effectiveGeneralSolarTermTextColor(BuildContext context, Color fallback) {
  return generalCalendarColorThemeOf(context).solarTermTextColor ?? fallback;
}
