import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/workspace_view_state.dart';

import '../theme/sked_expressive_theme.dart';
import '../theme/sked_menu_style.dart';
import 'sked_menu_item_content.dart';
import 'sked_menu_anchor.dart';

/// Builds row content around a current-value anchor. The dropdown owns pointer
/// activation and a single keyboard/semantics trigger for the whole row.
typedef SkedDropdownFieldBuilder = Widget Function(
  BuildContext context,
  String? selectedLabel,
  Widget Function(Widget child) anchor,
);

class SkedDropdownMenu<T> extends StatefulWidget {
  const SkedDropdownMenu({
    super.key,
    required this.dropdownMenuEntries,
    this.initialSelection,
    this.label,
    this.leadingIcon,
    this.expandedInsets,
    this.enabled = true,
    this.onSelected,
    this.workspace,
    this.sessionKey,
    this.fieldBuilder,
  });

  final List<DropdownMenuEntry<T>> dropdownMenuEntries;
  final T? initialSelection;
  final Widget? label;
  final Widget? leadingIcon;
  final EdgeInsetsGeometry? expandedInsets;
  final bool enabled;
  final ValueChanged<T?>? onSelected;
  final AppMode? workspace;
  final Object? sessionKey;

  /// Optional row presentation. Wrap only the current-value control with
  /// [SkedDropdownFieldBuilder]'s anchor so the popup follows that control,
  /// rather than taking the row's full width. Non-settings fields stay unchanged.
  final SkedDropdownFieldBuilder? fieldBuilder;

  @override
  State<SkedDropdownMenu<T>> createState() => _SkedDropdownMenuState<T>();
}

class _SkedDropdownMenuState<T> extends State<SkedDropdownMenu<T>>
    with WidgetsBindingObserver {
  late T? _selectedValue = widget.initialSelection;
  final _menu = MenuController();
  final _triggerFocus = FocusNode(debugLabel: 'Dropdown trigger');
  GlobalKey _selectedItem = GlobalKey();
  AppDataMaintenance? _maintenance;
  WorkspaceViewState? _workspaceView;
  Listenable? _sessionChanges;
  Object? _dataSession;
  String? _workspaces;
  bool _ownerCurrent = true, _acceptSelection = false;
  bool _menuClosing = false;
  int _generation = 0;
  bool _restoreTriggerFocus = true;

  bool get _sessionCurrent =>
      _ownerCurrent &&
      widget.enabled &&
      identical(_dataSession, _maintenance?.dataSessionToken) &&
      _workspaces ==
          _workspaceView?.enabledWorkspaces
              .map((mode) => mode.value)
              .join(',') &&
      (widget.workspace == null ||
          _workspaceView?.isEnabled(widget.workspace!) != false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    // The field may see unchanged, already-consumed page insets while the
    // open popup's available overlay height changes with the keyboard.
    if (mounted && _menu.isOpen) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ownerCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final maintenance = context.read<AppDataMaintenance?>();
    final workspaceView = context.read<WorkspaceViewState?>();
    if (!identical(maintenance, _maintenance) ||
        !identical(workspaceView, _workspaceView)) {
      _sessionChanges?.removeListener(_checkSession);
      _maintenance = maintenance;
      _workspaceView = workspaceView;
      _sessionChanges = Listenable.merge([maintenance, workspaceView])
        ..addListener(_checkSession);
    }
    _checkSession();
  }

  void _checkSession() {
    if (_menu.isOpen && !_sessionCurrent) _invalidateMenu();
  }

  void _invalidateMenu() {
    _acceptSelection = false;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && _menu.isOpen) _menu.close();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _opened() {
    _menuClosing = false;
    // Scroll the current selection into view without moving an old item State
    // (and its pending post-frame activation) into the new menu session.
    _selectedItem = GlobalKey();
    _dataSession = _maintenance?.dataSessionToken;
    _workspaces = _workspaceView?.enabledWorkspaces
        .map((mode) => mode.value)
        .join(',');
    _acceptSelection = true;
    final generation = ++_generation;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final itemContext = _selectedItem.currentContext;
      if (mounted &&
          generation == _generation &&
          _menu.isOpen &&
          itemContext != null) {
        unawaited(Scrollable.ensureVisible(itemContext, alignment: .5));
      }
    });
  }

  void _closed() {
    _menuClosing = false;
    _acceptSelection = false;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == _generation &&
          !_menu.isOpen &&
          _ownerCurrent &&
          widget.enabled) {
        if (_restoreTriggerFocus) {
          _triggerFocus.requestFocus();
        } else if (_triggerFocus.hasFocus) {
          // Release pointer focus without returning to the previously edited
          // TextField, which would reopen its IME and scroll the form to it.
          _triggerFocus.unfocus();
        }
      }
    });
  }

  Widget _trackInput(Widget child) {
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onKeyEvent: (_, event) {
        // Escape alone dismisses a pointer-opened menu without changing the input
        // mode. Actual keyboard navigation/activation keeps the trigger reachable.
        if (event is KeyDownEvent &&
            event.logicalKey != LogicalKeyboardKey.escape) {
          _restoreTriggerFocus = true;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _restoreTriggerFocus = false,
        child: child,
      ),
    );
  }

  bool _entriesChanged(List<DropdownMenuEntry<T>> before) {
    final after = widget.dropdownMenuEntries;
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      if (before[i].value != after[i].value ||
          before[i].label != after[i].label ||
          before[i].enabled != after[i].enabled) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _sessionChanges?.removeListener(_checkSession);
    _triggerFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SkedDropdownMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_menu.isOpen &&
        (!widget.enabled ||
            widget.workspace != oldWidget.workspace ||
            widget.sessionKey != oldWidget.sessionKey ||
            _entriesChanged(oldWidget.dropdownMenuEntries))) {
      _invalidateMenu();
    }
    // A command may fail without changing the provider value.  The menu is
    // disabled while that command is in flight, so resync when it reopens as
    // well as when its controlled value changes.  This clears an optimistic
    // local selection after a failed save without disturbing an editor draft
    // during ordinary rebuilds.
    final saveFinished = !oldWidget.enabled && widget.enabled;
    if (oldWidget.initialSelection != widget.initialSelection || saveFinished) {
      _selectedValue = widget.initialSelection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dropdownTheme = theme.dropdownMenuTheme;
    final effectiveInputDecorationTheme =
        dropdownTheme.inputDecorationTheme ?? theme.inputDecorationTheme;
    final baseMenuStyle =
        dropdownTheme.menuStyle ??
        MenuTheme.of(context).style ??
        SkedMenuStyle.of(context).menuStyle;
    final selectedEntry = _entryForValue(_selectedValue);
    final expand = widget.expandedInsets == EdgeInsets.zero;
    final motion = SkedMotionPolicy.of(context);
    final shapes = skedShapeSchemeOf(context);

    return LayoutBuilder(
      builder: (context, _) {
        final menuStyle = _menuStyleForAnchor(baseMenuStyle);
        final generation = _generation;
        void toggleMenu() {
          if (_menu.isOpen && !_menuClosing) {
            _menu.close();
          } else {
            _triggerFocus.requestFocus();
            _menu.open();
          }
        }

        Widget trigger(Widget content) => Semantics(
          button: true,
          enabled: widget.enabled,
          child: InkWell(
            focusNode: _triggerFocus,
            onTap: widget.enabled ? toggleMenu : null,
            borderRadius: shapes.fieldRadius,
            child: content,
          ),
        );
        Widget anchor({Widget? child}) => SkedMenuAnchor(
          controller: _menu,
          childFocusNode: _triggerFocus,
          onOpen: _opened,
          onClose: _closed,
          onAnimationStatusChanged: (status) {
            if (status == AnimationStatus.reverse) {
              _menuClosing = true;
              _acceptSelection = false;
              _generation++;
            }
          },
          style: menuStyle,
          clipBehavior: Clip.antiAlias,
          alignmentOffset: Offset.zero,
          crossAxisUnconstrained: false,
          menuChildren: [
            for (final entry in widget.dropdownMenuEntries)
              _trackInput(
                _SkedDropdownMenuItem<T>(
                  key: entry.value == _selectedValue ? _selectedItem : null,
                  entry: entry,
                  selected: entry.value == _selectedValue,
                  onSelected: widget.enabled && entry.enabled
                      ? (value) {
                          if (!_acceptSelection ||
                              generation != _generation ||
                              !_menu.isOpen ||
                              !_sessionCurrent) {
                            return;
                          }
                          _acceptSelection = false;
                          _menu.close();
                          setState(() => _selectedValue = value);
                          widget.onSelected?.call(value);
                        }
                      : null,
                ),
              ),
          ],
          child: child,
          builder: (context, controller, anchorChild) {
            if (anchorChild != null) {
              return Material(
                type: MaterialType.transparency,
                child: trigger(
                  Semantics(expanded: controller.isOpen, child: anchorChild),
                ),
              );
            }
            return trigger(
              Semantics(
                expanded: controller.isOpen,
                child: InputDecorator(
                  isEmpty: selectedEntry == null,
                  decoration: InputDecoration(
                    label: widget.label,
                    prefixIcon: widget.leadingIcon,
                    enabled: widget.enabled,
                    suffixIcon: AnimatedRotation(
                      turns: controller.isOpen ? 0.5 : 0,
                      duration: motion.spatialAnimationsEnabled
                          ? motion.effects(SkedMotionSpeed.fast)
                          : Duration.zero,
                      curve: motion.scheme.enterCurve,
                      child: const Icon(Icons.arrow_drop_down),
                    ),
                  ).applyDefaults(effectiveInputDecorationTheme),
                  child: _SelectedDropdownLabel(entry: selectedEntry),
                ),
              ),
            );
          },
        );
        final field = widget.fieldBuilder == null
            ? anchor()
            : MergeSemantics(
                child: InkWell(
                  // Pointer users may activate the full row, but keyboard and
                  // semantics have one trigger inside the actual MenuAnchor.
                  canRequestFocus: false,
                  excludeFromSemantics: true,
                  onTap: widget.enabled ? toggleMenu : null,
                  borderRadius: shapes.fieldRadius,
                  child: widget.fieldBuilder!(
                    context,
                    selectedEntry?.label,
                    (child) => anchor(child: child),
                  ),
                ),
              );
        final interactiveField = TapRegion(
          // The whole row is inside the menu's tap region so a slow tap
          // closes it once. Outside clicks must not have focus stolen back.
          groupId: _menu,
          onTapOutside: (_) {
            if (_menu.isOpen) _restoreTriggerFocus = false;
          },
          child: _trackInput(field),
        );
        return expand
            ? SizedBox(width: double.infinity, child: interactiveField)
            : interactiveField;
      },
    );
  }

  MenuStyle _menuStyleForAnchor(MenuStyle? baseStyle) {
    final constraints = SkedMenuStyle.constraintsFor(context);
    return (baseStyle ?? const MenuStyle()).copyWith(
      fixedSize: const WidgetStatePropertyAll<Size?>(null),
      minimumSize: WidgetStatePropertyAll(Size(constraints.minWidth, 0)),
      maximumSize: WidgetStatePropertyAll(
        Size(constraints.maxWidth, constraints.maxHeight),
      ),
      alignment: AlignmentDirectional.bottomStart,
    );
  }

  DropdownMenuEntry<T>? _entryForValue(T? value) {
    for (final entry in widget.dropdownMenuEntries) {
      if (entry.value == value) {
        return entry;
      }
    }
    return null;
  }
}

class _SkedDropdownMenuItem<T> extends StatelessWidget {
  const _SkedDropdownMenuItem({
    super.key,
    required this.entry,
    required this.selected,
    required this.onSelected,
  });

  final DropdownMenuEntry<T> entry;
  final bool selected;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final menu = SkedMenuStyle.of(context);
    final enabled = onSelected != null;
    final style = menu.itemStyle(selected: selected);

    return Padding(
      padding: menu.itemMargin,
      child: Semantics(
        checked: selected,
        child: MenuItemButton(
          overflowAxis: Axis.vertical,
          requestFocusOnHover: false,
          closeOnActivate: false,
          onPressed: enabled ? () => onSelected?.call(entry.value) : null,
          style: entry.style?.merge(style) ?? style,
          child: SkedMenuItemContent(
            leading: entry.leadingIcon,
            trailing: entry.trailingIcon,
            selected: selected,
            child: DefaultTextStyle.merge(
              maxLines: null,
              overflow: TextOverflow.visible,
              child: entry.labelWidget ?? Text(entry.label),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDropdownLabel<T> extends StatelessWidget {
  const _SelectedDropdownLabel({required this.entry});

  final DropdownMenuEntry<T>? entry;

  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    if (entry == null) {
      return const SizedBox(height: 24);
    }
    return DefaultTextStyle.merge(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: entry.labelWidget ?? Text(entry.label),
    );
  }
}
