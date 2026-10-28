import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../utils/latin_word_wrapping.dart';

/// Reserves room for a visible week status before optional course metadata.
/// The surrounding course target owns the full title, status and tap semantics.
class TimetableCourseWeekStatus extends StatelessWidget {
  const TimetableCourseWeekStatus({
    super.key,
    required this.title,
    required this.label,
    required this.titleStyle,
    required this.style,
    required this.child,
  });

  final String title, label;
  final TextStyle? titleStyle, style;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PaintingBinding.instance.systemFonts,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        final defaults = DefaultTextStyle.of(context);
        TextStyle resolve(TextStyle? value) {
          final result = defaults.style.merge(value);
          return MediaQuery.boldTextOf(context)
              ? result.copyWith(fontWeight: FontWeight.bold)
              : result;
        }

        final statusStyle = resolve(style);
        final textHeightBehavior =
            defaults.textHeightBehavior ??
            DefaultTextHeightBehavior.maybeOf(context);
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final locale = Localizations.maybeLocaleOf(context);
        ({double height, int lines, bool needsMarker}) measure(
          String text,
          TextStyle style,
          int? lines,
        ) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            textHeightBehavior: textHeightBehavior,
            maxLines: lines,
            ellipsis: lines == null ? null : '…',
          )..layout(maxWidth: constraints.maxWidth);
          limitOversizedLatinWords(painter, text, constraints.maxWidth);
          final result = (
            height: painter.height,
            lines: painter.computeLineMetrics().length,
            // Native paragraphs can lose even the ellipsis when no original
            // glyph fits. Use the existing bounded icon only for that case.
            needsMarker:
                painter.didExceedMaxLines &&
                painter
                    .getBoxesForSelection(
                      TextSelection(baseOffset: 0, extentOffset: text.length),
                    )
                    .isEmpty,
          );
          painter.dispose();
          return result;
        }

        Widget marker(double height) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(
            Icons.more_horiz,
            key: const ValueKey('timetable-week-status-overflow'),
            size: math.min(
              18,
              math.max(0, math.min(constraints.maxWidth, height)),
            ),
            color: statusStyle.color,
          ),
        );

        final primary = measure(title, resolve(titleStyle), 1).height;
        final full = measure(label, statusStyle, null);
        final firstLine = measure(label, statusStyle, 1).height;
        final room = constraints.maxHeight - primary - 2;
        if (room >= firstLine) {
          var lines = math.max(1, full.lines);
          var measured = full;
          while (lines > 1 && measured.height > room) {
            lines--;
            measured = measure(label, statusStyle, lines);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: child),
              const SizedBox(height: 2),
              SizedBox(
                height: measured.height,
                width: constraints.maxWidth,
                child: measured.needsMarker
                    ? marker(measured.height)
                    : Text(
                        label,
                        style: statusStyle,
                        textScaler: scaler,
                        locale: locale,
                        textHeightBehavior: textHeightBehavior,
                        maxLines: lines,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          );
        }
        // A very short time block cannot show two complete lines. Keep the
        // status first in its single summary; full course text remains on its
        // unchanged detail/semantic target, just as for other truncated cards.
        final summary = '$label · $title';
        final summaryMeasure = measure(summary, statusStyle, 1);
        if (summaryMeasure.height <= constraints.maxHeight) {
          if (summaryMeasure.needsMarker) return marker(summaryMeasure.height);
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: Text(
              summary,
              style: statusStyle,
              textScaler: scaler,
              locale: locale,
              textHeightBehavior: textHeightBehavior,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }
        return marker(constraints.maxHeight);
      },
    ),
  );
}
