import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_models.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/application/resource_contracts.dart';

void main() {
  AgentComposerReference resource({
    String id = 'course',
    String parent = 'table',
    String label = 'Algebra',
    String generation = 'data',
  }) => AgentComposerReference.resource(
    ref: ResourceRef(kind: ResourceKind.course, id: id, parentId: parent),
    datasetGeneration: generation,
    label: label,
  );

  SkillDescriptor skill({int revision = 1}) => SkillDescriptor.editable(
    id: 'review-week',
    title: 'Review week',
    summary: 'Plan the week',
    body: 'Use current resources.',
    revision: revision,
  );

  ConversationAttachment attachment({
    String name = 'week.pdf',
    String? digest,
  }) => ConversationAttachment(
    id: 'attachment',
    name: name,
    mediaType: 'application/pdf',
    byteLength: 10,
    digest: digest ?? 'a' * 64,
  );

  test('resource, skill and attachment references strictly round trip', () {
    final values = [
      resource(),
      AgentComposerReference.skill(skill: skill()),
      AgentComposerReference.attachment(
        attachment: attachment(),
        conversationId: 'chat',
      ),
    ];
    for (final value in values) {
      final restored = AgentComposerReference.fromJson(
        jsonDecode(jsonEncode(value.toJson())),
      );
      expect(restored.toJson(), value.toJson());
      expect(restored.stableKey, value.stableKey);
    }
    final original = resource();
    final json = original.toJson();
    (json['ref'] as Map)['id'] = 'changed';
    expect(original.resourceRef!.id, 'course');
  });

  test('stable identity ignores display labels and keeps scope boundaries', () {
    expect(resource().stableKey, resource(label: 'Renamed course').stableKey);
    expect(
      resource().stableKey,
      isNot(resource(parent: 'another-table').stableKey),
    );
    expect(
      resource().stableKey,
      isNot(resource(generation: 'restored-data').stableKey),
    );
    final oldSkill = AgentComposerReference.skill(skill: skill());
    final updatedSkill = AgentComposerReference.skill(
      skill: skill(revision: 2),
    );
    expect(oldSkill.stableKey, updatedSkill.stableKey);
    expect(oldSkill.skillVersion, isNot(updatedSkill.skillVersion));
    final first = AgentComposerReference.attachment(
      attachment: attachment(),
      conversationId: 'chat',
    );
    final renamed = AgentComposerReference.attachment(
      attachment: attachment(name: 'renamed.pdf'),
      conversationId: 'chat',
    );
    final foreign = AgentComposerReference.attachment(
      attachment: attachment(),
      conversationId: 'another-chat',
    );
    expect(first.stableKey, renamed.stableKey);
    expect(first.stableKey, isNot(foreign.stableKey));
  });

  test('resource parents and identity budgets match the domain contract', () {
    for (final kind in ResourceKind.values) {
      final child = const {
        ResourceKind.course,
        ResourceKind.event,
        ResourceKind.occurrence,
      }.contains(kind);
      final reference = AgentComposerReference.resource(
        ref: ResourceRef(
          kind: kind,
          id: 'id',
          parentId: child ? 'parent' : null,
        ),
        datasetGeneration: 'dataset',
        label: 'Name',
      );
      expect(
        AgentComposerReference.fromJson(reference.toJson()).resourceRef,
        reference.resourceRef,
      );
      expect(
        () => AgentComposerReference.resource(
          ref: ResourceRef(
            kind: kind,
            id: 'id',
            parentId: child ? null : 'parent',
          ),
          datasetGeneration: 'dataset',
          label: 'Name',
        ),
        throwsFormatException,
      );
    }
    expect(
      () => resource(id: 'i' * (ResourceQueryLimits.maxIdLength + 1)),
      throwsFormatException,
    );
    expect(
      () => resource(label: 'l' * (AgentComposerReference.maxLabelLength + 1)),
      throwsFormatException,
    );
    expect(() => resource(generation: 'g' * 129), throwsFormatException);
    expect(() => resource(id: ' '), throwsFormatException);
  });

  test('unknown and cross-kind payload fields never become references', () {
    final original = resource().toJson();
    final skillJson = AgentComposerReference.skill(skill: skill()).toJson();
    final attachmentJson = AgentComposerReference.attachment(
      attachment: attachment(),
      conversationId: 'chat',
    ).toJson();
    for (final value in <Object?>[
      null,
      [],
      {...original, 'kind': 'unknown'},
      {...original, 'permissions': 'full'},
      {...original, 'id': 'skill-id'},
      {...original, 'label': null},
      {...original, 'datasetGeneration': ''},
      {
        ...original,
        'ref': {
          'kind': 'course',
          'id': 'course',
          'parentId': 'table',
          'operationId': null,
        },
      },
      {
        ...original,
        'ref': {'kind': 'unknown', 'id': 'id'},
      },
      {...skillJson, 'version': '1.0'},
      {...skillJson, 'version': '01.0.0'},
      {...skillJson, 'contentSha256': 'not-a-digest'},
      {...skillJson, 'conversationId': 'chat'},
      {...attachmentJson, 'id': '../private'},
      {...attachmentJson, 'conversationId': ''},
      {...attachmentJson, 'digest': 'A' * 64},
      {...attachmentJson, 'ref': null},
    ]) {
      expect(
        () => AgentComposerReference.fromJson(value),
        throwsFormatException,
      );
    }
  });

  test(
    'reference lists are immutable, bounded and reject duplicate targets',
    () {
      final original = [resource()];
      final values = AgentComposerReference.validatedList(original);
      original.clear();
      expect(values.single.resourceRef!.id, 'course');
      expect(() => values.clear(), throwsUnsupportedError);
      expect(AgentComposerReference.decodeList(null), isEmpty);
      expect(
        AgentComposerReference.decodeList([resource().toJson()])
            .single
            .stableKey,
        resource().stableKey,
      );
      expect(
        () => AgentComposerReference.validatedList([
          resource(),
          resource(label: 'Different display'),
        ]),
        throwsFormatException,
      );
      expect(
        () => AgentComposerReference.validatedList([
          AgentComposerReference.skill(skill: skill()),
          AgentComposerReference.skill(skill: skill(revision: 2)),
        ]),
        throwsFormatException,
      );
      final maximum = List.generate(
        AgentComposerReference.maxPerMessage,
        (index) => resource(id: 'course-$index'),
      );
      expect(
        AgentComposerReference.validatedList(maximum),
        hasLength(AgentComposerReference.maxPerMessage),
      );
      expect(
        () => AgentComposerReference.validatedList([
          ...maximum,
          resource(id: 'extra'),
        ]),
        throwsFormatException,
      );
      expect(
        () => AgentComposerReference.decodeList(
          List.filled(
            AgentComposerReference.maxPerMessage + 1,
            resource().toJson(),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => AgentComposerReference.decodeList({}),
        throwsFormatException,
      );
    },
  );
}
