import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_tooltip.dart';

import '../models/timetable_models.dart';
import '../theme/sked_surface.dart';
import '../theme/sked_expressive_theme.dart';
import 'expressive_dialog.dart';
import 'sked_panel_header.dart';
import 'sked_dropdown_menu.dart';
import 'workbench_chrome_metrics.dart';

abstract final class WorkspaceEditorFormMetrics {
  static const controlHeight = 40.0;
  static const radius = 6.0;
  static const labelGap = 6.0;
  static const fieldGap = 12.0;
  static const sectionGap = 16.0;
  // Baseline for a compact field when the caller has no content measurement.
  // Each field can request its own width; columns do not stretch by default.
  static const minimumColumnWidth = 120.0;
}

TextStyle workspaceEditorLabelStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall!.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

TextStyle workspaceEditorContentStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurface,
    );

/// One input definition for touch sheets and compact desktop editors. The
/// caller owns the controller, validation and draft; only chrome is adaptive.
class SkedEditorTextField extends StatelessWidget {
  const SkedEditorTextField({
    super.key,
    required this.label,
    required this.controller,
    this.controlKey,
    this.enabled = true,
    this.icon,
    this.headline = false,
    this.formField = false,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.minLines,
    this.maxLines = 1,
    this.hintText,
    this.helperText,
    this.helperMaxLines,
    this.errorText,
    this.errorMaxLines,
    this.error,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
  });

  final String label;
  final TextEditingController controller;
  final Key? controlKey;
  final bool enabled, headline, formField;
  final bool autofocus, obscureText;
  final bool autocorrect, enableSuggestions;
  final IconData? icon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final int? minLines, maxLines, helperMaxLines, errorMaxLines;
  final String? hintText, helperText, errorText;
  final Widget? error, prefixIcon, suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final decoration =
        (desktop
                ? workspaceEditorInputDecoration(
                    context,
                    label,
                    headline: headline,
                  )
                : InputDecoration(labelText: label))
            .copyWith(
              hintText: hintText,
              helperText: helperText,
              helperMaxLines: helperMaxLines,
              errorText: errorText,
              errorMaxLines: errorMaxLines,
              error: error,
              prefixIcon:
                  prefixIcon ?? (!desktop && icon != null ? Icon(icon) : null),
              suffixIcon: suffixIcon,
              prefixIconConstraints: prefixIcon == null
                  ? null
                  : BoxConstraints(
                      minWidth: desktop ? 40 : 48,
                      minHeight: desktop ? 40 : 48,
                    ),
              suffixIconConstraints: suffixIcon == null
                  ? null
                  : BoxConstraints(
                      minWidth: desktop ? 40 : 48,
                      minHeight: desktop ? 40 : 48,
                    ),
            );
    final style = desktop
        ? headline
              ? workspaceEditorTitleStyle(context)
              : workspaceEditorContentStyle(context)
        : null;
    final input = formField || validator != null || autovalidateMode != null
        ? TextFormField(
            key: controlKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            obscureText: obscureText,
            autocorrect: autocorrect,
            enableSuggestions: enableSuggestions,
            style: style,
            decoration: decoration,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textAlign: textAlign,
            inputFormatters: inputFormatters,
            validator: validator,
            autovalidateMode: autovalidateMode,
            minLines: minLines,
            maxLines: maxLines,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
          )
        : TextField(
            key: controlKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            obscureText: obscureText,
            autocorrect: autocorrect,
            enableSuggestions: enableSuggestions,
            style: style,
            decoration: decoration,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textAlign: textAlign,
            inputFormatters: inputFormatters,
            minLines: minLines,
            maxLines: maxLines,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
          );
    if (!desktop) return input;
    return headline
        ? Semantics(label: label, child: input)
        : WorkspaceEditorField(label: label, child: input);
  }
}

/// The common picker field: a labelled 40dp value on desktop, and the course
/// editor's touch card with its icon, label and summary on phones and tablets.
class SkedEditorValueField extends StatelessWidget {
  const SkedEditorValueField({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
    this.enabled = true,
  });

  final String label, value;
  final ValueChanged<BuildContext>? onPressed;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return WorkspaceEditorField(
        label: label,
        child: Builder(
          builder: (anchor) => WorkspaceEditorValue(
            label: label,
            value: value,
            onPressed: active ? () => onPressed!(anchor) : null,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = active
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: .38);
    final secondary = active
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: .38);
    final onTap = active ? () => onPressed!(context) : null;
    return Semantics(
      container: true,
      button: true,
      enabled: active,
      label: label,
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      SkedEditorSelectionIcon(icon: icon!, enabled: active),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: secondary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reuses the app dropdown's routing, focus and stale-selection protection.
class SkedEditorChoiceField<T> extends StatelessWidget {
  const SkedEditorChoiceField({
    super.key,
    required this.label,
    required this.entries,
    required this.onSelected,
    this.initialSelection,
    this.controlKey,
    this.workspace,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final List<DropdownMenuEntry<T>> entries;
  final T? initialSelection;
  final Key? controlKey;
  final AppMode? workspace;
  final ValueChanged<T?>? onSelected;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final picker = SkedDropdownMenu<T>(
      key: controlKey,
      workspace: workspace,
      initialSelection: initialSelection,
      label: desktop ? null : Text(label),
      leadingIcon: desktop || icon == null ? null : Icon(icon),
      expandedInsets: EdgeInsets.zero,
      enabled: enabled,
      dropdownMenuEntries: entries,
      onSelected: onSelected,
    );
    return desktop
        ? WorkspaceEditorField(
            label: label,
            child: WorkspaceEditorDropdownStyle(child: picker),
          )
        : picker;
  }
}

/// Shared selection surface for picker rows and compact desktop option cells.
/// Business callers supply labels and selection callbacks, never density rules.
class SkedEditorOption extends StatelessWidget {
  const SkedEditorOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.leading,
    this.semanticLabel,
    this.compact = false,
  });

  final String label;
  final String? semanticLabel;
  final bool selected, compact;
  final Widget? leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = semanticLabel == null
        ? Text(label)
        : Semantics(
            label: semanticLabel,
            excludeSemantics: true,
            child: Text(label),
          );
    if (!WorkbenchChromeMetrics.of(context).desktop) {
      return ExpressiveDialogOption(
        title: text,
        titleMaxLines: null,
        leading: leading,
        selected: selected,
        enabled: onPressed != null,
        onTap: onPressed,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: selected
              ? compact
                    ? colors.onPrimaryContainer
                    : skedReadableAccent(
                        colors,
                        surface: Color.alphaBlend(
                          colors.primary.withValues(alpha: .12),
                          SkedSurface.colorOf(context),
                        ),
                      )
              : colors.onSurface,
          backgroundColor: selected
              ? compact
                    ? colors.primaryContainer
                    : colors.primary.withValues(alpha: .12)
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: compact
            ? text
            : Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 6)],
                  Expanded(child: text),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: selected ? const Icon(Icons.check, size: 16) : null,
                  ),
                ],
              ),
      ),
    );
  }
}

class SkedEditorSelectionIcon extends StatelessWidget {
  const SkedEditorSelectionIcon({
    super.key,
    required this.icon,
    this.enabled = true,
  });
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: ShapeDecoration(
        color: colors.primary.withValues(alpha: enabled ? .10 : .05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Icon(
        icon,
        color: enabled
            ? skedReadableAccent(
                colors,
                surface: colors.primary.withValues(alpha: .10),
              )
            : colors.onSurface.withValues(alpha: .38),
      ),
    );
  }
}

/// A picker action inside a grouped date/time range. Touch groups can expose
/// an icon action or an inline label/value while desktop always uses the same
/// compact value control as standalone fields.
class SkedEditorValueAction extends StatelessWidget {
  const SkedEditorValueAction({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
    this.iconOnlyOnTouch = false,
    this.tooltip,
    this.enabled = true,
  });

  final String label, value;
  final String? tooltip;
  final ValueChanged<BuildContext>? onPressed;
  final IconData? icon;
  final bool iconOnlyOnTouch, enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    final onTap = active ? () => onPressed!(context) : null;
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return SkedTooltip(
        message: tooltip ?? label,
        child: WorkspaceEditorValue(
          label: label,
          value: value,
          onPressed: onTap,
        ),
      );
    }
    if (iconOnlyOnTouch) {
      return IconButton(
        tooltip: tooltip ?? label,
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        icon: Icon(icon),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      enabled: active,
      label: label,
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: skedShapeSchemeOf(context).compact,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: active
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: .38),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: active
                                ? colors.onSurfaceVariant
                                : colors.onSurface.withValues(alpha: .38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared boolean field for compact rows and touch option cards.
class SkedEditorSwitchField extends StatelessWidget {
  const SkedEditorSwitchField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: workspaceEditorContentStyle(
                context,
              ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: label,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      );
    }
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        secondary: icon == null
            ? null
            : SkedEditorSelectionIcon(icon: icon!, enabled: onChanged != null),
        title: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// A disclosure keeps its children alive across collapse/expand. Desktop
/// editors opt into compact chrome; touch editors retain the full tile.
class WorkspaceEditorDisclosure extends StatelessWidget {
  const WorkspaceEditorDisclosure({
    super.key,
    this.controller,
    required this.icon,
    required this.title,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.enabled,
    required this.child,
    this.subtitle,
    this.compact = false,
  });

  final ExpansibleController? controller;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool initiallyExpanded, enabled, compact;
  final ValueChanged<bool> onExpansionChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = compact
        ? const RoundedRectangleBorder()
        : skedShapeSchemeOf(context).field;
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        controller: controller,
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        enabled: enabled,
        onExpansionChanged: enabled ? onExpansionChanged : null,
        leading: compact ? null : Icon(icon),
        minTileHeight: compact ? 36 : null,
        title: Text(
          title,
          style: compact
              ? workspaceEditorContentStyle(context).copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        tilePadding: compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
            : const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
        childrenPadding: compact
            ? const EdgeInsets.only(top: 12)
            : const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
        shape: shape,
        collapsedShape: shape,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        children: [child],
      ),
    );
  }
}

/// Touch forms and compact picker forms share the same responsive row. Keeping
/// the Flex and child slots stable preserves input focus when it changes axis.
class ResponsiveEditorFormRow extends StatelessWidget {
  const ResponsiveEditorFormRow({
    super.key,
    required this.children,
    this.flexes = const [],
    this.breakpoint = 480,
    this.spacing = 12,
    this.fitContent = false,
    this.minimumChildWidths = const [],
  });

  final List<Widget> children;
  final List<int> flexes;
  final double breakpoint, spacing;
  final bool fitContent;
  final List<double> minimumChildWidths;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      assert(
        minimumChildWidths.isEmpty ||
            minimumChildWidths.length == children.length,
      );
      final scale = WorkbenchChromeMetrics.of(context).textScale;
      final widths = List.generate(
        children.length,
        (index) => minimumChildWidths.isEmpty
            ? WorkspaceEditorFormMetrics.minimumColumnWidth * scale
            : minimumChildWidths[index],
      );
      final minimumWidth =
          widths.fold(0.0, (sum, width) => sum + width) +
          spacing * math.max(0, children.length - 1);
      final horizontal = fitContent
          ? minimumWidth <= constraints.maxWidth
          : constraints.maxWidth >= breakpoint;
      final weights = List.generate(
        children.length,
        (index) => index < flexes.length
            ? (fitContent ? flexes[index] : math.max(1, flexes[index]))
            : (fitContent ? 0 : 1),
      );
      final totalFlex = weights.fold(0, (sum, flex) => sum + flex);
      final availableWidth =
          constraints.maxWidth - spacing * (children.length - 1);
      final spareWidth = math.max(0.0, constraints.maxWidth - minimumWidth);
      double childWidth(int index) {
        if (!fitContent) {
          return horizontal
              ? availableWidth * weights[index] / totalFlex
              : constraints.maxWidth;
        }
        if (!horizontal) {
          return weights[index] > 0
              ? constraints.maxWidth
              : math.min(constraints.maxWidth, widths[index]);
        }
        return widths[index] +
            (totalFlex == 0 ? 0 : spareWidth * weights[index] / totalFlex);
      }

      return Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              SizedBox(
                width: horizontal ? spacing : 0,
                height: horizontal ? 0 : spacing,
              ),
            SizedBox(
              width: horizontal ? childWidth(index) : constraints.maxWidth,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                heightFactor: 1,
                child: SizedBox(
                  width: childWidth(index),
                  child: children[index],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Preserves child slots while adapting touch-width rows to compact,
/// content-sized desktop fields. Width hints describe content, not platforms.
class SkedEditorFormRow extends StatelessWidget {
  const SkedEditorFormRow({
    super.key,
    required this.children,
    this.flexes = const [],
    this.minimumChildWidths = const [],
    this.breakpoint = 480,
    this.spacing = 12,
  });

  final List<Widget> children;
  final List<int> flexes;
  final List<double> minimumChildWidths;
  final double breakpoint, spacing;

  @override
  Widget build(BuildContext context) => ResponsiveEditorFormRow(
    flexes: flexes,
    breakpoint: breakpoint,
    spacing: spacing,
    minimumChildWidths: minimumChildWidths,
    fitContent: WorkbenchChromeMetrics.of(context).desktop,
    children: children,
  );
}

/// Desktop form layout only. Labels and editors keep their elements when the
/// available width changes; no state, navigation or validation is owned here.
class WorkspaceEditorField extends StatelessWidget {
  const WorkspaceEditorField({
    super.key,
    required this.label,
    required this.child,
  });
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: workspaceEditorLabelStyle(context)),
      const SizedBox(height: WorkspaceEditorFormMetrics.labelGap),
      Semantics(
        key: const ValueKey('editor-field-control'),
        label: label,
        child: child,
      ),
    ],
  );
}

/// A compact form control. The caller provides its visible field label.
class WorkspaceEditorValue extends StatelessWidget {
  const WorkspaceEditorValue({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
  });
  final String label, value;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: value,
    button: true,
    enabled: onPressed != null,
    child: TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            minimumSize: const Size(
              0,
              WorkspaceEditorFormMetrics.controlHeight,
            ),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            textStyle: workspaceEditorContentStyle(context),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            disabledForegroundColor: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: .38),
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: .35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                WorkspaceEditorFormMetrics.radius,
              ),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith((states) {
              final colors = Theme.of(context).colorScheme;
              return BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? colors.outlineVariant.withValues(alpha: .38)
                    : states.contains(WidgetState.focused)
                    ? skedReadableAccent(
                        colors,
                        surface: colors.surfaceContainerHighest,
                      )
                    : states.contains(WidgetState.hovered)
                    ? colors.outline
                    : colors.outlineVariant,
              );
            }),
          ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(value)),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: onPressed == null
                  ? null
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

class WorkspaceEditorFormSection extends StatelessWidget {
  const WorkspaceEditorFormSection({
    super.key,
    this.title,
    this.action,
    required this.child,
    this.divider = false,
  });
  final bool divider;
  final String? title;
  final Widget? action;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: WorkspaceEditorFormMetrics.sectionGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (divider) const Divider(height: 1),
        if (title != null || action != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (title != null)
                  Text(title!, style: Theme.of(context).textTheme.labelLarge),
                ?action,
              ],
            ),
          )
        else if (divider)
          const SizedBox(height: 4),
        child,
      ],
    ),
  );
}

TextStyle workspaceEditorTitleStyle(BuildContext context) =>
    skedPanelHeadlineStyle(context);

InputDecoration workspaceEditorInputDecoration(
  BuildContext context,
  String label, {
  bool headline = false,
  String? hintText,
}) {
  final colors = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(WorkspaceEditorFormMetrics.radius),
    borderSide: headline
        ? BorderSide.none
        : BorderSide(color: colors.outlineVariant),
  );
  return InputDecoration(
    hintText: headline ? (hintText ?? label) : hintText,
    hintStyle: headline
        ? workspaceEditorTitleStyle(context)
              .copyWith(color: colors.onSurfaceVariant)
        : null,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    constraints: const BoxConstraints(
      minHeight: WorkspaceEditorFormMetrics.controlHeight,
    ),
    filled: !headline,
    fillColor: colors.surfaceContainerHighest.withValues(alpha: .35),
    isDense: true,
    visualDensity: VisualDensity.standard,
    contentPadding: EdgeInsets.symmetric(
      horizontal: headline ? 0 : 10,
      vertical: headline ? 8 : 10,
    ),
    border: border,
    enabledBorder: border,
    disabledBorder: headline
        ? border
        : border.copyWith(
            borderSide: BorderSide(
              color: colors.outlineVariant.withValues(alpha: .38),
            ),
          ),
    focusedBorder: border.copyWith(
      borderSide: BorderSide(
        color: skedReadableAccent(
          colors,
          surface: colors.surfaceContainerHighest,
        ),
      ),
    ),
    errorBorder: border.copyWith(borderSide: BorderSide(color: colors.error)),
    focusedErrorBorder: border.copyWith(
      borderSide: BorderSide(color: colors.error, width: 2),
    ),
  );
}

/// Limit decoration overrides to this editor's dropdown trigger. Menus keep
/// their original routing, keyboard behavior and selected-value semantics.
class WorkspaceEditorDropdownStyle extends StatelessWidget {
  const WorkspaceEditorDropdownStyle({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentStyle = workspaceEditorContentStyle(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(WorkspaceEditorFormMetrics.radius),
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          titleMedium: contentStyle,
          bodyLarge: contentStyle,
          bodyMedium: contentStyle,
        ),
        dropdownMenuTheme: theme.dropdownMenuTheme.copyWith(
          textStyle: contentStyle,
          inputDecorationTheme: InputDecorationThemeData(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: .35,
            ),
            isDense: true,
            visualDensity: VisualDensity.standard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            constraints: const BoxConstraints(
              minHeight: WorkspaceEditorFormMetrics.controlHeight,
            ),
            border: border,
            enabledBorder: border,
            disabledBorder: border.copyWith(
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .38),
              ),
            ),
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: skedReadableAccent(
                  theme.colorScheme,
                  surface: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: WorkspaceEditorFormMetrics.controlHeight,
            ),
          ),
        ),
      ),
      child: DefaultTextStyle.merge(style: contentStyle, child: child),
    );
  }
}
