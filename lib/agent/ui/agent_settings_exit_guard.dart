import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../widgets/adaptive_navigation_scope.dart';
import '../../widgets/editor_exit_guard.dart';
import '../../widgets/sked_confirmation_dialog.dart';

/// Settings drafts belong to their page and never save as a side effect of Back.
/// The adaptive settings sidebar can await the same discard decision as Back.
mixin AgentSettingsExitGuard<T extends StatefulWidget> on State<T> {
  Object get settingsDraftFingerprint;
  bool get settingsExitBlocked;

  late Object _originalDraft;
  bool _askingToDiscard = false;
  ModalRoute<dynamic>? _guardedRoute;
  RegisterAdaptivePageExitGuard? _registrar;
  VoidCallback? _unregister;

  bool get settingsHasUnsavedDraft =>
      settingsDraftFingerprint != _originalDraft;

  void initializeSettingsDraftGuard() {
    _originalDraft = settingsDraftFingerprint;
  }

  void markSettingsDraftSaved() {
    _originalDraft = settingsDraftFingerprint;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registrar = AdaptiveNavigationScope.maybeOf(context)
        ?.registerPageExitGuard;
    final route = ModalRoute.of(context);
    if (registrar == _registrar && route == _guardedRoute) return;
    _unregister?.call();
    _registrar = registrar;
    _guardedRoute = route;
    _unregister = registrar != null && route != null
        ? registrar(route, _prepareSettingsExit)
        : null;
  }

  Future<bool> _prepareSettingsExit() async {
    if (!mounted || settingsExitBlocked || _askingToDiscard) return false;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return false;
    if (settingsHasUnsavedDraft) {
      _askingToDiscard = true;
      bool discard;
      try {
        discard =
            await showDialog<bool>(
              context: context,
              builder: (_) => const SkedDiscardDraftDialog(),
            ) ==
            true;
      } finally {
        _askingToDiscard = false;
      }
      if (!discard) return false;
    }
    if (!mounted || settingsExitBlocked || route?.isCurrent != true) {
      return false;
    }
    completeEditorRoute(context);
    return true;
  }

  void requestSettingsExit() => unawaited(_prepareSettingsExit());

  /// Publish the cleared save guard before completing only this page, including
  /// when a newer route was opened while its accepted save was in flight.
  void completeSettingsSave<R>([R? result]) {
    markSettingsDraftSaved();
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !settingsExitBlocked && route?.isActive == true) {
        completeEditorRoute<R>(context, result);
      }
    });
  }

  Widget guardSettingsPage(Widget child) => PopScope(
    // Back can arrive before a field's pending rebuild. Read the controllers
    // in the exit decision instead of allowing a pop from the last frame.
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) requestSettingsExit();
    },
    child: child,
  );

  @override
  void dispose() {
    _unregister?.call();
    super.dispose();
  }
}
