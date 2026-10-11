import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../models/app_mode.dart';
import 'workspace_route_lifecycle.dart';
import '../screens/period_times_page.dart';
import 'adaptive_collection_scaffold.dart';
import 'desktop_window_host.dart';
import 'expressive_empty_state.dart';
import 'ui_command.dart';

class PeriodTimeSetManagerPage extends StatefulWidget {
  const PeriodTimeSetManagerPage({super.key});
  @override
  State<PeriodTimeSetManagerPage> createState() =>
      _PeriodTimeSetManagerPageState();
}

class _PeriodTimeSetManagerPageState extends State<PeriodTimeSetManagerPage>
    with
        UiCommandRunner<PeriodTimeSetManagerPage>,
        WorkspaceRouteLifecycle<PeriodTimeSetManagerPage> {
  String? _newSetId;

  @override
  AppMode get routeWorkspace => AppMode.student;
  @override
  Future<bool> prepareWorkspaceDisable() async => !uiCommandBusy;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimetableProvider>();
    final l = AppLocalizations.of(context);
    Future<void> createSet() async {
      String? createdId;
      final saved = await runUiCommand(
        debugLabel: 'Create period time set',
        command: () async {
          createdId = (await p.addPeriodTimeSet()).id;
        },
      );
      if (saved && mounted) setState(() => _newSetId = createdId);
    }

    final addAction = IconButton(
      key: const ValueKey('period-time-set-create'),
      tooltip: l.newPeriodTimeSetName,
      icon: const Icon(Icons.add),
      onPressed: uiCommandBusy ? null : () => unawaited(createSet()),
    );
    if (p.periodTimeSets.isEmpty) {
      return PopScope(
        canPop: !uiCommandBusy,
        child: Scaffold(
          appBar: WorkbenchAppBar(
            title: Text(l.managePeriodTimeSets),
            actions: [addAction],
          ),
          body: ExpressiveEmptyState(
            icon: Icons.schedule,
            title: l.noPeriodTimeAvailable,
          ),
        ),
      );
    }
    return PopScope(
      canPop: !uiCommandBusy,
      child: AdaptiveCollectionScaffold(
        title: l.managePeriodTimeSets,
        busy: uiCommandBusy,
        initialSelection: _newSetId,
        actions: [addAction],
        items: [
          for (final set in p.periodTimeSets)
            CollectionItem(
              id: set.id,
              title: set.name,
              subtitle: l.periodTimeSetUsageSummary(
                set.periodTimes.length,
                p.timetablesUsingPeriodTimeSet(set.id).length,
              ),
              tileBuilder: (selected, openDetail) => Material(
                type: MaterialType.transparency,
                child: ListTile(
                  key: ValueKey('period-time-set-${set.id}'),
                  selected: selected,
                  title: Text(set.name),
                  subtitle: Text(
                    l.periodTimeSetUsageSummary(
                      set.periodTimes.length,
                      p.timetablesUsingPeriodTimeSet(set.id).length,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: uiCommandBusy ? null : openDetail,
                ),
              ),
            ),
        ],
        detailBuilder: (id) => ChangeNotifierProvider<TimetableProvider>.value(
          value: p,
          child: PeriodTimesPage(periodTimeSetId: id),
        ),
      ),
    );
  }
}
