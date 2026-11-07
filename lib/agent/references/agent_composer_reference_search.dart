import '../../application/resource_queries.dart';
import '../../models/app_data.dart';
import '../conversations/conversation_models.dart';
import '../skills/shared_skill_loader.dart';
import 'agent_composer_reference.dart';

enum AgentComposerReferenceGroup {
  timetable,
  course,
  periodTimeSet,
  calendar,
  event,
  skill,
  attachment,
}

class AgentComposerReferenceCandidate {
  const AgentComposerReferenceCandidate({
    required this.reference,
    this.parentLabel,
    this.skillStatus,
  });

  final AgentComposerReference reference;
  final String? parentLabel;
  final SkillStatus? skillStatus;

  bool get isSelectable =>
      skillStatus == null ||
      skillStatus == SkillStatus.available ||
      skillStatus == SkillStatus.loaded;
}

class AgentComposerReferenceSearchGroup {
  AgentComposerReferenceSearchGroup._({
    required this.kind,
    required this.offset,
    required Iterable<AgentComposerReferenceCandidate> candidates,
    required this.totalMatches,
  }) : candidates = List.unmodifiable(candidates);

  final AgentComposerReferenceGroup kind;
  final int offset;
  final List<AgentComposerReferenceCandidate> candidates;
  final int totalMatches;

  bool get hasMore => offset + candidates.length < totalMatches;
  int? get nextOffset => hasMore ? offset + candidates.length : null;
}

class AgentComposerReferenceSearchResult {
  AgentComposerReferenceSearchResult._(
    Iterable<AgentComposerReferenceSearchGroup> groups,
  ) : groups = List.unmodifiable(groups);

  final List<AgentComposerReferenceSearchGroup> groups;
  int get totalCount =>
      groups.fold(0, (count, group) => count + group.candidates.length);

  AgentComposerReferenceSearchGroup group(AgentComposerReferenceGroup kind) =>
      groups.singleWhere((group) => group.kind == kind);
}

enum AgentComposerReferenceStatus { current, notFound, stale, unavailable }

class AgentComposerReferenceValidation {
  const AgentComposerReferenceValidation._(
    this.status, [
    this.currentReference,
  ]);

  final AgentComposerReferenceStatus status;
  final AgentComposerReference? currentReference;
  bool get isCurrent => status == AgentComposerReferenceStatus.current;
}

/// Searches one committed resource snapshot and one frozen skill catalog.
/// Create a new service when the host publishes another snapshot. Search and
/// validation never change selection, load a skill body or read attachment bytes.
class AgentComposerReferenceSearch {
  AgentComposerReferenceSearch({
    required AppData snapshot,
    required String datasetGeneration,
    required int snapshotRevision,
    required this.skills,
    required this.conversation,
  }) : _resources = ResourceQueries(
         snapshot: _resourceSnapshot(snapshot),
         datasetGeneration: datasetGeneration,
         snapshotRevision: snapshotRevision,
       );

  static const maxPerGroup = 20;
  final SharedSkillLoader skills;
  final AgentConversation conversation;
  final ResourceQueries _resources;

  Future<AgentComposerReferenceSearchResult> search(
    String query, {
    int limitPerGroup = 8,
    Map<AgentComposerReferenceGroup, int> offsets = const {},
  }) async {
    if (limitPerGroup < 1 ||
        limitPerGroup > maxPerGroup ||
        offsets.values.any((offset) => offset < 0)) {
      throw const FormatException('Invalid composer reference search bounds.');
    }
    final requestedOffsets = Map<AgentComposerReferenceGroup, int>.unmodifiable(
      offsets,
    );
    final normalized = query.trim();
    final groups = <AgentComposerReferenceSearchGroup>[];
    for (final kind in const [
      ResourceKind.timetable,
      ResourceKind.course,
      ResourceKind.periodTimeSet,
      ResourceKind.calendar,
      ResourceKind.event,
    ]) {
      final group = AgentComposerReferenceGroup.values.byName(kind.name);
      groups.add(
        _resourceGroup(
          kind,
          normalized,
          limitPerGroup,
          requestedOffsets[group] ?? 0,
        ),
      );
    }
    final catalog = normalized.isEmpty
        ? (await skills.catalog()).toList()
        : await skills.search(userRequest: normalized, limit: null);
    if (normalized.isEmpty) {
      catalog.sort((a, b) => a.skill.id.compareTo(b.skill.id));
    }
    final skillOffset =
        requestedOffsets[AgentComposerReferenceGroup.skill] ?? 0;
    groups.add(
      AgentComposerReferenceSearchGroup._(
        kind: AgentComposerReferenceGroup.skill,
        offset: skillOffset,
        totalMatches: catalog.length,
        candidates: catalog
            .skip(skillOffset)
            .take(limitPerGroup)
            .map(
              (entry) => AgentComposerReferenceCandidate(
                reference: AgentComposerReference.skill(
                  skill: entry.skill,
                  label: _label(entry.skill.title, entry.skill.id),
                ),
                skillStatus: entry.status,
              ),
            ),
      ),
    );
    final attachmentQuery = normalized.toLowerCase();
    final attachments =
        conversation.attachments
            .where(
              (attachment) =>
                  attachment.name.toLowerCase().contains(attachmentQuery),
            )
            .toList()
          ..sort((a, b) {
            final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return byName == 0 ? a.id.compareTo(b.id) : byName;
          });
    final attachmentOffset =
        requestedOffsets[AgentComposerReferenceGroup.attachment] ?? 0;
    groups.add(
      AgentComposerReferenceSearchGroup._(
        kind: AgentComposerReferenceGroup.attachment,
        offset: attachmentOffset,
        totalMatches: attachments.length,
        candidates: attachments
            .skip(attachmentOffset)
            .take(limitPerGroup)
            .map(
              (attachment) => AgentComposerReferenceCandidate(
                reference: AgentComposerReference.attachment(
                  attachment: attachment,
                  conversationId: conversation.id,
                ),
              ),
            ),
      ),
    );
    return AgentComposerReferenceSearchResult._(groups);
  }

  AgentComposerReferenceSearchGroup _resourceGroup(
    ResourceKind kind,
    String query,
    int limit,
    int offset,
  ) {
    final candidates = <AgentComposerReferenceCandidate>[];
    final pageSize = (offset + limit)
        .clamp(1, ResourceQueryLimits.maxPageItems)
        .toInt();
    String? cursor;
    var position = 0;
    late int total;
    do {
      final page = _resources.query(
        ResourceQuery(
          kind: kind,
          search: query,
          fields: {_labelField(kind)},
          limit: pageSize,
          cursor: cursor,
        ),
      );
      total = page.totalMatches;
      for (final record in page.items) {
        if (position >= offset && candidates.length < limit) {
          final parentKind = switch (kind) {
            ResourceKind.course => ResourceKind.timetable,
            ResourceKind.event => ResourceKind.calendar,
            _ => null,
          };
          final parent = parentKind == null
              ? null
              : _resources.get(
                  ResourceRef(kind: parentKind, id: record.ref.parentId!),
                  fields: const {'name'},
                );
          candidates.add(
            AgentComposerReferenceCandidate(
              reference: _resourceReference(record),
              parentLabel: parent == null
                  ? null
                  : _label(parent.values['name'], parent.ref.id),
            ),
          );
        }
        position++;
      }
      cursor = page.nextCursor;
    } while (cursor != null && position < offset + limit && offset < total);
    return AgentComposerReferenceSearchGroup._(
      kind: AgentComposerReferenceGroup.values.byName(kind.name),
      offset: offset,
      candidates: candidates,
      totalMatches: total,
    );
  }

  Future<AgentComposerReferenceValidation> validate(
    AgentComposerReference reference,
  ) async {
    reference.validate();
    switch (reference.kind) {
      case AgentComposerReferenceKind.resource:
        if (reference.datasetGeneration != _resources.datasetGeneration) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.stale,
          );
        }
        final ref = reference.resourceRef!;
        // Selecting an occurrence needs an explicit date window. The current
        // composer offers persistent resources and leaves instance lookup to tools.
        if (ref.kind == ResourceKind.occurrence) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.unavailable,
          );
        }
        try {
          final current = _resources.get(ref, fields: {_labelField(ref.kind)});
          return AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.current,
            _resourceReference(current),
          );
        } on ResourceQueryException catch (error) {
          if (error.code == ResourceQueryErrorCode.notFound) {
            return const AgentComposerReferenceValidation._(
              AgentComposerReferenceStatus.notFound,
            );
          }
          if (error.code == ResourceQueryErrorCode.invalidSnapshot) {
            return const AgentComposerReferenceValidation._(
              AgentComposerReferenceStatus.unavailable,
            );
          }
          rethrow;
        }
      case AgentComposerReferenceKind.skill:
        final matches = (await skills.catalog())
            .where((entry) => entry.skill.id == reference.skillId)
            .toList();
        if (matches.isEmpty) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.notFound,
          );
        }
        if (matches.length != 1) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.unavailable,
          );
        }
        final entry = matches.single;
        if (entry.skill.version != reference.skillVersion ||
            entry.skill.contentSha256 != reference.skillSha256) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.stale,
          );
        }
        if (entry.status != SkillStatus.available &&
            entry.status != SkillStatus.loaded) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.unavailable,
          );
        }
        return AgentComposerReferenceValidation._(
          AgentComposerReferenceStatus.current,
          AgentComposerReference.skill(
            skill: entry.skill,
            label: _label(entry.skill.title, entry.skill.id),
          ),
        );
      case AgentComposerReferenceKind.attachment:
        if (reference.conversationId != conversation.id) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.stale,
          );
        }
        final matches = conversation.attachments
            .where((attachment) => attachment.id == reference.attachmentId)
            .toList();
        if (matches.isEmpty) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.notFound,
          );
        }
        if (matches.length != 1) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.unavailable,
          );
        }
        final attachment = matches.single;
        if (attachment.digest != reference.attachmentDigest) {
          return const AgentComposerReferenceValidation._(
            AgentComposerReferenceStatus.stale,
          );
        }
        return AgentComposerReferenceValidation._(
          AgentComposerReferenceStatus.current,
          AgentComposerReference.attachment(
            attachment: attachment,
            conversationId: conversation.id,
          ),
        );
    }
  }

  AgentComposerReference _resourceReference(ResourceRecord record) =>
      AgentComposerReference.resource(
        ref: record.ref,
        datasetGeneration: _resources.datasetGeneration,
        label: _label(
          record.values[_labelField(record.ref.kind)],
          record.ref.id,
        ),
      );
}

String _labelField(ResourceKind kind) =>
    kind == ResourceKind.event ? 'title' : 'name';

AppData _resourceSnapshot(AppData source) => source.copyWith(
  studentMode: source.studentMode.copyWith(
    timetables: List.unmodifiable(
      source.studentMode.timetables.map(
        (table) => table.copyWith(courses: List.unmodifiable(table.courses)),
      ),
    ),
    periodTimeSets: List.unmodifiable(source.studentMode.periodTimeSets),
  ),
  generalMode: source.generalMode.copyWith(
    schedules: List.unmodifiable(
      source.generalMode.schedules.map(
        (calendar) =>
            calendar.copyWith(events: List.unmodifiable(calendar.events)),
      ),
    ),
  ),
);

String _label(Object? value, String fallback) {
  final text = value is String && value.trim().isNotEmpty
      ? value.trim()
      : fallback;
  return text;
}
