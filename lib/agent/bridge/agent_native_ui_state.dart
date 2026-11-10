import '../ui/contributions/agent_ui_contribution_contracts.dart';
import 'generated/api/ui_contracts.dart' as native;

/// The local token distinguishes core restarts even when native generations
/// restart at one. A null snapshot means that this core is still loading.
class AgentNativeUiState {
  const AgentNativeUiState({this.sessionToken, this.snapshot});

  final Object? sessionToken;
  final AgentUiContributionSnapshot? snapshot;
}

AgentUiContributionSnapshot agentUiSnapshotFromNative(
  native.UiContributionSnapshot snapshot,
) => AgentUiContributionSnapshot(
  contractVersion: snapshot.contractVersion,
  revision: snapshot.revision,
  owners: [
    for (final owner in snapshot.owners)
      AgentUiContributionOwnerSnapshot(
        instanceId: owner.instanceId,
        generation: owner.generation,
        contributions: [
          for (final entry in owner.contributions)
            AgentUiContribution(
              id: entry.id,
              slot: switch (entry.slot) {
                native.UiContributionSlot.toolResult =>
                  AgentUiContributionSlot.toolResult,
                native.UiContributionSlot.settings =>
                  AgentUiContributionSlot.settings,
                native.UiContributionSlot.inspectorSection =>
                  AgentUiContributionSlot.inspectorSection,
              },
              rendererId: entry.rendererId,
              order: entry.order,
            ),
        ],
      ),
  ],
);
