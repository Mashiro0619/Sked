import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/ui/agent_conversation_view.dart';
import '../agent/ui/agent_ui_delegate.dart';
import '../agent/ui/agent_model_picker.dart';
import '../agent/ui/agent_resource_view.dart';
import '../agent/provider/provider.dart';
import '../application/operation_contracts.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_settings.dart';
import '../widgets/workbench_chrome_metrics.dart';
import 'agent_settings_page.dart';

/// A full conversation workspace using the same application-owned repository
/// and runtime as the desktop pane. Popping it does not stop a run.
class AgentPage extends StatelessWidget {
  const AgentPage({super.key});

  static Future<void> open(BuildContext context) {
    final application = context.read<AgentApplication>();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<AgentApplication>.value(
          value: application,
          child: const AgentPage(),
        ),
      ),
    );
  }

  /// Opens the selected conversation in the current platform's product host.
  /// Desktop workspaces consume this request once, only while active.
  static Future<void> openConversation(BuildContext context) {
    if (WorkbenchChromeMetrics.of(context).desktop) {
      context.read<AgentApplication>().requestShowConversation();
      return Future.value();
    }
    return open(context);
  }

  @override
  Widget build(BuildContext context) {
    final application = context.watch<AgentApplication>();
    final route = ModalRoute.of(context);
    if (!application.settings.enabled &&
        route?.isCurrent == true &&
        route?.isFirst == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted &&
            !application.settings.enabled &&
            route?.isCurrent == true) {
          Navigator.of(context).maybePop();
        }
      });
    }
    return Scaffold(
      body: SafeArea(child: const AgentConversationHost(fullWorkspace: true)),
    );
  }
}

/// Keeps navigation local to this visible host. Other retained workspaces can
/// render the same runtime without replacing a global settings callback.
class AgentConversationHost extends StatefulWidget {
  const AgentConversationHost({
    super.key,
    this.fullWorkspace = false,
    this.active = true,
  });
  final bool fullWorkspace;
  final bool active;

  @override
  State<AgentConversationHost> createState() => _AgentConversationHostState();
}

class _AgentConversationHostState extends State<AgentConversationHost> {
  bool _settingsOpen = false;
  bool _retrying = false;
  AgentApplication? _initializationAttempt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeVisibleHost();
  }

  @override
  void didUpdateWidget(AgentConversationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _initializeVisibleHost();
  }

  void _initializeVisibleHost() {
    final application = context.read<AgentApplication>();
    if (!widget.active ||
        application.isInitialized ||
        application.initializationError ||
        identical(_initializationAttempt, application)) {
      return;
    }
    _initializationAttempt = application;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.active ||
          !identical(context.read<AgentApplication>(), application)) {
        _initializationAttempt = null;
        return;
      }
      // The application owns both the shared in-flight load and its failure
      // state. Retained, hidden hosts must never start this work at startup.
      application.initialize().ignore();
    });
  }

  Future<void> _retryInitialization() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await context.read<AgentApplication>().initialize();
    } catch (_) {
      // The application publishes its redacted initialization error state.
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _openSettings() async {
    if (_settingsOpen) return;
    _settingsOpen = true;
    try {
      await AgentSettingsPage.open(context);
    } finally {
      _settingsOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = context.watch<AgentApplication>();
    final l = AppLocalizations.of(context);
    if (!widget.active && !application.isInitialized) {
      return const SizedBox.shrink();
    }
    if (!application.isInitialized) {
      return Center(
        child: application.initializationError && !_retrying
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.agentOperationFailed),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _retryInitialization,
                      child: Text(l.agentRetry),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      );
    }
    return AgentConversationView(
      repository: application.conversations,
      showTitle: false,
      fullWorkspace: widget.fullWorkspace,
      modelPickerBuilder: (conversation, _) => AgentModelPicker(
        conversationId: conversation.id,
        delegate: application.runtime,
        enabled: !conversation.archived,
      ),
      canSendToModel: (id) =>
          agentConversationModelReady(application.runtime.state.value, id),
      operationChanges: application.tools.notificationEffectChanges,
      describeOperation: application.tools.describeCommitResult,
      delegate: _RoutedAgentDelegate(
        application.runtime,
        () => unawaited(_openSettings()),
      ),
      onUndoOperation: (conversationId, operationId) async {
        await application.runtime.runHostAction(conversationId, (
          scope,
          approve,
        ) async {
          final plan = await application.tools.execute(
            ProviderToolCall(
              id: '${scope.id}-undo-prepare',
              name: 'undo.prepare',
              arguments: jsonEncode({'operationId': operationId}),
            ),
            scope,
            approve,
          );
          final prepared = application.mutations.plan(
            plan['planId']! as String,
          );
          if (prepared == null) throw StateError('The undo plan expired.');
          await application.runtime.recordHostOperation(scope, prepared);
          return application.tools.execute(
            ProviderToolCall(
              id: '${scope.id}-undo-commit',
              name: 'mutation.commit',
              arguments: jsonEncode({'planId': plan['planId']}),
            ),
            scope,
            approve,
          );
        });
      },
      onOpenResource: (ref) => AgentResourceView.open(context, ref),
      onExportConversation: (id) async {
        final result = await application.conversationTools.exportConversation(
          id,
        );
        if (!result.saved && !result.cancelled) {
          throw const OperationProblem(
            OperationErrorCode.storageFailure,
            'The conversation export could not be saved.',
          );
        }
        return result.saved;
      },
      readDatasetGeneration: () => application.mutations.generation,
      recoverConversations: application.recoverConversations,
      binaryAttachments: application.binaryAttachments,
      history: application.history,
      onRegenerateReply: application.runtime.regenerateReply,
    );
  }
}

class _RoutedAgentDelegate implements AgentUiDelegate {
  const _RoutedAgentDelegate(this.runtime, this.onOpenSettings);
  final AgentUiDelegate runtime;
  final VoidCallback onOpenSettings;

  @override
  ValueListenable<AgentUiState> get state => runtime.state;
  @override
  Future<void> send(String conversationId, String text) =>
      runtime.send(conversationId, text);
  @override
  Future<void> queueFollowUp(String conversationId, String text) =>
      runtime.queueFollowUp(conversationId, text);
  @override
  Future<void> steer(String conversationId, String text) =>
      runtime.steer(conversationId, text);
  @override
  Future<void> continueConversation(String conversationId) =>
      runtime.continueConversation(conversationId);
  @override
  int pendingInputCount(String conversationId) =>
      runtime.pendingInputCount(conversationId);
  @override
  Future<void> setArchived(String conversationId, bool archived) =>
      runtime.setArchived(conversationId, archived);
  @override
  Future<void> stop(String conversationId) => runtime.stop(conversationId);
  @override
  Future<void> approve(String conversationId, String planId) =>
      runtime.approve(conversationId, planId);
  @override
  Future<void> reject(String conversationId, String planId) =>
      runtime.reject(conversationId, planId);
  @override
  Future<void> setMode(String conversationId, AgentPermissionMode mode) =>
      runtime.setMode(conversationId, mode);
  @override
  Future<void> setModelSelection(
    String conversationId,
    AgentModelSelection selection,
  ) => runtime.setModelSelection(conversationId, selection);
  @override
  void openSettings() => onOpenSettings();
}
