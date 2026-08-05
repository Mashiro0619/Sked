import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import 'expressive_motion.dart';
import 'ui_command.dart';

class ModeSwitchAction extends StatefulWidget {
  const ModeSwitchAction({super.key});

  @override
  State<ModeSwitchAction> createState() => _ModeSwitchActionState();
}

class _ModeSwitchActionState extends State<ModeSwitchAction>
    with UiCommandRunner<ModeSwitchAction> {
  void _switchMode(TimetableProvider provider, AppMode mode) {
    unawaited(
      runUiCommand(
        debugLabel: 'Switch application mode',
        command: () => provider.switchMode(mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    final isStudent = provider.isStudentMode;
    return ExpressiveSwitcher(
      child: IconButton(
        key: ValueKey((isStudent, uiCommandBusy)),
        icon: uiCommandBusy
            ? Semantics(
                liveRegion: true,
                label: l10n.savingChanges,
                child: const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Icon(
                isStudent ? Icons.event_note_outlined : Icons.school_outlined,
              ),
        tooltip: isStudent
            ? l10n.switchToGeneralSchedule
            : l10n.switchToStudentTimetable,
        onPressed: uiCommandBusy
            ? null
            : () => _switchMode(
                provider,
                isStudent ? AppMode.general : AppMode.student,
              ),
      ),
    );
  }
}
