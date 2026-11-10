part of 'general_schedule_home_screen.dart';

class _GeneralOccurrenceActions extends ChangeNotifier {
  _GeneralOccurrenceActions({
    required this.view,
    required this.commands,
    required this.workspace,
    required this.maintenance,
    required this.feedbackContext,
    required this.isOwnerActive,
    required this.canEdit,
    required this.onEdit,
  }) {
    _changes = Listenable.merge([view, workspace, maintenance])
      ..addListener(_changed);
  }

  final GeneralViewState view;
  final GeneralCommands commands;
  final WorkspaceViewState workspace;
  final AppDataMaintenance maintenance;
  final BuildContext feedbackContext;
  final bool Function() isOwnerActive;
  final bool Function() canEdit;
  final Future<void> Function(
    GeneralEventOccurrence,
    GeneralEventEditScope,
    WorkspaceEditorConfiguration,
  )
  onEdit;
  late final Listenable _changes;
  final _owners = Expando<_GeneralOccurrenceActionOwner>();
  final _busy = <String>{};
  final _sessions = <SkedTaskSession>{};
  var _generation = 0;
  var _disposed = false;

  Object get dataSession => maintenance.dataSessionToken;
  bool get available =>
      !_disposed &&
      isOwnerActive() &&
      workspace.isEnabled(AppMode.general) &&
      !maintenance.isReserved &&
      canEdit();

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void invalidate() {
    if (_disposed) return;
    _generation++;
    for (final session in _sessions.toList()) {
      session.invalidate();
    }
    _changed();
  }

  GeneralEventOccurrence? resolve(GeneralEventOccurrence occurrence) =>
      resolveCurrentGeneralOccurrence(view, occurrence);

  List<DesktopAction> buildActions(
    DesktopActionContext context,
    GeneralEventOccurrence occurrence,
    VoidCallback onView,
  ) {
    final owner = _owners[context] ??= _GeneralOccurrenceActionOwner(
      generation: _generation,
      dataSession: maintenance.dataSessionToken,
      resumeBoundary:
          workspace.data.workspaceReminderNotBefore[AppMode.general],
      occurrence: occurrence,
      eventDefinition: jsonEncode(occurrence.event.toJson()),
      route: ModalRoute.of(context.context),
    );
    final l = AppLocalizations.of(context.context);
    final enabled =
        available &&
        context.isCurrent() &&
        _current(owner) &&
        !_busy.contains(occurrence.occurrenceKey);
    DesktopAction action(String id, String label, IconData icon) =>
        DesktopAction(
          id: id,
          label: label,
          icon: icon,
          shortcut: id == 'delete' ? LogicalKeyboardKey.delete : null,
          enabled: enabled,
          onInvoke: () => _invoke(context, owner, id, onView),
        );
    return [
      action('view', l.viewEvent, Icons.info_outline),
      action('edit', l.editEvent, Icons.edit_outlined),
      action('duplicate', l.duplicateEvent, Icons.content_copy_outlined),
      action('delete', l.delete, Icons.delete_outline),
    ];
  }

  bool _current(_GeneralOccurrenceActionOwner owner, {bool target = true}) {
    if (_disposed ||
        owner.generation != _generation ||
        !isOwnerActive() ||
        !workspace.isEnabled(AppMode.general) ||
        !identical(owner.dataSession, maintenance.dataSessionToken) ||
        owner.resumeBoundary !=
            workspace.data.workspaceReminderNotBefore[AppMode.general] ||
        owner.route?.isActive == false) {
      return false;
    }
    if (!target) return true;
    final latest = resolve(owner.occurrence);
    return latest != null &&
        jsonEncode(latest.event.toJson()) == owner.eventDefinition;
  }

  Future<void> _invoke(
    DesktopActionContext context,
    _GeneralOccurrenceActionOwner owner,
    String action,
    VoidCallback onView,
  ) async {
    final key = owner.occurrence.occurrenceKey;
    if (!context.context.mounted ||
        !context.isCurrent() ||
        !available ||
        !_current(owner) ||
        _busy.contains(key)) {
      return;
    }
    final anchor = WorkspaceEditorConfiguration(anchorContext: context.context);
    var accepted = false;
    ModalRoute<dynamic>? childRoute;
    final session = SkedTaskSession(
      ownerRoute: owner.route,
      maintenance: maintenance,
      workspaceView: workspace,
      workspace: AppMode.general,
      targetChanges: this,
      isOwnerActive: () => _current(owner, target: !accepted),
    );
    void retireChild() {
      final route = childRoute;
      if (session.isCurrent || route?.isActive != true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!session.isCurrent && route?.isActive == true) {
          route!.navigator?.removeRoute(route);
        }
      });
    }

    session.addListener(retireChild);
    _sessions.add(session);
    _busy.add(key);
    _changed();
    try {
      switch (action) {
        case 'view':
          onView();
        case 'edit':
          final scope = await showGeneralEventEditScopeDialog(
            context.context,
            resolve(owner.occurrence)!,
            onChildRouteChanged: (route) {
              childRoute = route;
              retireChild();
            },
          );
          if (scope == null ||
              !session.isCurrent ||
              !available ||
              !feedbackContext.mounted) {
            return;
          }
          final current = resolve(owner.occurrence);
          if (current == null) return;
          accepted = true;
          await runUiCommandWithFeedback(
            context: feedbackContext,
            debugLabel: 'Edit general event from object menu',
            command: () => onEdit(current, scope, anchor),
          );
        case 'duplicate':
          final current = resolve(owner.occurrence);
          if (current == null || !session.isCurrent || !available) return;
          accepted = true;
          await runUiCommandWithFeedback(
            context: feedbackContext,
            debugLabel: 'Duplicate general event from object menu',
            command: () async {
              await commands.duplicateOccurrence(current);
            },
          );
        case 'delete':
          final scope = await showGeneralEventDeleteScopeDialog(
            context.context,
            resolve(owner.occurrence)!,
            session: session,
          );
          if (scope == null ||
              !session.isCurrent ||
              !available ||
              !feedbackContext.mounted) {
            return;
          }
          final current = resolve(owner.occurrence);
          if (current == null) return;
          accepted = true;
          await runUiCommandWithFeedback(
            context: feedbackContext,
            debugLabel: 'Delete general event from object menu',
            command: () => commands.deleteOccurrenceScope(current, scope),
          );
      }
    } finally {
      session.removeListener(retireChild);
      _sessions.remove(session);
      session.dispose();
      _busy.remove(key);
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _changes.removeListener(_changed);
    for (final session in _sessions.toList()) {
      session.invalidate();
    }
    super.dispose();
  }
}

class _GeneralOccurrenceActionOwner {
  const _GeneralOccurrenceActionOwner({
    required this.generation,
    required this.dataSession,
    required this.resumeBoundary,
    required this.occurrence,
    required this.eventDefinition,
    required this.route,
  });
  final int generation;
  final Object dataSession;
  final DateTime? resumeBoundary;
  final GeneralEventOccurrence occurrence;
  final String eventDefinition;
  final ModalRoute<dynamic>? route;
}

class _GeneralOccurrenceActionScope extends InheritedWidget {
  const _GeneralOccurrenceActionScope({
    required this.actions,
    this.menuKey,
    required super.child,
  });
  final _GeneralOccurrenceActions actions;
  final String? menuKey;
  static _GeneralOccurrenceActionScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_GeneralOccurrenceActionScope>();
  @override
  bool updateShouldNotify(_GeneralOccurrenceActionScope oldWidget) =>
      actions != oldWidget.actions || menuKey != oldWidget.menuKey;
}

class _GeneralOccurrenceMenu extends StatelessWidget {
  const _GeneralOccurrenceMenu({
    required this.occurrence,
    required this.onView,
    required this.child,
    this.actions,
  });
  final GeneralEventOccurrence occurrence;
  final VoidCallback onView;
  final Widget child;
  final _GeneralOccurrenceActions? actions;

  @override
  Widget build(BuildContext context) {
    final scope = _GeneralOccurrenceActionScope.maybeOf(context);
    final controller = actions ?? scope?.actions;
    if (!WorkbenchChromeMetrics.of(context).desktop ||
        controller == null ||
        scope?.menuKey == occurrence.occurrenceKey) {
      return child;
    }
    return _GeneralOccurrenceActionScope(
      actions: controller,
      menuKey: occurrence.occurrenceKey,
      child: DesktopContextMenuRegion(
        target: (controller, controller.dataSession, occurrence.occurrenceKey),
        targetChanges: controller,
        isOwnerCurrent: () =>
            controller.available && controller.resolve(occurrence) != null,
        actionsBuilder: (source) =>
            controller.buildActions(source, occurrence, onView),
        child: child,
      ),
    );
  }
}
