import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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

/// Starts a new responsive settings section without adding visible content.
///
/// This is useful when a detail panel belongs in the next wide-screen column
/// but should remain directly after its controlling section on narrow screens.
class SettingsSectionBreak extends StatelessWidget {
  const SettingsSectionBreak({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

List<Widget> _groupSettingsSections(List<Widget> children) {
  final sections = <List<Widget>>[];
  var currentSection = <Widget>[];
  for (final child in children) {
    final startsSection = child is SettingsSectionHeader;
    final breaksSection = child is SettingsSectionBreak;
    if ((startsSection || breaksSection) && currentSection.isNotEmpty) {
      sections.add(currentSection);
      currentSection = <Widget>[];
    }
    if (breaksSection) continue;
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
    this.foregroundColor,
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
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null || onLongPress != null;
    final resolvedForegroundColor = enabled
        ? foregroundColor
        : colors.onSurface.withValues(alpha: 0.38);
    final trailingWidget = trailing == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(
              color: resolvedForegroundColor ?? colors.onSurfaceVariant,
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
            color: resolvedForegroundColor ?? colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: resolvedForegroundColor ?? colors.onSurfaceVariant,
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
                      _SettingsTileIcon(
                        enabled: enabled,
                        color: foregroundColor,
                        child: leading,
                      ),
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
  const _SettingsTileIcon({
    required this.child,
    this.enabled = true,
    this.color,
  });

  final Widget child;
  final bool enabled;
  final Color? color;

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
                ? color ?? colors.onSurfaceVariant
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
    this.subtitle,
    this.step = 1,
    this.enabled = true,
  }) : assert(step > 0),
       assert((max - min) % step == 0);

  final IconData icon;
  final String title;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int value) labelBuilder;
  final ValueChanged<int> onChangeEnd;
  final bool enabled;

  @override
  State<SettingsSliderTile> createState() => _SettingsSliderTileState();
}

/// A compact editor for the controls that make up a workspace toolbar.
///
/// The surrounding settings page owns persistence.  This widget deliberately
/// keeps the reorder interaction local and reports only the completed order,
/// so dragging does not trigger a save for every intermediate position.
class SettingsToolbarNavigationItem {
  const SettingsToolbarNavigationItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.visible,
    this.canHide = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool visible;
  final bool canHide;
}

class SettingsToolbarNavigationEditor extends StatefulWidget {
  const SettingsToolbarNavigationEditor({
    super.key,
    required this.items,
    required this.onReorder,
    required this.onVisibilityChanged,
    this.reorderLabel = 'Reorder',
    this.visibilityLabel = 'Visibility',
    this.busy = false,
  });

  final List<SettingsToolbarNavigationItem> items;
  final ValueChanged<List<String>> onReorder;
  final void Function(String id, bool visible) onVisibilityChanged;
  final String reorderLabel;
  final String visibilityLabel;

  /// Whether the surrounding settings page is saving a toolbar change.
  ///
  /// Reorders are optimistic so the list can settle in its new position before
  /// persistence completes. The parent uses this to distinguish its initial
  /// busy rebuild from a failed save's rollback rebuild.
  final bool busy;

  @override
  State<SettingsToolbarNavigationEditor> createState() =>
      _SettingsToolbarNavigationEditorState();
}

/// Starts the native reorder recognizer for the pointer device under the
/// handle. Keeping both recognizers in one listener is important: nesting two
/// [ReorderableDragStartListener]s makes both call
/// [ReorderableListState.startItemDragReorder] for the same pointer and the
/// second recognizer cancels the first one before it can start.
class _ToolbarReorderIntent extends Intent {
  const _ToolbarReorderIntent(this.delta);

  final int delta;
}

class _ToolbarReorderHandle extends StatefulWidget {
  const _ToolbarReorderHandle({
    super.key,
    required this.index,
    required this.itemId,
    required this.enabled,
    required this.tooltipMessage,
    required this.semanticsLabel,
    required this.semanticsHint,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onPointerMove,
    required this.onMoveBy,
    this.onIncrease,
    this.onDecrease,
  });

  final int index;
  final String itemId;
  final bool enabled;
  final String tooltipMessage;
  final String semanticsLabel;
  final String semanticsHint;
  final ValueChanged<PointerDeviceKind> onPointerDown;
  final VoidCallback onPointerUp;
  final VoidCallback onPointerCancel;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<int> onMoveBy;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  State<_ToolbarReorderHandle> createState() => _ToolbarReorderHandleState();
}

class _ToolbarReorderHandleState extends State<_ToolbarReorderHandle> {
  var _showFocusHighlight = false;
  var _showHoverHighlight = false;

  MultiDragGestureRecognizer? _recognizerFor(PointerDownEvent event) {
    final MultiDragGestureRecognizer? recognizer = switch (event.kind) {
      PointerDeviceKind.mouse || PointerDeviceKind.trackpad =>
        ImmediateMultiDragGestureRecognizer(debugOwner: this),
      PointerDeviceKind.touch ||
      PointerDeviceKind.stylus ||
      PointerDeviceKind.invertedStylus => DelayedMultiDragGestureRecognizer(
        debugOwner: this,
      ),
      _ => null,
    };
    if (recognizer == null) return null;
    recognizer
      ..supportedDevices = {event.kind}
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    return recognizer;
  }

  void _startReorder(PointerDownEvent event) {
    if (!widget.enabled) return;
    if ((event.kind == PointerDeviceKind.mouse ||
            event.kind == PointerDeviceKind.trackpad) &&
        event.buttons != kPrimaryButton) {
      return;
    }
    final recognizer = _recognizerFor(event);
    if (recognizer == null) return;
    widget.onPointerDown(event.kind);
    ReorderableList.maybeOf(context)?.startItemDragReorder(
      index: widget.index,
      event: event,
      recognizer: recognizer,
    );
  }

  void _setFocusHighlight(bool value) {
    if (_showFocusHighlight == value) return;
    setState(() => _showFocusHighlight = value);
  }

  void _setHoverHighlight(bool value) {
    if (_showHoverHighlight == value) return;
    setState(() => _showHoverHighlight = value);
  }

  Widget _buildHandleVisual(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final motion = SkedMotionPolicy.of(context);
    final foreground = colors.onSurfaceVariant;
    final background = _showFocusHighlight
        ? colors.primary.withValues(alpha: 0.12)
        : _showHoverHighlight
        ? colors.onSurface.withValues(alpha: 0.08)
        : Colors.transparent;
    final border = _showFocusHighlight
        ? BorderSide(color: colors.primary, width: 2)
        : BorderSide.none;
    return AnimatedContainer(
      key: ValueKey('toolbar-navigation-drag-handle-visual-${widget.itemId}'),
      duration: motion.effects(SkedMotionSpeed.fast),
      curve: Curves.easeOutCubic,
      decoration: ShapeDecoration(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: border,
        ),
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(Icons.drag_indicator, color: foreground),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: widget.enabled,
      includeFocusSemantics: false,
      mouseCursor: SystemMouseCursors.grab,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): _ToolbarReorderIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _ToolbarReorderIntent(1),
      },
      actions: <Type, Action<Intent>>{
        _ToolbarReorderIntent: CallbackAction<_ToolbarReorderIntent>(
          onInvoke: (intent) {
            widget.onMoveBy(intent.delta);
            return null;
          },
        ),
      },
      onShowFocusHighlight: _setFocusHighlight,
      onShowHoverHighlight: _setHoverHighlight,
      child: Listener(
        onPointerDown: widget.enabled ? _startReorder : null,
        onPointerUp: widget.enabled ? (_) => widget.onPointerUp() : null,
        onPointerCancel: widget.enabled
            ? (_) => widget.onPointerCancel()
            : null,
        onPointerMove: widget.enabled ? widget.onPointerMove : null,
        child: Tooltip(
          message: widget.tooltipMessage,
          // Keep touch interactions reserved for the delayed drag recognizer.
          // RawTooltip still shows this message for mouse hover in manual mode.
          triggerMode: TooltipTriggerMode.manual,
          child: Semantics(
            container: true,
            button: true,
            enabled: widget.enabled,
            label: widget.semanticsLabel,
            hint: widget.semanticsHint,
            onIncrease: widget.enabled ? widget.onIncrease : null,
            onDecrease: widget.enabled ? widget.onDecrease : null,
            child: _buildHandleVisual(context),
          ),
        ),
      ),
    );
  }
}

class _SettingsToolbarNavigationEditorState
    extends State<SettingsToolbarNavigationEditor> {
  static const _dropSettlementDuration = Duration(milliseconds: 300);

  late List<SettingsToolbarNavigationItem> _items = List.of(widget.items);
  PointerDeviceKind? _lastPointerKind;
  var _dragInProgress = false;
  var _dropSettlementPending = false;
  var _reorderSavePending = false;
  Timer? _dropSettlementTimer;
  final _reorderableListKey = GlobalKey<ReorderableListState>();

  bool get _reorderInteractionEnabled =>
      !widget.busy &&
      !_dragInProgress &&
      !_dropSettlementPending &&
      !_reorderSavePending;

  @override
  void didUpdateWidget(covariant SettingsToolbarNavigationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameItems(_items, widget.items)) {
      // The Provider has published the optimistic order, so later external
      // changes can again become the source of truth.
      _reorderSavePending = false;
      return;
    }

    // Starting a command rebuilds the page before the Provider has published
    // the new order. Keep the native list's settled local order through that
    // frame. If saving fails, the page later leaves its busy state with the
    // old provider order, which is then deliberately restored below.
    if (_reorderSavePending && widget.busy) {
      return;
    }

    _items = List.of(widget.items);
    _reorderSavePending = false;
  }

  bool _sameItems(
    List<SettingsToolbarNavigationItem> left,
    List<SettingsToolbarNavigationItem> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].visible != right[index].visible ||
          left[index].label != right[index].label ||
          left[index].icon != right[index].icon ||
          left[index].canHide != right[index].canHide) {
        return false;
      }
    }
    return true;
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (widget.busy ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _items.length ||
        newIndex >= _items.length) {
      return;
    }
    _dropSettlementTimer?.cancel();
    setState(() {
      _dropSettlementPending = false;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _reorderSavePending = true;
    });
    widget.onReorder(_items.map((item) => item.id).toList(growable: false));
  }

  void _moveBy(int index, int delta) {
    if (!_reorderInteractionEnabled) return;
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    _onReorder(index, target);
  }

  void _onReorderStart(int index) {
    setState(() {
      _dragInProgress = true;
      _dropSettlementPending = false;
    });
    final kind = _lastPointerKind;
    if (kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus) {
      // ReorderableDelayedDragStartListener starts only after the long press
      // timeout, so this feedback acknowledges the actual drag start rather
      // than every pointer-down event.
      unawaited(Feedback.forLongPress(context));
    }
  }

  void _onReorderEnd(int index) {
    // Native ReorderableList calls onReorderEnd before its 250 ms drop
    // animation invokes onReorderItem. Keep the handle gated for that short
    // settlement window so a second pointer cannot cancel the first drop.
    _dropSettlementTimer?.cancel();
    setState(() {
      _dragInProgress = false;
      _dropSettlementPending = true;
      _lastPointerKind = null;
    });
    _dropSettlementTimer = Timer(
      _dropSettlementDuration,
      _finishDropSettlement,
    );
  }

  void _finishDropSettlement() {
    if (!mounted || !_dropSettlementPending) return;
    setState(() => _dropSettlementPending = false);
  }

  void _onPointerUp() {
    // A completed drop triggers onReorderEnd. A simple press never starts the
    // drag recognizer and must clear its device hint here instead.
    if (_dragInProgress) return;
    _lastPointerKind = null;
  }

  void _onPointerCancel() {
    // Flutter only calls onReorderEnd for a drop. Explicitly reset the native
    // gap on cancellation so an interrupted pointer cannot leave a stale
    // placeholder behind or publish an order.
    _dropSettlementTimer?.cancel();
    _reorderableListKey.currentState?.cancelReorder();
    if (!mounted) return;
    setState(() {
      _dragInProgress = false;
      _dropSettlementPending = false;
      _lastPointerKind = null;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_dragInProgress) return;
    final renderObject = _reorderableListKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final listBounds =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    // This editor has no nested scrolling. Once the pointer leaves its local
    // surface, cancel rather than committing an accidental edge drop.
    if (!listBounds.inflate(12).contains(event.position)) {
      _onPointerCancel();
    }
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    final colors = Theme.of(context).colorScheme;
    final shape = skedShapeSchemeOf(context).container;
    final motion = SkedMotionPolicy.of(context);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(animation.value);
        final scale = motion.spatialAnimationsEnabled
            ? 1 + progress * 0.02
            : 1.0;
        final lift = motion.spatialAnimationsEnabled ? -2 * progress : 0.0;
        final elevation = motion.animationsEnabled ? progress * 4 : 0.0;
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: scale,
            child: Material(
              color: colors.surfaceContainerLow,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              elevation: elevation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = skedShapeSchemeOf(context).container;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: colors.surfaceContainerLow,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        // This list is shrink-wrapped and cannot scroll independently. The
        // surrounding settings ListView remains the only scrollable surface,
        // while ReorderableList supplies the live gap animation and proxy.
        child: DragBoundary(
          child: KeyedSubtree(
            key: const ValueKey('toolbar-navigation-reorderable-list'),
            child: ReorderableList(
              key: _reorderableListKey,
              itemCount: _items.length,
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              dragBoundaryProvider: (context) =>
                  DragBoundary.forRectOf(context),
              onReorderItem: _onReorder,
              onReorderStart: _onReorderStart,
              onReorderEnd: _onReorderEnd,
              proxyDecorator: _proxyDecorator,
              itemBuilder: (context, index) =>
                  _buildItemRow(context, index, colors),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, int index, ColorScheme colors) {
    final item = _items[index];
    final enabled = item.canHide;
    final foreground = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.58);
    final dragHandle = _ToolbarReorderHandle(
      key: ValueKey('toolbar-navigation-drag-handle-${item.id}'),
      index: index,
      itemId: item.id,
      enabled: _reorderInteractionEnabled,
      tooltipMessage: widget.reorderLabel,
      semanticsLabel: '${widget.reorderLabel}: ${item.label}',
      semanticsHint: '${widget.reorderLabel}: ${item.label}',
      onPointerDown: (kind) => _lastPointerKind = kind,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerMove: _onPointerMove,
      onMoveBy: (delta) => _moveBy(index, delta),
      onIncrease: index < _items.length - 1 ? () => _moveBy(index, 1) : null,
      onDecrease: index > 0 ? () => _moveBy(index, -1) : null,
    );
    final row = ConstrainedBox(
      // Keep every row comfortably tappable while avoiding a tall block that
      // pushes the following quick actions needlessly far down the page.
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            dragHandle,
            const SizedBox(width: 4),
            Icon(item.icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: foreground, fontWeight: FontWeight.w500),
              ),
            ),
            Tooltip(
              message: widget.visibilityLabel,
              child: Semantics(
                label: '${widget.visibilityLabel}: ${item.label}',
                toggled: item.visible,
                enabled: enabled,
                child: Switch(
                  value: item.visible,
                  onChanged: enabled
                      ? (value) => widget.onVisibilityChanged(item.id, value)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return KeyedSubtree(
      key: ValueKey(item.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0)
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: colors.outlineVariant.withValues(alpha: 0.55),
            ),
          row,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dropSettlementTimer?.cancel();
    super.dispose();
  }
}

class _SettingsSliderTileState extends State<SettingsSliderTile> {
  late int _previewValue = _clamp(widget.value);
  var _isInteracting = false;

  int _clamp(int value) => value.clamp(widget.min, widget.max).toInt();

  int _snapToStep(int value) {
    final clamped = _clamp(value);
    final offset = clamped - widget.min;
    final snapped = widget.min + (offset / widget.step).round() * widget.step;
    return snapped.clamp(widget.min, widget.max).toInt();
  }

  @override
  void didUpdateWidget(covariant SettingsSliderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final interactionCompleted = !oldWidget.enabled && widget.enabled;
    final externalValueChanged = oldWidget.value != widget.value;
    final rangeChanged =
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.step != widget.step;
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
              if (widget.subtitle != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 52, end: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      widget.subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                  ),
                ),
              Semantics(
                label: widget.title,
                child: Slider(
                  value: safeValue.toDouble(),
                  min: widget.min.toDouble(),
                  max: widget.max.toDouble(),
                  divisions: ((widget.max - widget.min) ~/ widget.step).clamp(
                    1,
                    100,
                  ),
                  label: label,
                  semanticFormatterCallback: (_) => label,
                  onChangeStart: enabled ? (_) => _isInteracting = true : null,
                  onChanged: enabled
                      ? (value) => setState(() {
                          _previewValue = _snapToStep(value.round());
                        })
                      : null,
                  onChangeEnd: enabled
                      ? (value) {
                          _isInteracting = false;
                          final committedValue = _snapToStep(value.round());
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
