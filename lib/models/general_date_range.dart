import '../utils/calendar_date_utils.dart';

/// An inclusive, civil-date viewport. Independent from the focused date.
class GeneralDateRange {
  GeneralDateRange._(this.start, this.end);
  static const maxDays = 14;
  static final firstDate = DateTime(1970);
  static final lastDate = DateTime(2100);
  final DateTime start;
  final DateTime end;

  factory GeneralDateRange(DateTime start, DateTime end) {
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final days = calendarDaysBetween(first, last) + 1;
    if (days < 1 ||
        days > maxDays ||
        first.isBefore(firstDate) ||
        last.isAfter(lastDate)) {
      throw const FormatException(
        'Date range must contain 1–14 supported calendar days.',
      );
    }
    return GeneralDateRange._(first, last);
  }
  factory GeneralDateRange.fromJson(Object? json) {
    if (json is! Map || json['start'] is! String || json['end'] is! String) {
      throw const FormatException('Date range requires start and end dates.');
    }
    DateTime parse(String value) {
      final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
      if (match == null) {
        throw const FormatException('Invalid date range date.');
      }
      final date = DateTime(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
      if (_iso(date) != value) {
        throw const FormatException('Invalid date range date.');
      }
      return date;
    }

    return GeneralDateRange(
      parse(json['start'] as String),
      parse(json['end'] as String),
    );
  }
  int get dayCount => calendarDaysBetween(start, end) + 1;
  DateTime get endExclusive => addCalendarDays(end, 1);
  bool contains(DateTime date) =>
      calendarDaysBetween(start, date) >= 0 &&
      calendarDaysBetween(date, end) >= 0;
  GeneralDateRange? shifted(int days) {
    final first = addCalendarDays(start, days),
        last = addCalendarDays(end, days);
    if (first.isBefore(firstDate) || last.isAfter(lastDate)) return null;
    return GeneralDateRange(first, last);
  }

  /// Direct navigation preserves length and contains the requested date, even
  /// at the upper bound. It never silently changes an already containing range.
  GeneralDateRange containing(DateTime date) {
    if (contains(date)) return this;
    var first = DateTime(date.year, date.month, date.day);
    if (first.isBefore(firstDate) || first.isAfter(lastDate)) {
      throw const FormatException('Unsupported navigation date.');
    }
    final latestStart = addCalendarDays(lastDate, 1 - dayCount);
    if (first.isAfter(latestStart)) first = latestStart;
    return GeneralDateRange(first, addCalendarDays(first, dayCount - 1));
  }

  Map<String, dynamic> toJson() => {'start': _iso(start), 'end': _iso(end)};
  @override
  bool operator ==(Object other) =>
      other is GeneralDateRange && start == other.start && end == other.end;
  @override
  int get hashCode => Object.hash(start, end);
}

String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
