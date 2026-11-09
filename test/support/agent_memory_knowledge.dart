import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sked/agent/knowledge/agent_knowledge_editor_controller.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';

export 'package:sked/agent/knowledge/agent_knowledge_editor_controller.dart';

/// UI editor scenes with typed records and immediate in-memory receipts.
class MemoryKnowledgeController extends ChangeNotifier
    implements AgentKnowledgeEditorController {
  MemoryKnowledgeController({SkillAssetLoader? loadSkillAsset})
    : _loadAsset = loadSkillAsset ?? rootBundle.loadString;

  final SkillAssetLoader _loadAsset;
  final _originals = <String, KnowledgeRecord>{};
  final _records = <String, KnowledgeRecord>{};
  final _receipts = <String, KnowledgeReceipt>{};
  int _sequence = 0, _revision = 0;
  bool _loaded = false;
  bool available = true;
  Set<String> registeredTools = {};
  String generation = '';
  @override
  bool get ready => _loaded && available;
  @override
  bool get isLoaded => _loaded;
  List<KnowledgeRecord> get records => List.unmodifiable(_records.values);

  @override
  Future<void> initialize({bool reload = false}) async {
    if (_loaded && !reload) return;
    final loader = SharedSkillLoader(
      loadString: _loadAsset,
      registeredTools: registeredTools,
    );
    for (final entry in await loader.catalog()) {
      final skill = entry.skill;
      _originals['skill:${skill.id}'] = KnowledgeRecord(
        kind: KnowledgeKind.skill,
        id: skill.id,
        title: skill.title,
        summary: skill.summary,
        body: await _loadAsset('${SharedSkillLoader.assetRoot}${skill.asset}'),
        builtIn: true,
        usesOriginal: true,
        baseVersion: skill.version,
        baseSha256: skill.contentSha256,
        triggers: skill.triggers,
        sourceKinds: skill.sourceKinds,
        requiredTools: skill.requiredTools,
        optionalTools: skill.optionalTools,
      );
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  List<KnowledgeRecord> list(
    KnowledgeKind kind, {
    String query = '',
    bool includeDisabled = true,
  }) {
    final all = {..._originals, ..._records};
    final search = query.trim().toLowerCase();
    return List.unmodifiable(
      all.values.where(
        (record) =>
            record.kind == kind &&
            (includeDisabled || record.enabled) &&
            (search.isEmpty ||
                '${record.id} ${record.title} ${record.summary} ${record.body} ${record.sourceNote}'
                    .toLowerCase()
                    .contains(search)),
      ),
    );
  }

  @override
  Future<KnowledgeRecord> read(KnowledgeKind kind, String id) async {
    await initialize();
    final record =
        _records['${kind.name}:$id'] ?? _originals['${kind.name}:$id'];
    if (record == null) {
      throw const KnowledgeException(
        KnowledgeError.invalid,
        'The UI record does not exist.',
      );
    }
    return record;
  }

  @override
  List<String> missingTools(KnowledgeRecord record) => record.requiredTools
      .where((tool) => !registeredTools.contains(tool))
      .toList();
  @override
  bool originalChanged(KnowledgeRecord record) =>
      record.builtIn &&
      !record.usesOriginal &&
      _originals[record.key]?.baseSha256 != record.baseSha256;
  @override
  bool needsRecheck(KnowledgeRecord record) =>
      record.needsRecheck(generation, DateTime.now()) ||
      record.references.isNotEmpty;

  KnowledgeRecord newRecord(
    KnowledgeKind kind, {
    required String title,
    required String body,
    String summary = '',
    String sourceNote = '',
  }) => KnowledgeRecord(
    kind: kind,
    id: '${kind == KnowledgeKind.skill ? 'custom' : 'memory'}-ui-${++_sequence}',
    title: title,
    body: body,
    summary: summary,
    sourceNote: sourceNote,
  );

  Future<KnowledgeReceipt> seed(KnowledgeRecord record) => saveDraft(
    record,
    create: !_records.containsKey(record.key) && !record.builtIn,
  );

  @override
  Future<KnowledgeReceipt> saveDraft(
    KnowledgeRecord draft, {
    bool create = false,
  }) async {
    final before = _records[draft.key] ?? _originals[draft.key];
    if (before != null && before.revision != draft.revision) _conflict();
    var after = draft;
    final original = _originals[draft.key];
    if (original != null &&
        draft.usesOriginal &&
        draft.body != original.body &&
        draft.body.isNotEmpty) {
      after = draft.copyWith(usesOriginal: false);
    }
    return _publish(draft.key, before, after);
  }

  @override
  Future<KnowledgeReceipt> delete(KnowledgeRecord record) async {
    final before = _records[record.key];
    if (before?.revision != record.revision) _conflict();
    return _publish(record.key, before, null);
  }

  @override
  Future<KnowledgeReceipt> restoreOriginal(KnowledgeRecord record) async {
    final original = _originals[record.key];
    if (original == null) {
      throw const KnowledgeException(
        KnowledgeError.invalid,
        'No original UI record.',
      );
    }
    final before = _records[record.key] ?? original;
    if (before.revision != record.revision) _conflict();
    return _publish(
      record.key,
      before,
      original.copyWith(enabled: record.enabled),
    );
  }

  @override
  Future<KnowledgeReceipt> undoFromUi(String operationId) async {
    final receipt = _receipts[operationId]!;
    final change = receipt.changes.single;
    return _publish(
      change.key,
      _records[change.key],
      change.before,
      inverseOf: operationId,
    );
  }

  KnowledgeReceipt _publish(
    String key,
    KnowledgeRecord? before,
    KnowledgeRecord? after, {
    String? inverseOf,
  }) {
    _revision++;
    final saved = after?.copyWith(revision: _revision);
    if (saved == null) {
      _records.remove(key);
    } else {
      _records[key] = saved;
    }
    final operation = 'ui-knowledge-${++_sequence}';
    final receipt = KnowledgeReceipt(
      operationId: operation,
      digest: knowledgeDigest(operation),
      revision: _revision,
      inverseOf: inverseOf,
      changes: [
        KnowledgeChange(
          key: key,
          expectedRevision: before?.revision ?? 0,
          before: before,
          after: saved,
        ),
      ],
    );
    _receipts[operation] = receipt;
    notifyListeners();
    return receipt;
  }

  Future<void> waitForPendingWrites() async {}
  Never _conflict() => throw const KnowledgeException(
    KnowledgeError.conflict,
    'The UI record changed.',
  );
}
