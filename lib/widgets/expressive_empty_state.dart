import 'package:flutter/material.dart';

class ExpressiveEmptyState extends StatelessWidget {
  const ExpressiveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
    this.maxWidth = 420,
  });

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.96, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) {
                  if (MediaQuery.disableAnimationsOf(context)) return child!;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: ShapeDecoration(
                    color: colors.primary.withValues(alpha: 0.10),
                    shape: const StadiumBorder(),
                  ),
                  child: Icon(icon, size: 36, color: colors.primary),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                _ExpressiveActionArea(actions: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpressiveActionArea extends StatelessWidget {
  const _ExpressiveActionArea({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxActionWidth = constraints.maxWidth.clamp(160.0, 280.0);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxActionWidth),
                child: action,
              ),
          ],
        );
      },
    );
  }
}
