/// The saved recurrence record affected by an occurrence edit.
enum GeneralEventEditScope { thisOccurrence, thisAndFollowing, entireSeries }

/// The original occurrence or its owning calendar changed while editing.
class GeneralEventEditConflictException implements Exception {
  const GeneralEventEditConflictException([
    this.message = 'The event changed while it was being edited.',
  ]);

  final String message;

  @override
  String toString() => 'GeneralEventEditConflictException: $message';
}
