import 'sked_surface.dart';

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import '../utils/constants.dart';
import '../widgets/workbench_chrome_metrics.dart';
import 'app_motion.dart';
import 'color_contrast.dart';
import 'general_calendar_color_theme.dart';
import 'sked_expressive_theme.dart';
import 'sked_menu_style.dart';

ThemeMode themeModeFromValue(String value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    case 'light':
    default:
      return ThemeMode.light;
  }
}

ThemeData buildAppTheme({
  required Color seedColor,
  required Brightness brightness,
  required String themeColorMode,
  required Map<String, int> colorfulUiColorValues,
}) {
  final opaqueSeedColor = _opaque(seedColor);
  final baseScheme = _withPrimaryFamily(
    ColorScheme.fromSeed(seedColor: opaqueSeedColor, brightness: brightness),
    opaqueSeedColor,
    brightness,
  );
  final colorScheme = themeColorMode == themeColorModeColorful
      ? _withColorfulFamilies(baseScheme, brightness, colorfulUiColorValues)
      : baseScheme;
  final colorfulExtensionValues = themeColorMode == themeColorModeColorful
      ? colorfulUiColorValues
      : const <String, int>{};
  final theme = ThemeData(useMaterial3: true, colorScheme: colorScheme);
  final shapes = SkedShapeScheme.standard;
  final motion = SkedMotionScheme.standard;
  final desktop = WorkbenchChromeMetrics.isDesktop(theme.platform);
  final textTheme = desktop
      ? theme.textTheme.copyWith(
          bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
          bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          titleLarge: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
          titleMedium: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
          labelLarge: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
        )
      : theme.textTheme;
  final controlShape = desktop
      ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
      : shapes.control;
  final selectedSurface = colorScheme.primary.withValues(alpha: 0.12);
  final accent = skedReadableAccent(
    colorScheme,
    surface: colorScheme.surfaceContainerHighest,
  );
  final selectedAccent = skedReadableAccent(
    colorScheme,
    surface: Color.alphaBlend(
      selectedSurface,
      colorScheme.surfaceContainerHighest,
    ),
  );
  final menu = SkedMenuStyle(
    colors: colorScheme,
    textTheme: textTheme,
    shapes: shapes,
    desktop: desktop,
  );

  return theme.copyWith(
    textTheme: textTheme,
    visualDensity: desktop ? VisualDensity.compact : VisualDensity.standard,
    materialTapTargetSize: desktop
        ? MaterialTapTargetSize.shrinkWrap
        : MaterialTapTargetSize.padded,
    extensions: [
      GeneralCalendarColorTheme.fromValues(colorfulExtensionValues),
      shapes,
      motion,
    ],
    scaffoldBackgroundColor: colorScheme.surface,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
          backgroundColor: colorScheme.surface,
        ),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: const ZoomPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarThemeData(
      toolbarHeight: desktop ? 48 : null,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: SkedSurfaceRole.frame.resolve(colorScheme),
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: shapes.card,
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: desktop ? 36 : 48,
      minLeadingWidth: desktop ? 20 : 24,
      horizontalTitleGap: desktop ? 10 : 16,
      iconColor: colorScheme.onSurfaceVariant,
      selectedColor: selectedAccent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: shapes.compact,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        minimumSize: Size(64, desktop ? 36 : 48),
        shape: controlShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        minimumSize: Size(64, desktop ? 36 : 48),
        shape: controlShape,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: desktop ? const Size.square(32) : const Size.square(48),
        padding: EdgeInsets.all(desktop ? 6 : 8),
        iconSize: desktop ? 18 : 24,
        shape: controlShape,
        foregroundColor: colorScheme.onSurfaceVariant,
        highlightColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      highlightElevation: 6,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: shapes.fab,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      elevation: 0,
      backgroundColor: SkedSurfaceRole.frame.resolve(colorScheme),
      surfaceTintColor: Colors.transparent,
      indicatorColor: selectedSurface,
      indicatorShape: shapes.selectionIndicator,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? selectedAccent : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? selectedAccent : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: SkedSurfaceRole.frame.resolve(colorScheme),
      surfaceTintColor: Colors.transparent,
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: SkedSurfaceRole.frame.resolve(colorScheme),
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: SkedSurfaceRole.frame.resolve(colorScheme),
      indicatorColor: selectedSurface,
      selectedIconTheme: IconThemeData(color: selectedAccent),
      unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorColor: accent,
      labelColor: accent,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: textTheme.titleSmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      modalBackgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      constraints: const BoxConstraints(minWidth: 280),
      dragHandleColor: colorScheme.outlineVariant,
      shape: shapes.bottomSheet,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: shapes.dialog,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: colorScheme.primary.withValues(alpha: 0.24),
      selectionHandleColor: accent,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        final color = states.contains(WidgetState.disabled)
            ? colorScheme.onSurface.withValues(alpha: 0.38)
            : states.contains(WidgetState.error)
            ? colorScheme.error
            : states.contains(WidgetState.focused)
            ? accent
            : colorScheme.onSurfaceVariant;
        return TextStyle(color: color);
      }),
      border: OutlineInputBorder(
        borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) ||
            !states.contains(WidgetState.selected)) {
          return null;
        }
        return accent;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) ||
            !states.contains(WidgetState.selected)) {
          return null;
        }
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.focused)) {
          return accent.withValues(alpha: .10);
        }
        if (states.contains(WidgetState.hovered)) {
          return accent.withValues(alpha: .08);
        }
        return null;
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: colorScheme.surfaceContainerHighest,
      trackGap: 4,
      stopIndicatorColor: accent,
      stopIndicatorRadius: 2,
      // material_ui still defaults to the legacy appearance behind this flag.
      // ignore: deprecated_member_use
      year2023: false,
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.onPrimary;
        }
        return colorScheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colorScheme.outlineVariant;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colorScheme.primary.withValues(alpha: 0.12);
        }
        return null;
      }),
    ),
    sliderTheme: SliderThemeData(
      // Standalone marks need contrast against the track and its surface;
      // filled controls keep the user's exact primary/onPrimary pair.
      activeTrackColor: accent,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      thumbColor: accent,
      activeTickMarkColor: _onColorFor(accent),
      inactiveTickMarkColor: accent,
      overlayColor: accent.withValues(alpha: 0.12),
      valueIndicatorColor: colorScheme.primary,
      valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onPrimary,
      ),
      thumbShape: const HandleThumbShape(),
      trackShape: const GappedSliderTrackShape(),
      trackGap: 6,
      // Select current defaults for the handle, track and value indicator.
      // ignore: deprecated_member_use
      year2023: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(shapes.control),
        side: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          );
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return selectedSurface;
          }
          return colorScheme.surfaceContainerLow;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? selectedAccent
              : colorScheme.onSurfaceVariant;
        }),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: desktop ? BorderRadius.circular(6) : shapes.fieldRadius,
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      menuStyle: menu.menuStyle,
    ),
    menuTheme: MenuThemeData(style: menu.menuStyle),
    menuButtonTheme: MenuButtonThemeData(style: menu.itemStyle()),
    popupMenuTheme: menu.popupTheme,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: controlShape,
      showCloseIcon: true,
      closeIconColor: colorScheme.onInverseSurface,
    ),
    carouselViewTheme: CarouselViewThemeData(
      elevation: 0,
      backgroundColor: colorScheme.surfaceContainerLow,
      overlayColor: WidgetStatePropertyAll(
        colorScheme.primary.withValues(alpha: 0.12),
      ),
      shape: shapes.container,
      itemClipBehavior: Clip.antiAlias,
    ),
  );
}

AnimationStyle get appThemeAnimationStyle =>
    SkedMotionPolicy.systemAwareStyle(AppMotion.themeAnimationStyle);

ColorScheme _withColorfulFamilies(
  ColorScheme baseScheme,
  Brightness brightness,
  Map<String, int> colorfulUiColorValues,
) {
  var scheme = baseScheme;
  final primaryValue = colorfulUiColorValues[colorfulUiPrimaryKey];
  final secondaryValue = colorfulUiColorValues[colorfulUiSecondaryKey];
  final tertiaryValue = colorfulUiColorValues[colorfulUiTertiaryKey];

  if (primaryValue != null) {
    scheme = _withPrimaryFamily(scheme, Color(primaryValue), brightness);
  }
  if (secondaryValue != null) {
    scheme = _withSecondaryFamily(scheme, Color(secondaryValue), brightness);
  }
  if (tertiaryValue != null) {
    scheme = _withTertiaryFamily(scheme, Color(tertiaryValue), brightness);
  }
  return scheme;
}

ColorScheme _withPrimaryFamily(
  ColorScheme baseScheme,
  Color color,
  Brightness brightness,
) {
  final exactColor = _opaque(color);
  final generated = ColorScheme.fromSeed(
    seedColor: exactColor,
    brightness: brightness,
  );
  return baseScheme.copyWith(
    primary: exactColor,
    onPrimary: _onColorFor(exactColor),
    primaryContainer: generated.primaryContainer,
    onPrimaryContainer: generated.onPrimaryContainer,
    primaryFixed: generated.primaryFixed,
    primaryFixedDim: generated.primaryFixedDim,
    onPrimaryFixed: generated.onPrimaryFixed,
    onPrimaryFixedVariant: generated.onPrimaryFixedVariant,
    inversePrimary: generated.inversePrimary,
    surfaceTint: exactColor,
  );
}

ColorScheme _withSecondaryFamily(
  ColorScheme baseScheme,
  Color color,
  Brightness brightness,
) {
  final exactColor = _opaque(color);
  final generated = ColorScheme.fromSeed(
    seedColor: exactColor,
    brightness: brightness,
  );
  return baseScheme.copyWith(
    secondary: exactColor,
    onSecondary: _onColorFor(exactColor),
    secondaryContainer: generated.secondaryContainer,
    onSecondaryContainer: generated.onSecondaryContainer,
    secondaryFixed: generated.secondaryFixed,
    secondaryFixedDim: generated.secondaryFixedDim,
    onSecondaryFixed: generated.onSecondaryFixed,
    onSecondaryFixedVariant: generated.onSecondaryFixedVariant,
  );
}

ColorScheme _withTertiaryFamily(
  ColorScheme baseScheme,
  Color color,
  Brightness brightness,
) {
  final exactColor = _opaque(color);
  final generated = ColorScheme.fromSeed(
    seedColor: exactColor,
    brightness: brightness,
  );
  return baseScheme.copyWith(
    tertiary: exactColor,
    onTertiary: _onColorFor(exactColor),
    tertiaryContainer: generated.tertiaryContainer,
    onTertiaryContainer: generated.onTertiaryContainer,
    tertiaryFixed: generated.tertiaryFixed,
    tertiaryFixedDim: generated.tertiaryFixedDim,
    onTertiaryFixed: generated.onTertiaryFixed,
    onTertiaryFixedVariant: generated.onTertiaryFixedVariant,
  );
}

Color _opaque(Color color) => color.withValues(alpha: 1);

Color _onColorFor(Color color) {
  final blackContrast = colorContrastRatio(color, Colors.black);
  final whiteContrast = colorContrastRatio(color, Colors.white);
  return blackContrast >= whiteContrast ? Colors.black : Colors.white;
}
