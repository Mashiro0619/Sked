import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../application/resource_queries.dart';
import '../../controllers/app_session.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_data_commit.dart';
import '../../utils/time_utils.dart';
import '../../widgets/settings_page_header.dart';
import '../../widgets/workbench_chrome_metrics.dart';
import 'agent_selectable_text.dart';

/// Opens the current stored object without enabling its workspace, changing
/// visibility or turning a read-only inspection into another Agent mutation.
class AgentResourceView extends StatelessWidget {
  const AgentResourceView({
    super.key,
    required this.session,
    required this.ref,
  });

  final AppSession session;
  final ResourceRef ref;

  static Future<void> open(BuildContext context, Map<String, Object?> value) {
    final kind = ResourceKind.values
        .where((kind) => kind.name == value['kind'])
        .firstOrNull;
    if (kind == null || value['id'] is! String) {
      throw const FormatException('Invalid resource reference.');
    }
    final session = context.read<AppSession>();
    final ref = ResourceRef(
      kind: kind,
      id: value['id']! as String,
      parentId: value['parentId'] as String?,
    );
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgentResourceView(session: session, ref: ref),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: WorkbenchChromeMetrics.of(context).toolbarHeight,
              child: SettingsPageHeader(
                title: l.agentViewObject,
                toolbar: true,
              ),
            ),
            Expanded(
              child: StreamBuilder<AppDataCommit>(
                stream: session.commits,
                builder: (context, _) {
                  ResourceRecord record;
                  try {
                    record = ResourceQueries(
                      snapshot: session.committedData,
                      datasetGeneration: 'object-preview',
                      snapshotRevision: 0,
                    ).get(ref);
                  } on ResourceQueryException {
                    return Center(child: Text(l.agentOperationFailed));
                  }
                  final values = record.values;
                  final label = values['name'] ?? values['title'];
                  final effectiveTime = values['effectiveTime'];
                  final rows = <(String, Object?)>[
                    (l.timetableName, values['timetableName']),
                    (l.calendar, values['calendarName']),
                    (l.semesterStartDate, values['startDate']),
                    (l.totalWeeks, values['totalWeeks']),
                    (l.dayOfWeek, values['dayOfWeek']),
                    (l.semesterWeeks, values['semesterWeeks']),
                    (
                      l.startTime,
                      values['start'] ?? _time(effectiveTime, 'startMinutes'),
                    ),
                    (
                      l.endTime,
                      values['end'] ?? _time(effectiveTime, 'endMinutes'),
                    ),
                    (l.teacherName, values['teacher']),
                    (l.location, values['location']),
                    (l.credits, values['credit']),
                    (l.remarks, values['remarks'] ?? values['notes']),
                  ];
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (label is String)
                        AgentSelectableText(
                          label,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      for (final row in rows)
                        if (row.$2 != null && row.$2.toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.$1,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                AgentSelectableText(_display(row.$2)),
                              ],
                            ),
                          ),
                      ExpansionTile(
                        title: Text(l.agentPlanDetails),
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: AgentSelectableText(
                              const JsonEncoder.withIndent('  ')
                                  .convert(values),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _display(Object? value) =>
    value is List ? value.join(', ') : value.toString();

String? _time(Object? values, String key) => values is Map && values[key] is int
    ? formatMinutes(values[key] as int)
    : null;
