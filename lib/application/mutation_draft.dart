import '../models/timetable_models.dart';
import 'operation_contracts.dart';
import 'resource_contracts.dart';

enum ResourceMutationAction {
  create,
  patch,
  delete,
  copy,
  move,
  dismissReminder,
  restoreReminder,
}

/// A strict application command, independent of UI state and model providers.
class ResourceMutation {
  ResourceMutation({
    required this.kind,
    required this.action,
    this.target,
    this.destinationParentId,
    this.scope,
    Map<String, Object?> values = const {},
  }) : values = immutableMutationJson(values) as Map<String, Object?>;

  final ResourceKind kind;
  final ResourceMutationAction action;
  final ResourceRef? target;

  /// Required for child creation/movement; copying defaults to its old owner.
  final String? destinationParentId;

  /// Required for occurrence patch/delete/copy. Other commands reject a scope.
  final GeneralEventEditScope? scope;

  /// Missing fields stay unchanged in a patch. Null is accepted only for
  /// nullable fields. Nested objects are complete replacements, not deep patches.
  final Map<String, Object?> values;
}

/// Host-owned values captured once while preparing a concrete mutation.
class MutationContext {
  const MutationContext({required this.now, required this.idGenerator});

  final DateTime now;
  final String Function(ResourceKind kind) idGenerator;
}

class ResourceChange {
  ResourceChange({
    required this.key,
    this.ref,
    required Object? before,
    required Object? after,
  }) : before = immutableMutationJson(before),
       after = immutableMutationJson(after);

  /// Resource keys use [resourceChangeKey]. Auxiliary keys are a fixed host
  /// allowlist, never arbitrary paths supplied by tool arguments.
  final String key;
  final ResourceRef? ref;

  /// Native resource JSON; null means creation/deletion. These are host-side
  /// preview/undo records, not the compact projections sent to a model.
  final Object? before;
  final Object? after;

  Map<String, Object?> toJson() => {
    'key': key,
    if (ref != null) 'ref': ref!.toJson(),
    'before': before,
    'after': after,
  };
}

class MutationDraft {
  MutationDraft({
    required this.candidate,
    required List<ResourceChange> changes,
  }) : changes = List.unmodifiable(changes);

  /// A candidate only. The owning coordinator validates its baseline and
  /// permissions before writing it through the shared application session.
  final AppData candidate;
  final List<ResourceChange> changes;
  bool get isEmpty => changes.isEmpty;
}

String resourceChangeKey(ResourceRef ref) =>
    'resource:${ref.kind.name}:${Uri.encodeComponent(ref.parentId ?? '')}:'
    '${Uri.encodeComponent(ref.id)}';

/// Copies caller-owned JSON and rejects non-JSON/cyclic or excessive nesting.
Object? immutableMutationJson(Object? value, [int depth = 0]) {
  if (depth > 64) {
    throw const OperationProblem(
      OperationErrorCode.invalidArgument,
      'Mutation JSON exceeds the supported nesting depth.',
    );
  }
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (final item in value) immutableMutationJson(item, depth + 1),
    ]);
  }
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: immutableMutationJson(entry.value, depth + 1),
    });
  }
  throw const OperationProblem(
    OperationErrorCode.invalidArgument,
    'Mutation values must be finite JSON values.',
  );
}
