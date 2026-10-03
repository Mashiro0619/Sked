import 'package:material_ui/material_ui.dart';

import 'sked_floating_surface.dart';
import 'workbench_chrome_metrics.dart';

/// Header composition only. Host controls height/scroll budget and exit policy;
/// actions sit outside the title drag handle and never trigger dragging.
class SkedPanelHeader extends StatelessWidget {
  const SkedPanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.bottom,
    this.toolbar,
    this.onDrag,
    this.onClose,
    this.showClose = true,
    this.closeEnabled = true,
    this.dragKey,
    this.closeKey,
    this.inlineAction = true,
    this.actionGap = 0,
    this.closeGap = 0,
    this.bottomGap = 8,
  });
  final Widget title;
  final Widget? subtitle, action, bottom, toolbar;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback? onClose;
  final bool showClose, closeEnabled, inlineAction;
  final Key? dragKey, closeKey;
  final double actionGap, closeGap, bottomGap;
  @override
  Widget build(BuildContext context) {
    final heading = subtitle == null
        ? title
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 3), subtitle!],
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: onDrag == null
                  ? heading
                  : SkedFloatingTitleDragHandle(
                      key: dragKey,
                      onUpdate: onDrag!,
                      child: heading,
                    ),
            ),
            if (inlineAction && action != null) ...[
              SizedBox(width: actionGap),
              action!,
            ],
            if (showClose) ...[
              SizedBox(width: closeGap),
              IconButton(
                key: closeKey,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                style: WorkbenchChromeMetrics.of(context).iconStyle,
                onPressed: closeEnabled ? onClose : null,
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
        if (!inlineAction && action != null) ...[
          SizedBox(height: bottomGap),
          Align(alignment: AlignmentDirectional.centerStart, child: action!),
        ],
        if (bottom != null) ...[SizedBox(height: bottomGap), bottom!],
        if (toolbar != null) ...[const SizedBox(height: 8), toolbar!],
      ],
    );
  }
}
