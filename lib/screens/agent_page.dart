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
import '../controllers/settings_view_state.dart';
import '../widgets/desktop_window_host.dart';
import '../widgets/workspace_frame.dart';
import '../widgets/workspace_navigation.dart';
import 'agent_settings_page.dart';

typedef AgentWorkspaceActivator = Future<bool> Function({
  String? conversationId,
  bool Function()? isCurrent,
});

/// Retained main content backed by the application-owned repository and runtime.
/// Selecting another destination never stops a run or recreates the repository.
class AgentPage extends StatefulWidget {
  const AgentPage({
    super.key,
    this.embedded = false,
    this.active = true,
    this.interactive = true,
    this.onOpenSettings,
    this.settingsFocusNode,
  });

  final bool embedded;
  final bool active;
  final bool interactive;
  final VoidCallback? onOpenSettings;
  final FocusNode? settingsFocusNode;

  static final _workspaceActivators = Expando<AgentWorkspaceActivator>(
    'Agent shell activation',
  );

  /// Only the root shell owns destination selection. Captured route scopes keep
  /// the same application identity and can await that shell's acknowledgement.
  static VoidCallback registerWorkspaceActivator(
    AgentApplication application,
    AgentWorkspaceActivator activate,
  ) {
    _workspaceActivators[application] = activate;
    return () {
      if (identical(_workspaceActivators[application], activate)) {
        _workspaceActivators[application] = null;
      }
    };
  }

  /// Waits for central-content activation or invalidation of its shell/feature.
  /// It never waits for a separate conversation route to close.
  static Future<void> open(BuildContext context, {String? conversationId}) {
    if (!context.mounted) return Future.value();
    return _openApplication(
      context.read<AgentApplication>(),
      conversationId: conversationId,
      isCurrent: () => context.mounted,
    );
  }

  /// A completed source task can retire its own route before requesting the
  /// destination through the captured application identity.
  static Future<void> openApplication(
    AgentApplication application, {
    String? conversationId,
  }) => _openApplication(application, conversationId: conversationId);

  static Future<void> _openApplication(
    AgentApplication application, {
    String? conversationId,
    bool Function()? isCurrent,
  }) async {
    final activate = _workspaceActivators[application];
    if (activate == null || !application.settings.enabled) return;
    // Register the entire request with the shell before selection can wait on
    // storage. A newer destination or disposal must also cancel this phase.
    await activate(conversationId: conversationId, isCurrent: isCurrent);
  }

  static Future<void> openConversation(
    BuildContext context, {
    String? conversationId,
  }) => open(context, conversationId: conversationId);

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> {
  final _pane = WorkspacePaneController();

  @override
  void dispose() {
    _pane.dispose();
    super.dispose();
  }

  Widget _workspace(
    BuildContext context,
    Widget content,
    Widget Function(bool shrinkWrap) historyBuilder,
  ) {
    final settings = context.watch<SettingsViewState>();
    return WorkspaceFrame(
      key: const ValueKey('agent-workspace-frame'),
      controller: _pane,
      active: widget.active,
      resourcesCollapsed: settings.homeWorkspaceNavigationCollapsed,
      panelDisplayMode: settings.workspacePanelDisplayMode,
      canvas: content,
      resources: Builder(
        builder: (context) {
          final resources = WorkspaceResourceScope.maybeOf(context);
          return WorkspaceResourcePanel(
            title: AppLocalizations.of(context).agentConversations,
            resourceIcon: Icons.history,
            contentBuilder: historyBuilder,
            onOpenResources:
                resources?.canExpandInline == false &&
                    resources?.drawerOpen != true
                ? resources?.open
                : null,
            onSettings: widget.interactive ? widget.onOpenSettings : null,
            settingsFocusNode: widget.settingsFocusNode,
            children: const [],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final application = context.watch<AgentApplication>();
    if (!application.settings.enabled) return const SizedBox.shrink();
    final host = AgentConversationHost(
      fullWorkspace: true,
      embedded: widget.embedded,
      active: widget.active,
      interactive: widget.interactive,
      workspaceLayoutBuilder: widget.embedded ? _workspace : null,
    );
    return widget.embedded ? host : Scaffold(body: SafeArea(child: host));
  }
}

/// Keeps navigation local to this visible host. Other retained workspaces can
/// render the same runtime without replacing a global settings callback.
class AgentConversationHost extends StatefulWidget {
  const AgentConversationHost({
    super.key,
    this.fullWorkspace = false,
    this.active = true,
    this.interactive = true,
    this.embedded = false,
    this.workspaceLayoutBuilder,
  });
  final bool fullWorkspace;
  final bool active;
  final bool interactive;
  final bool embedded;
  final AgentWorkspaceLayoutBuilder? workspaceLayoutBuilder;

  @override
  State<AgentConversationHost> createState() => _AgentConversationHostState();
}

class _AgentConversationHostState extends State<AgentConversationHost> {
  bool _settingsOpen = false;
  bool _retrying = false;
  AgentApplication? _initializationAttempt;
  _RoutedAgentDelegate? _routedDelegate;

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
    if (_retrying || !widget.active || !widget.interactive) return;
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
    if (_settingsOpen || !widget.active || !widget.interactive) return;
    setState(() => _settingsOpen = true);
    try {
      await AgentSettingsPage.open(context);
    } finally {
      if (mounted) setState(() => _settingsOpen = false);
    }
  }

  Widget _initializationStatus(
    AgentApplication application,
    AppLocalizations l,
  ) {
    final failed = application.initializationError && !_retrying;
    final reason = switch (application.initializationFailure) {
      AgentInitializationFailure.applicationStorage =>
        l.agentInitializationApplicationStorage,
      AgentInitializationFailure.conversationStorage =>
        l.agentInitializationConversationStorage,
      AgentInitializationFailure.connectionStorage =>
        l.agentInitializationConnectionStorage,
      null => null,
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const ValueKey('agent-initialization-scroll'),
        primary: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!failed) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        failed
                            ? l.agentInitializationFailed
                            : l.agentInitializing,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (failed) ...[
                        if (reason != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            reason,
                            key: const ValueKey('agent-initialization-reason'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          key: const ValueKey('agent-initialization-retry'),
                          onPressed: _retryInitialization,
                          child: Text(l.agentRetry),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final application = context.watch<AgentApplication>();
    final l = AppLocalizations.of(context);
    if (!widget.active && !application.isInitialized) {
      return const SizedBox.shrink();
    }
    if (!application.isInitialized) {
      final status = _initializationStatus(application, l);
      if (!widget.fullWorkspace) return status;
      final navigationButtonStyle = IconButton.styleFrom(
        minimumSize: const Size.square(48),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.padded,
      );
      final content = Column(
        children: [
          Padding(
            key: const ValueKey('agent-initialization-header'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (widget.embedded)
                  Builder(
                    builder: (context) =>
                        workspaceMainNavigationButton(context) ??
                        const SizedBox.shrink(),
                  )
                else
                  BackButton(
                    key: const ValueKey('agent-initialization-back'),
                    style: navigationButtonStyle,
                  ),
                Expanded(
                  child: DesktopDragRegion(
                    child: Text(
                      l.agentTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('agent-initialization-settings'),
                  tooltip: l.agentSettingsTitle,
                  style: navigationButtonStyle,
                  onPressed: widget.interactive
                      ? () => unawaited(_openSettings())
                      : null,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const DesktopCaptionSpacer(),
              ],
            ),
          ),
          Expanded(child: status),
        ],
      );
      return widget.workspaceLayoutBuilder?.call(
            context,
            content,
            (_) => const SizedBox.shrink(),
          ) ??
          content;
    }
    final runtime = application.runtime;
    var delegate = _routedDelegate;
    if (delegate == null || !identical(delegate.runtime, runtime)) {
      delegate = _routedDelegate = _RoutedAgentDelegate(
        runtime,
        () => unawaited(_openSettings()),
      );
    }
    return AgentConversationView(
      repository: application.conversations,
      showTitle: false,
      fullWorkspace: widget.fullWorkspace,
      embedded: widget.embedded,
      active: widget.active,
      interactive: widget.interactive && !_settingsOpen,
      workspaceLayoutBuilder: widget.workspaceLayoutBuilder,
      modelPickerBuilder: (conversation, _, layout) => AgentModelPicker(
        layoutBuilder: layout,
        conversationId: conversation.id,
        delegate: application.runtime,
        enabled: !conversation.archived,
        active: widget.active,
        interactive: widget.interactive && !_settingsOpen,
      ),
      canSendToModel: (id) =>
          agentConversationModelReady(application.runtime.state.value, id),
      operationChanges: application.tools.notificationEffectChanges,
      describeOperation: application.tools.describeCommitResult,
      delegate: delegate,
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
