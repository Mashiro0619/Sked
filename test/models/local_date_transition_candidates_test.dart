import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/local_date_transition_candidates.dart';
import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('generated date-line index covers the installed timezone database', () {
    data.initializeTimeZones();
    final candidates = <int>{};
    int? unlocatedHistoryEnd;
    for (final location in tz.timeZoneDatabase.locations.values) {
      for (final instant in location.transitionAt) {
        final previousOffset = location.timeZone(instant - 1).offset;
        final newOffset = location.timeZone(instant).offset;
        if (newOffset - previousOffset < const Duration(hours: 12)) continue;
        if (instant == tz.minTime) {
          final next = location.transitionAt.firstWhere(
            (value) => value > tz.minTime,
          );
          if (unlocatedHistoryEnd == null || next > unlocatedHistoryEnd) {
            unlocatedHistoryEnd = next;
          }
        } else {
          candidates.add(instant);
        }
      }
    }
    final expected = candidates.toList()..sort();
    expect(
      localDateTransitionCandidateMilliseconds,
      expected,
      reason: 'Regenerate with dart run tool/generate_local_date_transition_candidates.dart after a timezone data update.',
    );
    expect(
      localDateTransitionUnlocatedHistoryEndMilliseconds,
      unlocatedHistoryEnd ?? 0,
    );
  });
}
