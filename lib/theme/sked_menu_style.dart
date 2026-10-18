import 'package:material_ui/material_ui.dart';

import '../widgets/sked_floating_surface.dart';
import '../widgets/workbench_chrome_metrics.dart';
import 'sked_expressive_theme.dart';
import 'sked_surface.dart';

/// Shared appearance for action popups, checked choices and field dropdowns.
/// The adapters keep their own route, focus and anchor behavior.
@immutable
class SkedMenuStyle {
  const SkedMenuStyle({
    required this.colors,
    required this.textTheme,
    required this.shapes,
    required this.desktop,
  });

  factory SkedMenuStyle.of(BuildContext context) =>
      SkedMenuStyle.fromTheme(Theme.of(context));

  factory SkedMenuStyle.fromTheme(ThemeData theme) => SkedMenuStyle(
    colors: theme.colorScheme,
    textTheme: theme.textTheme,
    shapes: theme.extension<SkedShapeScheme>() ?? SkedShapeScheme.standard,
    desktop: WorkbenchChromeMetrics.isDesktop(theme.platform),
  );

  final ColorScheme colors;
  final TextTheme textTheme;
  final SkedShapeScheme shapes;
  final bool desktop;

  static const elevation = 3.0;
  static const padding = EdgeInsets.symmetric(horizontal: 4, vertical: 6);
  static const itemPadding = EdgeInsets.symmetric(horizontal: 12);
  static const itemMargin = EdgeInsets.symmetric(vertical: 2);
  static const itemHeight = 48.0;
  static const iconSize = 20.0;

  // Floating menus must obscure content, including grid lines, beneath them.
  Color get surface =>
      SkedSurfaceRole.content.resolve(colors).withValues(alpha: 1);
  Color get shadow => colors.shadow.withValues(alpha: .18);
  Color get outline => desktop
      ? SkedFloatingStyle.outline(colors).color
      : colors.outlineVariant.withValues(alpha: .72);
  Color get selectedSurface =>
      Color.alphaBlend(colors.primary.withValues(alpha: .12), surface);
  Color get selectedForeground =>
      skedReadableAccent(colors, surface: selectedSurface);

  OutlinedBorder get shape =>
      (desktop
              ? const RoundedRectangleBorder(
                  borderRadius: SkedFloatingStyle.radius,
                )
              : shapes.menu)
          .copyWith(side: BorderSide(color: outline));

  OutlinedBorder get itemShape => desktop
      ? const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        )
      : shapes.compact;

  Color foreground(Set<WidgetState> states, {bool selected = false}) {
    if (states.contains(WidgetState.disabled)) {
      return colors.onSurface.withValues(alpha: .38);
    }
    return selected || states.contains(WidgetState.selected)
        ? selectedForeground
        : colors.onSurface;
  }

  TextStyle get _labelStyle =>
      (textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontSize: textTheme.labelLarge?.fontSize ?? 14,
        fontWeight: FontWeight.w600,
      );

  TextStyle labelStyle(Set<WidgetState> states, {bool selected = false}) =>
      _labelStyle.copyWith(color: foreground(states, selected: selected));

  WidgetStateProperty<Color?> get overlayColor =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.pressed)) {
          return colors.primary.withValues(alpha: .14);
        }
        if (states.contains(WidgetState.focused)) {
          return colors.primary.withValues(alpha: .12);
        }
        if (states.contains(WidgetState.hovered)) {
          return colors.primary.withValues(alpha: .08);
        }
        return null;
      });

  MenuStyle get menuStyle => MenuStyle(
    backgroundColor: WidgetStatePropertyAll(surface),
    shadowColor: WidgetStatePropertyAll(shadow),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(elevation),
    padding: const WidgetStatePropertyAll(padding),
    shape: WidgetStatePropertyAll(shape),
    side: WidgetStatePropertyAll(BorderSide(color: outline)),
    visualDensity: VisualDensity.standard,
  );

  PopupMenuThemeData get popupTheme => PopupMenuThemeData(
    color: surface,
    surfaceTintColor: Colors.transparent,
    elevation: elevation,
    shadowColor: shadow,
    menuPadding: padding,
    shape: shape,
    iconColor: colors.onSurfaceVariant,
    labelTextStyle: WidgetStateProperty.resolveWith(labelStyle),
  );

  ButtonStyle itemStyle({bool selected = false}) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(itemHeight)),
    padding: const WidgetStatePropertyAll(itemPadding),
    shape: WidgetStatePropertyAll(itemShape),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(_labelStyle),
    iconSize: const WidgetStatePropertyAll(iconSize),
    overlayColor: overlayColor,
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => selected || states.contains(WidgetState.selected)
          ? selectedSurface
          : Colors.transparent,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => foreground(states, selected: selected),
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => foreground(states, selected: selected),
    ),
  );
}
