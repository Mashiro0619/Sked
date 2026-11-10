import 'package:flutter/foundation.dart';

const agentUiContributionContractVersion = 1;

enum AgentUiContributionSlot { toolResult, settings, inspectorSection }

enum AgentUiContributionLifetime { native, profile }

/// A declaration selects a compiled renderer; it contains no executable UI.
@immutable
class AgentUiContribution {
  const AgentUiContribution({
    required this.id,
    required this.slot,
    required this.rendererId,
    required this.order,
  });

  final String id;
  final AgentUiContributionSlot slot;
  final String rendererId;
  final int order;

  @override
  bool operator ==(Object other) =>
      other is AgentUiContribution &&
      id == other.id &&
      slot == other.slot &&
      rendererId == other.rendererId &&
      order == other.order;

  @override
  int get hashCode => Object.hash(id, slot, rendererId, order);
}

@immutable
class AgentUiContributionOwnerSnapshot {
  AgentUiContributionOwnerSnapshot({
    required this.instanceId,
    required this.generation,
    required Iterable<AgentUiContribution> contributions,
  }) : contributions = List.unmodifiable(contributions);

  final String instanceId;
  final int generation;
  final List<AgentUiContribution> contributions;
}

/// A complete native inventory. The core session token is supplied separately
/// by the application and cannot be replaced by a late inventory response.
@immutable
class AgentUiContributionSnapshot {
  AgentUiContributionSnapshot({
    required this.contractVersion,
    required this.revision,
    required Iterable<AgentUiContributionOwnerSnapshot> owners,
  }) : owners = List.unmodifiable(owners);

  final int contractVersion;
  final int revision;
  final List<AgentUiContributionOwnerSnapshot> owners;
}

@immutable
class AgentUiContributionOwner {
  const AgentUiContributionOwner({
    required this.lifetime,
    required this.sessionToken,
    required this.instanceId,
    required this.generation,
  });

  final AgentUiContributionLifetime lifetime;
  final Object sessionToken;
  final String instanceId;
  final int generation;

  bool sameOwner(AgentUiContributionOwner other) =>
      lifetime == other.lifetime &&
      identical(sessionToken, other.sessionToken) &&
      instanceId == other.instanceId &&
      generation == other.generation;
}

abstract final class AgentUiRendererIds {
  static const operation = 'sked.tool.operation';
  static const changes = 'sked.inspector.changes';
  static const plan = 'sked.inspector.plan';
  static const attachments = 'sked.inspector.attachments';
  static const context = 'sked.inspector.context';
  static const connection = 'sked.settings.connection';
  static const preferences = 'sked.settings.preferences';
  static const skills = 'sked.settings.skills';
  static const memories = 'sked.settings.memories';
  static const files = 'sked.settings.files';
}

const defaultAgentSettingsContributions = [
  AgentUiContribution(
    id: AgentUiRendererIds.connection,
    slot: AgentUiContributionSlot.settings,
    rendererId: AgentUiRendererIds.connection,
    order: 0,
  ),
  AgentUiContribution(
    id: AgentUiRendererIds.preferences,
    slot: AgentUiContributionSlot.settings,
    rendererId: AgentUiRendererIds.preferences,
    order: 10,
  ),
  AgentUiContribution(
    id: AgentUiRendererIds.skills,
    slot: AgentUiContributionSlot.settings,
    rendererId: AgentUiRendererIds.skills,
    order: 20,
  ),
  AgentUiContribution(
    id: AgentUiRendererIds.memories,
    slot: AgentUiContributionSlot.settings,
    rendererId: AgentUiRendererIds.memories,
    order: 30,
  ),
  AgentUiContribution(
    id: AgentUiRendererIds.files,
    slot: AgentUiContributionSlot.settings,
    rendererId: AgentUiRendererIds.files,
    order: 40,
  ),
];

/// Standalone inspector widgets keep their previous built-in presentation when
/// no application registry is supplied. Production hosts use the native list.
const defaultAgentInspectorContributions = [
  AgentUiContribution(
    id: AgentUiRendererIds.changes,
    slot: AgentUiContributionSlot.inspectorSection,
    rendererId: AgentUiRendererIds.changes,
    order: 0,
  ),
  AgentUiContribution(
    id: AgentUiRendererIds.plan,
    slot: AgentUiContributionSlot.inspectorSection,
    rendererId: AgentUiRendererIds.plan,
    order: 10,
  ),
  AgentUiContribution(
    id: AgentUiRendererIds.attachments,
    slot: AgentUiContributionSlot.inspectorSection,
    rendererId: AgentUiRendererIds.attachments,
    order: 20,
  ),
  AgentUiContribution(
    id: AgentUiRendererIds.context,
    slot: AgentUiContributionSlot.inspectorSection,
    rendererId: AgentUiRendererIds.context,
    order: 30,
  ),
];
