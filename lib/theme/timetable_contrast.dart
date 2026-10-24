import 'package:material_ui/material_ui.dart';

import 'color_contrast.dart';

/// Contrast after an optional translucent foreground is painted on its fill.
double renderedTimetableContrast(Color foreground, Color background) =>
    colorContrastRatio(Color.alphaBlend(foreground, background), background);

/// Keep the theme foreground when readable; otherwise use the clearer neutral.
/// Call with the final opaque, composited card background.
Color resolveAutomaticTimetableTextColor(
  Color background, {
  Color? preferred,
  double minimumRatio = 4.5,
}) {
  if (preferred != null &&
      renderedTimetableContrast(preferred, background) >= minimumRatio) {
    return preferred;
  }
  return renderedTimetableContrast(Colors.black, background) >=
          renderedTimetableContrast(Colors.white, background)
      ? Colors.black
      : Colors.white;
}

/// A status outline needs non-text contrast against the individual card fill.
Color resolveTimetableOutlineColor(Color preferred, Color background) =>
    resolveAutomaticTimetableTextColor(
      background,
      preferred: preferred,
      minimumRatio: 3,
    );

/// Keep one line when it is distinct from both sides. Otherwise the outer
/// canvas edge and an inner guard each retain non-text contrast on their side.
({Color outer, Color? inner}) resolveTimetableOutlineColors(
  Color preferred, {
  required Color cardBackground,
  required Color surroundingSurface,
}) {
  bool readableOnBoth(Color candidate) =>
      renderedTimetableContrast(candidate, cardBackground) >= 3 &&
      renderedTimetableContrast(candidate, surroundingSurface) >= 3;
  for (final candidate in [preferred, Colors.black, Colors.white]) {
    if (readableOnBoth(candidate)) return (outer: candidate, inner: null);
  }
  return (
    outer: resolveTimetableOutlineColor(preferred, surroundingSurface),
    inner: resolveTimetableOutlineColor(preferred, cardBackground),
  );
}

/// Warn about a custom text choice without changing the user's saved color.
/// Include the same inactive fills and overlap opacities used by course cards.
bool hasLowContrastCourseText({
  required Color textColor,
  required Iterable<int> courseColorValues,
  required Color surfaceColor,
}) {
  for (final value in courseColorValues) {
    final active = Color(value);
    final backgrounds = <Color>[
      for (final alpha in const [.92, .94, .72, .62, .52, .48])
        Color.alphaBlend(active.withValues(alpha: alpha), surfaceColor),
      Color.alphaBlend(
        Color.lerp(active, surfaceColor, .58)!.withValues(alpha: .96),
        surfaceColor,
      ),
      Color.alphaBlend(
        Color.lerp(active, surfaceColor, .74)!.withValues(alpha: .92),
        surfaceColor,
      ),
    ];
    if (backgrounds.any(
      (background) => renderedTimetableContrast(textColor, background) < 4.5,
    )) {
      return true;
    }
  }
  return false;
}
