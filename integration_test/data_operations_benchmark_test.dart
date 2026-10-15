import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../benchmark/src/data_operations_runtime_adapter.dart';
import '../benchmark/src/data_operations_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('measures native disk operations with isolated fixed data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final report = await runDataOperationsBenchmarks(
      runtimeFactory: createDataOperationsRuntime,
      label: const String.fromEnvironment(
        'SKED_DATA_PERF_LABEL',
        defaultValue: 'local',
      ),
      revision: const String.fromEnvironment(
        'SKED_DATA_PERF_REVISION',
        defaultValue: 'unknown',
      ),
      datasetNames: const String.fromEnvironment(
        'SKED_DATA_PERF_DATASETS',
        defaultValue: 'sparse,1000,5000',
      ).split(',').map((name) => name.trim()).toList(),
      requireProfile: !const bool.fromEnvironment(
        'SKED_DATA_PERF_ALLOW_DEBUG_SMOKE',
      ),
    );
    binding.reportData = {'dataOperations': report};
  }, timeout: Timeout.none);
}
