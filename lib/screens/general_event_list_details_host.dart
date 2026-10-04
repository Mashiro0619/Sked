part of 'general_schedule_home_screen.dart';

/// Workspace-owned detail. Promotion retains the same content, but its lifetime
/// and input no longer belong to its agenda or reminder source list.
class _EventListDetailsHost extends StatefulWidget {
  const _EventListDetailsHost({
    required this.provider,
    required this.pane,
    required this.isOwnerActive,
    required this.onEdit,
    required this.canEdit,
    required this.child,
  });
  final TimetableProvider provider;
  final WorkspacePaneController pane;
  final bool Function() isOwnerActive;
  final Future<void> Function(GeneralEventOccurrence) onEdit;
  final bool Function() canEdit;
  final Widget child;
  @override
  State<_EventListDetailsHost> createState() => _EventListDetailsHostState();
}

class _EventListDetailsHostState extends State<_EventListDetailsHost>
    with WidgetsBindingObserver {
  late final ReminderDetailSessionController session;
  final _portal = OverlayPortalController();
  _EventListDetailsBindingState? _source;
  // Entry identity can change without changing the selected content session.
  String? _sourceKey;
  final Map<String, _EventListDetailsBindingState> _rowSources = {};
  int _nextSourceId = 0;
  GlobalKey? get bodyKey => _source?.bodyKey;
  final _overlayKey = GlobalKey();
  final _focus = FocusScopeNode(debugLabel: 'Event list detail');
  Map<String, GlobalKey> get _anchors => _source?.anchors ?? const {};
  final Map<String, GeneralEventOccurrence> _occurrences = {};
  ModalRoute<dynamic>? _ownerRoute, _childRoute;
  Object? _dataSession;
  VoidCallback? _unregister;
  _ReminderAutoDismissState? _autoDismiss;
  Rect _panel = Rect.zero, _bounds = Rect.zero;
  bool _foreground = true, _scheduled = false, _pointerInDetail = false;
  bool _syncing = false;
  int? _focusRevision;
  FocusNode? _returnFocus;
  Offset _overlayOrigin = Offset.zero;
  Offset? _independentPosition;
  double? _independentHeightLimit;
  double? _lastHeightLimit;
  int? _deletingRevision;

  bool get independent => session.independent;
  bool get _validData =>
      identical(_dataSession, widget.provider.dataSessionToken) &&
      widget.provider.isWorkspaceEnabled(AppMode.general);
  bool get _canInteract =>
      mounted &&
      _foreground &&
      !widget.pane.floatingEditor &&
      _validData &&
      widget.isOwnerActive() &&
      _ownerRoute?.isCurrent == true &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    session = ReminderDetailSessionController()..addListener(_changed);
    _dataSession = widget.provider.dataSessionToken;
    widget.provider.addListener(_providerChanged);
    widget.pane.addListener(_ownerChanged);
    _unregister = widget.pane.registerPriorityDismiss(_priorityDismiss);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ownerRoute = ModalRoute.of(context);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(_EventListDetailsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.provider, widget.provider)) {
      oldWidget.provider.removeListener(_providerChanged);
      widget.provider.addListener(_providerChanged);
    }
    _scheduleSync();
  }

  void _providerChanged() {
    _scheduleSync();
  }

  void _ownerChanged() {
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _validate();
      _syncPortal();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _changed() {
    if (!mounted) return;
    if (session.mode == ReminderDetailMode.preview) {
      final source = _rowSources[session.selectedKey];
      if (source != null) _useSource(source, session.selectedKey!);
    }
    // Busy/child-route hooks can run while a nested route is building.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _scheduleSync();
    } else {
      _syncPortal();
    }
  }

  void _syncPortal() {
    if (!mounted || _syncing) return;
    _syncing = true;
    _rowSources.removeWhere(
      (key, source) => source.anchors[key]?.currentContext == null,
    );
    _validate();
    if (session.visible) {
      if (!_portal.isShowing) _portal.show();
    } else {
      if (_portal.isShowing) _portal.hide();
      _pointerInDetail = false;
      _independentPosition = null;
      _independentHeightLimit = null;
    }
    _occurrences.removeWhere(
      (key, _) => !_rowSources.containsKey(key) && key != session.selectedKey,
    );
    _autoDismiss?.setSecondaryHover(_pointerInDetail && session.visible);
    setState(() {});
    _syncing = false;
  }

  void _validate() {
    if (!identical(_dataSession, widget.provider.dataSessionToken)) {
      _retire();
      _dataSession = widget.provider.dataSessionToken;
    }
    if (!_validData ||
        !widget.isOwnerActive() ||
        _ownerRoute?.isActive != true ||
        !TickerMode.valuesOf(context).enabled) {
      _retire();
      return;
    }
    if (!session.visible) return;
    final occurrence = _occurrences[session.selectedKey];
    final current = occurrence == null ? null : _resolveOccurrence(occurrence);
    if (current == null) {
      // Own deletion is optimistic until persistence settles. Keep its busy
      // detail/error host alive, but never exempt data/workspace invalidation.
      if (_deletingRevision != session.revision) {
        _retire();
        return;
      }
    } else {
      _occurrences[session.selectedKey!] = current;
    }
    if (session.mode == ReminderDetailMode.preview &&
        (!_canPreview || _anchorRect() == null)) {
      session.dismissPreview();
    }
  }

  GeneralEventOccurrence? _resolveOccurrence(GeneralEventOccurrence snapshot) {
    final calendar = widget.provider.generalSchedules
        .where((item) => item.id == snapshot.calendar.id)
        .firstOrNull;
    final event = calendar?.events
        .where((item) => item.id == snapshot.event.id)
        .firstOrNull;
    if (calendar == null || event == null) return null;
    // ID existence is not enough: moved/excluded/truncated occurrences must
    // retire, while unchanged instances receive current fields and sequence.
    return expandGeneralEventOccurrences(
      calendar: calendar,
      event: event,
      startInclusive: snapshot.start,
      endExclusive: snapshot.start.add(const Duration(microseconds: 1)),
    ).where((item) => item.start.isAtSameMomentAs(snapshot.start)).firstOrNull;
  }

  bool _canUseSource(_EventListDetailsBindingState source) =>
      _canInteract &&
      source.mounted &&
      source.route?.isCurrent == true &&
      source.visible &&
      _globalRect(source.bodyKey)?.isEmpty == false;

  bool get _canPreview => _source != null && _canUseSource(_source!);

  void _useSource(_EventListDetailsBindingState source, String key) {
    _sourceKey = key;
    if (identical(_source, source)) return;
    _autoDismiss?.setSecondaryHover(false);
    _source = source;
    _autoDismiss = source.context
        .findAncestorStateOfType<_ReminderAutoDismissState>();
  }

  void detachSource(_EventListDetailsBindingState source) {
    _rowSources.removeWhere((_, value) => identical(value, source));
    if (source.hoveredKey case final key?) session.leaveRow(key);
    if (identical(_source, source)) {
      _source = null;
      _sourceKey = null;
      _autoDismiss = null;
    }
    _scheduleSync();
  }

  void sourceContextChanged(_EventListDetailsBindingState source) {
    // A multi-day occurrence may keep the same row on a different agenda date.
    // Cancel only this source's preview/candidate, not another list's timers.
    source.hoveredKey = null;
    source.scrollSuppressed = true;
    session.invalidateHoverRows(source.anchors.keys.toSet());
    _scheduleSync();
  }

  void sourceScroll(
    _EventListDetailsBindingState source,
    ScrollNotification notification,
  ) {
    if (notification is ScrollStartNotification) {
      source.scrolling = true;
      sourcePointerSignal(source);
    } else if (notification is ScrollEndNotification) {
      source.scrolling = false;
    }
    _scheduleSync();
  }

  void sourcePointerSignal(_EventListDetailsBindingState source) {
    source.scrollSuppressed = true;
    if (identical(_source, source)) {
      session.dismissPreview();
    } else if (source.hoveredKey case final key?) {
      session.leaveRow(key);
    }
  }

  void _activate(_EventListDetailsBindingState source, String key) {
    if (!_canUseSource(source) || session.blocked) return;
    // Identical events in agenda and reminders keep one element and scroll.
    final sameEvent =
        session.visible &&
        _occurrences[session.selectedKey]?.occurrenceKey ==
            _occurrences[key]?.occurrenceKey;
    final returnFocus = skedFloatingAnchorFocus(
      source.anchors[key]?.currentContext,
    );
    _useSource(source, key);
    if (detach(sameEvent ? session.selectedKey : key) && returnFocus != null) {
      _returnFocus = returnFocus;
    }
  }

  void _retire() {
    _deletingRevision = null;
    final child = _childRoute;
    _childRoute = null;
    session.close(force: true, explicit: false);
    if (child?.isActive == true) child!.navigator?.removeRoute(child);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) session.dismissPreview();
  }

  bool _priorityDismiss() {
    // Parent commands only own transient previews. An independent detail is
    // never the first victim of a canvas click or the list's close button.
    if (session.mode != ReminderDetailMode.preview || !_canPreview) {
      return false;
    }
    dismiss();
    return true;
  }

  void dismiss() {
    final restore = _focus.hasFocus;
    if (!session.close()) return;
    if (restore) _restoreFocus();
  }

  void _restoreFocus() {
    final revision = session.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          session.visible ||
          session.revision != revision ||
          !_canInteract) {
        return;
      }
      if (_returnFocus?.context?.mounted == true &&
          _returnFocus!.canRequestFocus) {
        _returnFocus!.requestFocus();
      } else if (widget.pane.isOpen) {
        widget.pane.focusScope.requestFocus();
      } else {
        FocusScope.of(context).requestFocus();
      }
    });
  }

  bool detach([String? key]) {
    if (!_canInteract || session.blocked) return false;
    final selected = key ?? session.selectedKey;
    if (selected == null) return false;
    // Actions in an already independent detail must not replace the last
    // explicitly activated entry with one of the detail's own controls.
    if (!session.independent) {
      _returnFocus =
          skedFloatingAnchorFocus(_anchors[_sourceKey]?.currentContext) ??
          FocusManager.instance.primaryFocus;
    }
    if (session.independent && !_panel.isEmpty) {
      _independentPosition = _panel.topLeft;
    } else if (selected != session.selectedKey) {
      _independentPosition = null;
    } else if (!session.independent && !_panel.isEmpty) {
      // Removing the startup hint or preview action can resize the parent.
      // Promotion freezes this origin independently of the source list.
      _independentPosition = _panel.topLeft;
    }
    if (!session.independent && selected == session.selectedKey) {
      _independentHeightLimit = _lastHeightLimit;
    }
    _autoDismiss?._keepOpen();
    if (session.detach(selected)) {
      _focusRevision = session.revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            session.independent &&
            _focusRevision == session.revision &&
            _canInteract) {
          _focus.requestFocus();
        }
      });
      return true;
    }
    return false;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!session.visible || !_canInteract || _childRoute?.isActive == true) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      dismiss();
      return KeyEventResult.handled;
    }
    if (!session.independent || event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    // Focused independent windows keep their own keyboard cycle. Background
    // controls remain usable by pointer; parent Escape never closes this window.
    final targets = _focus.traversalDescendants
        .where((focus) => focus.canRequestFocus && !focus.skipTraversal)
        .toList();
    if (targets.isNotEmpty) {
      final index = targets.indexOf(
        FocusManager.instance.primaryFocus ?? _focus,
      );
      final backwards = HardwareKeyboard.instance.isShiftPressed;
      final next = index < 0
          ? (backwards ? targets.length - 1 : 0)
          : (index + (backwards ? -1 : 1)) % targets.length;
      targets[next].requestFocus();
    }
    return KeyEventResult.handled;
  }

  Rect? _globalRect(GlobalKey? key) {
    final element = key?.currentContext;
    final box = element is RenderObjectElement ? element.renderObject : null;
    for (
      RenderObject? ancestor = box;
      ancestor != null;
      ancestor = ancestor.parent
    ) {
      if (ancestor is RenderOffstage && ancestor.offstage) return null;
    }
    return box is RenderBox && box.attached && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  Rect? _anchorRect() {
    final anchor = _globalRect(_anchors[_sourceKey]);
    final body = _globalRect(bodyKey);
    if (anchor == null || body == null || !anchor.overlaps(body)) return null;
    return anchor.intersect(body).shift(-_overlayOrigin);
  }

  Widget row(
    GeneralEventOccurrence occurrence, {
    required _EventListDetailsBindingState source,
    required Widget Function(VoidCallback activate) builder,
  }) {
    final key = '${source.id}:${occurrence.occurrenceKey}';
    _occurrences[key] = occurrence;
    _rowSources[key] = source;
    final anchor = source.anchors.putIfAbsent(
      key,
      () => GlobalKey(debugLabel: key),
    );
    return MouseRegion(
      key: anchor,
      onEnter: (event) {
        if (event.kind != PointerDeviceKind.mouse) return;
        source.hoveredKey = key;
        if (_canUseSource(source) &&
            !source.scrolling &&
            !source.scrollSuppressed) {
          session.enterRow(key);
        }
      },
      onHover: (event) {
        // Do not reopen under a stationary pointer after list scrolling.
        if (source.scrollSuppressed &&
            event.kind == PointerDeviceKind.mouse &&
            event.delta != Offset.zero &&
            !source.scrolling &&
            _canUseSource(source)) {
          source.scrollSuppressed = false;
          source.hoveredKey = key;
          session.enterRow(key);
        }
      },
      onExit: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          if (source.hoveredKey == key) source.hoveredKey = null;
          session.leaveRow(key);
        }
      },
      child: builder(() => _activate(source, key)),
    );
  }

  void _enterDetail() {
    _pointerInDetail = true;
    session.enterPanel();
    _autoDismiss?.setSecondaryHover(true);
  }

  void _leaveDetail() {
    _pointerInDetail = false;
    session.leavePanel();
    _autoDismiss?.setSecondaryHover(false);
  }

  bool _inBridge(Offset point) {
    final a = _anchorRect();
    if (a == null || _panel.isEmpty) return false;
    // A narrow cross-axis overlap corridor, not a bounding box covering other rows.
    Rect bridge;
    if (_panel.right <= a.left) {
      bridge = Rect.fromLTRB(
        _panel.right - 1,
        math.max(a.top, _panel.top),
        a.left + 1,
        math.min(a.bottom, _panel.bottom),
      );
    } else if (_panel.left >= a.right) {
      bridge = Rect.fromLTRB(
        a.right - 1,
        math.max(a.top, _panel.top),
        _panel.left + 1,
        math.min(a.bottom, _panel.bottom),
      );
    } else if (_panel.bottom <= a.top) {
      bridge = Rect.fromLTRB(
        math.max(a.left, _panel.left),
        _panel.bottom - 1,
        math.min(a.right, _panel.right),
        a.top + 1,
      );
    } else {
      bridge = Rect.fromLTRB(
        math.max(a.left, _panel.left),
        a.bottom - 1,
        math.min(a.right, _panel.right),
        _panel.top + 1,
      );
    }
    return !bridge.isEmpty && bridge.contains(point);
  }

  Widget _details(BuildContext context) {
    final key = session.selectedKey!;
    final version = session.revision;
    final occurrence = _occurrences[key]!;
    bool current() =>
        mounted &&
        _validData &&
        widget.isOwnerActive() &&
        session.isCurrent(version, key);
    GeneralEventOccurrence? currentOccurrence() {
      if (!current()) return null;
      final latest = _resolveOccurrence(occurrence);
      if (latest == null) {
        _retire();
      } else {
        _occurrences[key] = latest;
      }
      return latest;
    }

    final l = AppLocalizations.of(context);
    Future<void> command(
      Future<void> Function(GeneralEventOccurrence) action, {
      String? message,
      bool deleting = false,
    }) async {
      final latest = currentOccurrence();
      if (latest == null) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (deleting) _deletingRevision = version;
      try {
        await action(latest);
        // A successful deletion no longer resolves an occurrence. Completion
        // belongs to the captured session, not to current event existence.
        if (current()) {
          session.close(force: true);
          _restoreFocus();
          if (message != null && messenger?.mounted == true) {
            messenger!.showSnackBar(SnackBar(content: Text(message)));
          }
        }
      } finally {
        if (_deletingRevision == version) _deletingRevision = null;
        // Rollback has settled before validation; failure stays available for retry.
        if (mounted) _scheduleSync();
      }
    }

    return UiCommandFeedbackHost(
      key: ValueKey('reminder-detail-session-$version'),
      builder: (_) => GeneralEventDetailsSheet(
        occurrence: occurrence,
        isReminderHandled: widget.provider.isGeneralReminderHandled(occurrence),
        onBeforeAction: () => currentOccurrence() != null && detach(),
        canEdit: () => _canInteract && widget.canEdit(),
        onBusyChanged: (value) {
          if (current()) session.setBusy(value);
        },
        onChildRouteChanged: (route) {
          if (!current()) return;
          _childRoute = route;
          session.setChildTask(route != null);
        },
        headerAction: session.independent
            ? null
            : TextButton.icon(
                key: const ValueKey('reminder-detail-detach'),
                style: TextButton.styleFrom(
                  foregroundColor: skedReadableAccent(
                    Theme.of(context).colorScheme,
                  ),
                ),
                onPressed: () => detach(),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  AppLocalizations.of(context).showReminderIndependently,
                ),
              ),
        onEditAnchor: (anchor) => widget.pane.editorEntry =
            WorkspaceEditorConfiguration(anchorContext: anchor),
        onEdit: () async {
          final latest = currentOccurrence();
          if (latest == null) return;
          session.close(force: true);
          await widget.onEdit(latest);
        },
        onDismissReminder: () => command(
          widget.provider.dismissGeneralReminder,
          message: l.reminderHandled,
        ),
        onRestoreReminder: () => command(
          widget.provider.restoreGeneralReminder,
          message: l.reminderRestored,
        ),
        onDuplicate: () => command((latest) async {
          await widget.provider.duplicateGeneralOccurrence(latest);
        }, message: l.eventDuplicated),
        onDeleteThis: () =>
            command(widget.provider.deleteGeneralOccurrence, deleting: true),
        onDeleteFuture: occurrence.event.recurrenceRule.isRepeating
            ? () => command(
                widget.provider.deleteFutureGeneralOccurrences,
                deleting: true,
              )
            : null,
        onDeleteAll: () => command(
          (latest) => widget.provider.deleteGeneralEvent(latest.event.id),
          deleting: true,
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) => Offstage(
    offstage: widget.pane.floatingEditor,
    child: ExcludeFocus(
      excluding: widget.pane.floatingEditor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final metrics = WorkbenchChromeMetrics.of(context);
          final render = _overlayKey.currentContext?.findRenderObject();
          _overlayOrigin = render is RenderBox && render.attached
              ? render.localToGlobal(Offset.zero)
              : Offset.zero;
          _bounds = Rect.fromLTRB(
            media.padding.left + 8,
            media.padding.top + metrics.toolbarHeight + 8,
            constraints.maxWidth - media.padding.right - 8,
            math.max(
              media.padding.top + metrics.toolbarHeight + 8,
              constraints.maxHeight -
                  math.max(media.padding.bottom, media.viewInsets.bottom) -
                  8,
            ),
          );
          final anchor = _anchorRect();
          final width = math.min(_bounds.width, 360 * metrics.textScale);
          final anchoredHeight = skedFloatingHeightLimit(
            _bounds,
            anchor,
            width,
          );
          if (session.independent) _independentHeightLimit ??= anchoredHeight;
          final heightLimit = session.independent
              ? math.min(_bounds.height, _independentHeightLimit!)
              : anchoredHeight;
          _lastHeightLimit = heightLimit;
          // Local tooltips share a full-size render-ancestor overlay. The detail
          // remains content-sized and the empty background does not hit-test.
          return Overlay.wrap(
            clipBehavior: Clip.none,
            child: Stack(
              key: _overlayKey,
              children: [
                Positioned.fill(
                  child: _ReminderHitRegion(
                    accepts: (point) =>
                        !session.independent && _inBridge(point),
                    child: MouseRegion(
                      onEnter: (_) => _enterDetail(),
                      onExit: (_) => _leaveDetail(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                CustomSingleChildLayout(
                  delegate: _ReminderDetailPosition(
                    bounds: _bounds,
                    anchor: anchor,
                    width: width,
                    heightLimit: heightLimit,
                    manual:
                        session.manualPosition ??
                        (session.independent ? _independentPosition : null),
                    lastPosition: _panel.isEmpty ? null : _panel.topLeft,
                    rtl: Directionality.of(context) == TextDirection.rtl,
                    onLayout: (position, size) {
                      _panel = position & size;
                      session.position.recordLayout(position, size);
                      if (session.independent && _independentPosition == null) {
                        _independentPosition = position;
                      }
                    },
                  ),
                  child: Listener(
                    onPointerDown: (_) {
                      // Clicking/dragging the independent window activates it even
                      // when the target is plain text, not a focusable control.
                      if (session.independent && _canInteract) {
                        _focus.requestFocus();
                      }
                    },
                    child: MouseRegion(
                      onEnter: (_) => _enterDetail(),
                      onExit: (_) => _leaveDetail(),
                      child: FocusScope(
                        node: _focus,
                        canRequestFocus: true,
                        onKeyEvent: _handleKey,
                        child: SkedFloatingSurface(
                          key: const ValueKey(
                            'workspace-companion-view-surface',
                          ),
                          child: WorkspaceViewTaskScope(
                            enabled: true,
                            onClose: dismiss,
                            showClose: session.independent,
                            onContentHeight: (_) {},
                            child: WorkspaceViewLayoutScope(
                              compact: true,
                              onDragUpdate: !session.independent
                                  ? null
                                  : (delta) {
                                      // Independent mode and busy policy belong to
                                      // the session; the controller only clamps geometry.
                                      if (session.blocked) return;
                                      session.position.recordLayout(
                                        _panel.topLeft,
                                        _panel.size,
                                      );
                                      session.moveTo(
                                        session.position.drag(delta, _bounds),
                                      );
                                    },
                              child: _details(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => OverlayPortal(
    overlayLocation: OverlayChildLocation.rootOverlay,
    controller: _portal,
    overlayChildBuilder: _overlay,
    child: _EventListDetailsScope(host: this, child: widget.child),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.provider.removeListener(_providerChanged);
    widget.pane.removeListener(_ownerChanged);
    _unregister?.call();
    session.removeListener(_changed);
    session.dispose();
    _focus.dispose();
    final child = _childRoute;
    if (child?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (child!.isActive) child.navigator?.removeRoute(child);
      });
    }
    super.dispose();
  }
}

/// Only the preview crossing corridor needs an extra hit region. Independent
/// windows have no barrier and do not intercept background input.
class _ReminderHitRegion extends SingleChildRenderObjectWidget {
  const _ReminderHitRegion({required this.accepts, required super.child});
  final bool Function(Offset) accepts;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReminderHitRegion(accepts);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReminderHitRegion renderObject,
  ) {
    renderObject.accepts = accepts;
  }
}

class _RenderReminderHitRegion extends RenderProxyBox {
  _RenderReminderHitRegion(this.accepts);
  bool Function(Offset) accepts;
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      accepts(position) && super.hitTest(result, position: position);
}

class _ReminderDetailPosition extends SingleChildLayoutDelegate {
  _ReminderDetailPosition({
    required this.bounds,
    required this.anchor,
    required this.width,
    required this.heightLimit,
    required this.manual,
    required this.lastPosition,
    required this.rtl,
    required this.onLayout,
  });
  final Rect bounds;
  final Rect? anchor;
  final double width, heightLimit;
  final Offset? manual, lastPosition;
  final bool rtl;
  final void Function(Offset, Size) onLayout;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: heightLimit);
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final position = manual != null || (anchor == null && lastPosition != null)
        ? boundSkedFloatingPosition(manual ?? lastPosition!, childSize, bounds)
        : positionSkedFloatingPanel(
            bounds: bounds,
            size: childSize,
            anchor: anchor,
            rtl: rtl,
            placement: SkedFloatingPlacement.left,
          );
    onLayout(position, childSize);
    return position;
  }

  @override
  bool shouldRelayout(_ReminderDetailPosition oldDelegate) => true;
}

/// Bind an agenda/reminder list without owning the shared detail lifetime.
class _EventListDetailsScope extends InheritedWidget {
  const _EventListDetailsScope({required this.host, required super.child});
  final _EventListDetailsHostState host;
  static _EventListDetailsHostState of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_EventListDetailsScope>()!
      .host;
  @override
  bool updateShouldNotify(_EventListDetailsScope oldWidget) =>
      host != oldWidget.host;
}

class _EventListDetailsBinding extends StatefulWidget {
  const _EventListDetailsBinding({required this.builder, this.contextToken});
  final Object? contextToken;
  final Widget Function(
    BuildContext,
    _EventListDetailsHostState,
    _EventListDetailsBindingState,
  )
  builder;
  @override
  State<_EventListDetailsBinding> createState() =>
      _EventListDetailsBindingState();
}

class _EventListDetailsBindingState extends State<_EventListDetailsBinding> {
  final bodyKey = GlobalKey(debugLabel: 'event-list-body');
  int? _id;
  int get id => _id!;
  bool scrolling = false, scrollSuppressed = false;
  String? hoveredKey;
  // Routes can coexist during exit/enter animations. Never share row keys
  // between them, even though both bind to the same workspace detail.
  final Map<String, GlobalKey> anchors = {};
  late _EventListDetailsHostState host;
  ModalRoute<dynamic>? route;
  bool visible = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    host = _EventListDetailsScope.of(context);
    route = ModalRoute.of(context);
    visible = TickerMode.valuesOf(context).enabled;
    _id ??= host._nextSourceId++;
    host._scheduleSync();
  }

  @override
  void didUpdateWidget(_EventListDetailsBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.contextToken != oldWidget.contextToken) {
      host.sourceContextChanged(this);
    }
    host._scheduleSync();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (_) => host.sourcePointerSignal(this),
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        host.sourceScroll(this, notification);
        return false;
      },
      child: widget.builder(context, host, this),
    ),
  );
  @override
  void dispose() {
    host.detachSource(this);
    super.dispose();
  }
}
