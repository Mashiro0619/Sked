import '../utils/unique_id.dart';
import 'operation_contracts.dart';
import 'resource_mutations.dart';
import 'resource_queries.dart';

/// A fixed, bounded set of resource identities owned by one run. A later query
/// or a changed data snapshot cannot silently retarget a common batch patch.
class ResourceSelection {
  ResourceSelection._({
    required this.id,
    required this.generation,
    required this.revision,
    required this.createdAt,
    required this.kind,
    required this.scope,
    required List<ResourceRef> targets,
  }) : targets = List.unmodifiable(targets);

  final String id;
  final String generation;
  final int revision;
  final DateTime createdAt;
  final ResourceKind kind;
  final OperationScope scope;
  final List<ResourceRef> targets;

  Map<String, Object?> page({int offset = 0, int limit = 50}) {
    if (offset < 0 || offset > targets.length || limit < 1 || limit > 100) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Invalid selection page bounds.',
      );
    }
    final items = targets.skip(offset).take(limit).toList();
    return {
      'selectionRef': id,
      'datasetGeneration': generation,
      'snapshotRevision': revision,
      'kind': kind.name,
      'totalMatches': targets.length,
      'items': [for (final target in items) target.toJson()],
      'hasMore': offset + items.length < targets.length,
      'nextOffset': offset + items.length < targets.length
          ? offset + items.length
          : null,
    };
  }
}

class ResourceSelectionRegistry {
  ResourceSelectionRegistry({DateTime Function()? clock, String Function()? id})
    : _clock = clock ?? DateTime.now,
      _id = id ?? generateUuidV4;

  static const maxSelections = 32;
  static const lifetime = Duration(minutes: 30);
  final DateTime Function() _clock;
  final String Function() _id;
  final _selections = <String, ResourceSelection>{};

  ResourceSelection create({
    required ResourceQueries reader,
    required ResourceQuery query,
    required OperationScope scope,
  }) {
    scope.checkActive();
    if (query.cursor != null) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Select the complete filtered set, without a page cursor.',
        field: 'cursor',
      );
    }
    final now = _clock();
    _selections.removeWhere(
      (_, value) =>
          value.scope.isCancelled || now.difference(value.createdAt) > lifetime,
    );
    if (_selections.length >= maxSelections) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'This run has too many pending selections.',
      );
    }
    final targets = <ResourceRef>[];
    String? cursor;
    do {
      final page = reader.query(
        ResourceQuery(
          kind: query.kind,
          ids: query.ids,
          parentIds: query.parentIds,
          sourceIds: query.sourceIds,
          occurrenceSource: query.occurrenceSource,
          search: query.search,
          includeHidden: query.includeHidden,
          includeDisabled: query.includeDisabled,
          startInclusive: query.startInclusive,
          endExclusive: query.endExclusive,
          fields: const {},
          limit: ResourceQueryLimits.maxPageItems,
          cursor: cursor,
        ),
      );
      if (page.totalMatches > ResourceMutationCompiler.maxOperations) {
        throw const OperationProblem(
          OperationErrorCode.invalidArgument,
          'Narrow the selection to at most 1000 resources. No partial set was selected.',
        );
      }
      targets.addAll(page.items.map((item) => item.ref));
      cursor = page.nextCursor;
    } while (cursor != null);
    final selection = ResourceSelection._(
      id: _id(),
      generation: reader.datasetGeneration,
      revision: reader.snapshotRevision,
      createdAt: now,
      kind: query.kind,
      scope: scope,
      targets: targets,
    );
    _selections[selection.id] = selection;
    return selection;
  }

  ResourceSelection get(
    String id,
    ResourceQueries reader,
    OperationScope scope,
  ) {
    scope.checkActive();
    final value = _selections[id];
    if (value == null ||
        !identical(value.scope, scope) ||
        value.generation != reader.datasetGeneration ||
        value.revision != reader.snapshotRevision ||
        _clock().difference(value.createdAt) > lifetime) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'The selection is stale or belongs to another run. Query and select again.',
        field: 'selectionRef',
      );
    }
    return value;
  }

  void discardScope(OperationScope scope) =>
      _selections.removeWhere((_, value) => identical(value.scope, scope));

  void invalidate() => _selections.clear();
}
