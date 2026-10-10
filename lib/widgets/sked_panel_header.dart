import 'package:material_ui/material_ui.dart';

import 'sked_floating_surface.dart';
import 'workbench_chrome_metrics.dart';

const skedPanelHeaderPadding = EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8);

/// Panel titles have explicit roles instead of inheriting the compact body
/// sizes of titleSmall/titleMedium. Preserve the app's primary font while
/// choosing predictable Windows CJK faces for characters it does not contain.
TextStyle _panelTextStyle(BuildContext context, double size, double height) {
  final theme = Theme.of(context);
  final base = theme.textTheme.titleMedium!;
  final locale = Localizations.maybeLocaleOf(context);
  final traditionalChinese =
      locale?.scriptCode == 'Hant' ||
      const ['TW', 'HK', 'MO'].contains(locale?.countryCode);
  final cjkFallback = switch (locale?.languageCode) {
    'ja' => const ['Yu Gothic UI', 'Meiryo'],
    'ko' => const ['Malgun Gothic'],
    'zh' when traditionalChinese => const [
      'Microsoft JhengHei UI',
      'Microsoft JhengHei',
    ],
    _ => const ['Microsoft YaHei UI', 'Microsoft YaHei'],
  };
  return base.copyWith(
    fontSize: size,
    fontWeight: FontWeight.w600,
    fontStyle: FontStyle.normal,
    height: height,
    leadingDistribution: TextLeadingDistribution.even,
    letterSpacing: 0,
    color: theme.colorScheme.onSurface,
    fontFamilyFallback: theme.platform == TargetPlatform.windows
        ? {...?base.fontFamilyFallback, ...cjkFallback}.toList()
        : base.fontFamilyFallback,
  );
}

TextStyle skedPanelTitleStyle(BuildContext context, {bool prominent = false}) =>
    _panelTextStyle(context, prominent ? 18 : 16, 1.35);

TextStyle skedPanelHeadlineStyle(BuildContext context) =>
    _panelTextStyle(context, 22, 1.25);

TextStyle skedPanelSubtitleStyle(BuildContext context) =>
    _panelTextStyle(context, 12, 1.4).copyWith(
      fontWeight: FontWeight.w400,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

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
    this.verticalAlignment,
    this.prominentTitle = false,
  });
  final Widget title;
  final Widget? subtitle, action, bottom, toolbar;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback? onClose;
  final bool showClose, closeEnabled, inlineAction;
  final Key? dragKey, closeKey;
  final double actionGap, closeGap, bottomGap;
  final CrossAxisAlignment? verticalAlignment;
  final bool prominentTitle;
  @override
  Widget build(BuildContext context) {
    final metrics = WorkbenchChromeMetrics.of(context);
    final alignment =
        verticalAlignment ??
        (metrics.desktop
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start);
    final titleText = metrics.desktop
        ? Semantics(
            header: true,
            child: DefaultTextStyle.merge(
              style: skedPanelTitleStyle(context, prominent: prominentTitle),
              child: title,
            ),
          )
        : title;
    final heading = subtitle == null || metrics.desktop
        ? titleText
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleText, const SizedBox(height: 3), subtitle!],
          );
    final headingAlignment = alignment == CrossAxisAlignment.center
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.topStart;
    final alignedHeading = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: metrics.desktop ? metrics.iconTarget : 0,
      ),
      child: Align(
        alignment: headingAlignment,
        heightFactor: 1,
        child: heading,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: alignment,
          children: [
            Expanded(
              child: onDrag == null
                  ? alignedHeading
                  : SkedFloatingTitleDragHandle(
                      key: dragKey,
                      onUpdate: onDrag!,
                      alignment: headingAlignment,
                      child: alignedHeading,
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
        if (metrics.desktop && subtitle != null) ...[
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: skedPanelSubtitleStyle(context),
            child: subtitle!,
          ),
        ],
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
