import 'package:flutter/material.dart';

import 'expressive_motion.dart';

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      child: Text(
        title,
        style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final leadingIcon = _SettingsTileIcon(child: leading);
                final textContent = _SettingsTileText(
                  title: title,
                  subtitle: subtitle,
                );
                final trailingWidget = trailing == null
                    ? null
                    : IconTheme.merge(
                        data: IconThemeData(color: colors.onSurfaceVariant),
                        child: trailing!,
                      );

                if (constraints.maxWidth < 280 && trailingWidget != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          leadingIcon,
                          const SizedBox(width: 16),
                          Expanded(child: textContent),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: trailingWidget,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    leadingIcon,
                    const SizedBox(width: 16),
                    Expanded(child: textContent),
                    if (trailingWidget != null) ...[
                      const SizedBox(width: 12),
                      trailingWidget,
                    ],
                  ],
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpressiveTap(
        onTap: enabled ? () => onChanged!(!value) : null,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: enabled
                      ? colors.onSurfaceVariant
                      : colors.onSurface.withValues(alpha: 0.38),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
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
                  ),
                ),
                const SizedBox(width: 16),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final int value;
  final int min;
  final int max;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final safeValue = value.clamp(min, max).toInt();
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
              Row(
                children: [
                  Icon(icon, color: colors.onSurfaceVariant),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: safeValue.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: (max - min).clamp(1, 24).toInt(),
                label: label,
                onChanged: (value) => onChanged(value.round()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
