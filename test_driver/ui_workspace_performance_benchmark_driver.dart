import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final report = data?['uiWorkspacePerformance'];
    if (report is! Map<String, dynamic> ||
        report['measurement'] != 'profile-workspace-engine-frames' ||
        report['validation'] != 'passed' ||
        report['results'] is! List ||
        (report['results'] as List).length != 60 ||
        report['mounts'] is! List ||
        (report['mounts'] as List).length != 3) {
      throw StateError(
        'The workspace benchmark did not return a complete workspace60 population.',
      );
    }
    final protocol = report['protocol'];
    final scrollTargeting = protocol is Map
        ? protocol['scrollTargeting']
        : null;
    if (scrollTargeting is! Map ||
        scrollTargeting['version'] != 1 ||
        scrollTargeting['id'] != 'workspace-canvas-scroll-v1' ||
        scrollTargeting['scope'] != 'workspace-canvas') {
      throw StateError(
        'The workspace benchmark must scroll its primary canvas.',
      );
    }
    final scope = protocol is Map ? protocol['scope'] : null;
    final content = protocol is Map ? protocol['listContent'] : null;
    final legacy =
        report['harnessVersion'] == 2 &&
        scope is Map &&
        scope['id'] == 'workspace60-v1';
    final guarded =
        report['harnessVersion'] == 3 &&
        scope is Map &&
        scope['id'] == 'workspace60-v2';
    if ((!legacy && !guarded) || (legacy && content != null)) {
      throw StateError(
        'Unknown workspace harness and population version pair.',
      );
    }
    if (guarded) {
      if (content is! Map ||
          content['version'] != 1 ||
          content['id'] != 'workspace-list-content-v1' ||
          report['workloadInputs'] is! List ||
          (report['workloadInputs'] as List).length != 3) {
        throw StateError(
          'workspace60-v2 requires its input hashes and content protocol.',
        );
      }
      final results = report['results'] as List;
      final rows = results.where(
        (row) => row is Map && row['scenario'] == 'general.list.open_scroll',
      );
      if (rows.length != 6) {
        throw StateError('workspace60-v2 requires six list observations.');
      }
      for (final row in rows) {
        final details = (row as Map)['details'];
        final listContent = details is Map ? details['listContent'] : null;
        final checkpoints = listContent is Map
            ? listContent['checkpoints']
            : null;
        if (checkpoints is! List ||
            checkpoints.length != 3 ||
            checkpoints.any(
              (point) =>
                  point is! Map ||
                  point['textSha256'] is! String ||
                  point['paragraphs'] is! List ||
                  (point['paragraphs'] as List).isEmpty,
            )) {
          throw StateError(
            'workspace60-v2 returned incomplete visible list checkpoints.',
          );
        }
      }
    }
    final label = report['label'];
    if (label is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(label)) {
      throw StateError(
        'SKED_UI_WORKSPACE_PERF_LABEL must be a short filename-safe label.',
      );
    }
    await writeResponseData(
      report,
      testOutputFilename: 'ui-workspace-performance-$label',
    );
  },
);
