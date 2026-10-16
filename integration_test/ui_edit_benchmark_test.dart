import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../benchmark/src/ui_edit_runtime_adapter.dart';
import '../benchmark/src/ui_edit_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });
  testWidgets(
    'profiles actual course and event editor save journeys',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final report = await runUiEditBenchmarks(
        tester,
        createSession: createUiEditSession,
        label: const String.fromEnvironment(
          'SKED_UI_EDIT_LABEL',
          defaultValue: 'local',
        ),
        revision: const String.fromEnvironment(
          'SKED_UI_EDIT_REVISION',
          defaultValue: 'unknown',
        ),
        datasets: const String.fromEnvironment(
          'SKED_UI_EDIT_DATASETS',
          defaultValue: 'sparse,1000,5000',
        ).split(',').map((value) => value.trim()).toList(),
        requireProfile: !const bool.fromEnvironment(
          'SKED_UI_EDIT_ALLOW_DEBUG_SMOKE',
        ),
      );
      binding.reportData = {'uiEdit': report};
    },
    timeout: Timeout.none,
    semanticsEnabled: false,
  );
}
