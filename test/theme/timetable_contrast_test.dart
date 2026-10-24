import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/theme/timetable_contrast.dart';

void main() {
  test('automatic course text and status outlines meet rendered contrast', () {
    for (final surface in const [Colors.white, Color(0xff111318)]) {
      for (final fill in const [
        Color(0xff111111),
        Color(0xffeeeeee),
        Color(0xffe57373),
        Color(0xff7986cb),
        Color(0xffffd54f),
        Color(0xff81c784),
      ]) {
        for (final alpha in const [.48, .62, .92, .94, .96]) {
          final background = Color.alphaBlend(
            fill.withValues(alpha: alpha),
            surface,
          );
          final text = resolveAutomaticTimetableTextColor(
            background,
            preferred: const Color(0xff6750a4),
          );
          expect(
            renderedTimetableContrast(text, background),
            greaterThanOrEqualTo(4.5),
          );
          final outline = resolveTimetableOutlineColor(fill, background);
          expect(
            renderedTimetableContrast(outline, background),
            greaterThanOrEqualTo(3),
          );
        }
      }
    }
  });

  test('readable explicit preferred colors retain their exact value', () {
    const preferred = Color(0xff123456);
    expect(
      resolveAutomaticTimetableTextColor(Colors.white, preferred: preferred),
      preferred,
    );
    expect(resolveTimetableOutlineColor(preferred, Colors.white), preferred);
  });

  test('outline guard distinguishes the card fill and the outside canvas', () {
    for (final canvas in const [Colors.white, Color(0xff111318)]) {
      for (final fill in const [
        Colors.black,
        Colors.white,
        Color(0xff555555),
      ]) {
        final colors = resolveTimetableOutlineColors(
          fill,
          cardBackground: fill,
          surroundingSurface: canvas,
        );
        expect(
          renderedTimetableContrast(colors.outer, canvas),
          greaterThanOrEqualTo(3),
        );
        expect(
          renderedTimetableContrast(colors.inner ?? colors.outer, fill),
          greaterThanOrEqualTo(3),
        );
      }
    }
  });

  test('custom color contrast at the threshold matches its original alpha', () {
    const color = Color(0xff767676);
    expect(renderedTimetableContrast(color, Colors.white), greaterThan(4.5));
    expect(
      hasLowContrastCourseText(
        textColor: color,
        courseColorValues: const [0xffffffff],
        surfaceColor: Colors.white,
      ),
      isFalse,
    );
    expect(
      hasLowContrastCourseText(
        textColor: color.withValues(alpha: .96),
        courseColorValues: const [0xffffffff],
        surfaceColor: Colors.white,
      ),
      isTrue,
    );
  });

  test(
    'custom warnings include inactive fills and translucent foregrounds',
    () {
      expect(
        hasLowContrastCourseText(
          textColor: Colors.black,
          courseColorValues: const [0xffffd54f],
          surfaceColor: Colors.white,
        ),
        isFalse,
      );
      expect(
        hasLowContrastCourseText(
          textColor: Colors.white,
          courseColorValues: const [0xffffd54f],
          surfaceColor: Colors.white,
        ),
        isTrue,
      );
      // White reads on the active dark fill, but not its faded past-week fill.
      expect(
        hasLowContrastCourseText(
          textColor: Colors.white,
          courseColorValues: const [0xff001133],
          surfaceColor: Colors.white,
        ),
        isTrue,
      );
      expect(
        hasLowContrastCourseText(
          textColor: const Color(0x40000000),
          courseColorValues: const [0xffffd54f],
          surfaceColor: Colors.white,
        ),
        isTrue,
      );
      expect(
        hasLowContrastCourseText(
          textColor: Colors.white,
          courseColorValues: const [],
          surfaceColor: Colors.white,
        ),
        isFalse,
      );
    },
  );
}
