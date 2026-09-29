import '../../utils/constants.dart';
import 'migration.dart';
import 'migration_runner.dart';

/// 当前 AppData JSON 的目标版本号。
///
/// 修改步骤：
/// 1. 把这里的常量 +1。
/// 2. 在 [appDataMigrations] 注册新的 `from: 旧版本, to: 新版本` 实现。
/// 3. 编写对应的单元测试，确认旧数据能升级、新数据 round-trip 保版本号。
const int appDataCurrentSchemaVersion = 4;

const _legacyThemeFieldKeys = <String>{
  'themeMode',
  'themeColorMode',
  'themeSeedColorValue',
  'colorfulUiColorValues',
};

class AppDataMigrationV1ToV2 extends Migration {
  const AppDataMigrationV1ToV2();

  @override
  int get from => 1;

  @override
  int get to => 2;

  @override
  Map<String, dynamic> apply(Map<String, dynamic> json) {
    final migrated = <String, dynamic>{...json};
    for (final modeKey in const ['studentMode', 'generalMode']) {
      final rawMode = json[modeKey];
      if (rawMode is! Map) continue;
      final mode = Map<String, dynamic>.from(rawMode);
      if (_legacyThemeFieldKeys.any(mode.containsKey)) continue;

      for (final themeKey in _legacyThemeFieldKeys) {
        if (json.containsKey(themeKey)) {
          mode[themeKey] = json[themeKey];
        }
      }
      migrated[modeKey] = mode;
    }

    // Keep the legacy fields until strict storage validation has inspected
    // them. Canonical AppData serialization omits them after decoding.
    return migrated;
  }
}

/// 已注册的 AppData 顶层迁移列表。
///
/// 在 [appDataMigrationRunner] 里集中注册，避免迁移逻辑散落到 fromJson。
class AppDataMigrationV2ToV3 extends Migration {
  const AppDataMigrationV2ToV3();
  @override
  int get from => 2;
  @override
  int get to => 3;
  @override
  Map<String, dynamic> apply(Map<String, dynamic> json) => {
    ...json,
    'activeMode': json['activeMode'] ?? 'student',
    'enabledWorkspaces': ['student', 'general'],
  };
}

/// Adopt mobile menu defaults once, without overwriting customized toolbars.
class AppDataMigrationV3ToV4 extends Migration {
  const AppDataMigrationV3ToV4();
  @override
  int get from => 3;
  @override
  int get to => 4;

  Map<String, dynamic> _toolbar(
    Map<String, dynamic> mode,
    List<String> oldOrder,
  ) {
    final oldKnown = [...oldOrder, 'more'];
    final order = decodeToolbarNavigationStringList(
      mode,
      'toolbarNavigationOrder',
      knownIds: oldKnown,
      defaultOrder: oldOrder,
    );
    // Validate types before applying v3's protected-settings semantics.
    final hidden = mode.containsKey('hiddenToolbarNavigationIds')
        ? decodeToolbarHiddenNavigationStringList(
            mode,
            'hiddenToolbarNavigationIds',
            knownIds: oldKnown,
          ).where((id) => id != 'settings').toList()
        : <String>[];
    final behavior = decodeToolbarHiddenItemsBehavior(
      mode,
      'toolbarHiddenItemsBehavior',
    );
    final oldDefault =
        (order.join(',') == oldOrder.join(',') ||
            order.join(',') == [...oldOrder, 'more'].join(',')) &&
        hidden.isEmpty &&
        behavior == toolbarHiddenItemsBehaviorRemove;
    final nextOrder = List<String>.from(order)
      ..insert(order.indexOf('settings'), 'workspace');
    if (!nextOrder.contains('more')) nextOrder.add('more');
    return {
      ...mode,
      'toolbarNavigationOrder': nextOrder,
      'hiddenToolbarNavigationIds': oldDefault
          ? toolbarNavigationDefaultHiddenIds
          : [...hidden, 'workspace'],
      'toolbarHiddenItemsBehavior': behavior,
    };
  }

  @override
  Map<String, dynamic> apply(Map<String, dynamic> json) {
    var result = <String, dynamic>{...json};
    const student = ['timetable', 'week', 'view', 'settings'];
    const general = ['category', 'date', 'view', 'settings'];
    for (final (key, order) in [
      ('studentMode', student),
      ('generalMode', general),
    ]) {
      final raw = json[key];
      // Invalid mode containers remain untouched for strict storage validation.
      if (raw is Map<String, dynamic>) result[key] = _toolbar(raw, order);
    }
    if (!json.containsKey('studentMode') && json.containsKey('timetables')) {
      result = _toolbar(result, student);
    }
    return result;
  }
}

const List<Migration> appDataMigrations = <Migration>[
  AppDataMigrationV1ToV2(),
  AppDataMigrationV2ToV3(),
  AppDataMigrationV3ToV4(),
];

/// AppData 加载路径统一使用的 runner。
const MigrationRunner appDataMigrationRunner = MigrationRunner(
  targetVersion: appDataCurrentSchemaVersion,
  migrations: appDataMigrations,
);
