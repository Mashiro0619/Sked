import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'app_motion.dart';
import 'general_calendar_color_theme.dart';

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
  final textTheme = theme.textTheme;
  final selectedSurface = colorScheme.primary.withValues(alpha: 0.12);
  final menuSurface = colorScheme.surfaceContainer;
  final menuOutline = colorScheme.outlineVariant.withValues(alpha: 0.72);
  final menuShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
    side: BorderSide(color: menuOutline),
  );
  final menuOverlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.transparent;
    }
    if (states.contains(WidgetState.pressed)) {
      return colorScheme.primary.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.focused)) {
      return colorScheme.primary.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return colorScheme.primary.withValues(alpha: 0.08);
    }
    return null;
  });

  return theme.copyWith(
    extensions: [GeneralCalendarColorTheme.fromValues(colorfulExtensionValues)],
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
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
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
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      selectedColor: colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        highlightColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      highlightElevation: 6,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      elevation: 0,
      backgroundColor: colorScheme.surfaceContainer,
      indicatorColor: selectedSurface,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: selectedSurface,
      selectedIconTheme: IconThemeData(color: colorScheme.primary),
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
      indicatorColor: colorScheme.primary,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: textTheme.titleSmall,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      modalBackgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      showDragHandle: true,
      constraints: const BoxConstraints(minWidth: 280),
      dragHandleColor: colorScheme.outlineVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 1,
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
      activeTrackColor: colorScheme.primary,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      thumbColor: colorScheme.primary,
      overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      valueIndicatorColor: colorScheme.primary,
      valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
        color: colorScheme.onPrimary,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
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
              ? colorScheme.primary
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
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(menuSurface),
        shadowColor: WidgetStatePropertyAll<Color>(
          colorScheme.shadow.withValues(alpha: 0.18),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(3),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(menuShape),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: menuOutline),
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(menuSurface),
        shadowColor: WidgetStatePropertyAll<Color>(
          colorScheme.shadow.withValues(alpha: 0.18),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(3),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(menuShape),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: menuOutline),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        overlayColor: menuOverlayColor,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurface;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.focused)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: menuSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
      menuPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: menuShape,
      iconColor: colorScheme.onSurfaceVariant,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.disabled)
            ? colorScheme.onSurface.withValues(alpha: 0.38)
            : colorScheme.onSurface;
        return textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      showCloseIcon: true,
      closeIconColor: colorScheme.onInverseSurface,
    ),
    carouselViewTheme: CarouselViewThemeData(
      elevation: 0,
      backgroundColor: colorScheme.surfaceContainerLow,
      overlayColor: WidgetStatePropertyAll(
        colorScheme.primary.withValues(alpha: 0.12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      itemClipBehavior: Clip.antiAlias,
    ),
  );
}

AnimationStyle get appThemeAnimationStyle => AppMotion.themeAnimationStyle;

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
  final blackContrast = _contrastRatio(color, Colors.black);
  final whiteContrast = _contrastRatio(color, Colors.white);
  return blackContrast >= whiteContrast ? Colors.black : Colors.white;
}

double _contrastRatio(Color a, Color b) {
  final aLuminance = a.computeLuminance();
  final bLuminance = b.computeLuminance();
  final lighter = aLuminance > bLuminance ? aLuminance : bLuminance;
  final darker = aLuminance > bLuminance ? bLuminance : aLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
