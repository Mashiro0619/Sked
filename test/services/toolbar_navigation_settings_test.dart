import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/settings_service.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://toolbar-navigation-test';
}

void main() {
  AppData baseData() => AppData.fromJson(const {});

  group('SettingsService toolbar navigation', () {
    const service = SettingsService();

    test('normalizes student order and guards repeated writes', () {
      final initial = baseData();
      final updated = service.updateStudentToolbarNavigationOrder(
        initial,
        const ['view', 'view', 'unknown'],
      );

      expect(updated.studentMode.toolbarNavigationOrder, [
        'view',
        'timetable',
        'week',
        'settings',
        'more',
      ]);
      expect(
        identical(
          updated,
          service.updateStudentToolbarNavigationOrder(
            updated,
            updated.studentMode.toolbarNavigationOrder,
          ),
        ),
        isTrue,
      );
    });

    test('updates student visibility while protecting settings', () {
      final initial = baseData();
      final hidden = service.updateStudentToolbarNavigationVisibility(
        initial,
        'week',
        false,
      );
      expect(hidden.studentMode.hiddenToolbarNavigationIds, ['week']);

      expect(
        identical(
          hidden,
          service.updateStudentToolbarNavigationVisibility(
            hidden,
            'week',
            false,
          ),
        ),
        isTrue,
      );
      expect(
        identical(
          hidden,
          service.updateStudentToolbarNavigationVisibility(
            hidden,
            'settings',
            false,
          ),
        ),
        isTrue,
      );

      final shown = service.updateStudentToolbarNavigationVisibility(
        hidden,
        'week',
        true,
      );
      expect(shown.studentMode.hiddenToolbarNavigationIds, isEmpty);

      final normalized = service.updateStudentToolbarNavigationHiddenIds(
        initial,
        const ['settings', 'week', 'week', 'unknown'],
      );
      expect(normalized.studentMode.hiddenToolbarNavigationIds, ['week']);
      expect(
        identical(
          normalized,
          service.updateStudentToolbarNavigationHiddenIds(normalized, const [
            'week',
          ]),
        ),
        isTrue,
      );
    });

    test('normalizes student hidden-item behavior', () {
      final initial = baseData();
      final updated = service.updateStudentToolbarHiddenItemsBehavior(
        initial,
        toolbarHiddenItemsBehaviorMore,
      );
      expect(updated.studentMode.toolbarHiddenItemsBehavior, 'more');
      expect(
        identical(
          updated,
          service.updateStudentToolbarHiddenItemsBehavior(updated, 'more'),
        ),
        isTrue,
      );
    });
  });

  group('GeneralCalendarService toolbar navigation', () {
    const service = GeneralCalendarService();

    GeneralScheduleData baseGeneralData() => const GeneralScheduleData(
      activeScheduleId: 'calendar',
      schedules: [
        GeneralSchedule(id: 'calendar', name: 'Calendar', events: []),
      ],
    );

    test('normalizes general order and guards repeated writes', () {
      final initial = baseGeneralData();
      final updated = service.updateToolbarNavigationOrder(initial, const [
        'date',
        'date',
        'unknown',
      ]);

      expect(updated.toolbarNavigationOrder, [
        'date',
        'category',
        'view',
        'settings',
        'more',
      ]);
      expect(
        identical(
          updated,
          service.updateToolbarNavigationOrder(
            updated,
            updated.toolbarNavigationOrder,
          ),
        ),
        isTrue,
      );
    });

    test('updates general visibility and hidden IDs safely', () {
      final initial = baseGeneralData();
      final hidden = service.updateToolbarNavigationVisibility(
        initial,
        'category',
        false,
      );
      expect(hidden.hiddenToolbarNavigationIds, ['category']);
      expect(
        identical(
          hidden,
          service.updateToolbarNavigationVisibility(hidden, 'category', false),
        ),
        isTrue,
      );
      expect(
        identical(
          hidden,
          service.updateToolbarNavigationVisibility(hidden, 'settings', false),
        ),
        isTrue,
      );

      final shown = service.updateToolbarNavigationVisibility(
        hidden,
        'category',
        true,
      );
      expect(shown.hiddenToolbarNavigationIds, isEmpty);

      final normalized = service.updateToolbarNavigationHiddenIds(
        initial,
        const ['settings', 'date', 'date', 'unknown'],
      );
      expect(normalized.hiddenToolbarNavigationIds, ['date']);
      expect(
        identical(
          normalized,
          service.updateToolbarNavigationHiddenIds(normalized, const ['date']),
        ),
        isTrue,
      );
    });

    test('normalizes general hidden-item behavior', () {
      final initial = baseGeneralData();
      final updated = service.updateToolbarHiddenItemsBehavior(
        initial,
        toolbarHiddenItemsBehaviorMore,
      );
      expect(updated.toolbarHiddenItemsBehavior, 'more');
      expect(
        identical(
          updated,
          service.updateToolbarHiddenItemsBehavior(updated, 'more'),
        ),
        isTrue,
      );
    });
  });

  group('TimetableProvider toolbar navigation persistence', () {
    Future<TimetableProvider> loadProvider(
      _MemoryTimetableStorage storage,
    ) async {
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      await provider.load();
      return provider;
    }

    test('student updates save once and no-op mutations do not save', () async {
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await loadProvider(storage);
      addTearDown(provider.dispose);
      storage.saveCount = 0;

      final defaultOrder = provider.studentToolbarNavigationOrder;
      await provider.updateStudentToolbarNavigationOrder(defaultOrder);
      expect(storage.saveCount, 0);

      await provider.updateStudentToolbarNavigationOrder(const [
        'week',
        'timetable',
        'view',
        'settings',
        'more',
      ]);
      expect(storage.saveCount, 1);

      await provider.updateStudentToolbarNavigationVisibility('week', false);
      expect(storage.saveCount, 2);
      await provider.updateStudentToolbarNavigationVisibility('week', true);
      expect(storage.saveCount, 3);
      await provider.updateStudentToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorMore,
      );
      expect(storage.saveCount, 4);
      await provider.updateStudentToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorMore,
      );
      expect(storage.saveCount, 4);

      await provider.updateStudentToolbarNavigationVisibility(
        'settings',
        false,
      );
      expect(storage.saveCount, 4);
      await provider.updateStudentToolbarNavigationHiddenIds(const [
        'week',
        'settings',
        'week',
        'unknown',
      ]);
      expect(storage.saveCount, 5);
      expect(provider.studentHiddenToolbarNavigationIds, ['week']);

      await provider.updateStudentToolbarNavigationHiddenIds(const ['week']);
      expect(storage.saveCount, 5);
    });

    test('general hidden ID updates save once and protect settings', () async {
      final storage = _MemoryTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await loadProvider(storage);
      addTearDown(provider.dispose);
      storage.saveCount = 0;

      final defaultOrder = provider.generalToolbarNavigationOrder;
      await provider.updateGeneralToolbarNavigationOrder(defaultOrder);
      expect(storage.saveCount, 0);
      await provider.updateGeneralToolbarNavigationOrder(const [
        'date',
        'category',
        'view',
        'settings',
        'more',
      ]);
      expect(storage.saveCount, 1);

      await provider.updateGeneralToolbarNavigationHiddenIds(const [
        'category',
        'settings',
        'category',
      ]);
      expect(storage.saveCount, 2);
      expect(provider.generalHiddenToolbarNavigationIds, ['category']);

      await provider.updateGeneralToolbarNavigationHiddenIds(const [
        'category',
      ]);
      expect(storage.saveCount, 2);

      await provider.updateGeneralToolbarNavigationVisibility(
        'settings',
        false,
      );
      expect(storage.saveCount, 2);
      await provider.updateGeneralToolbarNavigationVisibility('category', true);
      expect(storage.saveCount, 3);
      expect(provider.generalHiddenToolbarNavigationIds, isEmpty);
      await provider.updateGeneralToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorMore,
      );
      expect(storage.saveCount, 4);
      await provider.updateGeneralToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorMore,
      );
      expect(storage.saveCount, 4);
    });
  });
}
