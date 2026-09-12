import 'package:material_ui/material_ui.dart';

/// Large structural surfaces have two roles. Control/state colors remain owned
/// by their components; this never rewrites the user's ColorScheme.
enum SkedSurfaceRole {
  content,
  frame;

  Color resolve(ColorScheme colors) => switch (this) {
    content => colors.surface,
    frame => colors.surfaceContainerLow,
  };
}

/// Paints one continuous surface and lets nested tasks inherit its role. The
/// inherited canvas/scaffold defaults also cover route gaps and safe areas.
class SkedSurface extends StatelessWidget {
  const SkedSurface({
    super.key,
    required this.child,
    this.role,
    this.elevation = 0,
    this.shape,
    this.borderRadius,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final SkedSurfaceRole? role;
  final double elevation;
  final ShapeBorder? shape;
  final BorderRadiusGeometry? borderRadius;
  final Clip clipBehavior;

  static SkedSurfaceRole roleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SurfaceScope>()?.role ??
      SkedSurfaceRole.content;

  static Color colorOf(BuildContext context, {SkedSurfaceRole? role}) =>
      (role ?? roleOf(context)).resolve(Theme.of(context).colorScheme);

  @override
  Widget build(BuildContext context) {
    final resolved = role ?? roleOf(context);
    final theme = Theme.of(context);
    final color = resolved.resolve(theme.colorScheme);
    return SkedSurfaceScope(
      role: resolved,
      child: Material(
        color: color,
        surfaceTintColor: Colors.transparent,
        elevation: elevation,
        shape: shape,
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: child,
      ),
    );
  }
}

/// Changes surface inheritance without painting over a dialog's modal barrier.
class SkedSurfaceScope extends StatelessWidget {
  const SkedSurfaceScope({super.key, required this.role, required this.child});
  final SkedSurfaceRole role;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = role.resolve(theme.colorScheme);
    return _SurfaceScope(
      role: role,
      child: Theme(
        data: theme.copyWith(
          canvasColor: color,
          scaffoldBackgroundColor: color,
        ),
        child: child,
      ),
    );
  }
}

class _SurfaceScope extends InheritedWidget {
  const _SurfaceScope({required this.role, required super.child});
  final SkedSurfaceRole role;
  @override
  bool updateShouldNotify(_SurfaceScope oldWidget) => role != oldWidget.role;
}
