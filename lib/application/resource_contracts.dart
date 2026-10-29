/// Public, read-only application resource contracts. These are projections,
/// never serialized AppData snapshots or commands that can modify the app.
enum ResourceKind {
  timetable,
  course,
  periodTimeSet,
  calendar,
  event,
  occurrence,
}

enum ResourceView { summary, detail, edit }

enum OccurrenceSource { course, event }

enum ResourceQueryErrorCode {
  invalidArgument,
  invalidField,
  notFound,
  invalidCursor,
  staleCursor,
  cursorQueryMismatch,
  queryTooLarge,
  resultTooLarge,
  invalidSnapshot,
}

class ResourceQueryException implements Exception {
  const ResourceQueryException(this.code, this.message, {this.field});

  final ResourceQueryErrorCode code;
  final String message;
  final String? field;

  @override
  String toString() => 'ResourceQueryException(${code.name}): $message';
}

class ResourceRef {
  const ResourceRef({required this.kind, required this.id, this.parentId});

  final ResourceKind kind;
  final String id;

  /// The owning timetable/calendar for a course/event/occurrence.
  final String? parentId;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    if (parentId != null) 'parentId': parentId,
  };

  @override
  bool operator ==(Object other) =>
      other is ResourceRef &&
      kind == other.kind &&
      id == other.id &&
      parentId == other.parentId;

  @override
  int get hashCode => Object.hash(kind, id, parentId);
}

class ResourceQuery {
  ResourceQuery({
    required this.kind,
    this.view = ResourceView.summary,
    Set<String>? ids,
    Set<String>? parentIds,
    Set<String>? sourceIds,
    this.occurrenceSource,
    this.search = '',
    this.includeHidden = true,
    this.includeDisabled = true,
    this.startInclusive,
    this.endExclusive,
    Set<String>? fields,
    this.limit = 50,
    this.cursor,
  }) : ids = ids == null ? null : Set.unmodifiable(ids),
       parentIds = parentIds == null ? null : Set.unmodifiable(parentIds),
       sourceIds = sourceIds == null ? null : Set.unmodifiable(sourceIds),
       fields = fields == null ? null : Set.unmodifiable(fields);

  final ResourceKind kind;
  final ResourceView view;

  /// Null means unrestricted. An explicitly empty set matches no records.
  final Set<String>? ids;
  final Set<String>? parentIds;

  /// Course/event IDs, applied before occurrence expansion.
  final Set<String>? sourceIds;
  final OccurrenceSource? occurrenceSource;
  final String search;
  final bool includeHidden;
  final bool includeDisabled;

  /// Required only for occurrences. Bounds select overlapping instances.
  final DateTime? startInclusive;
  final DateTime? endExclusive;

  /// Null uses the named view. Empty selects only the mandatory reference.
  /// Requested fields are always present, including explicit null/empty values.
  final Set<String>? fields;
  final int limit;
  final String? cursor;
}

abstract final class ResourceQueryLimits {
  static const maxPageItems = 100;
  static const maxMatches = 20000;
  static const maxRangeDays = 366;
  static const maxPageBytes = 64 * 1024;
  static const maxFilterIds = 512;
  static const maxIdLength = 2048;
}

class ResourceRecord {
  ResourceRecord({
    required this.ref,
    required this.view,
    required Map<String, Object?> values,
  }) : values = _freezeMap(values, 0);

  final ResourceRef ref;
  final ResourceView view;
  final Map<String, Object?> values;

  List<String> get includedFields => List.unmodifiable(values.keys);

  Map<String, Object?> toJson() => {
    'ref': ref.toJson(),
    'view': view.name,
    'includedFields': includedFields,
    'data': values,
  };
}

class QueryPage {
  QueryPage({
    required this.datasetGeneration,
    required this.snapshotRevision,
    required List<ResourceRecord> items,
    required this.totalMatches,
    this.nextCursor,
  }) : items = List.unmodifiable(items);

  final String datasetGeneration;
  final int snapshotRevision;
  final List<ResourceRecord> items;
  final int totalMatches;
  final String? nextCursor;
  bool get hasMore => nextCursor != null;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'datasetGeneration': datasetGeneration,
    'snapshotRevision': snapshotRevision,
    'items': items.map((item) => item.toJson()).toList(),
    'totalMatches': totalMatches,
    'hasMore': hasMore,
    'nextCursor': nextCursor,
  };
}

Map<String, Object?> _freezeMap(Map<String, Object?> value, int depth) =>
    Map.unmodifiable({
      for (final entry in value.entries)
        entry.key: _freezeValue(entry.value, depth + 1),
    });

Object? _freezeValue(Object? value, int depth) {
  if (depth > 64) {
    throw const ResourceQueryException(
      ResourceQueryErrorCode.resultTooLarge,
      'The selected value exceeds the supported nesting depth.',
    );
  }
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (final item in value) _freezeValue(item, depth + 1),
    ]);
  }
  if (value is Map && value.keys.every((key) => key is String)) {
    return _freezeMap(value.cast<String, Object?>(), depth);
  }
  throw const ResourceQueryException(
    ResourceQueryErrorCode.invalidSnapshot,
    'The selected resource contains an unsupported JSON value.',
  );
}
