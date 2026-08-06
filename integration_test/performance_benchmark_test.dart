import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../benchmark/src/performance_suite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records the fixed performance suite', (tester) async {
    const label = String.fromEnvironment(
      'SKED_BENCHMARK_LABEL',
      defaultValue: 'android-profile',
    );
    const revision = String.fromEnvironment(
      'SKED_BENCHMARK_REVISION',
      defaultValue: 'unknown',
    );
    const runtime = String.fromEnvironment(
      'SKED_BENCHMARK_RUNTIME',
      defaultValue: 'android-profile-unspecified',
    );
    final report = await runPerformanceSuite(
      label: label,
      revision: revision,
      runtime: runtime,
    );
    binding.reportData = {'performance': report.toJson()};

    expect(report.results, isNotEmpty);
  }, timeout: Timeout.none);
}
