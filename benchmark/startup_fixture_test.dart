import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/models/school_site_models.dart';
import 'package:sked/services/import_export_service.dart';

import 'src/benchmark_fixtures.dart';
import 'src/startup_protocol.dart';
import 'src/ui_performance_fixtures.dart';

/// Preparation is a separate, unmeasured process. Never invoke this in a child
/// whose startup is being measured, and never modify an existing fixture root.
void main() {
  test('write immutable startup inputs', () async {
    const output = String.fromEnvironment('SKED_STARTUP_FIXTURES');
    if (!path.isAbsolute(output)) {
      throw StateError('Set SKED_STARTUP_FIXTURES.');
    }
    final root = Directory(path.normalize(output));
    if (await root.exists()) throw StateError('Fixture root already exists.');
    await root.create(recursive: true);
    await checkedDirectory(root.path);
    final sites = PerformanceFixtures.build().schoolSites;
    for (final fixture in buildUiPerformanceFixtures()) {
      final data = const ImportExportService().normalizeAppData(
        fixture.data.copyWith(
          privacyPolicyAcceptedVersion: startupPrivacyVersion,
          privacyPolicyAcceptedAtIso: '2026-08-07T00:00:00.000Z',
          notificationSettings: fixture.data.notificationSettings.copyWith(
            enabled: true,
          ),
        ),
        localeCode: 'zh',
      );
      final directory = Directory(path.join(root.path, fixture.name));
      await Directory(path.join(directory.path, 'archive'))
          .create(recursive: true);
      final files = <String, String>{
        'archive/Sked_data.json': data.encode(),
        'archive/Sked_school_sites.json': encodeSchoolSiteStorageSnapshot(
          sites,
        ),
        'desktop-layout.json': jsonEncode({'version': 1, 'regions': {}}),
        'developer-ui.json': 'false',
      };
      for (final entry in files.entries) {
        await File(path.join(directory.path, entry.key))
            .writeAsString(entry.value, flush: true);
      }
      await writeJson(File(path.join(directory.path, 'fixture.json')), {
        'protocolVersion': startupProtocolVersion,
        'dataset': fixture.name,
        'sourceDatasetVersion': performanceDatasetVersion,
        'uiDatasetVersion': uiPerformanceDatasetVersion,
        'selectedDate': startupSelectedDate,
        'inputDate': startupInputDate,
        'semanticSha256': semanticHash(data),
        'semanticSummary': semanticSummary(data),
        'files': {
          for (final entry in files.entries)
            entry.key: sha256.convert(utf8.encode(entry.value)).toString(),
        },
      });
    }
  });
}
