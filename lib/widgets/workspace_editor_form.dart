import 'package:material_ui/material_ui.dart';

/// Desktop form layout only. Labels and editors keep their elements when the
/// available width changes; no state, navigation or validation is owned here.
class WorkspaceEditorField extends StatelessWidget {
  const WorkspaceEditorField({
    super.key,
    required this.label,
    required this.child,
    this.minimumControlWidth = 180,
    this.labelWidth = 96,
  });
  final String label;
  final Widget child;
  final double minimumControlWidth, labelWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final labelExtent = labelWidth * scale;
      final horizontal =
          bounds.maxWidth >= labelExtent + 12 + minimumControlWidth * scale;
      return Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: horizontal ? labelExtent : bounds.maxWidth,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('editor-field-control'),
            width: horizontal
                ? bounds.maxWidth - labelExtent - 12
                : bounds.maxWidth,
            child: Semantics(label: label, child: child),
          ),
        ],
      );
    },
  );
}

/// A value, not a two-line menu tile. The caller provides the field label.
class WorkspaceEditorValue extends StatelessWidget {
  const WorkspaceEditorValue({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
    this.tonal = false,
  });
  final String label, value;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool tonal;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: value,
    button: true,
    enabled: onPressed != null,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        disabledForegroundColor: Theme.of(context).colorScheme.onSurface
            .withValues(alpha: .38),
        backgroundColor: tonal
            ? Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: .45)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(value)),
            const SizedBox(width: 6),
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
    padding: const EdgeInsets.only(top: 12),
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
    Theme.of(context).textTheme.titleLarge!
        .copyWith(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25);

InputDecoration workspaceEditorInputDecoration(
  BuildContext context,
  String label, {
  bool headline = false,
  String? hintText,
  bool metadata = false,
}) {
  final colors = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: headline || metadata ? (hintText ?? label) : hintText,
    hintStyle: headline
        ? workspaceEditorTitleStyle(context)
              .copyWith(color: colors.onSurfaceVariant)
        : null,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    constraints: const BoxConstraints(minHeight: 36),
    filled: !headline,
    fillColor: metadata
        ? Colors.transparent
        : colors.surfaceContainerHighest.withValues(alpha: .35),
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: headline ? 0 : 10,
      vertical: headline ? 8 : 10,
    ),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colors.primary),
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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide.none,
    );
    return Theme(
      data: theme.copyWith(
        dropdownMenuTheme: theme.dropdownMenuTheme.copyWith(
          inputDecorationTheme: InputDecorationThemeData(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: .35,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            constraints: const BoxConstraints(minHeight: 36),
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 36,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}
