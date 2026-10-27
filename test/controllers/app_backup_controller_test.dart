import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/controllers/app_backup_controller.dart';
import 'package:sked/controllers/app_data_maintenance.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/data_transfer_codec.dart';

import '../support/data_transfer_codec.dart';
import '../support/workspace_harness.dart';

class _BackupCodec extends DataTransferCodec {
  _BackupCodec({this.delayed = false}) : super(run: runDataTransferInline);

  final bool delayed;
  final started = Completer<void>();
  final release = Completer<void>();
  var decodes = 0;

  @override
  Future<AppBackupData> decodeBackup(
    String source, {
    required String localeCode,
  }) async {
    decodes += 1;
    if (!started.isCompleted) started.complete();
    if (delayed) await release.future;
    return super.decodeBackup(source, localeCode: localeCode);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final localUrl in ['', 'https://local.example/v1']) {
    test(
      'restore retains local parser settings at apply time: $localUrl',
      () async {
        final app = await workspaceProvider();
        addTearDown(app.dispose);
        final backup = app.session.committedData.copyWith(
          localeCode: 'de',
          aiApiSettings: const AiApiSettings(
            customBaseUrl: 'https://backup.example/v1',
            customModel: 'backup-model',
            customPrompt: 'backup prompt',
          ),
        );
        final prepared = await app.backups.prepareJson(
          encodeAppBackup(backup, []),
        );
        await app.settingsCommands.updateCustomSchoolImportTextSettings(
          baseUrl: localUrl,
          model: localUrl.isEmpty ? '' : 'local-model',
          prompt: localUrl.isEmpty ? '' : 'local prompt',
        );
        await app.schoolImportSecrets.update('local-secret');
        final local = app.session.committedData.aiApiSettings;
        await app.backups.restorePrepared(prepared);
        final restored = app.session.committedData;
        expect(restored.localeCode, 'de');
        expect(restored.aiApiSettings.customBaseUrl, local.customBaseUrl);
        expect(restored.aiApiSettings.customModel, local.customModel);
        expect(restored.aiApiSettings.customPrompt, local.customPrompt);
        expect(app.schoolImportSecrets.value, isEmpty);
        expect(
          prepared.value.appData.aiApiSettings.customBaseUrl,
          'https://backup.example/v1',
        );
      },
    );
  }

  test(
    'confirmation applies its decoded backup without parsing it again',
    () async {
      final codec = _BackupCodec();
      final app = await workspaceProvider(codec: codec);
      addTearDown(app.dispose);
      final original = app.session.committedData;
      final prepared = await app.backups.prepareJson(
        encodeAppBackup(original.copyWith(localeCode: 'de'), []),
      );
      expect(app.session.committedData, same(original));
      expect(app.maintenance.isReserved, isFalse);
      expect(codec.decodes, 1);

      final restoring = app.backups.restorePrepared(prepared);
      expect(app.maintenance.isReserved, isTrue);
      await restoring;
      expect(codec.decodes, 1);
      expect(app.session.committedData.localeCode, 'de');
      expect(app.maintenance.isReserved, isFalse);
      expect(app.backups.isCurrent(prepared), isFalse);
    },
  );

  test('direct restore reserves before asynchronous decoding starts', () async {
    final codec = _BackupCodec(delayed: true);
    final app = await workspaceProvider(codec: codec);
    addTearDown(app.dispose);
    final original = app.session.committedData;
    final restoring = app.backups.importJson(
      encodeAppBackup(original.copyWith(localeCode: 'de'), []),
      mode: AppImportMode.replaceAll,
    );
    expect(app.maintenance.isReserved, isTrue);
    await codec.started.future;
    expect(app.session.committedData, same(original));
    await expectLater(
      app.settingsCommands.updateLocaleCode('zh'),
      throwsA(isA<AppBackupRestoreInProgressException>()),
    );
    codec.release.complete();
    await restoring;
    expect(app.maintenance.isReserved, isFalse);
    expect(app.session.committedData.localeCode, 'de');
  });

  test(
    'a late backup preview cannot enter a replacement data session',
    () async {
      final codec = _BackupCodec(delayed: true);
      final app = await workspaceProvider(codec: codec);
      addTearDown(app.dispose);
      final original = app.session.committedData;
      final preparing = app.backups.prepareJson(encodeAppBackup(original, []));
      final rejected = expectLater(preparing, throwsStateError);
      await codec.started.future;
      final reservation = app.maintenance.reserve();
      app.maintenance.release(reservation);
      codec.release.complete();
      await rejected;
      expect(app.session.committedData, same(original));
      expect(app.maintenance.isReserved, isFalse);
    },
  );

  test('a candidate cannot restore into a different owner', () async {
    final first = await workspaceProvider();
    final second = await workspaceProvider();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final prepared = await first.backups.prepareJson(
      encodeAppBackup(first.session.committedData, []),
    );
    final original = second.session.committedData;
    await expectLater(
      second.backups.restorePrepared(prepared),
      throwsStateError,
    );
    expect(second.maintenance.isReserved, isFalse);
    expect(second.session.committedData, same(original));
  });

  test(
    'replacement during an exit guard invalidates the pending confirmation',
    () async {
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final original = app.session.committedData;
      final prepared = await app.backups.prepareJson(
        encodeAppBackup(original.copyWith(localeCode: 'de'), []),
      );
      final started = Completer<void>();
      final release = Completer<bool>();
      final unregister = app.workspaces.registerExitGuard(AppMode.student, () {
        started.complete();
        return release.future;
      });
      addTearDown(unregister);
      final restoring = app.backups.restorePrepared(prepared);
      final rejected = expectLater(restoring, throwsStateError);
      await started.future;
      final reservation = app.maintenance.reserve();
      app.maintenance.release(reservation);
      release.complete(true);
      await rejected;
      expect(app.session.committedData, same(original));
      expect(app.maintenance.isReserved, isFalse);
    },
  );
}
