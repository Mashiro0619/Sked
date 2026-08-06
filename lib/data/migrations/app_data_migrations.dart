import 'migration.dart';
import 'migration_runner.dart';

/// 当前 AppData JSON 的目标版本号。
///
/// 修改步骤：
/// 1. 把这里的常量 +1。
/// 2. 在 [appDataMigrations] 注册新的 `from: 旧版本, to: 新版本` 实现。
/// 3. 编写对应的单元测试，确认旧数据能升级、新数据 round-trip 保版本号。
const int appDataCurrentSchemaVersion = 2;

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
const List<Migration> appDataMigrations = <Migration>[AppDataMigrationV1ToV2()];

/// AppData 加载路径统一使用的 runner。
const MigrationRunner appDataMigrationRunner = MigrationRunner(
  targetVersion: appDataCurrentSchemaVersion,
  migrations: appDataMigrations,
);
