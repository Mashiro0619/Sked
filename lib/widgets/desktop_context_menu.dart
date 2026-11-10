import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_menu_item_content.dart';
import 'sked_popup_menu.dart';
import 'sked_task_session.dart';

/// One object action shared by a menu and other desktop entry points.
class DesktopAction {
  const DesktopAction({
    required this.id,
    required this.label,
    this.icon,
    this.shortcut,
    this.enabled = true,
    this.onInvoke,
  });

  final String id;
  final String label;
  final IconData? icon;

  /// An unmodified object key, such as F2 or Delete. Text fields keep their keys.
  final LogicalKeyboardKey? shortcut;
  String? get shortcutLabel => shortcut?.keyLabel;
  final bool enabled;
  final FutureOr<void> Function()? onInvoke;
}

/// The object and owner captured when an action entry point was invoked.
/// [isCurrent] remains usable while the action opens a confirmation dialog.
class DesktopActionContext {
  const DesktopActionContext({
    required this.context,
    required this.target,
    required this.isCurrent,
  });

  final BuildContext context;
  final Object target;
  final bool Function() isCurrent;
}

/// Opens object actions without selecting the object or adding a Tab stop.
/// Child controls receive their normal pointer and keyboard gestures first.
class DesktopContextMenuRegion extends StatefulWidget {
  const DesktopContextMenuRegion({
    super.key,
    required this.target,
    this.enabled = true,
    this.isOwnerCurrent,
    this.targetChanges,
    required this.actionsBuilder,
    required this.child,
  });

  final Object target;
  final bool enabled;

  /// Checks the feature and target lifetime, including hidden parent content.
  /// Covering the owner route with this menu or a dialog must remain valid.
  final bool Function()? isOwnerCurrent;
  final Listenable? targetChanges;
  final List<DesktopAction> Function(DesktopActionContext) actionsBuilder;
  final Widget child;

  @override
  State<DesktopContextMenuRegion> createState() =>
      _DesktopContextMenuRegionState();
}

class _DesktopContextMenuRegionState extends State<DesktopContextMenuRegion> {
  ModalRoute<dynamic>? _ownerRoute;
  SkedTaskSession? _parentSession;
  SkedTaskSession? _task;
  SkedMenuSession? _menu;
  bool _dependenciesRead = false;
  bool _sourceAttached = true;
  bool _visible = true;
  int _generation = 0;

  bool get _ownerCurrent =>
      mounted &&
      _visible &&
      widget.enabled &&
      widget.isOwnerCurrent?.call() != false;

  bool get _canOpen =>
      _sourceAttached &&
      _ownerCurrent &&
      _task == null &&
      _ownerRoute?.isCurrent != false &&
      _parentSession?.isCurrent != false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ownerRoute = ModalRoute.of(context);
    final parent = context
        .dependOnInheritedWidgetOfExactType<SkedTaskSessionScope>()
        ?.session;
    if (_dependenciesRead &&
        (!identical(ownerRoute, _ownerRoute) ||
            !identical(parent, _parentSession))) {
      _invalidate();
    }
    _dependenciesRead = true;
    _ownerRoute = ownerRoute;
    _parentSession = parent;
    _visible = TickerMode.valuesOf(context).enabled;
    _task?.check();
  }

  @override
  void didUpdateWidget(DesktopContextMenuRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target ||
        !identical(oldWidget.targetChanges, widget.targetChanges) ||
        (oldWidget.enabled && !widget.enabled)) {
      _invalidate();
    }
    _task?.check();
  }

  void _invalidate() {
    _generation++;
    _task?.invalidate();
    _menu?.invalidate();
  }

  @override
  void activate() {
    super.activate();
    _sourceAttached = true;
    _task?.check();
  }

  @override
  void deactivate() {
    _sourceAttached = false;
    // A normal selection already popped its menu. Preserve its pending result
    // when the source is only being reparented during that close.
    if (_menu?.isOpen == true) _invalidate();
    super.deactivate();
  }

  @override
  void dispose() {
    _invalidate();
    super.dispose();
  }

  void _launch(Offset? pointerPosition) {
    unawaited(
      _open(pointerPosition).catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'Sked desktop actions',
            context: ErrorDescription('while invoking an object action'),
          ),
        );
      }),
    );
  }

  SkedTaskSession _beginTask() {
    final generation = _generation;
    final target = widget.target;
    final targetChanges = widget.targetChanges;
    return _task = SkedTaskSession(
      ownerRoute: _ownerRoute,
      parent: _parentSession,
      targetChanges: targetChanges,
      isOwnerActive: () =>
          _ownerCurrent &&
          generation == _generation &&
          widget.target == target &&
          identical(widget.targetChanges, targetChanges),
    );
  }

  bool _invokeShortcut(LogicalKeyboardKey key) {
    final task = _beginTask();
    final invocation = DesktopActionContext(
      context: context,
      target: widget.target,
      isCurrent: () => task.isCurrent,
    );
    DesktopAction? selected;
    try {
      selected = widget
          .actionsBuilder(invocation)
          .where((action) => action.shortcut == key)
          .firstOrNull;
    } catch (_) {
      task.dispose();
      if (identical(_task, task)) _task = null;
      rethrow;
    }
    if (selected == null ||
        !task.isCurrent ||
        !selected.enabled ||
        selected.onInvoke == null) {
      task.dispose();
      if (identical(_task, task)) _task = null;
      return selected != null;
    }
    unawaited(_runShortcut(task, selected));
    return true;
  }

  Future<void> _runShortcut(SkedTaskSession task, DesktopAction action) async {
    try {
      await action.onInvoke!();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Sked desktop actions',
          context: ErrorDescription('while invoking an object shortcut'),
        ),
      );
    } finally {
      task.dispose();
      if (identical(_task, task)) _task = null;
    }
  }

  Future<void> _open(Offset? pointerPosition) async {
    if (!_canOpen) return;
    final source = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (source == null ||
        overlay == null ||
        !source.attached ||
        !overlay.attached) {
      return;
    }

    final target = widget.target;
    final menu = _menu = SkedMenuSession();
    final task = _beginTask();
    void checkTask() {
      if (!task.isCurrent) menu.invalidate();
    }

    task.addListener(checkTask);
    final actionContext = DesktopActionContext(
      context: context,
      target: target,
      isCurrent: () => task.isCurrent,
    );
    try {
      if (!task.isCurrent) return;
      final actions = widget.actionsBuilder(actionContext);
      if (actions.isEmpty || !task.isCurrent) return;
      assert(
        actions.map((action) => action.id).toSet().length == actions.length,
      );
      RelativeRect? lastPosition;
      final selected = await showSkedMenu<String>(
        context: context,
        menuSession: menu,
        items: [
          for (final action in actions)
            SkedPopupMenuItem<String>(
              value: action.id,
              enabled: action.enabled && action.onInvoke != null,
              child: SkedMenuItemContent(
                leading: action.icon == null ? null : Icon(action.icon),
                trailing: action.shortcutLabel == null
                    ? null
                    : Text(
                        action.shortcutLabel!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                child: Text(action.label),
              ),
            ),
        ],
        positionBuilder: (_, _) {
          if (!menu.valid || !source.attached || !overlay.attached) {
            return lastPosition ?? RelativeRect.fill;
          }
          final anchor = pointerPosition == null
              ? source.localToGlobal(Offset.zero, ancestor: overlay) &
                    source.size
              : overlay.globalToLocal(pointerPosition) & Size.zero;
          return lastPosition = RelativeRect.fromRect(
            anchor,
            Offset.zero & overlay.size,
          );
        },
      );
      if (selected == null || !menu.valid || !task.isCurrent) return;
      if (!_sourceAttached) await WidgetsBinding.instance.endOfFrame;
      if (!_sourceAttached || !menu.valid || !task.isCurrent) return;

      // Rebuild by identity after the menu closes: availability and callbacks
      // may have changed while the original menu items were visible.
      for (final action in widget.actionsBuilder(actionContext)) {
        if (action.id != selected) continue;
        if (!task.isCurrent || !action.enabled || action.onInvoke == null) {
          return;
        }
        await action.onInvoke!();
        return;
      }
    } finally {
      task.removeListener(checkTask);
      task.dispose();
      if (identical(_task, task)) _task = null;
      if (identical(_menu, menu)) _menu = null;
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_canOpen) return KeyEventResult.ignored;
    if (FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>() !=
        null) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (!keyboard.isShiftPressed &&
        (event.logicalKey == LogicalKeyboardKey.f2 ||
            event.logicalKey == LogicalKeyboardKey.delete) &&
        _invokeShortcut(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    final contextMenu =
        event.logicalKey == LogicalKeyboardKey.contextMenu &&
        !keyboard.isShiftPressed;
    final shiftF10 =
        event.logicalKey == LogicalKeyboardKey.f10 && keyboard.isShiftPressed;
    if (!contextMenu && !shiftF10) return KeyEventResult.ignored;
    _launch(null);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onKeyEvent: _onKeyEvent,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.enabled
          ? (details) => _launch(details.globalPosition)
          : null,
      child: widget.child,
    ),
  );
}
