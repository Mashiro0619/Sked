import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';

import '../theme/sked_expressive_theme.dart';
import 'expressive_motion.dart';

/// Blocks a settings surface during persistence without switching every child
/// to its disabled colors. Pointer and keyboard actions are unavailable while
/// labels, values, and controls keep their stable visual state.
class SettingsInteractionBlocker extends StatelessWidget {
  const SettingsInteractionBlocker({
    super.key,
    required this.blocked,
    required this.child,
  });

  final bool blocked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: !blocked,
      descendantsAreFocusable: !blocked,
      descendantsAreTraversable: !blocked,
      child: AbsorbPointer(absorbing: blocked, child: child),
    );
  }
}

/// A full-width scroll viewport for settings pages with centered, adaptive
/// content. Wide layouts may split complete sections into two columns while
/// compact and large-text layouts keep the caller-provided reading order.
class ResponsiveSettingsBody extends StatelessWidget {
  const ResponsiveSettingsBody({
    super.key,
    required this.children,
    this.firstColumnChildren,
    this.secondColumnChildren,
    this.firstColumnSectionIndices,
    this.scrollViewKey,
    this.controller,
    this.topPadding = 8,
    this.bottomPadding = 24,
  });

  final List<Widget> children;
  final List<Widget>? firstColumnChildren;
  final List<Widget>? secondColumnChildren;
  final Set<int>? firstColumnSectionIndices;
  final Key? scrollViewKey;
  final ScrollController? controller;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final availableContentWidth =
            (constraints.maxWidth - horizontalPadding * 2)
                .clamp(0.0, 1120.0)
                .toDouble();
        final availableColumnWidth = (availableContentWidth - 20) / 2;
        final groupedSections = firstColumnSectionIndices == null
            ? null
            : _groupSettingsSections(children);
        final derivedFirstColumnChildren = groupedSections == null
            ? firstColumnChildren
            : [
                for (var index = 0; index < groupedSections.length; index++)
                  if (firstColumnSectionIndices!.contains(index))
                    groupedSections[index],
              ];
        final derivedSecondColumnChildren = groupedSections == null
            ? secondColumnChildren
            : [
                for (var index = 0; index < groupedSections.length; index++)
                  if (!firstColumnSectionIndices!.contains(index))
                    groupedSections[index],
              ];
        final hasWideColumns =
            derivedFirstColumnChildren != null &&
            derivedSecondColumnChildren != null;
        final useTwoColumns =
            hasWideColumns &&
            constraints.maxWidth >= 840 &&
            textScale <= 1.3 &&
            availableColumnWidth >= 360;
        final maxContentWidth = useTwoColumns ? 1120.0 : 720.0;

        final content = useTwoColumns
            ? KeyedSubtree(
                key: const ValueKey('responsive-settings-two-column'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: derivedFirstColumnChildren,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: derivedSecondColumnChildren,
                      ),
                    ),
                  ],
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('responsive-settings-single-column'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              );

        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
            },
          ),
          child: ListView(
            key: scrollViewKey,
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              bottomPadding,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: ConstrainedBox(
                  key: const ValueKey('responsive-settings-content'),
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SizedBox(width: double.infinity, child: content),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<Widget> _groupSettingsSections(List<Widget> children) {
  final sections = <List<Widget>>[];
  var currentSection = <Widget>[];
  for (final child in children) {
    if (child is SettingsSectionHeader && currentSection.isNotEmpty) {
      sections.add(currentSection);
      currentSection = <Widget>[];
    }
    currentSection.add(child);
  }
  if (currentSection.isNotEmpty) sections.add(currentSection);
  return [
    for (final section in sections)
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: section),
  ];
}

/// A full-width scroll viewport for pages that intentionally stay single
/// column on large windows.
class ResponsiveSettingsSingleColumnBody extends StatelessWidget {
  const ResponsiveSettingsSingleColumnBody({
    super.key,
    required this.child,
    this.scrollViewKey,
    this.controller,
    this.padding,
    this.topPadding = 8,
    this.bottomPadding = 24,
  });

  final Widget child;
  final Key? scrollViewKey;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
            },
          ),
          child: ListView(
            key: scrollViewKey,
            controller: controller,
            padding:
                padding ??
                EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: ConstrainedBox(
                  key: const ValueKey(
                    'responsive-settings-single-column-content',
                  ),
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SizedBox(width: double.infinity, child: child),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Keeps a heading and its controls together when a settings body switches
/// between one and two columns.
class ResponsiveSettingsSection extends StatelessWidget {
  const ResponsiveSettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: title),
        ...children,
      ],
    );
  }
}

/// A settings group whose rows read as one connected surface.
///
/// The group deliberately owns the separators and outer shape so callers can
/// focus on the setting semantics.  It is used by the settings landing page;
/// the existing [SettingsListTile] remains available for the denser secondary
/// pages.
class SettingsConnectedGroup extends StatelessWidget {
  const SettingsConnectedGroup({
    super.key,
    required this.children,
    this.title,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
  });

  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes = skedShapeSchemeOf(context);
    final visibleChildren = children;
    if (visibleChildren.isEmpty && title == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Material(
            color: colors.surfaceContainerLow,
            shape: shapes.container,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var index = 0;
                  index < visibleChildren.length;
                  index++
                ) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: colors.outlineVariant.withValues(alpha: 0.55),
                    ),
                  visibleChildren[index],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row for [SettingsConnectedGroup]. The trailing affordance stays in a
/// fixed touch slot while the text column takes responsibility for wrapping.
class SettingsConnectedTile extends StatelessWidget {
  const SettingsConnectedTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticToggled,
    this.onLongPress,
    this.onLongPressHint,
    this.onTapHint,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Exposes a trailing toggle's state on the single combined row semantics
  /// node.  The visual subtree is intentionally excluded to avoid duplicate
  /// announcements, so toggle state must be forwarded explicitly.
  final bool? semanticToggled;

  /// Optional secondary action exposed on the same semantics node. Physical
  /// gesture ownership remains with the caller so specialized timings do not
  /// change the tap behavior of every settings row.
  final VoidCallback? onLongPress;
  final String? onLongPressHint;
  final String? onTapHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null || onLongPress != null;
    final trailingWidget = trailing == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(
              color: enabled
                  ? colors.onSurfaceVariant
                  : colors.onSurface.withValues(alpha: 0.38),
            ),
            child: trailing!,
          );
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: enabled
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.38),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: enabled
                  ? colors.onSurfaceVariant
                  : colors.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ],
      ],
    );
    return Semantics(
      button: semanticToggled == null && enabled,
      toggled: semanticToggled,
      enabled: enabled,
      label: subtitle == null ? title : '$title, $subtitle',
      onTap: onTap,
      onTapHint: onTapHint,
      onLongPress: onLongPress,
      onLongPressHint: onLongPressHint,
      child: ExcludeSemantics(
        child: ExpressiveTap(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SettingsTileIcon(enabled: enabled, child: leading),
                      SizedBox(width: compact ? 8 : 12),
                      Expanded(child: textContent),
                      if (trailingWidget != null) ...[
                        SizedBox(width: compact ? 4 : 8),
                        _SettingsTileTrailing(child: trailingWidget),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
      ),
    );
  }
}

class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null;
    final trailingWidget = trailing == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(
              color: enabled
                  ? colors.onSurfaceVariant
                  : colors.onSurface.withValues(alpha: 0.38),
            ),
            child: trailing!,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpressiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: ShapeDecoration(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SettingsTileIcon(enabled: enabled, child: leading),
                      SizedBox(width: compact ? 8 : 12),
                      Expanded(
                        child: _SettingsTileText(
                          title: title,
                          subtitle: subtitle,
                          enabled: enabled,
                        ),
                      ),
                      if (trailingWidget != null) ...[
                        SizedBox(width: compact ? 4 : 8),
                        _SettingsTileTrailing(child: trailingWidget),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTileIcon extends StatelessWidget {
  const _SettingsTileIcon({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(
            color: enabled
                ? colors.onSurfaceVariant
                : colors.onSurface.withValues(alpha: 0.38),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SettingsTileTrailing extends StatelessWidget {
  const _SettingsTileTrailing({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(child: child),
    );
  }
}

class _SettingsTileText extends StatelessWidget {
  const _SettingsTileText({
    required this.title,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: enabled
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.38),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: enabled
                  ? colors.onSurfaceVariant
                  : colors.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ],
      ],
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final toggle = enabled ? () => onChanged!(!value) : null;
    return Semantics(
      label: title,
      hint: subtitle,
      toggled: value,
      enabled: enabled,
      onTap: toggle,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ExpressiveTap(
            onTap: toggle,
            enabled: enabled,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: ShapeDecoration(
                color: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(
                          icon,
                          color: enabled
                              ? colors.onSurfaceVariant
                              : colors.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            softWrap: true,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: enabled
                                  ? colors.onSurface
                                  : colors.onSurface.withValues(alpha: 0.38),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              softWrap: true,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: enabled
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface.withValues(alpha: 0.38),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(value: value, onChanged: onChanged),
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

class SettingsSliderTile extends StatefulWidget {
  const SettingsSliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.labelBuilder,
    required this.onChangeEnd,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final int value;
  final int min;
  final int max;
  final String Function(int value) labelBuilder;
  final ValueChanged<int> onChangeEnd;
  final bool enabled;

  @override
  State<SettingsSliderTile> createState() => _SettingsSliderTileState();
}

class _SettingsSliderTileState extends State<SettingsSliderTile> {
  late int _previewValue = _clamp(widget.value);
  var _isInteracting = false;

  int _clamp(int value) => value.clamp(widget.min, widget.max).toInt();

  @override
  void didUpdateWidget(covariant SettingsSliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final interactionCompleted = !oldWidget.enabled && widget.enabled;
    final externalValueChanged = oldWidget.value != widget.value;
    final rangeChanged =
        oldWidget.min != widget.min || oldWidget.max != widget.max;
    if (!_isInteracting &&
        widget.enabled &&
        (interactionCompleted || externalValueChanged || rangeChanged)) {
      _previewValue = _clamp(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.enabled;
    final safeValue = _clamp(_previewValue);
    final foregroundColor = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    final label = widget.labelBuilder(safeValue);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Ink(
        decoration: ShapeDecoration(
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleWidget = Text(
                    widget.title,
                    softWrap: true,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                  final valueWidget = Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: enabled
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final iconWidget = SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(widget.icon, color: secondaryColor),
                    ),
                  );
                  final valueMaxWidth =
                      constraints.maxWidth.clamp(120.0, 300.0) * 0.4;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(width: 12),
                      Expanded(child: titleWidget),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 48,
                          maxWidth: valueMaxWidth,
                          minHeight: 48,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: valueWidget,
                        ),
                      ),
                    ],
                  );
                },
              ),
              Semantics(
                label: widget.title,
                child: Slider(
                  value: safeValue.toDouble(),
                  min: widget.min.toDouble(),
                  max: widget.max.toDouble(),
                  divisions: (widget.max - widget.min).clamp(1, 24).toInt(),
                  label: label,
                  semanticFormatterCallback: (_) => label,
                  onChangeStart: enabled ? (_) => _isInteracting = true : null,
                  onChanged: enabled
                      ? (value) => setState(() {
                          _previewValue = _clamp(value.round());
                        })
                      : null,
                  onChangeEnd: enabled
                      ? (value) {
                          _isInteracting = false;
                          final committedValue = _clamp(value.round());
                          if (committedValue != widget.value) {
                            widget.onChangeEnd(committedValue);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
