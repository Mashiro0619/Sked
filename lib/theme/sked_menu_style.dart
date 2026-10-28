import 'package:material_ui/material_ui.dart';

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

  static const minimumItemHeight = 32.0;
  static const minimumWidth = 144.0;
  static const maximumWidth = 360.0;
  static const constraints = BoxConstraints(
    minWidth: minimumWidth,
    maxWidth: maximumWidth,
  );

  double get elevation => desktop ? 2 : 3;
  EdgeInsets get padding => desktop
      ? const EdgeInsets.all(4)
      : const EdgeInsets.symmetric(horizontal: 4, vertical: 6);
  EdgeInsets get itemPadding => desktop
      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
      : const EdgeInsets.symmetric(horizontal: 12);
  EdgeInsets get itemMargin =>
      desktop ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 2);
  double get itemHeight => desktop ? minimumItemHeight : 48;
  double get iconSize => desktop ? 16 : 20;
  double get iconGap => desktop ? 8 : 12;
  double get _selectionOpacity => desktop ? .06 : .12;

  // Floating menus must obscure content, including grid lines, beneath them.
  Color get surface =>
      SkedSurfaceRole.content.resolve(colors).withValues(alpha: 1);
  Color get shadow => colors.shadow.withValues(alpha: desktop ? .14 : .18);
  Color get outline =>
      colors.outlineVariant.withValues(alpha: desktop ? .65 : .72);
  Color get selectedSurface => Color.alphaBlend(
    colors.primary.withValues(alpha: _selectionOpacity),
    surface,
  );
  Color get selectedForeground =>
      skedReadableAccent(colors, surface: selectedSurface);

  OutlinedBorder get shape =>
      shapes.menu.copyWith(side: BorderSide(color: outline));

  OutlinedBorder get itemShape => shapes.compact;

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
        fontSize: textTheme.labelLarge?.fontSize ?? (desktop ? 13 : 14),
        fontWeight: desktop ? FontWeight.w400 : FontWeight.w600,
        letterSpacing: desktop ? 0 : textTheme.labelLarge?.letterSpacing,
        // MenuAnchor resolves localized typography, while PopupMenuTheme keeps
        // the original theme style. Give both the same desktop line metrics.
        height: desktop ? 1.4 : textTheme.labelLarge?.height,
        leadingDistribution: desktop
            ? TextLeadingDistribution.even
            : textTheme.labelLarge?.leadingDistribution,
      );

  TextStyle labelStyle(Set<WidgetState> states, {bool selected = false}) =>
      _labelStyle.copyWith(color: foreground(states, selected: selected));

  // InkWell paints focus and hover as separate overlays. Resolve their combined
  // state once so pointer and keyboard menus cannot accumulate different tints.
  Color background(Set<WidgetState> states, {bool selected = false}) {
    final checked = selected || states.contains(WidgetState.selected);
    if (states.contains(WidgetState.disabled)) {
      return checked ? selectedSurface : Colors.transparent;
    }
    final double opacity;
    if (states.contains(WidgetState.pressed)) {
      opacity = desktop ? .10 : .14;
    } else if (states.contains(WidgetState.focused)) {
      opacity = desktop ? .08 : .12;
    } else if (checked) {
      opacity = _selectionOpacity;
    } else if (states.contains(WidgetState.hovered)) {
      opacity = desktop ? .04 : .08;
    } else {
      return Colors.transparent;
    }
    return Color.alphaBlend(colors.primary.withValues(alpha: opacity), surface);
  }

  BorderSide itemBorder(Set<WidgetState> states) =>
      states.contains(WidgetState.focused) &&
          !states.contains(WidgetState.disabled)
      ? BorderSide(color: selectedForeground)
      : BorderSide.none;

  WidgetStateProperty<Color?> get overlayColor =>
      const WidgetStatePropertyAll(Colors.transparent);

  MenuStyle get menuStyle => MenuStyle(
    backgroundColor: WidgetStatePropertyAll(surface),
    shadowColor: WidgetStatePropertyAll(shadow),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: WidgetStatePropertyAll(elevation),
    padding: WidgetStatePropertyAll(padding),
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
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(itemHeight)),
    padding: WidgetStatePropertyAll(itemPadding),
    shape: WidgetStatePropertyAll(itemShape),
    side: WidgetStateProperty.resolveWith(itemBorder),
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(_labelStyle),
    iconSize: WidgetStatePropertyAll(iconSize),
    overlayColor: overlayColor,
    animationDuration: Duration.zero,
    splashFactory: NoSplash.splashFactory,
    mouseCursor: WidgetStateMouseCursor.adaptiveClickable,
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => background(states, selected: selected),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => foreground(states, selected: selected),
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => foreground(states, selected: selected),
    ),
  );
}
