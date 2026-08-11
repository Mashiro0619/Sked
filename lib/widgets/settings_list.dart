import 'package:flutter/material.dart';

import '../theme/sked_expressive_theme.dart';
import 'expressive_motion.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final trailingWidget = trailing == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(color: colors.onSurfaceVariant),
            child: trailing!,
          );
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      button: semanticToggled == null && onTap != null,
      toggled: semanticToggled,
      enabled: onTap != null,
      label: subtitle == null ? title : '$title, $subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: ExpressiveTap(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SettingsTileIcon(child: leading),
                  const SizedBox(width: 12),
                  Expanded(child: textContent),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: 8),
                    _SettingsTileTrailing(child: trailingWidget),
                  ],
                ],
              ),
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
    final trailingWidget = trailing == null
        ? null
        : IconTheme.merge(
            data: IconThemeData(color: colors.onSurfaceVariant),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SettingsTileIcon(child: leading),
                const SizedBox(width: 12),
                Expanded(
                  child: _SettingsTileText(title: title, subtitle: subtitle),
                ),
                if (trailingWidget != null) ...[
                  const SizedBox(width: 8),
                  _SettingsTileTrailing(child: trailingWidget),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTileIcon extends StatelessWidget {
  const _SettingsTileIcon({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onSurfaceVariant),
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
  const _SettingsTileText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
            color: colors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
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
                  horizontal: 16,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final iconWidget = Icon(
                      icon,
                      color: enabled
                          ? colors.onSurfaceVariant
                          : colors.onSurface.withValues(alpha: 0.38),
                    );
                    final textWidget = Column(
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
                    );
                    final stack = constraints.maxWidth < 360 || textScale > 1.3;
                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(child: iconWidget),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: textWidget),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Switch(value: value, onChanged: onChanged),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(child: iconWidget),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: textWidget),
                        const SizedBox(width: 16),
                        Switch(value: value, onChanged: onChanged),
                      ],
                    );
                  },
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
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
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
                    softWrap: true,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: enabled
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  final stack = constraints.maxWidth < 360 || textScale > 1.3;
                  final iconWidget = SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(widget.icon, color: secondaryColor),
                    ),
                  );
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            iconWidget,
                            const SizedBox(width: 16),
                            Expanded(child: titleWidget),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: valueWidget,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      iconWidget,
                      const SizedBox(width: 16),
                      Expanded(child: titleWidget),
                      const SizedBox(width: 12),
                      Flexible(child: valueWidget),
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
