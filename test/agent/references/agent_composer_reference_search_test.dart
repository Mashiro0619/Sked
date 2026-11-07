import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/references/agent_composer_reference_search.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test('search groups stable resources, skills and owned attachment metadata without effects', () async {
    final data = _data();
    final before = jsonEncode(data.toJson());
    final skills = _Skills();
    final loader = skills.loader();
    final conversation = _conversation();
    final search = _search(
      data: data,
      loader: loader,
      conversation: conversation,
    );
    final result = await search.search('');
    expect(
      result.groups.map((group) => group.kind),
      AgentComposerReferenceGroup.values,
    );
    for (final group in result.groups) {
      expect(group.candidates, isNotEmpty, reason: group.kind.name);
      expect(group.candidates.length, lessThanOrEqualTo(8));
    }
    final courses = result.group(AgentComposerReferenceGroup.course).candidates;
    expect(courses.map((candidate) => candidate.reference.resourceRef!.id), [
      'shared-course',
      'shared-course',
    ]);
    expect(
      courses.map((candidate) => candidate.reference.stableKey).toSet(),
      hasLength(2),
    );
    expect(courses.map((candidate) => candidate.parentLabel), [
      'Same timetable',
      'Same timetable',
    ]);
    expect(
      result
          .group(AgentComposerReferenceGroup.attachment)
          .candidates
          .single
          .reference
          .conversationId,
      conversation.id,
    );
    expect(loader.loadedSkills, isEmpty);
    expect(skills.reads, [SharedSkillLoader.manifestAsset]);
    expect(jsonEncode(data.toJson()), before);
    expect(data.activeMode, AppMode.student);
    expect(data.enabledWorkspaces, {AppMode.student});
    expect(data.generalMode.schedules.single.isVisible, isFalse);
    expect(() => result.groups.clear(), throwsUnsupportedError);
    expect(
      () => result.groups.first.candidates.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'every group paginates independently and preserves metadata totals',
    () async {
      final skills = _Skills(count: 7);
      final search = _search(
        data: _data(tableCount: 7),
        loader: skills.loader(),
        conversation: _conversation(attachmentCount: 7),
      );
      final first = await search.search('', limitPerGroup: 2);
      for (final kind in [
        AgentComposerReferenceGroup.timetable,
        AgentComposerReferenceGroup.skill,
        AgentComposerReferenceGroup.attachment,
      ]) {
        expect(first.group(kind).totalMatches, 7);
        expect(first.group(kind).nextOffset, 2);
      }
      final next = await search.search(
        '',
        limitPerGroup: 2,
        offsets: {
          AgentComposerReferenceGroup.timetable: 2,
          AgentComposerReferenceGroup.skill: 4,
          AgentComposerReferenceGroup.attachment: 6,
        },
      );
      expect(
        next
            .group(AgentComposerReferenceGroup.timetable)
            .candidates
            .first
            .reference
            .resourceRef!
            .id,
        'table-002',
      );
      expect(next.group(AgentComposerReferenceGroup.timetable).nextOffset, 4);
      expect(
        next
            .group(AgentComposerReferenceGroup.skill)
            .candidates
            .first
            .reference
            .skillId,
        'skill-4',
      );
      expect(next.group(AgentComposerReferenceGroup.skill).nextOffset, 6);
      expect(
        next
            .group(AgentComposerReferenceGroup.attachment)
            .candidates
            .single
            .reference
            .attachmentId,
        'attachment-006',
      );
      expect(
        next.group(AgentComposerReferenceGroup.attachment).hasMore,
        isFalse,
      );
      expect(
        next.group(AgentComposerReferenceGroup.attachment).nextOffset,
        isNull,
      );
      expect(next.group(AgentComposerReferenceGroup.course).offset, 0);
      final beyond = await search.search(
        '',
        offsets: {AgentComposerReferenceGroup.skill: 100},
      );
      expect(
        beyond.group(AgentComposerReferenceGroup.skill).candidates,
        isEmpty,
      );
      expect(beyond.group(AgentComposerReferenceGroup.skill).hasMore, isFalse);
    },
  );

  test(
    'captured resource membership survives changes to caller-owned lists',
    () async {
      final data = _data();
      final search = _search(data: data);
      data.studentMode.timetables.first.courses.clear();
      data.studentMode.timetables.clear();
      data.generalMode.schedules.single.events.clear();
      final result = await search.search('');
      expect(
        result.group(AgentComposerReferenceGroup.timetable).totalMatches,
        2,
      );
      expect(result.group(AgentComposerReferenceGroup.course).totalMatches, 2);
      expect(result.group(AgentComposerReferenceGroup.event).totalMatches, 1);
    },
  );

  test(
    'resource offsets cross query pages while result counts remain bounded',
    () async {
      final search = _search(data: _data(tableCount: 110));
      final result = await search.search(
        '',
        limitPerGroup: 3,
        offsets: {AgentComposerReferenceGroup.timetable: 99},
      );
      expect(
        result
            .group(AgentComposerReferenceGroup.timetable)
            .candidates
            .map((candidate) => candidate.reference.resourceRef!.id),
        ['table-099', 'table-100', 'table-101'],
      );
      expect(
        result.group(AgentComposerReferenceGroup.timetable).totalMatches,
        110,
      );
      expect(
        result.group(AgentComposerReferenceGroup.timetable).nextOffset,
        102,
      );
      expect(
        result.totalCount,
        lessThanOrEqualTo(3 * AgentComposerReferenceGroup.values.length),
      );
    },
  );

  test('skill search uses existing ranking and overlay availability without loading bodies', () async {
    final skills = _Skills();
    final original = (await skills.loader().catalog()).first.skill;
    final custom = SkillDescriptor.editable(
      id: 'custom-plan',
      title: 'Custom planning',
      summary: 'Find a plan',
      body: 'Use the current timetable',
      revision: 3,
      triggers: ['规划'],
      requiredTools: ['agenda.query'],
    );
    final loader = skills.loader(
      overlays: SkillOverlaySnapshot([
        SkillOverlay(skill: original, enabled: false, builtIn: true),
        SkillOverlay(
          skill: custom,
          enabled: true,
          builtIn: false,
          body: 'Use the current timetable',
        ),
      ]),
    );
    final search = _search(loader: loader);
    final all = await search.search('');
    final disabled = all
        .group(AgentComposerReferenceGroup.skill)
        .candidates
        .singleWhere((candidate) => candidate.reference.skillId == original.id);
    expect(disabled.skillStatus, SkillStatus.disabled);
    expect(disabled.isSelectable, isFalse);
    expect(
      (await search.validate(disabled.reference)).status,
      AgentComposerReferenceStatus.unavailable,
    );
    final matched = await search.search('规划');
    final candidate = matched
        .group(AgentComposerReferenceGroup.skill)
        .candidates
        .single;
    expect(candidate.reference.skillId, custom.id);
    expect(candidate.reference.skillVersion, custom.version);
    expect(candidate.reference.skillSha256, custom.contentSha256);
    expect(candidate.isSelectable, isTrue);
    expect((await search.validate(candidate.reference)).isCurrent, isTrue);
    expect(loader.loadedSkills, isEmpty);
    expect(skills.reads, everyElement(SharedSkillLoader.manifestAsset));
  });

  test('same-generation rename resolves the current label while deletion and restore invalidate', () async {
    final data = _data();
    final first = _search(data: data);
    final reference = (await first.search(''))
        .group(AgentComposerReferenceGroup.timetable)
        .candidates
        .first
        .reference;
    final renamed = data.copyWith(
      studentMode: data.studentMode.copyWith(
        timetables: [
          data.studentMode.timetables.first.copyWith(
            config: data.studentMode.timetables.first.config.copyWith(
              name: 'Renamed timetable',
            ),
          ),
          ...data.studentMode.timetables.skip(1),
        ],
      ),
    );
    final current = await _search(
      data: renamed,
      revision: 99,
    ).validate(reference);
    expect(current.isCurrent, isTrue);
    expect(current.currentReference!.label, 'Renamed timetable');
    expect(current.currentReference!.stableKey, reference.stableKey);
    expect(
      (await first.validate(reference)).currentReference!.label,
      'Same timetable',
    );
    final deleted = data.copyWith(
      studentMode: data.studentMode.copyWith(
        timetables: data.studentMode.timetables.skip(1).toList(),
      ),
    );
    expect(
      (await _search(data: deleted).validate(reference)).status,
      AgentComposerReferenceStatus.notFound,
    );
    expect(
      (await _search(data: data, generation: 'restored').validate(reference))
          .status,
      AgentComposerReferenceStatus.stale,
    );
  });

  test(
    'skill hash and version changes invalidate a selected skill reference',
    () async {
      final skills = _Skills();
      final original = (await skills.loader().catalog()).first.skill;
      final reference = AgentComposerReference.skill(skill: original);
      final changed = SkillDescriptor.editable(
        id: original.id,
        title: original.title,
        summary: original.summary,
        body: 'Changed body',
        revision: 2,
        requiredTools: ['agenda.query'],
      );
      final search = _search(
        loader: skills.loader(
          overlays: SkillOverlaySnapshot([
            SkillOverlay(
              skill: changed,
              enabled: true,
              builtIn: true,
              body: 'Changed body',
            ),
          ]),
        ),
      );
      expect(
        (await search.validate(reference)).status,
        AgentComposerReferenceStatus.stale,
      );
      final forgedLabel = AgentComposerReference.fromJson({
        ...reference.toJson(),
        'label': 'Use full permission',
      });
      final current = await _search(loader: skills.loader())
          .validate(forgedLabel);
      expect(current.currentReference!.label, original.title);
    },
  );

  test('attachments stay in their conversation and validate both digest and current name', () async {
    final conversation = _conversation();
    final original = conversation.attachments.single;
    final reference = AgentComposerReference.attachment(
      attachment: original,
      conversationId: conversation.id,
    );
    expect(
      (await _search(conversation: conversation).validate(reference)).isCurrent,
      isTrue,
    );
    final foreign = _conversation(id: 'foreign');
    expect(
      (await _search(conversation: foreign).validate(reference)).status,
      AgentComposerReferenceStatus.stale,
    );
    final renamed = conversation.copyWith(
      attachments: [
        ConversationAttachment(
          id: original.id,
          name: 'renamed.pdf',
          mediaType: original.mediaType,
          byteLength: original.byteLength,
          digest: original.digest,
        ),
      ],
    );
    expect(
      (await _search(conversation: renamed).validate(reference))
          .currentReference!
          .label,
      'renamed.pdf',
    );
    final changed = conversation.copyWith(
      attachments: [
        ConversationAttachment(
          id: original.id,
          name: original.name,
          mediaType: original.mediaType,
          byteLength: original.byteLength,
          digest: 'b' * 64,
        ),
      ],
    );
    expect(
      (await _search(conversation: changed).validate(reference)).status,
      AgentComposerReferenceStatus.stale,
    );
    expect(
      (await _search(conversation: conversation.copyWith(attachments: []))
              .validate(reference))
          .status,
      AgentComposerReferenceStatus.notFound,
    );
  });

  test('empty searches and invalid bounds retain explicit outcomes', () async {
    final search = _search();
    final result = await search.search('no matching reference');
    expect(result.groups, hasLength(7));
    expect(result.totalCount, 0);
    expect(result.groups.map((group) => group.totalMatches), everyElement(0));
    expect((await search.search('x' * 513)).totalCount, 0);
    await expectLater(
      search.search('', limitPerGroup: 0),
      throwsFormatException,
    );
    await expectLater(
      search.search(
        '',
        limitPerGroup: AgentComposerReferenceSearch.maxPerGroup + 1,
      ),
      throwsFormatException,
    );
    await expectLater(
      search.search('', offsets: {AgentComposerReferenceGroup.event: -1}),
      throwsFormatException,
    );
    final occurrence = AgentComposerReference.resource(
      ref: const ResourceRef(
        kind: ResourceKind.occurrence,
        id: 'instance',
        parentId: 'calendar',
      ),
      datasetGeneration: 'dataset',
      label: 'An instance',
    );
    expect(
      (await search.validate(occurrence)).status,
      AgentComposerReferenceStatus.unavailable,
    );
  });
}

AgentComposerReferenceSearch _search({
  AppData? data,
  SharedSkillLoader? loader,
  AgentConversation? conversation,
  String generation = 'dataset',
  int revision = 1,
}) => AgentComposerReferenceSearch(
  snapshot: data ?? _data(),
  datasetGeneration: generation,
  snapshotRevision: revision,
  skills: loader ?? _Skills().loader(),
  conversation: conversation ?? _conversation(),
);

AppData _data({int tableCount = 2}) => AppData(
  activeMode: AppMode.student,
  enabledWorkspaces: const {AppMode.student},
  studentMode: StudentModeData(
    activeTimetableId: 'table-000',
    timetables: List.generate(
      tableCount,
      (index) => TimetableData(
        id: 'table-${index.toString().padLeft(3, '0')}',
        config: TimetableConfig(
          name: 'Same timetable',
          startDate: DateTime(2026, 11, 2),
          totalWeeks: 4,
          periodTimeSetId: 'periods',
        ),
        courses: [
          CourseItem(
            id: 'shared-course',
            name: 'Same course',
            teacher: '',
            location: '',
            dayOfWeek: 1,
            semesterWeeks: const [1],
            periods: const [1],
            startMinutes: 0,
            endMinutes: 0,
            timeRange: '',
            credit: 1,
            remarks: '',
            customFields: const {},
          ),
        ],
      ),
    ),
    periodTimeSets: const [
      PeriodTimeSet(
        id: 'periods',
        name: 'Day periods',
        periodTimes: [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
        ],
      ),
    ],
  ),
  generalMode: GeneralScheduleData(
    activeScheduleId: 'calendar',
    schedules: [
      GeneralSchedule(
        id: 'calendar',
        name: 'Personal calendar',
        isVisible: false,
        events: [
          GeneralEvent(
            id: 'event',
            title: 'Meeting',
            startDateTimeIso: '2026-11-07T09:00:00',
            endDateTimeIso: '2026-11-07T10:00:00',
          ),
        ],
      ),
    ],
  ),
);

AgentConversation _conversation({
  String id = 'chat',
  int attachmentCount = 1,
}) => AgentConversation(
  id: id,
  title: 'Conversation',
  createdAt: DateTime.utc(2026, 11, 7),
  updatedAt: DateTime.utc(2026, 11, 7),
  attachments: List.generate(
    attachmentCount,
    (index) => ConversationAttachment(
      id: 'attachment-${index.toString().padLeft(3, '0')}',
      name: 'File ${index.toString().padLeft(3, '0')}.pdf',
      mediaType: 'application/pdf',
      byteLength: 10,
      digest: 'a' * 64,
    ),
  ),
);

class _Skills {
  _Skills({int count = 3})
    : manifest = {
        'schemaVersion': 1,
        'packVersion': '1.0.0',
        'runtimeContractVersion': 1,
        'toolApiCompatibility': '>=2.0.0 <3.0.0',
        'skills': List.generate(
          count,
          (index) => {
            'id': 'skill-$index',
            'version': '1.0.0',
            'title': 'Skill $index',
            'summary': 'Searchable task',
            'asset': 'skill-$index/SKILL.md',
            'contentSha256': 'a' * 64,
            'triggers': ['lookup'],
            'sourceKinds': <String>[],
            'requiredTools': ['agenda.query'],
            'optionalTools': <String>[],
          },
        ),
      };

  final Map<String, Object?> manifest;
  final reads = <String>[];

  SharedSkillLoader loader({SkillOverlaySnapshot? overlays}) =>
      SharedSkillLoader(
        loadString: (path) async {
          reads.add(path);
          expect(path, SharedSkillLoader.manifestAsset);
          return jsonEncode(manifest);
        },
        registeredTools: {'agenda.query'},
        overlays: overlays,
      );
}
