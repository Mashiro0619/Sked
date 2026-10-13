import 'package:material_ui/material_ui.dart';

import 'sked_panel_header.dart';
import 'workbench_chrome_metrics.dart';

/// Title composition shared by bottom tasks, embedded forms and action sheets.
class SkedTaskHeader extends StatelessWidget {
  const SkedTaskHeader({super.key, required this.title, this.subtitle});

  final Widget title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return SkedPanelHeader(
        title: title,
        subtitle: subtitle,
        showClose: false,
      );
    }
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: DefaultTextStyle.merge(
            style: theme.textTheme.headlineSmall!.copyWith(
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface,
            ),
            child: title,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );
  }
}
