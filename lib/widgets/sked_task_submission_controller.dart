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
