import 'package:material_ui/material_ui.dart';

import '../../theme/sked_expressive_theme.dart';
import '../../theme/sked_menu_style.dart';

/// Shared reading, input and floating surfaces for the Agent workspace.
/// State colors still come from the active application color scheme.
class AgentUiStyle {
  AgentUiStyle.of(BuildContext context)
    : colors = Theme.of(context).colorScheme,
      _text = Theme.of(context).textTheme,
      _shapes = skedShapeSchemeOf(context),
      desktop = SkedMenuStyle.of(context).desktop;

  static const contentWidth = 812.0;
  static const contentInset = 16.0;

  final ColorScheme colors;
  final TextTheme _text;
  final SkedShapeScheme _shapes;
  final bool desktop;

  bool get _dark => colors.brightness == Brightness.dark;
  Color get foreground => colors.onSurface;
  Color get muted => colors.onSurfaceVariant;
  Color get canvas => colors.surface;
  Color _surface(double opacity) =>
      Color.alphaBlend(foreground.withValues(alpha: opacity), canvas);
  Color get composer => _surface(_dark ? .055 : .025);
  Color get popover => _surface(_dark ? .075 : .008);
  Color get subtleSurface => _surface(.035);
  Color get hover => foreground.withValues(alpha: _dark ? .07 : .045);
  Color get selected => foreground.withValues(alpha: _dark ? .10 : .075);
  Color get border => foreground.withValues(alpha: _dark ? .14 : .12);

  TextStyle get body => (_text.bodyLarge ?? const TextStyle()).copyWith(
    fontSize: desktop ? 15 : 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0,
    color: foreground,
  );

  TextStyle get title =>
      body.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);

  TextStyle get label =>
      body.copyWith(fontSize: desktop ? 13 : 14, height: 1.45);

  TextStyle get caption =>
      label.copyWith(fontSize: desktop ? 12 : 13, height: 1.4, color: muted);

  OutlinedBorder get popoverShape =>
      _shapes.menu.copyWith(side: BorderSide(color: border));

  ButtonStyle get controlStyle => ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.square(desktop ? 32 : 48)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: desktop ? 8 : 10, vertical: 6),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    textStyle: WidgetStatePropertyAll(label),
    shape: WidgetStatePropertyAll(_shapes.compact),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? foreground.withValues(alpha: .38)
          : muted,
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (states.contains(WidgetState.pressed)) return selected;
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return hover;
      }
      return Colors.transparent;
    }),
    side: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.focused) &&
              !states.contains(WidgetState.disabled)
          ? BorderSide(color: muted)
          : BorderSide.none,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    splashFactory: NoSplash.splashFactory,
  );

  ButtonStyle get filledControlStyle => controlStyle.copyWith(
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => foreground.withValues(
        alpha: states.contains(WidgetState.disabled) ? .10 : 1,
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? foreground.withValues(alpha: .38)
          : canvas,
    ),
    overlayColor: WidgetStatePropertyAll(canvas.withValues(alpha: .12)),
  );

  ButtonStyle get primaryActionStyle => filledControlStyle.copyWith(
    minimumSize: WidgetStatePropertyAll(Size.square(desktop ? 32 : 48)),
    maximumSize: WidgetStatePropertyAll(Size.square(desktop ? 32 : 48)),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    shape: const WidgetStatePropertyAll(CircleBorder()),
    iconSize: WidgetStatePropertyAll(desktop ? 18 : 22),
  );
}
