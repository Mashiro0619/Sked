import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../models/app_mode.dart';
import 'workspace_route_lifecycle.dart';
import '../screens/period_times_page.dart';
import 'adaptive_collection_scaffold.dart';
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
  @override
  AppMode get routeWorkspace => AppMode.student;
  @override
  Future<bool> prepareWorkspaceDisable() async => !uiCommandBusy;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimetableProvider>();
    final l = AppLocalizations.of(context);
    return AdaptiveCollectionScaffold(
      title: l.periodTimeSets,
      busy: uiCommandBusy,
      actions: [
        IconButton(
          tooltip: l.newPeriodTimeSetName,
          icon: const Icon(Icons.add),
          onPressed: uiCommandBusy
              ? null
              : () => unawaited(
                  runUiCommand(
                    debugLabel: 'Create period time set',
                    command: () async {
                      await p.addPeriodTimeSet();
                    },
                  ),
                ),
        ),
      ],
      items: [
        for (final set in p.periodTimeSets)
          CollectionItem(
            id: set.id,
            title: set.name,
            subtitle: l.periodTimeSetSummary(set.name, set.periodTimes.length),
            trailing: p.activeTimetableOrNull == null
                ? null
                : IconButton(
                    tooltip: l.selectPeriodTimeSet,
                    isSelected:
                        p.activeTimetableOrNull!.config.periodTimeSetId ==
                        set.id,
                    icon: const Icon(Icons.radio_button_unchecked),
                    selectedIcon: const Icon(Icons.radio_button_checked),
                    onPressed: uiCommandBusy
                        ? null
                        : () => unawaited(
                            runUiCommand(
                              debugLabel: 'Assign period time set',
                              command: () => p.assignPeriodTimeSetToTimetable(
                                p.activeTimetable.id,
                                set.id,
                              ),
                            ),
                          ),
                  ),
          ),
      ],
      detailBuilder: (id) => ChangeNotifierProvider<TimetableProvider>.value(
        value: p,
        child: PeriodTimesPage(periodTimeSetId: id),
      ),
    );
  }
}
