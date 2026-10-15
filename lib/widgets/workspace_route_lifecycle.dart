import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import 'sked_confirmation_dialog.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';

/// A disabled domain must also disappear from routes pushed above the shell.
/// Removing only the shell's offstage page would leave a browser or parser alive.
mixin WorkspaceRouteLifecycle<T extends StatefulWidget> on State<T> {
  AppMode get routeWorkspace;
  bool get routeWorkspaceEnabled =>
      _workspaceView?.isEnabled(routeWorkspace) != false;
  Future<bool> prepareWorkspaceDisable() async => true;
  void workspaceDisabled() {}
  WorkspaceViewState? _workspaceView;
  WorkspaceCommands? _workspaceCommands;
  VoidCallback? _unregisterWorkspaceGuard;
  bool _removalScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = context.read<WorkspaceViewState?>();
    final commands = context.read<WorkspaceCommands?>();
    if (!identical(view, _workspaceView) ||
        !identical(commands, _workspaceCommands)) {
      _workspaceView?.removeListener(_checkWorkspace);
      _unregisterWorkspaceGuard?.call();
      _workspaceView = view;
      _workspaceCommands = commands;
      view?.addListener(_checkWorkspace);
      _unregisterWorkspaceGuard = commands?.registerExitGuard(
        routeWorkspace,
        prepareWorkspaceDisable,
      );
    }
    _checkWorkspace();
  }

  void _checkWorkspace() {
    if (!mounted ||
        _workspaceView?.isEnabled(routeWorkspace) != false ||
        _removalScheduled) {
      return;
    }
    setState(() => _removalScheduled = true);
    workspaceDisabled();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null &&
          route.isActive &&
          !route.isFirst &&
          route.navigator != null) {
        route.navigator!.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _workspaceView?.removeListener(_checkWorkspace);
    _unregisterWorkspaceGuard?.call();
    super.dispose();
  }
}

Future<bool> confirmWorkspaceDraftDiscard(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => const SkedDiscardDraftDialog(),
      ) ==
      true;
}
