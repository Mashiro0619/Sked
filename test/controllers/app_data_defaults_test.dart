import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/controllers/app_data_defaults.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/timetable_storage_fakes.dart';

void _mockPeriodAsset(String source) {
  rootBundle.evict(defaultPeriodTimesAssetPath);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    if (key != defaultPeriodTimesAssetPath) return null;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  });
  addTearDown(() {
    rootBundle.evict(defaultPeriodTimesAssetPath);
    messenger.setMockMessageHandler('flutter/assets', null);
  });
}

AppDataDefaults _defaultsWithoutStudentWorkspace() {
  final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
    activeMode: AppMode.general,
    enabledWorkspaces: const {AppMode.general},
  );
  final session = AppSession(
    repository: AppRepository(storage: WorkspaceMemoryStorage(data)),
    initialData: data,
    requireMutationAllowed: () {},
  );
  addTearDown(session.close);
  return AppDataDefaults(session: session, localeCodeResolver: () => 'en');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recovery defaults use the packaged periods when student is disabled',
    () async {
      final source = File(defaultPeriodTimesAssetPath).readAsStringSync();
      _mockPeriodAsset(source);
      final expected =
          ((jsonDecode(source) as Map<String, dynamic>)['data']
              as Map<String, dynamic>)['periodTimes'];

      final restored = await _defaultsWithoutStudentWorkspace().build();
      final periods = restored.studentMode.periodTimeSets.single.periodTimes;

      expect(periods, hasLength(13));
      expect(periods.map((period) => period.toJson()).toList(), expected);
    },
  );

  test('invalid packaged periods retain the recovery fallback', () async {
    _mockPeriodAsset('not valid JSON');

    final restored = await _defaultsWithoutStudentWorkspace().build();
    final periods = restored.studentMode.periodTimeSets.single.periodTimes;

    expect(periods, hasLength(12));
    expect(
      periods.map((period) => period.toJson()).toList(),
      buildDefaultPeriodTimes().map((period) => period.toJson()).toList(),
    );
  });
}
