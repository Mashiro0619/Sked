import 'package:material_ui/material_ui.dart';

/// Desktop form layout only. Labels and editors keep their elements when the
/// available width changes; no state, navigation or validation is owned here.
class WorkspaceEditorField extends StatelessWidget {
  const WorkspaceEditorField({
    super.key,
    required this.label,
    required this.child,
    this.minimumControlWidth = 180,
    this.labelWidth = 104,
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
            child: child,
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
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, size: 16),
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
  });
  final String? title;
  final Widget? action;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        if (title != null || action != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
        else
          const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

InputDecoration workspaceEditorInputDecoration(
  BuildContext context,
  String label, {
  bool headline = false,
  String? hintText,
}) => InputDecoration(
  labelText: label,
  hintText: hintText,
  floatingLabelBehavior: FloatingLabelBehavior.never,
  labelStyle: headline ? Theme.of(context).textTheme.titleLarge : null,
  constraints: const BoxConstraints(minHeight: 36),
  filled: false,
  isDense: true,
  contentPadding: EdgeInsets.symmetric(
    horizontal: headline ? 0 : 10,
    vertical: 10,
  ),
  border: headline
      ? const UnderlineInputBorder()
      : OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
  focusedBorder: headline
      ? UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        )
      : OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(
      color: Theme.of(context).colorScheme.error,
      width: 2,
    ),
  ),
  enabledBorder: headline
      ? UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        )
      : OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
);
