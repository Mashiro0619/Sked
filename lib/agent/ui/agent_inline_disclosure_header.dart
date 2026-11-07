import 'package:material_ui/material_ui.dart';

import '../../theme/sked_menu_style.dart';

/// A disclosure whose hover and tap surface follows its visible content.
class AgentInlineDisclosureHeader extends StatelessWidget {
  const AgentInlineDisclosureHeader({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.titleStyle,
    this.semanticsLabel,
    this.expanded,
    this.onTap,
    this.toggleKey,
    this.controlsKey,
    this.maxLines = 2,
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final TextStyle? titleStyle;
  final String? semanticsLabel;
  final bool? expanded;
  final VoidCallback? onTap;
  final Key? toggleKey;
  final Key? controlsKey;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final disclosure = expanded != null;
    final desktop = SkedMenuStyle.of(context).desktop;
    final extent = disclosure ? (desktop ? 32.0 : 48.0) : 24.0;
    final style =
        titleStyle ??
        theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: extent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading case final icon?) ...[icon, const SizedBox(width: 8)],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: style,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle case final detail?)
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (disclosure) ...[
              const SizedBox(width: 4),
              Icon(
                expanded!
                    ? Icons.expand_more_rounded
                    : Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: disclosure ? true : null,
        enabled: disclosure ? onTap != null : null,
        expanded: expanded,
        label: semanticsLabel ?? [title, ?subtitle].join(' · '),
        excludeSemantics: true,
        onTap: disclosure ? onTap : null,
        child: KeyedSubtree(
          key: controlsKey,
          child: disclosure
              ? Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: toggleKey,
                    borderRadius: BorderRadius.circular(8),
                    onTap: onTap,
                    child: content,
                  ),
                )
              : content,
        ),
      ),
    );
  }
}
