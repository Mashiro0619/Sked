import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/utils/mobile_toolbar_layout.dart';

void main() {
  Map<String, dynamic> old({
    Map<String, dynamic>? student,
    Map<String, dynamic>? general,
  }) => {
    ...buildInitialAppData(buildDefaultPeriodTimes()).toJson(),
    'schemaVersion': 3,
    'studentMode': {
      ...buildInitialAppData(buildDefaultPeriodTimes()).studentMode.toJson(),
      'toolbarNavigationOrder': ['timetable', 'week', 'view', 'settings'],
      'hiddenToolbarNavigationIds': [],
      ...?student,
    },
    'generalMode': {
      ...GeneralScheduleData.createDefault().toJson(),
      'toolbarNavigationOrder': ['category', 'date', 'view', 'settings'],
      'hiddenToolbarNavigationIds': [],
      ...?general,
    },
  };
  test(
    'new installation and v3 defaults put workspace and settings in More',
    () {
      final fresh = buildInitialAppData(buildDefaultPeriodTimes());
      final upgraded = AppData.fromJson(old());
      for (final p in [fresh, upgraded]) {
        expect(p.toJson()['schemaVersion'], 4);
        expect(
          p.studentMode.toolbarNavigationOrder,
          studentToolbarNavigationDefaultOrder,
        );
        expect(
          p.generalMode.toolbarNavigationOrder,
          generalToolbarNavigationDefaultOrder,
        );
        expect(p.studentMode.hiddenToolbarNavigationIds, [
          'workspace',
          'settings',
        ]);
        expect(p.generalMode.hiddenToolbarNavigationIds, [
          'workspace',
          'settings',
        ]);
      }
    },
  );
  test('missing legacy fields acquire defaults and input stays untouched', () {
    final input = old();
    for (final key in ['studentMode', 'generalMode']) {
      final mode = input[key] as Map;
      mode.remove('toolbarNavigationOrder');
      mode.remove('hiddenToolbarNavigationIds');
      mode.remove('toolbarHiddenItemsBehavior');
    }
    final result = appDataMigrationRunner.run(input);
    expect((result['studentMode'] as Map)['hiddenToolbarNavigationIds'], [
      'workspace',
      'settings',
    ]);
    expect(
      (input['studentMode'] as Map).containsKey('hiddenToolbarNavigationIds'),
      isFalse,
    );
  });
  test(
    'custom order and ordinary hiding policy survive once-only migration',
    () {
      final upgraded = AppData.fromJson(
        old(
          student: {
            'toolbarNavigationOrder': [
              'settings',
              'week',
              'more',
              'view',
              'timetable',
            ],
            'hiddenToolbarNavigationIds': ['week', 'more'],
            'toolbarHiddenItemsBehavior': 'more',
          },
        ),
      );
      expect(upgraded.studentMode.toolbarNavigationOrder, [
        'workspace',
        'settings',
        'week',
        'more',
        'view',
        'timetable',
      ]);
      expect(upgraded.studentMode.hiddenToolbarNavigationIds, [
        'week',
        'more',
        'workspace',
      ]);
      expect(upgraded.studentMode.toolbarHiddenItemsBehavior, 'more');
      final changed = upgraded.copyWith(
        studentMode: upgraded.studentMode.copyWith(
          hiddenToolbarNavigationIds: [],
        ),
      );
      expect(
        AppData.fromJson(changed.toJson())
            .studentMode
            .hiddenToolbarNavigationIds,
        isEmpty,
      );
    },
  );
  for (final field in [
    'toolbarNavigationOrder',
    'hiddenToolbarNavigationIds',
    'toolbarHiddenItemsBehavior',
  ]) {
    for (final value in [
      null,
      42,
      {},
      [true],
    ]) {
      test('v3 migration rejects invalid $field=$value', () {
        expect(
          () => AppData.fromJson(old(student: {field: value})),
          throwsFormatException,
        );
      });
    }
  }
  test('mobile resolver protects essential actions without reviving removed shortcuts', () {
    for (final order in [
      studentToolbarNavigationDefaultOrder,
      generalToolbarNavigationDefaultOrder,
    ]) {
      final p = MobileToolbarLayout.resolve(
        order: order,
        hiddenIds: [...order],
        hiddenBehavior: 'remove',
        defaultOrder: order,
        availableIds: order.toSet(),
      );
      expect(p.toolbarIds, ['more']);
      expect(p.menuIds, ['workspace', 'settings']);
      expect(p.moreRequired, isTrue);
    }
  });
  test('placement uses one order and hides unavailable workspace without losing preference', () {
    final p = MobileToolbarLayout.resolve(
      order: ['settings', 'workspace', 'category', 'date', 'view', 'more'],
      hiddenIds: ['workspace', 'settings', 'category'],
      hiddenBehavior: 'more',
      defaultOrder: generalToolbarNavigationDefaultOrder,
      availableIds: {'settings', 'category', 'date', 'view'},
      hasFixedMenuItems: true,
    );
    expect(p.toolbarIds, ['date', 'view', 'more']);
    expect(p.menuIds, ['settings', 'category']);
  });
  test(
    'v3 composite backup upgrades once and retains subsequent customization',
    () {
      final source = ImportExportEnvelope(
        schema: appBackupSchema,
        version: appBackupVersion,
        data: {'appData': old(), 'schoolSites': <Object>[]},
      ).encode();
      final decoded = decodeAppBackup(source);
      expect(decoded.appData.studentMode.hiddenToolbarNavigationIds, [
        'workspace',
        'settings',
      ]);
      final changed = decoded.appData.copyWith(
        studentMode: decoded.appData.studentMode.copyWith(
          hiddenToolbarNavigationIds: ['settings'],
          toolbarNavigationOrder: [
            'workspace',
            'week',
            'view',
            'timetable',
            'settings',
            'more',
          ],
        ),
      );
      final restored = decodeAppBackup(encodeAppBackup(changed, [])).appData;
      expect(restored.studentMode.hiddenToolbarNavigationIds, ['settings']);
      expect(restored.studentMode.toolbarNavigationOrder.first, 'workspace');
    },
  );
}
