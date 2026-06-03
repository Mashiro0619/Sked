import 'package:flutter/material.dart';

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
  });

  final List<DropdownMenuEntry<T>> dropdownMenuEntries;
  final T? initialSelection;
  final Widget? label;
  final Widget? leadingIcon;
  final EdgeInsetsGeometry? expandedInsets;
  final bool enabled;
  final ValueChanged<T?>? onSelected;

  @override
  State<SkedDropdownMenu<T>> createState() => _SkedDropdownMenuState<T>();
}

class _SkedDropdownMenuState<T> extends State<SkedDropdownMenu<T>> {
  static const double _menuOffsetY = 4;

  late T? _selectedValue = widget.initialSelection;

  @override
  void didUpdateWidget(covariant SkedDropdownMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelection != widget.initialSelection) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchorWidth = constraints.maxWidth;
        final menuStyle = _menuStyleForAnchor(baseMenuStyle, anchorWidth);
        return MenuAnchor(
          animated: !MediaQuery.disableAnimationsOf(context),
          style: menuStyle,
          alignmentOffset: const Offset(0, _menuOffsetY),
          crossAxisUnconstrained: false,
          menuChildren: [
            for (final entry in widget.dropdownMenuEntries)
              _SkedDropdownMenuItem<T>(
                entry: entry,
                selected: entry.value == _selectedValue,
                onSelected: widget.enabled && entry.enabled
                    ? (value) {
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
                onTap: widget.enabled
                    ? () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      }
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  isEmpty: selectedEntry == null,
                  decoration: InputDecoration(
                    label: widget.label,
                    prefixIcon: widget.leadingIcon,
                    enabled: widget.enabled,
                    suffixIcon: AnimatedRotation(
                      turns: controller.isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
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

    return (baseStyle ?? const MenuStyle()).copyWith(
      fixedSize: fixedSize,
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
    required this.entry,
    required this.selected,
    required this.onSelected,
  });

  final DropdownMenuEntry<T> entry;
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
        closeOnActivate: true,
        onPressed: enabled ? () => onSelected?.call(entry.value) : null,
        style:
            entry.style ??
            ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
