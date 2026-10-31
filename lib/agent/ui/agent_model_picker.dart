import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/sked_popup_menu.dart';
import 'agent_model_labels.dart';
import 'agent_ui_delegate.dart';

bool agentConversationModelReady(AgentUiState state, String conversationId) {
  final selection = state.selectionFor(conversationId);
  return selection != null &&
      state.availableModels.any(
        (model) =>
            model.id == selection.modelId &&
            model.reasoningEfforts.contains(selection.reasoningEffort),
      );
}

/// Changes only the saved choice for the next request. The runtime owns the
/// current request snapshot, queued input repair and explicit continuation.
class AgentModelPicker extends StatefulWidget {
  const AgentModelPicker({
    super.key,
    required this.conversationId,
    required this.delegate,
    this.enabled = true,
  });

  final String conversationId;
  final AgentUiDelegate delegate;
  final bool enabled;

  @override
  State<AgentModelPicker> createState() => _AgentModelPickerState();
}

class _AgentModelPickerState extends State<AgentModelPicker> {
  bool _saving = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void didUpdateWidget(AgentModelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.delegate != widget.delegate) {
      _generation++;
      _saving = false;
      _failed = false;
    }
  }

  Future<void> _select(AgentModelSelection selection) async {
    if (_saving || !widget.enabled) return;
    final generation = _generation;
    final delegate = widget.delegate;
    final id = widget.conversationId;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await delegate.setModelSelection(id, selection);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Widget _label(BuildContext context, String label, IconData icon) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: skedShapeSchemeOf(context).selection,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AgentUiState>(
    valueListenable: widget.delegate.state,
    builder: (context, state, _) {
      final l = AppLocalizations.of(context);
      final selection = state.selectionFor(widget.conversationId);
      final model = state.availableModels
          .where((item) => item.id == selection?.modelId)
          .firstOrNull;
      final run = state.runFor(widget.conversationId);
      final ready = agentConversationModelReady(state, widget.conversationId);
      final enabled =
          widget.enabled && state.enabled && !state.maintenance && !_saving;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: SkedPopupMenuButton<String>(
                    key: const ValueKey('agent-model-picker'),
                    tooltip: l.agentModelSelection,
                    enabled: enabled && state.availableModels.isNotEmpty,
                    initialValue: model?.id,
                    onSelected: (id) {
                      final selected = state.availableModels
                          .where((item) => item.id == id)
                          .firstOrNull;
                      if (selected == null) return;
                      final effort = selection?.reasoningEffort;
                      unawaited(
                        _select(
                          AgentModelSelection(
                            modelId: id,
                            reasoningEffort:
                                effort != null &&
                                    selected.reasoningEfforts.contains(effort)
                                ? effort
                                : selected.defaultReasoningEffort,
                          ),
                        ),
                      );
                    },
                    itemBuilder: (context) => [
                      for (final item in state.availableModels)
                        PopupMenuItem(
                          key: ValueKey('agent-model-choice-${item.id}'),
                          value: item.id,
                          child: Text(item.id),
                        ),
                    ],
                    child: _label(
                      context,
                      selection?.modelId ?? l.agentChooseModel,
                      Icons.auto_awesome_outlined,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: SkedPopupMenuButton<AgentReasoningEffort>(
                    key: const ValueKey('agent-effort-picker'),
                    tooltip: l.agentThinkingEffort,
                    enabled: enabled && model != null,
                    initialValue: ready ? selection?.reasoningEffort : null,
                    onSelected: (effort) {
                      if (model != null) {
                        unawaited(
                          _select(
                            AgentModelSelection(
                              modelId: model.id,
                              reasoningEffort: effort,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      for (final effort
                          in model?.reasoningEfforts ??
                              const <AgentReasoningEffort>[])
                        PopupMenuItem(
                          key: ValueKey('agent-effort-choice-${effort.name}'),
                          value: effort,
                          child: Text(agentReasoningEffortLabel(l, effort)),
                        ),
                    ],
                    child: _label(
                      context,
                      selection == null
                          ? l.agentThinkingEffort
                          : agentReasoningEffortLabel(
                              l,
                              selection.reasoningEffort,
                            ),
                      Icons.tune_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (run.isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                l.agentModelNextRunHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if ((!ready && selection != null) || run.requiresModelSelection)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                l.agentModelSelectionRequired,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Text(
                l.agentOperationFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    },
  );
}
