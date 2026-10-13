import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Shared read-only properties for details and import summaries. Interactive
/// choices use the editor/selection controls rather than this presentation.
class SkedDetailRow extends StatelessWidget {
  const SkedDetailRow({
    super.key,
    required this.value,
    this.label,
    this.icon,
    this.stacked = false,
    this.compact = false,
    this.labelWidth,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final String value;
  final String? label;
  final IconData? icon;
  final bool stacked, compact;
  final double? labelWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueText = Text(
      value,
      softWrap: true,
      style: _valueStyle(context, compact),
    );
    final labelText = label == null
        ? null
        : Text(label!, style: _labelStyle(context, compact));
    final Widget content;
    if (labelText == null) {
      content = valueText;
    } else if (stacked) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          labelText,
          if (value.isNotEmpty) ...[const SizedBox(height: 2), valueText],
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labelWidth == null)
            Flexible(flex: 3, child: labelText)
          else
            SizedBox(width: labelWidth, child: labelText),
          const SizedBox(width: 12),
          if (labelWidth == null)
            Flexible(flex: 7, child: valueText)
          else
            Expanded(child: valueText),
        ],
      );
    }
    return Padding(
      padding: padding,
      child: icon == null
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: content),
              ],
            ),
    );
  }
}

/// Align labels as a group while retaining the desktop compact presentation
/// and stacking whole properties when large text exhausts the available width.
class SkedDetailGroup extends StatelessWidget {
  const SkedDetailGroup({
    super.key,
    required this.entries,
    this.compact = false,
  });

  final List<({String label, String value})> entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries)
            SkedDetailRow(label: entry.label, value: entry.value),
        ],
      );
    }
    final scaler = MediaQuery.textScalerOf(context);
    var labelWidth = 56 * scaler.scale(12) / 12;
    for (final entry in entries) {
      final painter = TextPainter(
        text: TextSpan(text: entry.label, style: _labelStyle(context, true)),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      labelWidth = math.max(labelWidth, painter.width);
      painter.dispose();
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        final stacked =
            labelWidth + 12 + 160 * scaler.scale(14) / 14 > bounds.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < entries.length; index++)
              SkedDetailRow(
                label: entries[index].label,
                value: entries[index].value,
                compact: true,
                stacked: stacked,
                labelWidth: labelWidth,
                padding: EdgeInsets.only(
                  bottom: index == entries.length - 1 ? 0 : 8,
                ),
              ),
          ],
        );
      },
    );
  }
}

TextStyle? _labelStyle(BuildContext context, bool compact) {
  final theme = Theme.of(context);
  return compact
      ? theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.75,
          color: theme.colorScheme.onSurfaceVariant,
        )
      : theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
}

TextStyle? _valueStyle(BuildContext context, bool compact) => compact
    ? Theme.of(context).textTheme.bodyMedium
          ?.copyWith(fontSize: 14, height: 1.5)
    : Theme.of(context).textTheme.bodyMedium;
