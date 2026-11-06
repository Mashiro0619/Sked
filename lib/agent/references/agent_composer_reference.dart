import 'dart:convert';

import '../../application/resource_contracts.dart';
import '../attachments/attachment_models.dart';
import '../skills/shared_skill_loader.dart';

enum AgentComposerReferenceKind { resource, skill, attachment }

/// An explicit input reference. Labels are display data and confer no identity,
/// execution authority, resource contents or attachment delivery guarantee.
class AgentComposerReference {
  const AgentComposerReference._({
    required this.kind,
    required this.label,
    this.resourceRef,
    this.datasetGeneration,
    this.skillId,
    this.skillVersion,
    this.skillSha256,
    this.attachmentId,
    this.conversationId,
    this.attachmentDigest,
  });

  factory AgentComposerReference.resource({
    required ResourceRef ref,
    required String datasetGeneration,
    required String label,
  }) => AgentComposerReference._(
    kind: AgentComposerReferenceKind.resource,
    label: label,
    resourceRef: ResourceRef(
      kind: ref.kind,
      id: ref.id,
      parentId: ref.parentId,
    ),
    datasetGeneration: datasetGeneration,
  )..validate();

  factory AgentComposerReference.skill({
    required SkillDescriptor skill,
    String? label,
  }) => AgentComposerReference._(
    kind: AgentComposerReferenceKind.skill,
    label: label ?? skill.title,
    skillId: skill.id,
    skillVersion: skill.version,
    skillSha256: skill.contentSha256,
  )..validate();

  factory AgentComposerReference.attachment({
    required ConversationAttachment attachment,
    required String conversationId,
  }) {
    attachment.validate();
    return AgentComposerReference._(
      kind: AgentComposerReferenceKind.attachment,
      label: attachment.name,
      attachmentId: attachment.id,
      conversationId: conversationId,
      attachmentDigest: attachment.digest,
    )..validate();
  }

  static const maxPerMessage = 20;
  static const maxLabelLength = 256;

  final AgentComposerReferenceKind kind;
  final String label;
  final ResourceRef? resourceRef;
  final String? datasetGeneration;
  final String? skillId;
  final String? skillVersion;
  final String? skillSha256;
  final String? attachmentId;
  final String? conversationId;
  final String? attachmentDigest;

  /// Same object across renames and content revisions. Dataset restoration and
  /// attachment ownership create a different identity namespace.
  String get stableKey => switch (kind) {
    AgentComposerReferenceKind.resource => jsonEncode([
      kind.name,
      datasetGeneration,
      resourceRef!.kind.name,
      resourceRef!.parentId,
      resourceRef!.id,
    ]),
    AgentComposerReferenceKind.skill => jsonEncode([kind.name, skillId]),
    AgentComposerReferenceKind.attachment => jsonEncode([
      kind.name,
      conversationId,
      attachmentId,
    ]),
  };

  void validate() {
    _text(label, maxLabelLength);
    switch (kind) {
      case AgentComposerReferenceKind.resource:
        final ref = resourceRef;
        if (ref == null) {
          throw const FormatException('Missing resource reference.');
        }
        _text(datasetGeneration, 128);
        _text(ref.id, ResourceQueryLimits.maxIdLength);
        final needsParent = const {
          ResourceKind.course,
          ResourceKind.event,
          ResourceKind.occurrence,
        }.contains(ref.kind);
        if (needsParent != (ref.parentId != null)) {
          throw const FormatException('Invalid resource parent scope.');
        }
        if (ref.parentId != null) {
          _text(ref.parentId, ResourceQueryLimits.maxIdLength);
        }
      case AgentComposerReferenceKind.skill:
        if (!RegExp(r'^[a-z][a-z0-9-]{0,127}$').hasMatch(_text(skillId, 128)) ||
            !RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')
                .hasMatch(_text(skillVersion, 128))) {
          throw const FormatException(
            'Invalid skill reference identity or version.',
          );
        }
        _digest(skillSha256);
      case AgentComposerReferenceKind.attachment:
        if (!validAttachmentId(_text(attachmentId, 128))) {
          throw const FormatException('Invalid attachment reference identity.');
        }
        _text(conversationId, 256);
        _digest(attachmentDigest);
    }
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'label': label,
    ...switch (kind) {
      AgentComposerReferenceKind.resource => {
        'ref': resourceRef!.toJson(),
        'datasetGeneration': datasetGeneration,
      },
      AgentComposerReferenceKind.skill => {
        'id': skillId,
        'version': skillVersion,
        'contentSha256': skillSha256,
      },
      AgentComposerReferenceKind.attachment => {
        'id': attachmentId,
        'conversationId': conversationId,
        'digest': attachmentDigest,
      },
    },
  };

  factory AgentComposerReference.fromJson(Object? value) {
    final json = _object(value);
    final kind = AgentComposerReferenceKind.values
        .where((kind) => kind.name == json['kind'])
        .firstOrNull;
    if (kind == null) {
      throw const FormatException('Unknown composer reference kind.');
    }
    _keys(json, {
      'kind',
      'label',
      ...switch (kind) {
        AgentComposerReferenceKind.resource => {'ref', 'datasetGeneration'},
        AgentComposerReferenceKind.skill => {'id', 'version', 'contentSha256'},
        AgentComposerReferenceKind.attachment => {
          'id',
          'conversationId',
          'digest',
        },
      },
    });
    final label = _text(json['label'], maxLabelLength);
    if (kind == AgentComposerReferenceKind.resource) {
      final ref = _object(json['ref']);
      _keys(ref, const {'kind', 'id', 'parentId'});
      final resourceKind = ResourceKind.values
          .where((kind) => kind.name == ref['kind'])
          .firstOrNull;
      if (resourceKind == null) {
        throw const FormatException('Unknown resource kind.');
      }
      return AgentComposerReference.resource(
        ref: ResourceRef(
          kind: resourceKind,
          id: _text(ref['id'], ResourceQueryLimits.maxIdLength),
          parentId: ref['parentId'] == null
              ? null
              : _text(ref['parentId'], ResourceQueryLimits.maxIdLength),
        ),
        datasetGeneration: _text(json['datasetGeneration'], 128),
        label: label,
      );
    }
    return AgentComposerReference._(
      kind: kind,
      label: label,
      skillId: kind == AgentComposerReferenceKind.skill
          ? _text(json['id'], 128)
          : null,
      skillVersion: kind == AgentComposerReferenceKind.skill
          ? _text(json['version'], 128)
          : null,
      skillSha256: kind == AgentComposerReferenceKind.skill
          ? _digest(json['contentSha256'])
          : null,
      attachmentId: kind == AgentComposerReferenceKind.attachment
          ? _text(json['id'], 128)
          : null,
      conversationId: kind == AgentComposerReferenceKind.attachment
          ? _text(json['conversationId'], 256)
          : null,
      attachmentDigest: kind == AgentComposerReferenceKind.attachment
          ? _digest(json['digest'])
          : null,
    )..validate();
  }

  static List<AgentComposerReference> decodeList(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > maxPerMessage) {
      throw const FormatException('Invalid composer reference list.');
    }
    return validatedList(value.map(AgentComposerReference.fromJson));
  }

  static List<AgentComposerReference> validatedList(
    Iterable<AgentComposerReference> references,
  ) {
    final result = <AgentComposerReference>[];
    final identities = <String>{};
    for (final reference in references) {
      reference.validate();
      if (result.length == maxPerMessage ||
          !identities.add(reference.stableKey)) {
        throw const FormatException(
          'Too many or duplicate composer references.',
        );
      }
      result.add(reference);
    }
    return List.unmodifiable(result);
  }
}

String _text(Object? value, int max) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw const FormatException('Invalid composer reference text.');
  }
  return value;
}

String _digest(Object? value) {
  final digest = _text(value, 64);
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
    throw const FormatException('Invalid composer reference digest.');
  }
  return digest;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a composer reference object.');
  }
  return value;
}

void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException('Unknown composer reference field.');
  }
}
