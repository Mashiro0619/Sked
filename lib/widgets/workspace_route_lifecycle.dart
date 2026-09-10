import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';

/// A disabled domain must also disappear from routes pushed above the shell.
/// Removing only the shell's offstage page would leave a browser or parser alive.
mixin WorkspaceRouteLifecycle<T extends StatefulWidget> on State<T> {
  AppMode get routeWorkspace;
  bool get routeWorkspaceEnabled =>
      _workspaceProvider?.isWorkspaceEnabled(routeWorkspace) != false;
  Future<bool> prepareWorkspaceDisable() async => true;
  void workspaceDisabled() {}
  TimetableProvider? _workspaceProvider;
  VoidCallback? _unregisterWorkspaceGuard;
  bool _removalScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<TimetableProvider?>(context, listen: false);
    if (!identical(provider, _workspaceProvider)) {
      _workspaceProvider?.removeListener(_checkWorkspace);
      _unregisterWorkspaceGuard?.call();
      _workspaceProvider = provider;
      provider?.addListener(_checkWorkspace);
      _unregisterWorkspaceGuard = provider?.registerWorkspaceExitGuard(
        routeWorkspace,
        prepareWorkspaceDisable,
      );
    }
    _checkWorkspace();
  }

  void _checkWorkspace() {
    if (!mounted ||
        _workspaceProvider?.isWorkspaceEnabled(routeWorkspace) != false ||
        _removalScheduled) {
      return;
    }
    setState(() => _removalScheduled = true);
    workspaceDisabled();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isFirst && route.navigator != null) {
        route.navigator!.removeRoute(route);
      }
    });
  }

  @override
  void dispose() {
    _workspaceProvider?.removeListener(_checkWorkspace);
    _unregisterWorkspaceGuard?.call();
    super.dispose();
  }
}

Future<bool> confirmWorkspaceDraftDiscard(BuildContext context) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.periodTimesUnsavedExitTitle),
          content: Text(l.unsavedChangesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.discardChangesAndExit),
            ),
          ],
        ),
      ) ==
      true;
}
