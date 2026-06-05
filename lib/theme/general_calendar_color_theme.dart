import 'package:flutter/material.dart';

import '../utils/constants.dart';

@immutable
class GeneralCalendarColorTheme
    extends ThemeExtension<GeneralCalendarColorTheme> {
  const GeneralCalendarColorTheme({
    required this.color1,
    required this.color2,
    required this.color3,
    required this.color4,
    required this.color5,
    required this.color6,
    this.lunarTextColor,
    this.festivalTextColor,
    this.solarTermTextColor,
  });

  factory GeneralCalendarColorTheme.fromValues(Map<String, int> values) {
    return GeneralCalendarColorTheme(
      color1: _colorFor(
        values,
        colorfulGeneralCalendarColor1Key,
        fallback.color1,
      ),
      color2: _colorFor(
        values,
        colorfulGeneralCalendarColor2Key,
        fallback.color2,
      ),
      color3: _colorFor(
        values,
        colorfulGeneralCalendarColor3Key,
        fallback.color3,
      ),
      color4: _colorFor(
        values,
        colorfulGeneralCalendarColor4Key,
        fallback.color4,
      ),
      color5: _colorFor(
        values,
        colorfulGeneralCalendarColor5Key,
        fallback.color5,
      ),
      color6: _colorFor(
        values,
        colorfulGeneralCalendarColor6Key,
        fallback.color6,
      ),
      lunarTextColor: _optionalColorFor(
        values,
        colorfulGeneralLunarTextColorKey,
      ),
      festivalTextColor: _optionalColorFor(
        values,
        colorfulGeneralFestivalTextColorKey,
      ),
      solarTermTextColor: _optionalColorFor(
        values,
        colorfulGeneralSolarTermTextColorKey,
      ),
    );
  }

  static const fallback = GeneralCalendarColorTheme(
    color1: Color(0xFF4DB6AC),
    color2: Color(0xFF64B5F6),
    color3: Color(0xFFFFB74D),
    color4: Color(0xFFBA68C8),
    color5: Color(0xFF81C784),
    color6: Color(0xFFE57373),
  );

  final Color color1;
  final Color color2;
  final Color color3;
  final Color color4;
  final Color color5;
  final Color color6;
  final Color? lunarTextColor;
  final Color? festivalTextColor;
  final Color? solarTermTextColor;

  List<Color> get colors => [color1, color2, color3, color4, color5, color6];

  Color colorForKey(String key) {
    return switch (key) {
      colorfulGeneralCalendarColor1Key => color1,
      colorfulGeneralCalendarColor2Key => color2,
      colorfulGeneralCalendarColor3Key => color3,
      colorfulGeneralCalendarColor4Key => color4,
      colorfulGeneralCalendarColor5Key => color5,
      colorfulGeneralCalendarColor6Key => color6,
      _ => color1,
    };
  }

  @override
  GeneralCalendarColorTheme copyWith({
    Color? color1,
    Color? color2,
    Color? color3,
    Color? color4,
    Color? color5,
    Color? color6,
    Color? lunarTextColor,
    Color? festivalTextColor,
    Color? solarTermTextColor,
  }) {
    return GeneralCalendarColorTheme(
      color1: color1 ?? this.color1,
      color2: color2 ?? this.color2,
      color3: color3 ?? this.color3,
      color4: color4 ?? this.color4,
      color5: color5 ?? this.color5,
      color6: color6 ?? this.color6,
      lunarTextColor: lunarTextColor ?? this.lunarTextColor,
      festivalTextColor: festivalTextColor ?? this.festivalTextColor,
      solarTermTextColor: solarTermTextColor ?? this.solarTermTextColor,
    );
  }

  @override
  GeneralCalendarColorTheme lerp(
    ThemeExtension<GeneralCalendarColorTheme>? other,
    double t,
  ) {
    if (other is! GeneralCalendarColorTheme) {
      return this;
    }
    return GeneralCalendarColorTheme(
      color1: Color.lerp(color1, other.color1, t) ?? color1,
      color2: Color.lerp(color2, other.color2, t) ?? color2,
      color3: Color.lerp(color3, other.color3, t) ?? color3,
      color4: Color.lerp(color4, other.color4, t) ?? color4,
      color5: Color.lerp(color5, other.color5, t) ?? color5,
      color6: Color.lerp(color6, other.color6, t) ?? color6,
      lunarTextColor: Color.lerp(lunarTextColor, other.lunarTextColor, t),
      festivalTextColor: Color.lerp(
        festivalTextColor,
        other.festivalTextColor,
        t,
      ),
      solarTermTextColor: Color.lerp(
        solarTermTextColor,
        other.solarTermTextColor,
        t,
      ),
    );
  }
}

GeneralCalendarColorTheme generalCalendarColorThemeOf(BuildContext context) {
  return Theme.of(context).extension<GeneralCalendarColorTheme>() ??
      GeneralCalendarColorTheme.fromValues(const {});
}

Color generalCalendarSlotColorOf(BuildContext context, String key) {
  return generalCalendarColorThemeOf(context).colorForKey(key);
}

Color _colorFor(Map<String, int> values, String key, Color fallback) {
  return Color(values[key] ?? fallback.toARGB32());
}

Color? _optionalColorFor(Map<String, int> values, String key) {
  final value = values[key];
  return value == null ? null : Color(value);
}
