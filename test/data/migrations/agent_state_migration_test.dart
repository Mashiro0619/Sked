import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/data/migrations/app_data_migrations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  AppData data() => buildInitialAppData(buildDefaultPeriodTimes());
  final ledger =
      ApplicationLedger(generation: 'd1d0c5ea-5dca-43b8-8a3b-d924f6de059e')
          .append(
            OperationReceipt(
              operationId: 'operation-1',
              sequence: 1,
              commandDigest: '1' * 64,
              completedAtIso: '2026-10-30T00:00:00Z',
              result: {'created': 'timetable'},
            ),
          );
  const settings = AgentSettings(
    enabled: true,
    permissionMode: AgentPermissionMode.full,
    endpoint: 'https://example.test/v1',
    model: 'model',
    credentialRef: 'local-reference',
  );

  test(
    'v4 migration is deterministic and cannot adopt unknown Agent authority',
    () {
      final old = data().toJson()
        ..['schemaVersion'] = 4
        ..['agentSettings'] = settings.toJson()
        ..['applicationLedger'] = ledger.toJson();
      final before = jsonEncode(old);
      final first = appDataMigrationRunner.run(old);
      final second = appDataMigrationRunner.run(old);
      expect(first, second);
      expect(jsonEncode(old), before);
      expect(first['agentSettings'], const AgentSettings().toJson());
      expect(first['applicationLedger'], isNull);
      expect(first['schemaVersion'], 5);
      expect(appDataMigrationRunner.run(first), first);
      final decoded = AppData.decodeStorageSnapshot(jsonEncode(old));
      expect(decoded.agentSettings, const AgentSettings());
      expect(decoded.applicationLedger, isNull);
    },
  );

  test(
    'local v5 snapshots round trip exact settings and retained receipts',
    () {
      final original = data().copyWith(
        agentSettings: settings,
        applicationLedger: ledger,
      );
      final decoded = AppData.decodeStorageSnapshot(original.encode());
      expect(decoded.agentSettings, settings);
      expect(decoded.applicationLedger, ledger);
      expect(decoded.copyWith(localeCode: 'zh').applicationLedger, ledger);
      expect(
        decoded.copyWith(applicationLedger: null).applicationLedger,
        isNull,
      );
    },
  );

  test('v5 local decoding refuses missing and malformed Agent state', () {
    for (final key in ['agentSettings', 'applicationLedger']) {
      final missing = data().toJson()..remove(key);
      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(missing)),
        throwsFormatException,
      );
      expect(() => AppData.fromJson(missing), throwsFormatException);
      final malformed = data().toJson()..[key] = false;
      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(malformed)),
        throwsFormatException,
      );
    }
    final malformed = data().copyWith(applicationLedger: ledger).toJson();
    (((malformed['applicationLedger'] as Map)['receipts'] as List).first
        as Map)['result'] = {
      1: true,
    };
    expect(() => AppData.fromJson(malformed), throwsFormatException);
  });

  test('portable backup omits local-only state while recovery retains it', () {
    final original = data().copyWith(
      agentSettings: settings,
      applicationLedger: ledger,
    );
    final portable = encodeAppBackup(original, const []);
    expect(portable, isNot(contains('agentSettings')));
    expect(portable, isNot(contains('applicationLedger')));
    expect(portable, isNot(contains('local-reference')));
    final imported = decodeAppBackup(portable).appData;
    expect(imported.agentSettings, const AgentSettings());
    expect(imported.applicationLedger, isNull);
    final recovery = encodeAppBackupForRecovery(original, const []);
    final restored = decodeAppBackupForRecovery(recovery).appData;
    expect(restored.agentSettings, settings);
    expect(restored.applicationLedger, ledger);
    final externallyImported = decodeAppBackup(recovery).appData;
    expect(externallyImported.agentSettings, const AgentSettings());
    expect(externallyImported.applicationLedger, isNull);
  });

  test('legacy AppData envelope also excludes or ignores local-only state', () {
    final original = data().copyWith(
      agentSettings: settings,
      applicationLedger: ledger,
    );
    final portable = encodeAppDataEnvelope(original);
    expect(portable, isNot(contains('agentSettings')));
    expect(
      decodeAppDataEnvelope(portable).agentSettings,
      const AgentSettings(),
    );
    final forged = ImportExportEnvelope(
      schema: appDataSchema,
      version: importExportVersion,
      data: original.toJson(),
    ).encode();
    expect(decodeAppDataEnvelope(forged).applicationLedger, isNull);
    expect(
      decodeAppBackup(forged).appData.agentSettings,
      const AgentSettings(),
    );
    expect(
      decodeAppBackupForRecovery(forged).appData.applicationLedger,
      ledger,
    );
  });
}
