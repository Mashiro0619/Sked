import 'package:material_ui/material_ui.dart';

import '../theme/sked_surface.dart';
import '../theme/sked_expressive_theme.dart';
import 'sked_panel_header.dart';

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
            ? EdgeInsets.zero
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
  });

  final List<Widget> children;
  final List<int> flexes;
  final double breakpoint, spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth >= breakpoint;
      final totalFlex = List.generate(
        children.length,
        (index) => index < flexes.length ? flexes[index] : 1,
      ).fold(0, (sum, flex) => sum + flex);
      final availableWidth =
          constraints.maxWidth - spacing * (children.length - 1);
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
              width: horizontal
                  ? availableWidth *
                        (index < flexes.length ? flexes[index] : 1) /
                        totalFlex
                  : constraints.maxWidth,
              child: children[index],
            ),
          ],
        ],
      );
    },
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
