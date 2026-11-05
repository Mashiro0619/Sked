import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../application/resource_queries.dart';
import '../../controllers/app_session.dart';
import '../../l10n/app_localizations.dart';
import '../../models/app_data_commit.dart';
import '../../widgets/settings_page_header.dart';
import '../../widgets/workbench_chrome_metrics.dart';
import 'agent_selectable_text.dart';
import 'agent_change_fields.dart';

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
                  final rows = agentReadableFields(context, values)
                    ..remove(l.name);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (label is String)
                        AgentSelectableText(
                          label,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      for (final row in rows.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.key,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              AgentSelectableText(row.value),
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
