import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';
import 'adaptive_navigation_scope.dart';

/// Covers system Back, panel Close and workspace disable with one draft policy.
/// The caller owns the draft and persistence; this guard never saves implicitly.
mixin EditorExitGuard<T extends StatefulWidget> on State<T> {
  String get draftFingerprint;
  bool get exitBlocked;
  AppMode get editorWorkspace;
  void closeEditor();
  late final String _originalDraft;
  VoidCallback? _unregisterExitGuard;
  VoidCallback? _unregisterPageExitGuard;
  ModalRoute<dynamic>? _guardedRoute;
  RegisterAdaptivePageExitGuard? _pageExitRegistrar;
  TimetableProvider? _exitProvider;
  bool _askingToDiscard = false;
  bool get hasUnsavedDraft => draftFingerprint != _originalDraft;

  void initializeDraftGuard() {
    _originalDraft = draftFingerprint;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registrar = AdaptiveNavigationScope.maybeOf(context)
        ?.registerPageExitGuard;
    final route = ModalRoute.of(context);
    if (registrar != _pageExitRegistrar || route != _guardedRoute) {
      _unregisterPageExitGuard?.call();
      _pageExitRegistrar = registrar;
      _guardedRoute = route;
      _unregisterPageExitGuard = registrar != null && route != null
          ? registrar(route, _prepareWorkspaceExit)
          : null;
    }
    final provider = Provider.of<TimetableProvider?>(context, listen: false);
    if (identical(provider, _exitProvider)) return;
    _unregisterExitGuard?.call();
    _exitProvider = provider;
    _unregisterExitGuard = provider?.registerWorkspaceExitGuard(
      editorWorkspace,
      _prepareWorkspaceExit,
    );
  }

  Future<bool> confirmDiscardDraft() async {
    if (!mounted || exitBlocked || _askingToDiscard) return false;
    if (!hasUnsavedDraft) return true;
    _askingToDiscard = true;
    try {
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
    } finally {
      _askingToDiscard = false;
    }
  }

  Future<bool> _prepareWorkspaceExit() async {
    if (!await confirmDiscardDraft() || !mounted || exitBlocked) return false;
    // Restore may replace this domain without disabling it. Retire the old
    // editor before publishing replacement data so it cannot submit a stale draft.
    closeEditor();
    return true;
  }

  Future<void> requestEditorExit() async {
    if (await confirmDiscardDraft() && mounted && !exitBlocked) closeEditor();
  }

  @override
  void dispose() {
    _unregisterExitGuard?.call();
    _unregisterPageExitGuard?.call();
    super.dispose();
  }
}
