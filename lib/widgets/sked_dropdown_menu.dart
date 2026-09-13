import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';
import 'workbench_chrome_metrics.dart';

import '../theme/sked_expressive_theme.dart';

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

  @override
  State<SkedDropdownMenu<T>> createState() => _SkedDropdownMenuState<T>();
}

class _SkedDropdownMenuState<T> extends State<SkedDropdownMenu<T>> {
  static const double _menuOffsetY = 4;

  late T? _selectedValue = widget.initialSelection;
  final _menu = MenuController();
  final _triggerFocus = FocusNode(debugLabel: 'Dropdown trigger');
  final _selectedItem = GlobalKey();
  TimetableProvider? _provider;
  Object? _dataSession;
  String? _workspaces;
  bool _compact = false, _ownerCurrent = true, _acceptSelection = false;
  int _generation = 0;

  bool get _sessionCurrent =>
      _ownerCurrent &&
      widget.enabled &&
      identical(_dataSession, _provider?.dataSessionToken) &&
      _workspaces ==
          _provider?.enabledWorkspaces.map((mode) => mode.value).join(',') &&
      (widget.workspace == null ||
          _provider?.isWorkspaceEnabled(widget.workspace!) != false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _compact = WorkbenchChromeMetrics.compactTouch(context);
    _ownerCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final provider = Provider.of<TimetableProvider?>(context, listen: false);
    if (!identical(provider, _provider)) {
      _provider?.removeListener(_checkSession);
      _provider = provider;
      provider?.addListener(_checkSession);
    }
    _checkSession();
  }

  void _checkSession() {
    if (_compact && _menu.isOpen && !_sessionCurrent) _invalidateMenu();
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
    if (!_compact) return;
    _dataSession = _provider?.dataSessionToken;
    _workspaces = _provider?.enabledWorkspaces
        .map((mode) => mode.value)
        .join(',');
    _acceptSelection = true;
    final generation = ++_generation;
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
    _acceptSelection = false;
    if (!_compact) return;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == _generation &&
          !_menu.isOpen &&
          _ownerCurrent &&
          widget.enabled) {
        _triggerFocus.requestFocus();
      }
    });
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
    _provider?.removeListener(_checkSession);
    _triggerFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SkedDropdownMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_compact &&
        _menu.isOpen &&
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
        dropdownTheme.menuStyle ?? MenuTheme.of(context).style;
    final selectedEntry = _entryForValue(_selectedValue);
    final expand = widget.expandedInsets == EdgeInsets.zero;
    final motion = SkedMotionPolicy.of(context);
    final shapes = skedShapeSchemeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchorWidth = constraints.maxWidth;
        final menuStyle = _menuStyleForAnchor(baseMenuStyle, anchorWidth);
        return MenuAnchor(
          controller: _menu,
          childFocusNode: _compact ? _triggerFocus : null,
          onOpen: _opened,
          onClose: _closed,
          animated: motion.spatialAnimationsEnabled,
          style: menuStyle,
          alignmentOffset: const Offset(0, _menuOffsetY),
          crossAxisUnconstrained: false,
          menuChildren: [
            for (final entry in widget.dropdownMenuEntries)
              _SkedDropdownMenuItem<T>(
                key: _compact && entry.value == _selectedValue
                    ? _selectedItem
                    : null,
                compact: _compact,
                entry: entry,
                selected: entry.value == _selectedValue,
                onSelected: widget.enabled && entry.enabled
                    ? (value) {
                        if (_compact) {
                          if (!_acceptSelection ||
                              !_menu.isOpen ||
                              !_sessionCurrent) {
                            return;
                          }
                          _acceptSelection = false;
                          _menu.close();
                        }
                        setState(() => _selectedValue = value);
                        widget.onSelected?.call(value);
                      }
                    : null,
              ),
          ],
          builder: (context, controller, child) {
            final field = Semantics(
              button: true,
              enabled: widget.enabled,
              expanded: controller.isOpen,
              child: InkWell(
                focusNode: _compact ? _triggerFocus : null,
                onTap: widget.enabled
                    ? () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      }
                    : null,
                borderRadius: shapes.fieldRadius,
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
            if (!expand) {
              return field;
            }
            return SizedBox(width: double.infinity, child: field);
          },
        );
      },
    );
  }

  MenuStyle _menuStyleForAnchor(MenuStyle? baseStyle, double anchorWidth) {
    final fixedSize = anchorWidth.isFinite && anchorWidth > 0
        ? WidgetStatePropertyAll(Size.fromWidth(anchorWidth))
        : null;

    if (!_compact) {
      return (baseStyle ?? const MenuStyle()).copyWith(
        fixedSize: fixedSize,
        alignment: AlignmentDirectional.bottomStart,
      );
    }
    final media = MediaQuery.of(context);
    final width = math.min(
      anchorWidth,
      math.max(0.0, media.size.width - media.padding.horizontal - 16),
    );
    final height = math.min(
      360.0,
      math.max(
        48.0,
        media.size.height -
            media.padding.top -
            math.max(media.padding.bottom, media.viewInsets.bottom) -
            16,
      ),
    );
    return (baseStyle ?? const MenuStyle()).copyWith(
      // A fixed Size.fromWidth has infinite height; clamping it to a finite
      // maximum would accidentally force every small menu to that maximum.
      fixedSize: const WidgetStatePropertyAll<Size?>(null),
      minimumSize: WidgetStatePropertyAll(Size(width, 0)),
      maximumSize: WidgetStatePropertyAll(Size(width, height)),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
      backgroundColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surface,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    required this.compact,
    required this.entry,
    required this.selected,
    required this.onSelected,
  });

  final DropdownMenuEntry<T> entry;
  final bool compact;
  final bool selected;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onSelected != null;
    final foregroundColor = !enabled
        ? colors.onSurface.withValues(alpha: 0.38)
        : selected
        ? colors.primary
        : colors.onSurface;
    final backgroundColor = selected
        ? colors.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MenuItemButton(
        leadingIcon: entry.leadingIcon,
        trailingIcon:
            entry.trailingIcon ??
            (selected ? Icon(Icons.check, color: colors.primary) : null),
        closeOnActivate: !compact,
        onPressed: enabled ? () => onSelected?.call(entry.value) : null,
        style:
            entry.style ??
            ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
              shape: WidgetStatePropertyAll(skedShapeSchemeOf(context).compact),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return colors.primary.withValues(alpha: 0.12);
                }
                return backgroundColor;
              }),
              foregroundColor: WidgetStatePropertyAll(foregroundColor),
              iconColor: WidgetStatePropertyAll(foregroundColor),
              overlayColor: _dropdownOverlayColor(colors),
            ),
        child: DefaultTextStyle.merge(
          maxLines: compact ? null : 1,
          overflow: compact ? TextOverflow.visible : TextOverflow.ellipsis,
          child: entry.labelWidget ?? Text(entry.label),
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

WidgetStateProperty<Color?> _dropdownOverlayColor(ColorScheme colors) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.transparent;
    }
    if (states.contains(WidgetState.pressed)) {
      return colors.primary.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.focused)) {
      return colors.primary.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return colors.primary.withValues(alpha: 0.08);
    }
    return null;
  });
}
