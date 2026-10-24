import '../models/timetable_models.dart';
import '../services/general_calendar_service.dart';
import 'app_session.dart';

/// General calendar/event mutations with explicit session and save ownership.
/// The pure calendar service remains responsible for recurrence semantics.
class GeneralCommands {
  GeneralCommands({
    required this._session,
    required this._persist,
    this._service = const GeneralCalendarService(),
  });

  final AppSession _session;
  final Future<void> Function() _persist;
  final GeneralCalendarService _service;

  GeneralScheduleData get _data => _session.data.generalMode;

  void _requireEnabled() {
    if (!_session.data.isWorkspaceEnabled(AppMode.general)) {
      throw StateError('Workspace is disabled: general');
    }
  }

  void _replace(GeneralScheduleData next) {
    _session.replaceData(_session.data.copyWith(generalMode: next));
  }

  Future<void> switchSchedule(String id) async {
    _requireEnabled();
    final next = _service.switchSchedule(_data, id);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> addSchedule({String? name, int? colorValue}) async {
    _requireEnabled();
    _replace(
      _service.addSchedule(
        _data,
        name: name,
        colorValue: colorValue,
        localeCode: _session.data.localeCode,
      ),
    );
    await _persist();
  }

  Future<void> renameSchedule(String id, String name) async {
    _requireEnabled();
    final next = _service.renameSchedule(_data, id, name);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> updateSchedule(GeneralSchedule schedule) async {
    _requireEnabled();
    final next = _service.updateSchedule(_data, schedule);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> updateScheduleColor(String id, int colorValue) async {
    _requireEnabled();
    final next = _service.updateScheduleColor(_data, id, colorValue);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> updateScheduleVisibility(String id, bool visible) async {
    _requireEnabled();
    _replace(_service.updateScheduleVisibility(_data, id, visible));
    await _persist();
  }

  Future<void> deleteSchedule(String id) async {
    _requireEnabled();
    _replace(
      _service.deleteSchedule(_data, id, localeCode: _session.data.localeCode),
    );
    await _persist();
  }

  Future<void> updateCustomDayMinWidth(int? value) async {
    _requireEnabled();
    final width = normalizeGeneralCustomDayMinWidth(value);
    if (width == _data.customDayMinWidth) return;
    _replace(_data.copyWith(customDayMinWidth: width));
    await _persist();
  }

  Future<void> updateDisplaySettings({
    String? defaultView,
    String? viewSwitchBehavior,
    String? toolbarWidthPolicy,
    String? dateLabelFormat,
    bool? fitWeekColumnsToWidth,
    bool? showWeekends,
    bool? showLunarCalendar,
    int? dayStartHour,
    int? dayEndHour,
    int? timeGridMinutes,
    int? timeGridHourHeight,
    bool? closeEventPopupOnOutsideTap,
    bool? showAddEventFab,
    bool? enableLongPressAddEvent,
    bool? allDayTimelineCollapsed,
    List<String>? toolbarNavigationOrder,
    List<String>? hiddenToolbarNavigationIds,
    String? toolbarHiddenItemsBehavior,
  }) async {
    _requireEnabled();
    _replace(
      _service.updateDisplaySettings(
        _data,
        defaultView: defaultView,
        viewSwitchBehavior: viewSwitchBehavior,
        toolbarWidthPolicy: toolbarWidthPolicy,
        dateLabelFormat: dateLabelFormat,
        fitWeekColumnsToWidth: fitWeekColumnsToWidth,
        showWeekends: showWeekends,
        showLunarCalendar: showLunarCalendar,
        dayStartHour: dayStartHour,
        dayEndHour: dayEndHour,
        timeGridMinutes: timeGridMinutes,
        timeGridHourHeight: timeGridHourHeight,
        closeEventPopupOnOutsideTap: closeEventPopupOnOutsideTap,
        showAddEventFab: showAddEventFab,
        enableLongPressAddEvent: enableLongPressAddEvent,
        allDayTimelineCollapsed: allDayTimelineCollapsed,
        toolbarNavigationOrder: toolbarNavigationOrder,
        hiddenToolbarNavigationIds: hiddenToolbarNavigationIds,
        toolbarHiddenItemsBehavior: toolbarHiddenItemsBehavior,
      ),
    );
    await _persist();
  }

  Future<void> updateToolbarNavigationOrder(List<String> order) async {
    _requireEnabled();
    final next = _service.updateToolbarNavigationOrder(_data, order);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> updateToolbarNavigationVisibility(
    String id,
    bool visible,
  ) async {
    _requireEnabled();
    final next = _service.updateToolbarNavigationVisibility(_data, id, visible);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> updateToolbarNavigationHiddenIds(List<String> ids) async {
    _requireEnabled();
    final next = _service.updateToolbarNavigationHiddenIds(_data, ids);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> updateToolbarHiddenItemsBehavior(String behavior) async {
    _requireEnabled();
    final next = _service.updateToolbarHiddenItemsBehavior(_data, behavior);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> saveEvent(GeneralEvent event) async {
    _requireEnabled();
    final next = _service.saveEvent(_data, event);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  GeneralEvent prepareOccurrenceEdit(
    GeneralEventOccurrence occurrence,
    GeneralEventEditScope scope,
  ) => _service.prepareOccurrenceEdit(occurrence, scope);

  Future<GeneralEvent> editOccurrence(
    GeneralEventOccurrence occurrence,
    GeneralEvent draft,
    GeneralEventEditScope scope,
  ) async {
    _requireEnabled();
    final result = _service.editOccurrence(_data, occurrence, draft, scope);
    _replace(result.data);
    await _persist();
    return result.event;
  }

  Future<void> deleteOccurrenceScope(
    GeneralEventOccurrence occurrence,
    GeneralEventEditScope scope,
  ) => switch (scope) {
    GeneralEventEditScope.thisOccurrence => deleteOccurrence(occurrence),
    GeneralEventEditScope.thisAndFollowing => deleteFutureOccurrences(
      occurrence,
    ),
    GeneralEventEditScope.entireSeries => deleteEvent(occurrence.event.id),
  };

  Future<void> deleteEvent(String eventId) async {
    _requireEnabled();
    _replace(_service.deleteEvent(_data, eventId));
    await _persist();
  }

  Future<GeneralEvent> duplicateOccurrence(
    GeneralEventOccurrence occurrence,
  ) async {
    _requireEnabled();
    final result = _service.duplicateOccurrence(_data, occurrence);
    _replace(result.data);
    await _persist();
    return result.event;
  }

  Future<void> deleteOccurrence(GeneralEventOccurrence occurrence) async {
    _requireEnabled();
    _replace(_service.deleteOccurrence(_data, occurrence));
    await _persist();
  }

  Future<void> deleteFutureOccurrences(
    GeneralEventOccurrence occurrence,
  ) async {
    _requireEnabled();
    _replace(_service.deleteFutureOccurrences(_data, occurrence));
    await _persist();
  }

  Future<void> dismissReminder(GeneralEventOccurrence occurrence) async {
    _requireEnabled();
    _replace(
      _service.dismissReminder(
        _data,
        occurrence,
        defaultMinutesBefore:
            _session.data.notificationSettings.generalDefaultMinutesBefore,
      ),
    );
    await _persist();
  }

  Future<void> restoreReminder(GeneralEventOccurrence occurrence) async {
    _requireEnabled();
    _replace(_service.restoreReminder(_data, occurrence));
    await _persist();
  }
}
