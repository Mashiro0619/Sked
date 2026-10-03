import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../models/app_mode.dart';

import 'package:material_ui/material_ui.dart';

import 'sked_task_session.dart';
import 'ui_command.dart';

/// One shared mutation gate per task. This owns no draft, route or progress UI.
/// Callers freeze the submitted value before calling run, and decide how a
/// successful result completes their own task.
class SkedTaskSubmissionController extends ChangeNotifier {
  SkedTaskSubmissionController({required this.session}) {
    final workspace = session.workspace;
    if (workspace != null) {
      _unregister = session.provider?.registerWorkspaceExitGuard(
        workspace,
        () async => !busy,
      );
    }
  }
  final SkedTaskSession session;
  VoidCallback? _unregister;
  bool _busy = false;
  bool _disposed = false;
  bool get busy => _busy;
  bool get isCurrent => !_disposed && session.isCurrent;
  bool get blocked => busy || !isCurrent;

  Future<bool> run({
    required BuildContext context,
    required String debugLabel,
    required Future<void> Function() command,
  }) async {
    if (blocked || !context.mounted) return false;
    _busy = true;
    notifyListeners();
    try {
      final saved = await runUiCommandWithFeedback(
        context: context,
        debugLabel: debugLabel,
        command: command,
      );
      return saved && context.mounted && isCurrent;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister?.call();
    _unregister = null;
    super.dispose();
  }
}

/// State adapter for tasks that already own their draft and PopScope policy.
/// Multiple mutations in the same state share exactly one submission gate.
mixin SkedTaskSubmissionHost<T extends StatefulWidget> on State<T> {
  AppMode get submissionWorkspace;
  SkedTaskSubmissionController? _taskSubmission;
  SkedTaskSession? _ownedSubmissionSession;
  SkedTaskSubmissionController get taskSubmission => _taskSubmission!;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_taskSubmission != null) return;
    final inherited = SkedTaskSessionScope.maybeOf(context)?.session;
    final session =
        inherited ??
        (_ownedSubmissionSession = SkedTaskSession(
          provider: Provider.of<TimetableProvider?>(context, listen: false),
          workspace: submissionWorkspace,
          isOwnerActive: () => mounted,
        ));
    _taskSubmission = SkedTaskSubmissionController(session: session)
      ..addListener(_submissionChanged);
  }

  void _submissionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _taskSubmission?.removeListener(_submissionChanged);
    _taskSubmission?.dispose();
    _ownedSubmissionSession?.dispose();
    super.dispose();
  }
}
