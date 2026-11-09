import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../knowledge/agent_knowledge_editor_controller.dart';
import '../skills/shared_skill_loader.dart';
import 'generated/api/contracts.dart' as native;
import 'generated/api/management_contracts.dart' as management;
import 'generated/api/models.dart' as view;
import 'knowledge_projection.dart';
import 'rust_agent_client.dart';
import 'rust_storage_errors.dart';

/// Keeps a read projection for the editor while Rust owns every saved change.
class RustKnowledgeEditorController extends ChangeNotifier
    implements AgentKnowledgeEditorController {
  RustKnowledgeEditorController({
    required this.client,
    required this.readDataGeneration,
    required this.readRegisteredTools,
    this.isReferenceCurrent,
    this.isAvailable,
    this.validateMutation,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _subscription = client.events.listen(_event, onError: _streamError);
  }

  final AgentRustClient client;
  final String Function() readDataGeneration;
  final Set<String> Function() readRegisteredTools;
  final bool Function(KnowledgeReference)? isReferenceCurrent;
  final bool Function()? isAvailable;
  final void Function()? validateMutation;
  final DateTime Function() _clock;
  late final StreamSubscription<native.AgentEvent> _subscription;
  final _records = <String, KnowledgeRecord>{};
  final _originalDigests = <String, String>{};
  final _projectedRevisions = <String, int>{};
  final _tasks = <Future<void>>{};
  Future<void>? _refreshing;
  Object? _loadFailure;
  bool _loaded = false;
  bool _disposed = false;
  bool _frozen = false;
  bool _refreshAgain = false;
  int _epoch = 0;
  int _fullRevision = -1;
  int _storageRevision = -1;
  int _minimumReceiptRevision = 0;

  @override
  bool get ready =>
      _loaded &&
      !_disposed &&
      !_frozen &&
      _loadFailure == null &&
      (isAvailable?.call() ?? true);

  @override
  bool get isLoaded => _loaded && !_disposed;

  SkillOverlaySnapshot captureSkillSnapshot() {
    _checkReady();
    return SkillOverlaySnapshot(
      _records.values
          .where((record) => record.kind == KnowledgeKind.skill)
          .map(
            (record) => SkillOverlay(
              skill: SkillDescriptor.editable(
                id: record.id,
                title: record.title,
                summary: record.summary,
                body: record.body,
                revision: record.revision,
                triggers: record.triggers,
                sourceKinds: record.sourceKinds,
                requiredTools: record.requiredTools,
                optionalTools: record.optionalTools,
              ),
              enabled: record.enabled,
              builtIn: record.builtIn,
              body: record.usesOriginal ? null : record.body,
            ),
          ),
    );
  }

  @override
  Future<void> initialize({bool reload = false}) {
    _checkAvailable();
    if (reload) _loadFailure = null;
    if (_loadFailure != null) {
      return Future.error(knowledgeErrorFromRust(_loadFailure!));
    }
    if (!reload && ready) return Future.value();
    return _refresh();
  }

  Future<void> _refresh() {
    if (_disposed) return Future.value();
    _refreshAgain = true;
    return _refreshing ??= _track(
      _refreshLoop().whenComplete(() => _refreshing = null),
    );
  }

  Future<void> _refreshLoop() async {
    try {
      do {
        _refreshAgain = false;
        final epoch = _epoch;
        final result = await client.query(
          const native.AgentQuery(kind: native.QueryKind.knowledgeCatalog),
        );
        if (_disposed) return;
        if (epoch != _epoch) {
          _refreshAgain = true;
          continue;
        }
        final catalog = result.knowledgeCatalog;
        if (catalog == null) {
          throw const KnowledgeException(
            KnowledgeError.unavailable,
            'The native knowledge catalog is unavailable.',
          );
        }
        if (catalog.revision < _minimumReceiptRevision) {
          _refreshAgain = true;
          continue;
        }
        if (catalog.storageRevision < _storageRevision) continue;
        final records = catalog.records.map(knowledgeRecordFromRust).toList();
        _records
          ..clear()
          ..addEntries(records.map((record) => MapEntry(record.key, record)));
        _originalDigests
          ..clear()
          ..addAll(catalog.originalDigests);
        _projectedRevisions.clear();
        _fullRevision = catalog.revision;
        _storageRevision = catalog.storageRevision;
        _loadFailure = null;
        _loaded = true;
        notifyListeners();
      } while (_refreshAgain && !_disposed);
    } catch (error) {
      if (!_disposed) {
        _loadFailure = error;
        notifyListeners();
      }
      throw knowledgeErrorFromRust(error);
    }
  }

  void _event(native.AgentEvent event) {
    if (_disposed) return;
    if (event.kind == native.EventKind.resync) {
      _epoch++;
      _fullRevision = -1;
      _storageRevision = -1;
      _minimumReceiptRevision = 0;
      _projectedRevisions.clear();
    } else if (event.kind != native.EventKind.knowledgeChanged) {
      return;
    }
    if (_loaded && !_frozen && (isAvailable?.call() ?? true)) {
      _refreshInBackground();
    }
  }

  void _streamError(Object error, StackTrace stack) {
    if (_disposed) return;
    _loadFailure = error;
    notifyListeners();
  }

  void _refreshInBackground() {
    unawaited(_refresh().catchError((Object _, StackTrace _) {}));
  }

  @override
  List<KnowledgeRecord> list(
    KnowledgeKind kind, {
    String query = '',
    bool includeDisabled = true,
  }) {
    final filter = query.trim().toLowerCase();
    return List.unmodifiable(
      _records.values.where(
        (record) =>
            record.kind == kind &&
            (includeDisabled || record.enabled) &&
            (filter.isEmpty ||
                '${record.id} ${record.title} ${record.summary} ${record.body} ${record.sourceNote}'
                    .toLowerCase()
                    .contains(filter)),
      ),
    );
  }

  @override
  Future<KnowledgeRecord> read(KnowledgeKind kind, String id) =>
      _track(_read(kind, id));

  Future<KnowledgeRecord> _read(KnowledgeKind kind, String id) async {
    await initialize();
    final epoch = _epoch;
    try {
      final result = await client.query(
        native.AgentQuery(
          kind: native.QueryKind.readKnowledgeRecord,
          targetId: '${kind.name}:$id',
        ),
      );
      _checkAvailable();
      if (epoch != _epoch) _conflict();
      final record = result.knowledge.firstOrNull;
      if (record == null) {
        throw const KnowledgeException(
          KnowledgeError.invalid,
          'The knowledge record no longer exists.',
        );
      }
      return knowledgeRecordFromRust(record);
    } catch (error) {
      throw knowledgeErrorFromRust(error);
    }
  }

  @override
  List<String> missingTools(KnowledgeRecord record) => List.unmodifiable(
    record.requiredTools.where((tool) => !readRegisteredTools().contains(tool)),
  );

  @override
  bool originalChanged(KnowledgeRecord record) =>
      record.builtIn &&
      !record.usesOriginal &&
      _originalDigests[record.id] != record.baseSha256;

  @override
  bool needsRecheck(KnowledgeRecord record) =>
      record.needsRecheck(readDataGeneration(), _clock()) ||
      record.references.any(
        (reference) => isReferenceCurrent?.call(reference) != true,
      );

  @override
  Future<KnowledgeReceipt> saveDraft(
    KnowledgeRecord draft, {
    bool create = false,
  }) => _edit(management.KnowledgeEditAction.save, draft, create: create);

  @override
  Future<KnowledgeReceipt> delete(KnowledgeRecord record) =>
      _edit(management.KnowledgeEditAction.delete, record);

  @override
  Future<KnowledgeReceipt> restoreOriginal(KnowledgeRecord record) =>
      _edit(management.KnowledgeEditAction.restoreOriginal, record);

  Future<KnowledgeReceipt> _edit(
    management.KnowledgeEditAction action,
    KnowledgeRecord record, {
    bool create = false,
  }) => _track(
    _mutate(() async {
      final core = await client.ensureInitialized();
      _checkReady();
      validateMutation?.call();
      return core.editKnowledge(
        request: management.KnowledgeEdit(
          action: action,
          kind: knowledgeKindToRust(record.kind),
          id: create ? null : record.id,
          expectedRevision: create ? 0 : record.revision,
          generation: readDataGeneration(),
          desired: action == management.KnowledgeEditAction.save
              ? knowledgeDraftToRust(record)
              : null,
        ),
      );
    }),
  );

  @override
  Future<KnowledgeReceipt> undoFromUi(String operationId) => _track(
    _mutate(() async {
      final result = await client.dispatch(
        native.AgentCommand(
          kind: native.CommandKind.undoKnowledge,
          targetId: operationId,
        ),
      );
      return result.knowledgeReceipt ??
          (throw const KnowledgeException(
            KnowledgeError.unavailable,
            'The native knowledge receipt is unavailable.',
          ));
    }),
  );

  Future<KnowledgeReceipt> _mutate(
    Future<view.ViewKnowledgeReceipt> Function() action,
  ) async {
    _checkReady();
    validateMutation?.call();
    final epoch = _epoch;
    try {
      final receipt = knowledgeReceiptFromRust(await action());
      if (!_disposed && epoch == _epoch) {
        _projectReceipt(receipt);
        _refreshInBackground();
      }
      return receipt;
    } catch (error) {
      throw knowledgeErrorFromRust(error);
    }
  }

  void _projectReceipt(KnowledgeReceipt receipt) {
    if (receipt.revision <= _fullRevision) return;
    _minimumReceiptRevision = math.max(
      _minimumReceiptRevision,
      receipt.revision,
    );
    for (final change in receipt.changes) {
      if (receipt.revision <=
          (_projectedRevisions[change.key] ?? _fullRevision)) {
        continue;
      }
      _projectedRevisions[change.key] = receipt.revision;
      final after = change.after;
      if (after == null) {
        _records.remove(change.key);
      } else {
        _records[change.key] = after;
      }
    }
    notifyListeners();
  }

  void ownerChanged() {
    if (!_disposed) notifyListeners();
  }

  void invalidateAfterDataBoundary() {
    _epoch++;
    _loaded = false;
    _loadFailure = null;
    _fullRevision = -1;
    _storageRevision = -1;
    _minimumReceiptRevision = 0;
    _records.clear();
    _originalDigests.clear();
    _projectedRevisions.clear();
    ownerChanged();
  }

  Future<void> freezeAndDrain() async {
    _frozen = true;
    ownerChanged();
    await waitForPendingOperations();
  }

  void resume() {
    if (_disposed) return;
    _frozen = false;
    ownerChanged();
    if (_loaded) _refreshInBackground();
  }

  Future<void> waitForPendingOperations() async {
    while (_tasks.isNotEmpty) {
      await Future.wait(_tasks.toList());
    }
  }

  Future<T> _track<T>(Future<T> task) {
    final settled = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tasks.add(settled);
    unawaited(settled.whenComplete(() => _tasks.remove(settled)));
    return task;
  }

  void _checkReady() {
    _checkAvailable();
    if (!ready) {
      throw const KnowledgeException(
        KnowledgeError.unavailable,
        'Knowledge is not ready.',
      );
    }
  }

  void _checkAvailable() {
    if (_disposed || _frozen || !(isAvailable?.call() ?? true)) {
      throw const KnowledgeException(
        KnowledgeError.unavailable,
        'Knowledge is unavailable while application data is changing.',
      );
    }
  }

  Never _conflict() => throw const KnowledgeException(
    KnowledgeError.conflict,
    'Knowledge changed while it was being read.',
  );

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
