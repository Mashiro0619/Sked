import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:material_ui/material_ui.dart';

import '../../application/operation_contracts.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/sked_surface.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../theme/sked_menu_style.dart';
import '../../widgets/desktop_window_host.dart';
import '../../widgets/expressive_dialog.dart';
import '../../widgets/sked_expressive_loading_indicator.dart';
import '../../widgets/sked_popup_menu.dart';
import '../../widgets/sked_spring_builder.dart';
import '../../widgets/workbench_chrome_metrics.dart';
import '../../widgets/workspace_frame.dart';
import '../../widgets/workspace_navigation.dart';
import 'agent_conversation_list.dart';
import 'agent_conversation_timeline.dart';
import 'agent_message_content.dart';
import 'agent_message_actions.dart';
import 'agent_model_picker.dart';
import 'agent_model_labels.dart';
import 'agent_selectable_text.dart';
import 'agent_transcript.dart';
import 'agent_turn_activity.dart';
import 'agent_attachment_view.dart';
import '../attachments/conversation_attachments.dart';
import '../conversations/conversation_repository.dart';
import '../history/conversation_history.dart';
import '../history/conversation_history_service.dart';
import '../imports/conversation_file_attachments.dart';
import 'agent_ui_delegate.dart';
import 'agent_operation_card.dart';
import 'agent_plan_preview.dart';

// Failed saves remain available when a panel is closed and reopened. The
// buffer follows the repository lifetime and is never shared across archives.
final _draftBuffers = Expando<_AgentDraftBuffer>();
final _fileAttachments = Expando<ConversationFileAttachments>();

class _AgentDraftBuffer {
  final drafts = <String, String>{};
  final saved = <String, String>{};
  final writes = <String, Future<void>>{};
  final reading = <String, AgentReadingPosition>{};
  final historyDrafts = <String, String>{};
  final replyVersions = <(String, String), String>{};
}

/// Shared content for a desktop panel or a phone route. The host owns routing,
/// runtime lifetime and feature visibility; hiding this widget never stops a run.
typedef AgentWorkspaceLayoutBuilder = Widget Function(
  BuildContext context,
  Widget content,
  Widget Function(bool shrinkWrap) historyBuilder,
);

typedef _AgentHistorySource = ({
  ConversationRepository repository,
  AgentUiDelegate delegate,
  int generation,
  String? selectedId,
});

class AgentConversationView extends StatefulWidget {
  const AgentConversationView({
    super.key,
    required this.repository,
    required this.delegate,
    this.showTitle = true,
    this.fullWorkspace = false,
    this.embedded = false,
    this.active = true,
    this.interactive = true,
    this.workspaceLayoutBuilder,
    this.modelPickerBuilder,
    this.canSendToModel,
    this.onConfigureConnection,
    this.operationChanges,
    this.describeOperation,
    this.onUndoOperation,
    this.onOpenResource,
    this.onExportConversation,
    this.readDatasetGeneration,
    this.recoverConversations,
    this.pickAttachment = ConversationFileAttachments.pickFile,
    this.binaryAttachments,
    this.pickBinaryAttachment = ConversationAttachments.pickFile,
    this.history,
    this.onRegenerateReply,
  });
  final ConversationRepository repository;
  final AgentUiDelegate delegate;
  final bool showTitle;
  final bool fullWorkspace;
  final bool embedded;
  final bool active;
  final bool interactive;
  final AgentWorkspaceLayoutBuilder? workspaceLayoutBuilder;
  final Widget Function(
    AgentConversation conversation,
    AgentUiRunState state,
    AgentModelPickerLayoutBuilder layout,
  )?
  modelPickerBuilder;
  final bool Function(String conversationId)? canSendToModel;
  final VoidCallback? onConfigureConnection;
  final Listenable? operationChanges;
  final Map<String, Object?> Function(Map<String, Object?> receipt)?
  describeOperation;
  final Future<void> Function(String conversationId, String operationId)?
  onUndoOperation;
  final Future<void> Function(Map<String, Object?> ref)? onOpenResource;
  final Future<bool> Function(String conversationId)? onExportConversation;
  final String Function()? readDatasetGeneration;
  final Future<void> Function()? recoverConversations;
  final Future<PickedTextFile?> Function() pickAttachment;
  final ConversationAttachments? binaryAttachments;
  final Future<XFile?> Function() pickBinaryAttachment;
  final ConversationHistoryService? history;
  final Future<void> Function(String conversationId, String messageId)?
  onRegenerateReply;

  @override
  State<AgentConversationView> createState() => _AgentConversationViewState();
}

class _AgentConversationViewState extends State<AgentConversationView> {
  bool get _uiActive =>
      mounted &&
      widget.active &&
      widget.interactive &&
      ModalRoute.of(context)?.isCurrent != false;
  int _uiGeneration = 0;
  int _configurationGeneration = 0;
  int _approvalActionGeneration = 0;
  bool Function()? _approvalRevisionCurrent;
  TransitionRoute<dynamic>? _ownedHistoryRoute;

  void _invalidateUiSource() {
    _uiGeneration++;
    _retireHistory();
  }

  void _retireHistory() {
    final route = _ownedHistoryRoute;
    if (route == null) return;
    _ownedHistoryRoute = null;
    // Owner changes can arrive while its parent is building. Remove only the
    // owned drawer after that frame, leaving any newer route above it intact.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _uiSessionCurrent(int generation, String? conversationId) =>
      _uiActive &&
      generation == _uiGeneration &&
      _repository.selectedId == conversationId;
  final _composer = TextEditingController();
  // Reparent the editor without replacing its platform text-input client.
  final _composerField = GlobalKey();
  final _composerFocus = FocusNode();
  late _AgentDraftBuffer _draftBuffer = _draftBuffers[_repository] ??=
      _AgentDraftBuffer();
  Map<String, String> get _drafts => _draftBuffer.drafts;
  Map<String, String> get _savedDrafts => _draftBuffer.saved;
  Map<String, Future<void>> get _draftWrites => _draftBuffer.writes;
  final _transcripts = <String, GlobalKey<AgentTranscriptState>>{};
  final _transcriptVersions = <String, Object>{};
  final _replyRuns = <String, (String?, String)>{};
  final _replyBrowseRevisions = <String, int>{};
  bool _historyVisible = true;
  bool _hostActive = true;
  bool _initialDraftScheduled = false;
  bool _initialDraftRetry = false;

  AgentReadingPosition _reading(String id) =>
      _draftBuffer.reading.putIfAbsent(id, AgentReadingPosition.new);
  final _busy = <String>{};
  bool _failed = false;
  bool _loading = false;
  String? _shownId;
  String? _exportedId;
  bool _attachmentTooLarge = false;
  bool _attachmentFailed = false;
  AttachmentError? _binaryAttachmentError;
  ConversationFileAttachments get _attachments =>
      _fileAttachments[_repository] ??= ConversationFileAttachments(
        _repository,
      );

  bool _canModifyBinaryAttachments(String id) {
    final conversation = _repository.find(id);
    return _uiActive &&
        _repository.canWrite &&
        _repository.selectedId == id &&
        _runtime.enabled &&
        !_runtime.maintenance &&
        conversation != null &&
        !conversation.archived;
  }

  Future<void> _binaryAction(
    String id,
    Future<void> Function(ConversationAttachments service) action,
  ) => _perform('attachment-$id', () async {
    final service = widget.binaryAttachments;
    if (service == null) return;
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    final dataGeneration = widget.readDatasetGeneration?.call();
    bool isCurrent() =>
        _uiSessionCurrent(uiGeneration, id) &&
        identical(repository, _repository) &&
        identical(service, widget.binaryAttachments) &&
        dataGeneration == widget.readDatasetGeneration?.call();
    if (mounted) setState(() => _binaryAttachmentError = null);
    try {
      await action(service);
    } on AttachmentException catch (error) {
      if (isCurrent()) {
        setState(() => _binaryAttachmentError = error.code);
      }
    } catch (_) {
      if (isCurrent()) {
        setState(() => _binaryAttachmentError = AttachmentError.unavailable);
      }
    }
  });

  VoidCallback? _cancelAttachmentImport(
    String id,
    ConversationAttachments service,
  ) {
    final cancel = service.importCancellation(id);
    if (cancel == null) return null;
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    return () {
      if (_uiSessionCurrent(uiGeneration, id) &&
          identical(repository, _repository) &&
          identical(service, widget.binaryAttachments)) {
        cancel();
      }
    };
  }

  Future<void> _attachBinaryFile(String id) =>
      _binaryAction(id, (service) async {
        final repository = _repository;
        final generation = widget.readDatasetGeneration?.call();
        final uiGeneration = _uiGeneration;
        final file = await widget.pickBinaryAttachment();
        if (file == null || !mounted) return;
        if (!identical(repository, _repository) ||
            !identical(service, widget.binaryAttachments) ||
            generation != widget.readDatasetGeneration?.call() ||
            !_uiSessionCurrent(uiGeneration, id) ||
            !_canModifyBinaryAttachments(id)) {
          throw const AttachmentException(AttachmentError.conflict);
        }
        await service.attach(
          id,
          file,
          canModify: () =>
              identical(repository, _repository) &&
              generation == widget.readDatasetGeneration?.call() &&
              _uiSessionCurrent(uiGeneration, id) &&
              _canModifyBinaryAttachments(id),
        );
      });

  Future<void> _retryBinaryAttachment(String id) =>
      _binaryAction(id, (service) async {
        final repository = _repository;
        final uiGeneration = _uiGeneration;
        if (!repository.canWrite) {
          if (widget.recoverConversations case final recover?) {
            await recover();
          } else {
            await repository.load();
          }
        }
        if (!_uiSessionCurrent(uiGeneration, id) ||
            !identical(repository, _repository)) {
          return;
        }
        await service.retry(
          id,
          canModify: () =>
              _uiSessionCurrent(uiGeneration, id) &&
              _canModifyBinaryAttachments(id),
        );
      });

  bool _hasInput(AgentConversation conversation) =>
      _composer.text.trim().isNotEmpty ||
      conversation.draftAttachmentIds.isNotEmpty;

  bool _canModifyAttachments(String id) {
    final conversation = _repository.find(id);
    return _uiActive &&
        _repository.canWrite &&
        _repository.selectedId == id &&
        _runtime.enabled &&
        !_runtime.maintenance &&
        conversation != null &&
        !conversation.archived &&
        !_runtime.runFor(id).isActive &&
        conversation.status != ConversationStatus.running &&
        conversation.status != ConversationStatus.waitingApproval &&
        widget.delegate.pendingInputCount(id) == 0;
  }

  Future<void> _attachFile(String id) => _perform('attachment-$id', () async {
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    final generation = widget.readDatasetGeneration!();
    setState(() {
      _attachmentTooLarge = false;
      _attachmentFailed = false;
    });
    try {
      final file = await widget.pickAttachment();
      if (file == null ||
          !mounted ||
          !_uiSessionCurrent(uiGeneration, id) ||
          !identical(repository, _repository) ||
          generation != widget.readDatasetGeneration!()) {
        return;
      }
      await _attachments.attach(
        id,
        file,
        generation: generation,
        locale: Localizations.localeOf(context).toLanguageTag(),
        canModify: () =>
            identical(repository, _repository) &&
            generation == widget.readDatasetGeneration!() &&
            _uiSessionCurrent(uiGeneration, id) &&
            _canModifyAttachments(id),
      );
    } on TextFileTooLargeException {
      if (_uiSessionCurrent(uiGeneration, id) &&
          identical(repository, _repository) &&
          generation == widget.readDatasetGeneration!()) {
        setState(() => _attachmentTooLarge = true);
      }
    } catch (_) {
      if (_uiSessionCurrent(uiGeneration, id) &&
          identical(repository, _repository) &&
          generation == widget.readDatasetGeneration!()) {
        setState(() => _attachmentFailed = true);
      }
    }
  });

  Future<void> _retryAttachment(String id) =>
      _perform('attachment-$id', () async {
        final repository = _repository;
        final uiGeneration = _uiGeneration;
        if (widget.recoverConversations != null) {
          await widget.recoverConversations!();
        } else {
          await repository.load();
        }
        if (!_uiSessionCurrent(uiGeneration, id) ||
            !identical(repository, _repository)) {
          return;
        }
        await _attachments.retry(
          id,
          generation: widget.readDatasetGeneration!(),
          canModify: () =>
              _uiSessionCurrent(uiGeneration, id) && _canModifyAttachments(id),
        );
        if (mounted) {
          setState(() {
            _attachmentTooLarge = false;
            _attachmentFailed = false;
          });
        }
      });

  ConversationRepository get _repository => widget.repository;
  AgentUiState get _runtime => widget.delegate.state.value;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_changed);
    widget.delegate.state.addListener(_changed);
    widget.binaryAttachments?.addListener(_changed);
    _synchronizeDraft();
    if (!_repository.isLoaded) unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        FocusScope.of(context).canRequestFocus &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (_hostActive && !active) _configurationGeneration++;
    final becameActive = active && !_hostActive;
    _hostActive = active;
    if (becameActive) _restoreReading(_repository.selectedId);
    _scheduleInitialDraft();
  }

  @override
  void didUpdateWidget(AgentConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.active && !widget.active) ||
        (oldWidget.interactive && !widget.interactive) ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.delegate, widget.delegate)) {
      _invalidateUiSource();
    }
    if (!widget.active) {
      _hostActive = false;
    } else if (!oldWidget.active) {
      _hostActive = true;
      _restoreReading(_repository.selectedId);
    }
    if (oldWidget.repository != _repository) {
      oldWidget.repository.removeListener(_changed);
      _repository.addListener(_changed);
      _draftBuffer = _draftBuffers[_repository] ??= _AgentDraftBuffer();
      _transcripts.clear();
      _transcriptVersions.clear();
      _replyRuns.clear();
      _replyBrowseRevisions.clear();
      _shownId = null;
      _synchronizeDraft();
      if (!_repository.isLoaded) unawaited(_load());
    }
    if (oldWidget.delegate.state != widget.delegate.state) {
      oldWidget.delegate.state.removeListener(_changed);
      widget.delegate.state.addListener(_changed);
    }
    if (oldWidget.binaryAttachments != widget.binaryAttachments) {
      oldWidget.binaryAttachments?.removeListener(_changed);
      widget.binaryAttachments?.addListener(_changed);
    }
    _scheduleInitialDraft();
  }

  @override
  void dispose() {
    _invalidateUiSource();
    _repository.removeListener(_changed);
    widget.delegate.state.removeListener(_changed);
    widget.binaryAttachments?.removeListener(_changed);
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _synchronizeDraft() {
    if (_repository.isLoaded) {
      _attachments.discardDeletedConversations();
      for (final id in _drafts.keys.toList()) {
        if (_repository.find(id) != null) continue;
        _drafts.remove(id);
        _savedDrafts.remove(id);
        unawaited(_draftWrites.remove(id));
      }
    }
    for (final conversation in _repository.ownedConversations) {
      final id = conversation.id;
      if (!_drafts.containsKey(id) || _drafts[id] == _savedDrafts[id]) {
        _drafts[id] = conversation.draft;
        _savedDrafts[id] = conversation.draft;
      }
    }
    final selected = _repository.selected;
    if (_shownId != selected?.id) {
      _invalidateUiSource();
      _attachmentTooLarge = false;
      _attachmentFailed = false;
      _binaryAttachmentError = null;
    }
    final draft = selected == null
        ? ''
        : _drafts[selected.id] ?? selected.draft;
    if (_shownId != selected?.id || _composer.text != draft) {
      _composer.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
    _shownId = selected?.id;
  }

  void _changed() {
    if (!mounted) return;
    _approvalActionGeneration++;
    if (_approvalRevisionCurrent?.call() == false) {
      _approvalRevisionCurrent = null;
    }
    final conversation = _repository.selected;
    final id = conversation?.id;
    final switched = id != _shownId;
    var changedContent = false;
    String? revealReply;
    if (id != null) {
      final state = _runtime.runFor(id);
      final version = _transcriptRevision(conversation!, state);
      changedContent = _transcriptVersions[id] != version;
      _transcriptVersions[id] = version;
      final target = state.replyTargetMessageId;
      if (state.isActive && target != null) {
        final replyRun = (state.runId, target);
        if (_replyRuns[id] != replyRun) {
          _draftBuffer.replyVersions.remove((id, target));
          if (_uiActive) revealReply = target;
        }
        _replyRuns[id] = replyRun;
      } else {
        _replyRuns.remove(id);
      }
      if (!switched &&
          changedContent &&
          target == null &&
          !_reading(id).followLatest) {
        _reading(id).unread = true;
      }
    }
    setState(_synchronizeDraft);
    _scheduleInitialDraft();
    if (id != null && revealReply != null) {
      _revealReply(id, revealReply);
    } else if (switched) {
      _restoreReading(id);
    } else if (id != null && changedContent && _reading(id).followLatest) {
      _scrollToEnd(id);
    }
  }

  Object _transcriptRevision(
    AgentConversation conversation,
    AgentUiRunState state,
  ) => (
    Object.hashAll(
      conversation.messages.map(
        (message) => (
          message.id,
          message.text,
          message.attachmentDelivery,
          Object.hashAll(message.attachmentIds),
          Object.hashAll(
            message.toolCalls.map(
              (call) => (call.id, call.name, call.arguments),
            ),
          ),
        ),
      ),
    ),
    Object.hashAll(
      conversation.sources.map(
        (source) => (source.id, source.text, source.provenance?.title),
      ),
    ),
    state.runId,
    state.replyTargetMessageId,
    state.streamingText,
    state.phase,
    state.errorMessage,
    state.providerErrorDetails,
    state.providerErrorResponseBody,
    state.providerErrorMetadata,
  );

  void _revealReply(String conversationId, String messageId) {
    if (!_uiActive) return;
    final generation = _uiGeneration;
    _reading(conversationId).followLatest = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_uiSessionCurrent(generation, conversationId) || !_hostActive) {
        return;
      }
      _transcripts[conversationId]?.currentState?.reveal(
        ValueKey('agent-message-group-$messageId'),
      );
    });
  }

  void _restoreReading(String? id) {
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hostActive || _repository.selectedId != id) return;
      _transcripts[id]?.currentState?.restore();
    });
  }

  void _scrollToEnd(String? id) {
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hostActive || _repository.selectedId != id) return;
      _transcripts[id]?.currentState?.followLatest();
    });
  }

  void _jumpToLatest(String id) {
    setState(() {
      _reading(id).followLatest = true;
      _reading(id).unread = false;
    });
    _scrollToEnd(id);
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (_repository.isLoaded && widget.recoverConversations != null) {
        await widget.recoverConversations!();
      } else {
        await _repository.load();
      }
      _draftWrites.clear();
      for (final entry in _drafts.entries.toList()) {
        final conversation = _repository.find(entry.key);
        if (conversation == null) continue;
        if (conversation.draft == entry.value) {
          _savedDrafts[entry.key] = entry.value;
        } else {
          _draftChanged(entry.key, entry.value);
        }
      }
      await Future.wait(_draftWrites.values);
      if (mounted) setState(() => _failed = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
      _scheduleInitialDraft();
    }
  }

  void _scheduleInitialDraft() {
    if (!_uiActive ||
        !_repository.isLoaded ||
        !_repository.canWrite ||
        _repository.selected != null) {
      return;
    }
    if (_initialDraftScheduled) {
      // Availability may return while an older source is still completing.
      // Retry only this explicit request after that source has finished.
      _initialDraftRetry = true;
      return;
    }
    _initialDraftScheduled = true;
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (_uiActive &&
            uiGeneration == _uiGeneration &&
            identical(repository, _repository) &&
            repository.canWrite &&
            repository.selected == null) {
          await _newConversation(focusComposer: false);
        }
      } finally {
        _initialDraftScheduled = false;
        final retry = _initialDraftRetry;
        _initialDraftRetry = false;
        if (retry) _scheduleInitialDraft();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _perform(
    String action,
    Future<void> Function() operation, {
    bool Function()? isCurrent,
  }) async {
    if (!(isCurrent?.call() ?? _uiActive) || _busy.contains(action)) return;
    final generation = _uiGeneration;
    final conversationId = _repository.selectedId;
    final repository = _repository;
    final delegate = widget.delegate;
    bool ownerCurrent() =>
        _uiSessionCurrent(generation, conversationId) &&
        identical(repository, _repository) &&
        identical(delegate, widget.delegate) &&
        (isCurrent?.call() ?? true);
    setState(() {
      _busy.add(action);
      _failed = false;
    });
    try {
      await operation();
    } catch (_) {
      // Runtime-specific details arrive separately through its redacted state.
      if (ownerCurrent()) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy.remove(action));
    }
  }

  void _draftChanged(String id, String text) {
    final repository = _repository;
    setState(() => _drafts[id] = text);
    // Enqueue immediately: removing a panel or route cannot discard a timer's
    // unsaved text. Repository serialization keeps these writes in order.
    final write = repository
        .update(id, (current) => current.copyWith(draft: text))
        .then<void>((_) {
          if (identical(repository, _repository)) _savedDrafts[id] = text;
        });
    _draftWrites[id] = write;
    unawaited(
      write.catchError((Object _) {
        if (mounted) setState(() => _failed = true);
      }),
    );
  }

  Future<void> _flushDraft(String? id) async {
    if (id != null) await _draftWrites[id];
  }

  Future<void> _newConversation({bool focusComposer = true}) =>
      _perform('new', () async {
        final repository = _repository;
        final uiGeneration = _uiGeneration;
        final selectedId = repository.selectedId;
        final title = AppLocalizations.of(context).agentNewConversation;
        await _flushDraft(selectedId);
        if (!_uiSessionCurrent(uiGeneration, selectedId) ||
            !identical(repository, _repository)) {
          return;
        }
        try {
          await repository.createDraft(
            title: title,
            mode: _runtime.defaultMode,
            modelSelection: _runtime.defaultModelSelection,
            validate: () {
              if (!_uiSessionCurrent(uiGeneration, selectedId) ||
                  !identical(repository, _repository)) {
                throw StateError('This New chat request is no longer active.');
              }
            },
          );
        } catch (_) {
          if (!_uiSessionCurrent(uiGeneration, selectedId) ||
              !identical(repository, _repository)) {
            return;
          }
          rethrow;
        }
        if (focusComposer && _uiActive) _composerFocus.requestFocus();
      });

  Future<void> _select(String id) => _perform('select', () async {
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    final selectedId = repository.selectedId;
    await _flushDraft(selectedId);
    if (!_uiSessionCurrent(uiGeneration, selectedId) ||
        !identical(repository, _repository)) {
      return;
    }
    await repository.select(id);
  });

  Future<void> _send(AgentConversation conversation) async {
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    final delegate = widget.delegate;
    final text = _composer.text;
    if (text.trim().isEmpty && conversation.draftAttachmentIds.isEmpty) return;
    _jumpToLatest(conversation.id);
    await _perform('send-${conversation.id}', () async {
      await _flushDraft(conversation.id);
      if (!_uiSessionCurrent(uiGeneration, conversation.id) ||
          !identical(repository, _repository)) {
        return;
      }
      await delegate.send(conversation.id, text);
    });
  }

  Future<void> _queue(
    AgentConversation conversation, {
    required bool steering,
  }) async {
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    final delegate = widget.delegate;
    final text = _composer.text;
    if (text.trim().isEmpty && conversation.draftAttachmentIds.isEmpty) return;
    await _perform('queue-${conversation.id}', () async {
      await _flushDraft(conversation.id);
      if (!_uiSessionCurrent(uiGeneration, conversation.id) ||
          !identical(repository, _repository)) {
        return;
      }
      if (steering) {
        await delegate.steer(conversation.id, text);
      } else {
        await delegate.queueFollowUp(conversation.id, text);
      }
    });
  }

  Future<void> _rename(AgentConversation conversation) async {
    if (!_uiActive) return;
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    final title = await showExpressiveDialog<String>(
      context: context,
      builder: (context) =>
          _RenameConversationDialog(title: conversation.title),
    );
    if (title == null ||
        !_uiSessionCurrent(uiGeneration, conversation.id) ||
        !identical(repository, _repository)) {
      return;
    }
    await _perform('rename', () async {
      await repository.update(
        conversation.id,
        (current) => current.copyWith(title: title),
      );
    });
  }

  Future<void> _delete(AgentConversation conversation) async {
    if (!_uiActive) return;
    final repository = _repository;
    final uiGeneration = _uiGeneration;
    final delegate = widget.delegate;
    final l = AppLocalizations.of(context);
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.agentDeleteConversation),
        content: Text(l.agentDeleteConversationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop<bool>(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !_uiSessionCurrent(uiGeneration, conversation.id) ||
        !identical(repository, _repository)) {
      return;
    }
    await _perform('delete', () async {
      await delegate.stop(conversation.id);
      if (!identical(repository, _repository)) return;
      await repository.delete(conversation.id);
      _drafts.remove(conversation.id);
      _savedDrafts.remove(conversation.id);
      unawaited(_draftWrites.remove(conversation.id));
      _draftBuffer.reading.remove(conversation.id);
    });
  }

  Future<void> _editHistory(
    AgentConversation conversation,
    ConversationMessage message,
  ) async {
    if (!_uiActive) return;
    final repository = _repository;
    final history = widget.history!;
    final draftBuffer = _draftBuffer;
    final uiGeneration = _uiGeneration;
    final l = AppLocalizations.of(context);
    final key = '${conversation.id}:${message.id}';
    final edited = await showExpressiveDialog<String>(
      context: context,
      builder: (context) => _EditHistoryDialog(
        text: draftBuffer.historyDrafts[key] ?? message.text,
        hasAttachments: message.attachmentIds.isNotEmpty,
        onChanged: (text) => draftBuffer.historyDrafts[key] = text,
      ),
    );
    if (edited == null ||
        !_uiSessionCurrent(uiGeneration, conversation.id) ||
        !identical(repository, _repository) ||
        !identical(history, widget.history)) {
      return;
    }
    await _perform('history-${conversation.id}', () async {
      await _flushDraft(conversation.id);
      if (!_uiSessionCurrent(uiGeneration, conversation.id) ||
          !identical(repository, _repository) ||
          !identical(history, widget.history)) {
        return;
      }
      try {
        await history.editAndRedo(conversation.id, message.id, edited);
        draftBuffer.historyDrafts.remove(key);
      } catch (_) {
        if (!mounted || !_uiSessionCurrent(uiGeneration, conversation.id)) {
          rethrow;
        }
        final pending = repository.find(conversation.id)?.pendingRedo;
        if (pending != null &&
            pending.phase != ConversationRedoPhase.prepared) {
          rethrow;
        }
        final keep = await showExpressiveDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.agentEditAndRedo),
            content: Text(l.agentRedoConflict),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.agentKeepAndRevise),
              ),
            ],
          ),
        );
        if (pending != null) {
          await history.cancelPrepared(conversation.id);
        }
        if (keep == true && _uiSessionCurrent(uiGeneration, conversation.id)) {
          _draftChanged(conversation.id, edited);
          _composerFocus.requestFocus();
        }
      }
    });
  }

  Future<void> _showMessageHistory(AgentConversation conversation) =>
      showExpressiveDialog<void>(
        context: context,
        builder: (context) {
          final l = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l.agentHistoryVersions),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final version in conversation.historyVersions)
                      ExpansionTile(
                        title: Text(version.createdAt.toLocal().toString()),
                        children: [
                          for (final message in version.messages)
                            if (message.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: AgentSelectableText(message.text),
                              ),
                        ],
                      ),
                    for (final revision in conversation.replyRevisions)
                      ExpansionTile(
                        title: Text(revision.createdAt.toLocal().toString()),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: AgentSelectableText(revision.text),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.confirm),
              ),
            ],
          );
        },
      );

  AgentConversationList _historyList(
    ValueChanged<String> onSelected, {
    VoidCallback? onNewConversation,
    Widget? header,
    bool shrinkWrap = false,
    bool active = true,
    _AgentHistorySource? source,
  }) {
    final owner = source ?? _historySource;
    final repository = owner.repository;
    final delegate = owner.delegate;
    final state = delegate.state.value;
    return AgentConversationList(
      repository: repository,
      onSelected: onSelected,
      active: widget.active && active,
      interactive: widget.interactive && !state.maintenance,
      interactionRevision: owner.generation,
      // A standalone drawer lives on another route and may outlive a rebuild of
      // its parent. Bind it to the source without requiring that parent route to
      // be current while the drawer or its own menu is open.
      isOwnerCurrent: () => _historySourceCurrent(owner),
      onRecover: widget.recoverConversations,
      onNewConversation:
          widget.active &&
              active &&
              widget.interactive &&
              repository.canWrite &&
              state.enabled &&
              !state.maintenance &&
              !_busy.contains('new')
          ? (onNewConversation ?? () => unawaited(_newConversation()))
          : null,
      header: header,
      shrinkWrap: shrinkWrap,
      onRestore:
          widget.active &&
              active &&
              widget.interactive &&
              (repository.canWrite ||
                  (repository.blocked &&
                      widget.recoverConversations != null)) &&
              state.enabled &&
              !state.maintenance
          ? (id) => delegate.setArchived(id, false)
          : null,
    );
  }

  _AgentHistorySource get _historySource => (
    repository: _repository,
    delegate: widget.delegate,
    generation: _uiGeneration,
    selectedId: _repository.selectedId,
  );

  bool _historySourceCurrent(_AgentHistorySource source) =>
      mounted &&
      widget.active &&
      widget.interactive &&
      source.generation == _uiGeneration &&
      identical(source.repository, _repository) &&
      identical(source.delegate, widget.delegate) &&
      source.repository.selectedId == source.selectedId;

  Future<void> _newFromResources(WorkspaceResourceScope? resources) async {
    final repository = _repository;
    final generation = _uiGeneration;
    final selectedId = repository.selectedId;
    if (!_uiSessionCurrent(generation, selectedId)) return;
    resources?.close();
    // A resource drawer is part of the frame, so its focus exclusion retires
    // with the next layout rather than a Navigator completion Future.
    if (resources?.drawerOpen == true) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (_uiSessionCurrent(generation, selectedId) &&
        identical(repository, _repository) &&
        _repository.canWrite &&
        _runtime.enabled &&
        !_runtime.maintenance) {
      await _newConversation();
    }
  }

  Future<void> _showHistory() async {
    if (!_uiActive) return;
    final uiGeneration = _uiGeneration;
    final conversationId = _repository.selectedId;
    final l = AppLocalizations.of(context);
    final repository = _repository;
    final historySource = _historySource;
    final historyChanges = Listenable.merge([
      repository,
      historySource.delegate.state,
    ]);
    final motion = SkedMotionPolicy.of(context);
    final direction = Directionality.of(context);
    var createDraft = false;
    TransitionRoute<dynamic>? historyRoute;
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: motion.effects(SkedMotionSpeed.standard),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = animation.drive(
          CurveTween(curve: motion.scheme.enterCurve),
        );
        return FadeTransition(
          opacity: curved,
          child: motion.reduceMotion
              ? child
              : SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(direction == TextDirection.ltr ? -1 : 1, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
        );
      },
      pageBuilder: (sheetContext, _, _) {
        historyRoute = ModalRoute.of(sheetContext);
        _ownedHistoryRoute = historyRoute;
        if (!_historySourceCurrent(historySource)) _retireHistory();
        bool historyCurrent() =>
            mounted &&
            widget.active &&
            widget.interactive &&
            sheetContext.mounted &&
            ModalRoute.of(sheetContext)?.isCurrent == true &&
            uiGeneration == _uiGeneration &&
            identical(repository, _repository) &&
            repository.selectedId == conversationId;
        return InheritedTheme.captureAll(
          context,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Drawer(
                key: const ValueKey('agent-history-drawer'),
                width: (MediaQuery.sizeOf(sheetContext).width - 24).clamp(
                  0.0,
                  420.0,
                ),
                child: SafeArea(
                  child: ListenableBuilder(
                    listenable: historyChanges,
                    builder: (_, _) => _historyList(
                      (id) => Navigator.of(sheetContext).pop(id),
                      source: historySource,
                      active: _historySourceCurrent(historySource),
                      onNewConversation: () {
                        if (!historyCurrent()) return;
                        createDraft = true;
                        Navigator.of(sheetContext).pop();
                      },
                      header: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          12,
                          8,
                          4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.agentConversations,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleLarge,
                              ),
                            ),
                            IconButton(
                              key: const ValueKey('agent-history-close'),
                              tooltip: l.cancel,
                              onPressed: () {
                                if (historyCurrent()) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    await historyRoute?.completed;
    if (identical(_ownedHistoryRoute, historyRoute)) {
      _ownedHistoryRoute = null;
    }
    if (_uiSessionCurrent(uiGeneration, conversationId) &&
        identical(repository, _repository)) {
      if (createDraft &&
          _repository.canWrite &&
          _runtime.enabled &&
          !_runtime.maintenance) {
        await _newConversation();
      } else if (selected != null) {
        await _select(selected);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final conversation = _repository.selected;
    final runtime = _runtime;
    final writable =
        _uiActive &&
        _repository.canWrite &&
        runtime.enabled &&
        !runtime.maintenance;
    final state = conversation == null
        ? const AgentUiRunState()
        : runtime.runFor(conversation.id);
    final colors = Theme.of(context).colorScheme;
    if (conversation != null) {
      _transcriptVersions.putIfAbsent(
        conversation.id,
        () => _transcriptRevision(conversation, state),
      );
    }
    final canvas = SkedSurface(
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wideHistory =
                widget.fullWorkspace &&
                !widget.embedded &&
                constraints.maxWidth >=
                    980 * MediaQuery.textScalerOf(context).scale(14) / 14;
            final header = _header(
              context,
              l,
              conversation,
              writable,
              wideHistory,
            );
            final body = <Widget>[
              if (_loading)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: SkedExpressiveLoadingIndicator(
                      semanticsLabel: l.agentRunning,
                    ),
                  ),
                ),
              if (_failed || (!_repository.canWrite && !_loading))
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.agentOperationFailed,
                        style: TextStyle(color: colors.error),
                      ),
                      if (!_repository.canWrite)
                        TextButton(
                          onPressed: _loading ? null : _load,
                          child: Text(l.agentRetry),
                        ),
                    ],
                  ),
                ),
              if (!runtime.enabled) _notice(l.agentDisabled),
              if (runtime.maintenance) _notice(l.agentMaintenance),
              if (state.recoveryRequired)
                _notice(l.agentRecoveryRequired, error: true),
              if (_attachmentTooLarge)
                _notice(l.agentAttachmentTooLarge, error: true),
              if (_binaryAttachmentError case final error?)
                _notice(agentAttachmentError(l, error), error: true),
              if (conversation != null &&
                  widget.binaryAttachments?.hasPending(conversation.id) == true)
                Wrap(
                  children: [
                    TextButton(
                      key: const ValueKey('agent-retry-binary-attachment'),
                      onPressed: _busy.contains('attachment-${conversation.id}')
                          ? null
                          : () => _retryBinaryAttachment(conversation.id),
                      child: Text(l.agentRetry),
                    ),
                    TextButton(
                      onPressed: _busy.contains('attachment-${conversation.id}')
                          ? null
                          : () => _binaryAction(
                              conversation.id,
                              (service) =>
                                  service.discardPending(conversation.id),
                            ),
                      child: Text(l.cancel),
                    ),
                  ],
                ),
              if (_attachmentFailed ||
                  (conversation != null &&
                      _attachments.pending(conversation.id) != null))
                _notice(l.agentAttachmentFailed, error: true),
              if (conversation != null &&
                  _attachments.pending(conversation.id) != null)
                Wrap(
                  children: [
                    TextButton(
                      key: const ValueKey('agent-retry-attachment'),
                      onPressed: _busy.contains('attachment-${conversation.id}')
                          ? null
                          : () => _retryAttachment(conversation.id),
                      child: Text(l.agentRetry),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _attachments.discardPending(conversation.id);
                        _attachmentFailed = false;
                      }),
                      child: Text(l.cancel),
                    ),
                  ],
                ),
              if (_exportedId == conversation?.id && _exportedId != null)
                _notice(l.agentActionApplied),
              if (runtime.enabled && !runtime.configured)
                _configurationNotice(l),
              if ((conversation == null || conversation.messages.isEmpty) &&
                  !(runtime.enabled && !runtime.configured))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 28,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.agentChatWelcome,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.agentEmptyConversation,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              if (conversation != null) ..._messageWidgets(conversation, l),
              if (conversation?.pendingRedo != null) ...[
                _notice(l.agentRedoPending),
                TextButton.icon(
                  key: const ValueKey('agent-continue-history-redo'),
                  onPressed:
                      widget.history == null ||
                          _busy.contains('history-${conversation!.id}')
                      ? null
                      : () => _perform(
                          'history-${conversation.id}',
                          () => widget.history!.continueRedo(conversation.id),
                        ),
                  icon: const Icon(Icons.replay),
                  label: Text(l.agentContinue),
                ),
              ],
              if (state.replyTargetMessageId == null &&
                  state.streamingText.isNotEmpty)
                _messageText(
                  l.agentAssistant,
                  state.streamingText,
                  streaming: state.isActive,
                  key: const ValueKey('agent-streaming-text'),
                  showCopy: false,
                ),
              if (state.replyTargetMessageId == null)
                ..._runStatusWidgets(state, conversation, l),
              if (state.replyTargetMessageId == null &&
                  conversation != null &&
                  state.pendingApproval != null)
                _approval(conversation.id, state.pendingApproval!, writable, l),
            ];
            final continued =
                conversation != null &&
                !_repository.isDraft(conversation.id) &&
                !state.isActive &&
                conversation.status != ConversationStatus.running &&
                conversation.status != ConversationStatus.waitingApproval &&
                (state.phase == AgentUiPhase.stopped ||
                    conversation.status == ConversationStatus.interrupted ||
                    widget.delegate.pendingInputCount(conversation.id) > 0);
            Widget composer({required bool scrollWithTranscript}) =>
                conversation == null
                ? const SizedBox.shrink()
                : _composerWidget(
                    conversation,
                    state,
                    writable &&
                        runtime.configured &&
                        !conversation.archived &&
                        conversation.pendingRedo == null &&
                        widget.binaryAttachments?.isImporting(
                              conversation.id,
                            ) !=
                            true &&
                        widget.binaryAttachments?.hasPending(conversation.id) !=
                            true &&
                        (widget.canSendToModel?.call(conversation.id) ?? true),
                    l,
                    scrollWithTranscript: scrollWithTranscript,
                    continued: continued,
                  );
            final id = conversation?.id ?? '';
            Widget transcript(List<Widget> children, {Widget? footer}) =>
                AgentTranscript(
                  key: _transcripts.putIfAbsent(id, GlobalKey.new),
                  scrollViewKey: ValueKey('agent-transcript-$id'),
                  position: _reading(id),
                  active: _hostActive,
                  contentRevision: (
                    _transcriptVersions[id],
                    _replyBrowseRevisions[id],
                  ),
                  onReadingChanged: () {
                    if (mounted) setState(() {});
                  },
                  footer: footer,
                  children: children,
                );
            final content = LayoutBuilder(
              builder: (context, contentConstraints) {
                final budget = _composerBudget(
                  context,
                  contentConstraints.maxWidth,
                  continued: continued,
                );
                if (contentConstraints.maxHeight <
                    budget.minimumComposer + budget.minimumTranscript) {
                  return transcript(
                    body,
                    footer: composer(scrollWithTranscript: true),
                  );
                }
                final maxComposerHeight = math
                    .max(
                      contentConstraints.maxHeight * 0.58,
                      budget.minimumComposer,
                    )
                    .clamp(
                      0.0,
                      contentConstraints.maxHeight - budget.minimumTranscript,
                    );
                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: transcript(body)),
                          if (!_reading(id).followLatest)
                            PositionedDirectional(
                              bottom: 12,
                              end: 20,
                              child: IconButton.filledTonal(
                                key: const ValueKey('agent-jump-latest'),
                                tooltip: l.agentJumpToLatest,
                                onPressed: () => _jumpToLatest(id),
                                icon: Badge(
                                  isLabelVisible: _reading(id).unread,
                                  child: const Icon(
                                    Icons.arrow_downward_rounded,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxComposerHeight),
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 812),
                          child: composer(scrollWithTranscript: false),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
            return Column(
              children: [
                header,
                Expanded(
                  child: Row(
                    children: [
                      if (wideHistory)
                        SkedSpringBuilder(
                          value: _historyVisible ? 1 : 0,
                          speed: SkedMotionSpeed.fast,
                          builder: (context, value, child) => SizedBox(
                            width: 273 * value.clamp(0.0, 1.0),
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: AlignmentDirectional.centerStart,
                                minWidth: 273,
                                maxWidth: 273,
                                child: child,
                              ),
                            ),
                          ),
                          child: ExcludeFocus(
                            excluding: !_historyVisible,
                            child: ExcludeSemantics(
                              excluding: !_historyVisible,
                              child: IgnorePointer(
                                ignoring: !_historyVisible,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Material(
                                        key: const ValueKey(
                                          'agent-workspace-history',
                                        ),
                                        color: colors.surfaceContainerLow,
                                        child: _historyList(
                                          (id) => unawaited(_select(id)),
                                          active: _historyVisible,
                                        ),
                                      ),
                                    ),
                                    const VerticalDivider(width: 1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    return widget.workspaceLayoutBuilder?.call(
          context,
          canvas,
          (shrinkWrap) => Builder(
            builder: (context) {
              final resources = WorkspaceResourceScope.maybeOf(context);
              final layout = WorkspaceCanvasScope.maybeOf(context);
              return _historyList(
                (id) {
                  resources?.close();
                  unawaited(_select(id));
                },
                onNewConversation: () =>
                    unawaited(_newFromResources(resources)),
                shrinkWrap: shrinkWrap,
                active:
                    resources == null ||
                    resources.drawerOpen ||
                    layout == null ||
                    layout.resourcePresentation ==
                        WorkspaceResourcePresentation.expanded,
              );
            },
          ),
        ) ??
        canvas;
  }

  Widget _configurationNotice(AppLocalizations l) {
    final generation = _uiGeneration;
    final configurationGeneration = _configurationGeneration;
    final id = _repository.selectedId;
    final runtime = _runtime;
    final configure = widget.onConfigureConnection;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.agentConfigureFirst),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('agent-configure-connection'),
              onPressed: !_uiActive || runtime.maintenance
                  ? null
                  : () {
                      if (!_uiSessionCurrent(generation, id) ||
                          configurationGeneration != _configurationGeneration ||
                          !identical(runtime, _runtime) ||
                          !identical(configure, widget.onConfigureConnection) ||
                          !_runtime.enabled ||
                          _runtime.configured ||
                          _runtime.maintenance) {
                        return;
                      }
                      (configure ?? widget.delegate.openSettings)();
                    },
              icon: const Icon(Icons.hub_outlined),
              label: Text(l.agentConnectionAndModels),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(String text, {bool error = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Semantics(
      liveRegion: error,
      child: Text(
        text,
        style: TextStyle(
          color: error ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    ),
  );

  Widget _header(
    BuildContext headerContext,
    AppLocalizations l,
    AgentConversation? conversation,
    bool writable,
    bool wideHistory,
  ) {
    final uiGeneration = _uiGeneration;
    final title = _repository.isDraft(conversation?.id)
        ? l.agentTitle
        : conversation?.title ??
              (widget.showTitle || widget.fullWorkspace ? l.agentTitle : '');
    final metrics = WorkbenchChromeMetrics.of(headerContext);
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(headerContext).textTheme.titleMedium,
    );
    final heading = metrics.desktop
        ? DesktopDragRegion(child: IgnorePointer(child: titleText))
        : Tooltip(message: title, child: titleText);
    final row = Row(
      children: [
        if (widget.embedded) ...[
          ?workspaceMainNavigationButton(headerContext),
        ] else if (widget.fullWorkspace)
          const BackButton(),
        if (!widget.embedded)
          IconButton(
            key: const ValueKey('agent-history'),
            tooltip: wideHistory
                ? (_historyVisible
                      ? l.agentHideConversations
                      : l.agentShowConversations)
                : l.agentConversations,
            onPressed: !_repository.isLoaded
                ? null
                : wideHistory
                ? () => setState(() => _historyVisible = !_historyVisible)
                : _showHistory,
            icon: const Icon(Icons.view_sidebar_outlined),
          ),
        Expanded(child: heading),
        KeyedSubtree(
          key: ValueKey(('agent-actions-session', uiGeneration)),
          child: SkedPopupMenuButton<String>(
            key: const ValueKey('agent-conversation-menu'),
            tooltip: l.agentConversationActions,
            enabled: _uiActive && !_runtime.maintenance,
            onSelected: (value) {
              if (!_uiSessionCurrent(uiGeneration, conversation?.id)) return;
              switch (value) {
                case 'settings':
                  widget.delegate.openSettings();
                case 'rename':
                  if (conversation != null) unawaited(_rename(conversation));
                case 'message-history':
                  if (conversation != null) {
                    unawaited(_showMessageHistory(conversation));
                  }
                case 'delete':
                  if (conversation != null) unawaited(_delete(conversation));
                case 'archive':
                  if (conversation != null) {
                    unawaited(
                      _perform(
                        'archive-${conversation.id}',
                        () => widget.delegate.setArchived(
                          conversation.id,
                          !conversation.archived,
                        ),
                      ),
                    );
                  }
                case 'export':
                  if (conversation != null &&
                      widget.onExportConversation != null) {
                    unawaited(
                      _perform('export-${conversation.id}', () async {
                        final saved = await widget.onExportConversation!(
                          conversation.id,
                        );
                        if (mounted) {
                          setState(
                            () => _exportedId = saved ? conversation.id : null,
                          );
                        }
                      }),
                    );
                  }
              }
            },
            itemBuilder: (context) => [
              SkedPopupMenuItem(
                key: const ValueKey('agent-settings'),
                value: 'settings',
                child: Text(l.agentSettingsTitle),
              ),
              if (conversation != null &&
                  !_repository.isDraft(conversation.id)) ...[
                const SkedPopupMenuDivider<String>(),
                if (conversation.historyVersions.isNotEmpty ||
                    conversation.replyRevisions.isNotEmpty)
                  SkedPopupMenuItem(
                    value: 'message-history',
                    child: Text(l.agentHistoryVersions),
                  ),
                SkedPopupMenuItem(
                  value: 'rename',
                  enabled: writable && !_busy.contains('rename'),
                  child: Text(l.rename),
                ),
                SkedPopupMenuItem(
                  value: 'archive',
                  enabled: writable,
                  child: Text(
                    conversation.archived
                        ? l.agentRestoreConversation
                        : l.agentArchiveConversation,
                  ),
                ),
                if (widget.onExportConversation != null)
                  SkedPopupMenuItem(
                    value: 'export',
                    enabled: writable,
                    child: Text(l.agentExportConversation),
                  ),
                SkedPopupMenuItem(
                  value: 'delete',
                  enabled: writable && !_busy.contains('delete'),
                  child: Text(l.delete),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return SkedSurface(
      role: SkedSurfaceRole.frame,
      shape: Border(
        bottom: BorderSide(
          color: Theme.of(headerContext).colorScheme.outlineVariant,
        ),
      ),
      child: SizedBox(
        height: metrics.toolbarHeight,
        child: IconButtonTheme(
          data: IconButtonThemeData(style: metrics.iconStyle),
          child: Row(
            // Native captions remain physically right-aligned in RTL too.
            textDirection: TextDirection.ltr,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: row,
                ),
              ),
              if (widget.fullWorkspace) const DesktopCaptionSpacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionPicker(
    AgentConversation conversation,
    AppLocalizations l, {
    bool compact = false,
  }) {
    final uiGeneration = _uiGeneration;
    final desktop = SkedMenuStyle.of(context).desktop;
    final target = desktop ? 32.0 : 48.0;
    return KeyedSubtree(
      key: ValueKey(('agent-mode-session', uiGeneration)),
      child: SkedPopupMenuButton<AgentPermissionMode>(
        key: const ValueKey('agent-mode-picker'),
        tooltip:
            "${l.agentPermissionMode}: ${_modeLabel(l, conversation.mode)}",
        enabled:
            _uiActive &&
            _repository.canWrite &&
            _runtime.enabled &&
            !_runtime.maintenance &&
            !conversation.archived &&
            !_busy.contains('mode-${conversation.id}'),
        initialValue: conversation.mode,
        onSelected: (mode) {
          if (!_uiSessionCurrent(uiGeneration, conversation.id)) return;
          unawaited(
            _perform(
              'mode-${conversation.id}',
              () => widget.delegate.setMode(conversation.id, mode),
            ),
          );
        },
        itemBuilder: (context) => [
          for (final mode in AgentPermissionMode.values)
            SkedCheckedPopupMenuItem(
              key: ValueKey('agent-mode-${mode.name}'),
              value: mode,
              checked: conversation.mode == mode,
              label: _modeLabel(l, mode),
              description: _modeDescription(l, mode),
            ),
        ],
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: target, minHeight: target),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: desktop ? (compact ? 7 : 8) : (compact ? 12 : 10),
              vertical: desktop ? 6 : 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(switch (conversation.mode) {
                  AgentPermissionMode.plan => Icons.visibility_outlined,
                  AgentPermissionMode.ask => Icons.verified_user_outlined,
                  AgentPermissionMode.full => Icons.bolt_rounded,
                }, size: 18),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    _modeLabel(l, conversation.mode),
                    style: Theme.of(context).textTheme.labelLarge,
                    maxLines: 1,
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _messageWidgets(
    AgentConversation conversation,
    AppLocalizations l,
  ) {
    final state = _runtime.runFor(conversation.id);
    final timeline = projectAgentConversationTimeline(
      conversation,
      activeRunId: state.isActive ? state.runId : null,
      currentRunActive: state.isActive && state.replyTargetMessageId == null,
      replyTargetMessageId: state.replyTargetMessageId,
    );
    final latestMessageId = conversation.messages
        .where(
          (message) =>
              (message.role == ConversationRole.user ||
                  message.role == ConversationRole.assistant) &&
              message.text.isNotEmpty,
        )
        .lastOrNull
        ?.id;
    return [
      for (final source in conversation.sources)
        ExpansionTile(
          key: ValueKey('agent-source-${source.id}'),
          title: Text(
            source.provenance?.title.isNotEmpty == true
                ? source.provenance!.title
                : l.agentSourceMaterial,
          ),
          trailing:
              _canModifyAttachments(conversation.id) &&
                  ConversationFileAttachments.canRemove(conversation, source)
              ? IconButton(
                  tooltip: l.agentRemoveAttachment,
                  icon: const Icon(Icons.close),
                  onPressed: () => _perform(
                    'remove-source-${source.id}',
                    () => _attachments.remove(
                      conversation.id,
                      source.id,
                      canModify: () => _canModifyAttachments(conversation.id),
                    ),
                  ),
                )
              : null,
          childrenPadding: const EdgeInsets.all(16),
          children: [
            if (source.truncated) Text(l.agentSourceTruncated),
            AgentSelectableText(source.text),
          ],
        ),
      for (final entry in timeline)
        if (entry case AgentTimelineActivity activity)
          AgentTurnActivity(
            key: ValueKey(('agent-activity', conversation.id, activity.id)),
            activity: activity,
            active: widget.active,
            interactive: _uiActive,
            interactionRevision: _uiGeneration,
          )
        else if (entry case AgentTimelineMessage(:final message))
          if (!_isInternalHostOperation(message))
            if (_queuedInput(message) case final String text)
              Column(
                key: ValueKey('agent-message-group-${message.id}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _messageText(
                    l.agentQueuedMessages(1),
                    text,
                    key: ValueKey('agent-message-${message.id}'),
                  ),
                  if (message.attachmentIds.isNotEmpty &&
                      widget.binaryAttachments != null)
                    _messageAttachments(conversation, message),
                ],
              )
            else if (message.role == ConversationRole.tool &&
                AgentOperationCard.parse(message.text) != null)
              _ObservedOperationReceipt(
                key: ValueKey('agent-receipt-${message.id}'),
                receipt: AgentOperationCard.parse(message.text)!,
                changes: widget.operationChanges,
                describe: widget.describeOperation,
                builder: (receipt) => AgentOperationCard(
                  key: ValueKey('agent-message-${message.id}'),
                  receipt: receipt,
                  onUndo:
                      widget.onUndoOperation != null &&
                          !_runtime.runFor(conversation.id).isActive &&
                          !_runtime.runFor(conversation.id).recoveryRequired &&
                          !_busy.contains('undo-${message.id}') &&
                          _repository.canWrite &&
                          _runtime.enabled &&
                          !conversation.archived &&
                          !_runtime.maintenance
                      ? () => _perform(
                          'undo-${message.id}',
                          () => widget.onUndoOperation!(
                            conversation.id,
                            receipt['operationId'] as String,
                          ),
                        )
                      : null,
                  canOpenConversation: (id) =>
                      _repository.canWrite &&
                      !_runtime.maintenance &&
                      _repository.find(id) != null,
                  onOpenConversation: (id) => unawaited(_select(id)),
                  onOpenResource: widget.onOpenResource == null
                      ? null
                      : (ref) => _perform(
                          'view-${message.id}',
                          () => widget.onOpenResource!(ref),
                        ),
                ),
              )
            else
              _conversationMessage(
                conversation,
                message,
                l,
                latest: message.id == latestMessageId,
                finalResponse: entry.isFinalResponse,
              ),
    ];
  }

  List<(String id, String text)> _replyChoices(
    AgentConversation conversation,
    ConversationMessage message,
  ) {
    final choices = <(String, String)>[
      for (final revision in conversation.replyRevisions)
        if (revision.messageId == message.id) (revision.id, revision.text),
    ];
    if (choices.isEmpty || choices.last.$2 != message.text) {
      choices.add(('current-${message.id}', message.text));
    }
    return choices;
  }

  List<Widget> _runStatusWidgets(
    AgentUiRunState state,
    AgentConversation? conversation,
    AppLocalizations l,
  ) => [
    if (state.phase == AgentUiPhase.running)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(l.agentRunning)),
          ],
        ),
      ),
    if (state.phase == AgentUiPhase.stopped ||
        (state.replyTargetMessageId == null &&
            state.phase == AgentUiPhase.idle &&
            conversation?.status == ConversationStatus.interrupted))
      _notice(l.agentStopped),
    if (state.phase == AgentUiPhase.failed || state.errorMessage != null)
      _requestFailure(state, l),
  ];

  Future<void> _regenerateReply(
    AgentConversation conversation,
    ConversationMessage message,
  ) {
    final generation = _uiGeneration;
    _draftBuffer.replyVersions.remove((conversation.id, message.id));
    _revealReply(conversation.id, message.id);
    return _perform(
      'regenerate-${conversation.id}',
      () => widget.onRegenerateReply!(conversation.id, message.id),
      isCurrent: () => _uiSessionCurrent(generation, conversation.id),
    );
  }

  Widget _conversationMessage(
    AgentConversation conversation,
    ConversationMessage message,
    AppLocalizations l, {
    required bool latest,
    required bool finalResponse,
  }) {
    final state = _runtime.runFor(conversation.id);
    final target = state.replyTargetMessageId == message.id;
    final replacing = target && state.isActive;
    final choices = _replyChoices(conversation, message);
    final selected = _draftBuffer.replyVersions[(conversation.id, message.id)];
    final savedIndex = choices.indexWhere((choice) => choice.$1 == selected);
    final index = savedIndex < 0 ? choices.length - 1 : savedIndex;
    final text = replacing && state.streamingText.isNotEmpty
        ? state.streamingText
        : choices[index].$2;
    final canModifyHistory =
        conversation.pendingRedo == null &&
        !conversation.archived &&
        !state.isActive &&
        !state.recoveryRequired &&
        _repository.canWrite &&
        _runtime.enabled &&
        !_runtime.maintenance;
    final generation = _uiGeneration;
    return AgentMessageActions(
      key: ValueKey('agent-message-group-${message.id}'),
      messageId: message.id,
      copyText:
          !replacing && (message.role == ConversationRole.user || finalResponse)
          ? text
          : '',
      isUser: message.role == ConversationRole.user,
      active: widget.active,
      interactive: _uiActive,
      alwaysVisible: latest || choices.length > 1,
      versionCount: choices.length,
      versionIndex: index,
      showEditAndRedo:
          !conversation.archived &&
          message.role == ConversationRole.user &&
          widget.history != null &&
          conversation.turns.any((turn) => turn.requestMessageId == message.id),
      showRegenerate:
          !conversation.archived &&
          message.role == ConversationRole.assistant &&
          message.toolCalls.isEmpty &&
          message.text.isNotEmpty &&
          widget.onRegenerateReply != null,
      onVersionSelected: !replacing && choices.length > 1
          ? (next) {
              if (!_uiSessionCurrent(generation, conversation.id) ||
                  next < 0 ||
                  next >= choices.length) {
                return;
              }
              setState(() {
                _draftBuffer.replyVersions[(conversation.id, message.id)] =
                    choices[next].$1;
                _replyBrowseRevisions.update(
                  conversation.id,
                  (value) => value + 1,
                  ifAbsent: () => 1,
                );
              });
              _revealReply(conversation.id, message.id);
            }
          : null,
      onEditAndRedo:
          canModifyHistory &&
              message.role == ConversationRole.user &&
              widget.history != null &&
              conversation.turns.any(
                (turn) => turn.requestMessageId == message.id,
              ) &&
              !_busy.contains('history-${conversation.id}')
          ? () => unawaited(_editHistory(conversation, message))
          : null,
      onRegenerate:
          canModifyHistory &&
              message.role == ConversationRole.assistant &&
              message.toolCalls.isEmpty &&
              message.text.isNotEmpty &&
              widget.onRegenerateReply != null &&
              !_busy.contains('regenerate-${conversation.id}')
          ? () => unawaited(_regenerateReply(conversation, message))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.attachmentIds.isNotEmpty &&
              widget.binaryAttachments != null)
            _messageAttachments(conversation, message),
          if (text.isNotEmpty)
            _messageText(
              switch (message.role) {
                ConversationRole.user => l.agentYou,
                ConversationRole.assistant => l.agentAssistant,
                _ => l.agentNotice,
              },
              text,
              key: ValueKey('agent-message-${message.id}'),
              streaming: replacing && state.streamingText.isNotEmpty,
              showCopy: false,
            ),
          if (target) ..._runStatusWidgets(state, conversation, l),
          if (target && state.pendingApproval != null)
            _approval(
              conversation.id,
              state.pendingApproval!,
              _uiActive &&
                  _repository.canWrite &&
                  _runtime.enabled &&
                  !_runtime.maintenance,
              l,
            ),
        ],
      ),
    );
  }

  Widget _messageAttachments(
    AgentConversation conversation,
    ConversationMessage message,
  ) => AgentAttachmentList(
    conversationId: conversation.id,
    active: widget.active,
    interactive: widget.interactive,
    attachments: conversation.attachments,
    ids: message.attachmentIds,
    repository: widget.binaryAttachments!.repository,
    delivery: message.attachmentDelivery,
    onUseAgain:
        _canModifyBinaryAttachments(conversation.id) &&
            !_busy.contains('attachment-${conversation.id}')
        ? (id) => _binaryAction(
            conversation.id,
            (service) => service.useAgain(
              conversation.id,
              id,
              canModify: () => _canModifyBinaryAttachments(conversation.id),
            ),
          )
        : null,
  );

  Widget _messageText(
    String role,
    String text, {
    Key? key,
    bool streaming = false,
    bool showCopy = true,
  }) {
    final l = AppLocalizations.of(context);
    return AgentMessageContent(
      key: key,
      text: text,
      roleLabel: role,
      isUser: role == l.agentYou,
      isNotice: role != l.agentYou && role != l.agentAssistant,
      streaming: streaming,
      showCopy: showCopy,
      active: widget.active,
      interactive: _uiActive,
      interactionRevision: _uiGeneration,
    );
  }

  Widget _requestFailure(AgentUiRunState state, AppLocalizations l) {
    final body = state.providerErrorResponseBody;
    final details = state.providerErrorDetails;
    final hasBody = body != null && body.isNotEmpty;
    final serviceFailure = const {
      'provider.authentication',
      'provider.rateLimited',
      'provider.httpFailure',
      'provider.redirectRejected',
    }.contains(state.errorMessage);
    final errorStyle = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.error);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasBody && !serviceFailure) ...[
                Text(_errorMessage(state.errorMessage, l), style: errorStyle),
                if (details?.isNotEmpty == true)
                  Text(details!, style: errorStyle),
              ],
              AgentSelectableText(
                hasBody
                    ? body
                    : details?.isNotEmpty == true
                    ? details!
                    : _errorMessage(state.errorMessage, l),
                key: const ValueKey('agent-request-error'),
                style: errorStyle,
              ),
              if (hasBody)
                if (state.providerErrorMetadata case final metadata?)
                  Text(metadata, style: errorStyle),
            ],
          ),
        ),
      ),
    );
  }

  String _errorMessage(String? code, AppLocalizations l) {
    if (code?.startsWith('attachment.') == true) {
      final error = AttachmentError.values
          .where((error) => 'attachment.${error.name}' == code)
          .firstOrNull;
      return agentAttachmentError(l, error ?? AttachmentError.unavailable);
    }
    if (code == 'provider.unsupportedAttachment') return l.agentFileUnsupported;
    if (code == 'provider.attachmentMissing') return l.agentFileMissing;
    if (code == 'provider.attachmentChanged') return l.agentFileChanged;
    if (code == 'connectionChanged') return l.agentConnectionChanged;
    if (code == 'disabled' || code == 'operation.disabled') {
      return l.agentDisabled;
    }
    if (code == 'maintenance' || code == 'operation.busy') {
      return l.agentMaintenance;
    }
    if (code == 'unconfigured') return l.agentConfigureFirst;
    if (code == 'storageUnavailable' || code == 'operation.storageFailure') {
      return l.agentSaveFailed;
    }
    if (code == 'operation.outcomeUnknown') return l.agentActionUncertain;
    if (code == 'contextLimit' ||
        code == 'budgetExceeded' ||
        code == 'timeout') {
      return l.agentLimitsReached;
    }
    if (code == 'sensitiveContent') return l.agentSensitiveContent;
    if (code?.startsWith('provider.') ?? false) {
      final reason = code!.substring('provider.'.length);
      return switch (reason) {
        'transportFailure' => l.agentProviderTransportFailure(reason),
        'timeout' => l.agentProviderTimeoutFailure(reason),
        'cancelled' => l.agentStopped,
        'authentication' ||
        'rateLimited' ||
        'httpFailure' ||
        'redirectRejected' => l.agentProviderServiceFailure(reason),
        'invalidRequest' ||
        'insecureEndpoint' => l.agentProviderConfigurationFailure(reason),
        'requestBudgetExceeded' ||
        'responseBudgetExceeded' ||
        'eventBudgetExceeded' ||
        'toolBudgetExceeded' ||
        'tokenBudgetExceeded' => l.agentProviderLimitFailure(reason),
        _ => l.agentProviderResponseFailure(reason),
      };
    }
    return l.agentRunFailed;
  }

  Widget _approval(
    String id,
    AgentUiApproval plan,
    bool writable,
    AppLocalizations l,
  ) {
    final generation = _uiGeneration;
    final actionGeneration = _approvalActionGeneration;
    final routeGeneration = _configurationGeneration;
    final mode = _repository.find(id)?.mode;
    final delegate = widget.delegate;
    final runId = _runtime.runFor(id).runId;
    final clearsLocalData = agentPlanClearsLocalData(plan.details);
    final colors = Theme.of(context).colorScheme;
    bool isCurrent() =>
        _uiSessionCurrent(generation, id) &&
        identical(delegate, widget.delegate) &&
        _runtime.runFor(id).runId == runId &&
        identical(_runtime.runFor(id).pendingApproval, plan);
    bool canRevise() =>
        isCurrent() &&
        routeGeneration == _configurationGeneration &&
        _repository.canWrite &&
        _runtime.enabled &&
        _runtime.configured &&
        !_runtime.maintenance &&
        _repository.find(id)?.archived == false &&
        _repository.find(id)?.mode == mode;
    return Padding(
      key: ValueKey('agent-approval-card-${plan.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: clearsLocalData
            ? colors.errorContainer
            : colors.surfaceContainerLow,
        shape: skedShapeSchemeOf(context).card.copyWith(
          side: BorderSide(
            color: clearsLocalData ? colors.error : colors.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                clearsLocalData
                    ? l.clearAppDataConfirmTitle
                    : plan.details['kind'] == 'httpTransport'
                    ? l.agentHttpTransportApproval
                    : l.agentApprovalRequired,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: clearsLocalData
                      ? colors.onErrorContainer
                      : colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              AgentPlanPreview(details: plan.details),
              if (plan.details['kind'] != 'httpTransport') ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('agent-revise-approval'),
                    onPressed:
                        writable &&
                            canRevise() &&
                            !_busy.contains('approval-$id')
                        ? () {
                            if (actionGeneration != _approvalActionGeneration) {
                              return;
                            }
                            _focusApprovalRevision(canRevise);
                          }
                        : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.agentSteer),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('agent-approve'),
                    style: clearsLocalData
                        ? FilledButton.styleFrom(
                            backgroundColor: colors.error,
                            foregroundColor: colors.onError,
                          )
                        : null,
                    onPressed: writable && !_busy.contains('approval-$id')
                        ? () => _perform(
                            'approval-$id',
                            () => delegate.approve(id, plan.id),
                            isCurrent: isCurrent,
                          )
                        : null,
                    child: Text(
                      clearsLocalData
                          ? l.clearAppDataAction
                          : plan.details['kind'] == 'httpTransport'
                          ? l.confirm
                          : l.agentApprove,
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('agent-reject'),
                    onPressed: writable && !_busy.contains('approval-$id')
                        ? () => _perform(
                            'approval-$id',
                            () => delegate.reject(id, plan.id),
                            isCurrent: isCurrent,
                          )
                        : null,
                    child: Text(
                      plan.details['kind'] == 'httpTransport'
                          ? l.cancel
                          : l.agentReject,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _focusApprovalRevision(bool Function() isCurrent) {
    if (!isCurrent()) return;
    setState(() => _approvalRevisionCurrent = isCurrent);
    _composerFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_approvalRevisionCurrent, isCurrent) ||
          !isCurrent()) {
        return;
      }
      final editor = _composerField.currentContext;
      if (editor != null) {
        unawaited(
          Scrollable.ensureVisible(
            editor,
            alignment: 1,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ),
        );
      }
    });
  }

  ({double minimumComposer, double minimumTranscript}) _composerBudget(
    BuildContext context,
    double width, {
    required bool continued,
  }) {
    final theme = Theme.of(context);
    Size measureText(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final desktop = SkedMenuStyle.of(context).desktop;
    final button = desktop ? 32.0 : 48.0;
    final hasAttachment =
        widget.binaryAttachments != null ||
        widget.readDatasetGeneration != null;
    final continuationWidth = desktop && continued
        ? measureText(
                AppLocalizations.of(context).agentContinue,
                theme.textTheme.labelLarge,
              ).width +
              46
        : 0.0;
    final minimumWidth =
        button * 2 +
        continuationWidth +
        (hasAttachment ? button + 4 : 0) +
        4 +
        (widget.modelPickerBuilder == null ? 0 : button + 4);
    final wraps = math.min(width, 812.0) - (desktop ? 48 : 52) < minimumWidth;
    final controlHeight = math.max(
      button,
      measureText('M', theme.textTheme.labelLarge).height + (desktop ? 12 : 24),
    );
    final controlsHeight = controlHeight * (wraps ? 2 : 1) + (wraps ? 4 : 0);
    final inputLine = measureText('M', theme.textTheme.bodyLarge).height;
    return (
      minimumComposer:
          (desktop ? 40 : 44) +
          controlsHeight +
          inputLine +
          (desktop ? 16 : 44),
      minimumTranscript: math.max(48.0, inputLine * 2),
    );
  }

  Widget _composerWidget(
    AgentConversation conversation,
    AgentUiRunState state,
    bool canSend,
    AppLocalizations l, {
    required bool scrollWithTranscript,
    required bool continued,
  }) {
    final active =
        state.isActive ||
        conversation.status == ConversationStatus.running ||
        conversation.status == ConversationStatus.waitingApproval;
    // send() may remain pending for the whole run. Once the host has published
    // an active run, that Future must not disable steering or follow-up input.
    final sending =
        (!active && _busy.contains('send-${conversation.id}')) ||
        _busy.contains('queue-${conversation.id}');
    final enabled =
        _uiActive &&
        _repository.canWrite &&
        _runtime.enabled &&
        !_runtime.maintenance &&
        !conversation.archived;
    if (conversation.archived) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          key: const ValueKey('agent-restore-conversation'),
          onPressed:
              _repository.canWrite &&
                  _runtime.enabled &&
                  !_runtime.maintenance &&
                  !_busy.contains('archive-${conversation.id}')
              ? () => _perform(
                  'archive-${conversation.id}',
                  () => widget.delegate.setArchived(conversation.id, false),
                )
              : null,
          icon: const Icon(Icons.unarchive_outlined),
          label: Text(l.agentRestoreConversation),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter, control: true):
              _SendAgentMessageIntent(),
        },
        child: Actions(
          actions: {
            _SendAgentMessageIntent: CallbackAction<_SendAgentMessageIntent>(
              onInvoke: (_) {
                final composing = _composer.value.composing;
                if (canSend &&
                    !sending &&
                    !(composing.isValid && !composing.isCollapsed)) {
                  unawaited(
                    active
                        ? _queue(conversation, steering: false)
                        : _send(conversation),
                  );
                }
                return null;
              },
            ),
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = SkedMenuStyle.of(context).desktop;
              final padding = desktop ? 8.0 : 10.0;
              final availableWidth = math.max(
                0.0,
                constraints.maxWidth - padding * 2,
              );
              final style = Theme.of(context).textTheme.labelLarge;
              double labelWidth(String label) {
                final measure = TextPainter(
                  text: TextSpan(text: label, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final width = measure.width;
                measure.dispose();
                return width;
              }

              final permissionWidth =
                  labelWidth(_modeLabel(l, conversation.mode)) +
                  (desktop ? 58 : 62);
              final selection = _runtime.selectionFor(conversation.id);
              final buttonWidth = desktop ? 32.0 : 48.0;
              final continuationWidth = desktop && continued
                  ? labelWidth(l.agentContinue) + 46
                  : 0.0;
              final pickerWidth = widget.modelPickerBuilder == null
                  ? 0.0
                  : math.min(
                      320.0,
                      math.max(
                        buttonWidth,
                        labelWidth(selection?.modelId ?? l.agentChooseModel) +
                            (selection == null
                                ? 0
                                : labelWidth(
                                        agentReasoningEffortLabel(
                                          l,
                                          selection.reasoningEffort,
                                        ),
                                      ) +
                                      11) +
                            36,
                      ),
                    );
              final hasAttachment =
                  widget.binaryAttachments != null ||
                  widget.readDatasetGeneration != null;
              final spacingWidth =
                  (hasAttachment ? 4.0 : 0.0) +
                  4 +
                  (widget.modelPickerBuilder == null ? 0 : 4);
              final otherWidth =
                  buttonWidth +
                  continuationWidth +
                  (hasAttachment ? buttonWidth : 0) +
                  spacingWidth;
              final compactPermission =
                  availableWidth < permissionWidth + pickerWidth + otherWidth;
              final wrapActions =
                  availableWidth <
                  buttonWidth +
                      otherWidth +
                      (widget.modelPickerBuilder == null ? 0 : buttonWidth);

              Widget layout(Widget? picker, Widget status) {
                final continuation = continued
                    ? TextButton.icon(
                        key: const ValueKey('agent-continue'),
                        style: desktop
                            ? TextButton.styleFrom(
                                minimumSize: const Size(32, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                iconSize: 18,
                              )
                            : null,
                        onPressed:
                            canSend &&
                                !sending &&
                                !_busy.contains('continue-${conversation.id}')
                            ? () => _perform(
                                'continue-${conversation.id}',
                                () => widget.delegate.continueConversation(
                                  conversation.id,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l.agentContinue),
                      )
                    : null;
                final body = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.binaryAttachments case final service?) ...[
                      if (conversation.draftAttachmentIds.isNotEmpty)
                        AgentAttachmentList(
                          key: const ValueKey('agent-draft-attachments'),
                          conversationId: conversation.id,
                          active: widget.active,
                          interactive: widget.interactive,
                          attachments: conversation.attachments,
                          ids: conversation.draftAttachmentIds,
                          repository: service.repository,
                          onRemove:
                              _canModifyBinaryAttachments(conversation.id) &&
                                  !_busy.contains(
                                    'attachment-${conversation.id}',
                                  )
                              ? (id) => _binaryAction(
                                  conversation.id,
                                  (service) => service.remove(
                                    conversation.id,
                                    id,
                                    canModify: () =>
                                        _canModifyBinaryAttachments(
                                          conversation.id,
                                        ),
                                  ),
                                )
                              : null,
                        ),
                      if (service.isImporting(conversation.id) ||
                          (active &&
                              const {
                                AttachmentDelivery.preparing,
                                AttachmentDelivery.sending,
                              }.contains(
                                service.progressFor(conversation.id)?.delivery,
                              )))
                        AgentAttachmentProgress(
                          progress:
                              service.progressFor(conversation.id) ??
                              const AttachmentProgress(
                                AttachmentDelivery.saving,
                              ),
                          onCancel: service.isImporting(conversation.id)
                              ? _cancelAttachmentImport(
                                  conversation.id,
                                  service,
                                )
                              : null,
                        ),
                    ],
                    if (widget.delegate.pendingInputCount(conversation.id) > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          l.agentQueuedMessages(
                            widget.delegate.pendingInputCount(conversation.id),
                          ),
                        ),
                      ),
                    if (!desktop && continuation != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: continuation,
                      ),
                    if (_approvalRevisionCurrent?.call() == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l.agentApprovalReviseHint,
                            key: const ValueKey('agent-approval-revise-hint'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    KeyedSubtree(
                      key: _composerField,
                      child: TextField(
                        key: const ValueKey('agent-composer'),
                        controller: _composer,
                        focusNode: _composerFocus,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 128 * 1024,
                        textInputAction: TextInputAction.newline,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          isDense: desktop,
                          filled: false,
                          hintText: l.agentMessageHint,
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          // Android's collapsed handle reaches 39dp below the
                          // caret once its 48dp hit area is included. Keep it
                          // above the action row, including when it fades out.
                          contentPadding: EdgeInsets.fromLTRB(
                            8,
                            8,
                            8,
                            desktop ? 8 : 36,
                          ),
                        ),
                        onChanged: (value) =>
                            _draftChanged(conversation.id, value),
                      ),
                    ),
                    if (active && _hasInput(conversation))
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                            key: const ValueKey('agent-steer'),
                            onPressed: canSend && !sending
                                ? () => _queue(conversation, steering: true)
                                : null,
                            child: Text(l.agentSteer),
                          ),
                          FilledButton.tonal(
                            key: const ValueKey('agent-queue'),
                            onPressed: canSend && !sending
                                ? () => _queue(conversation, steering: false)
                                : null,
                            child: Text(l.agentQueueFollowUp),
                          ),
                        ],
                      ),
                    status,
                  ],
                );
                return ListenableBuilder(
                  listenable: _composerFocus,
                  builder: (context, child) => Material(
                    animationDuration: SkedMotionPolicy.of(context)
                        .effects(SkedMotionSpeed.fast),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    shape: skedShapeSchemeOf(context).container.copyWith(
                      side: BorderSide(
                        color: _composerFocus.hasFocus
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (scrollWithTranscript)
                          body
                        else
                          Flexible(
                            child: SingleChildScrollView(
                              key: const ValueKey('agent-composer-body-scroll'),
                              primary: false,
                              child: body,
                            ),
                          ),
                        const SizedBox(height: 4),
                        _AgentComposerActions(
                          key: const ValueKey('agent-composer-actions'),
                          wrap: wrapActions,
                          picker: picker,
                          continuation: desktop ? continuation : null,
                          permission: _permissionPicker(
                            conversation,
                            l,
                            compact: compactPermission,
                          ),
                          attachment: widget.binaryAttachments != null
                              ? IconButton(
                                  key: const ValueKey('agent-attach-file'),
                                  tooltip: l.agentAttachAnyFile,
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed:
                                      _canModifyBinaryAttachments(
                                            conversation.id,
                                          ) &&
                                          !widget.binaryAttachments!.hasPending(
                                            conversation.id,
                                          ) &&
                                          !widget.binaryAttachments!
                                              .isImporting(conversation.id) &&
                                          !_busy.contains(
                                            'attachment-${conversation.id}',
                                          )
                                      ? () => _attachBinaryFile(conversation.id)
                                      : null,
                                )
                              : widget.readDatasetGeneration != null
                              ? IconButton(
                                  key: const ValueKey('agent-attach-file'),
                                  tooltip: l.agentAttachFile,
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed:
                                      _canModifyAttachments(conversation.id) &&
                                          _attachments.pending(
                                                conversation.id,
                                              ) ==
                                              null &&
                                          !_busy.contains(
                                            'attachment-${conversation.id}',
                                          )
                                      ? () => _attachFile(conversation.id)
                                      : null,
                                )
                              : null,
                          send: SkedSpringBuilder(
                            value: active ? 1 : 0,
                            speed: SkedMotionSpeed.fast,
                            builder: (context, value, _) {
                              final progress = value.clamp(0.0, 1.0);
                              return IconButton.filled(
                                key: ValueKey(
                                  active ? 'agent-stop' : 'agent-send',
                                ),
                                tooltip: active ? l.agentStop : l.agentSend,
                                onPressed: active
                                    ? _busy.contains('stop-${conversation.id}')
                                          ? null
                                          : () => _perform(
                                              'stop-${conversation.id}',
                                              () => widget.delegate.stop(
                                                conversation.id,
                                              ),
                                            )
                                    : canSend &&
                                          !sending &&
                                          _hasInput(conversation)
                                    ? () => _send(conversation)
                                    : null,
                                icon: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Opacity(
                                      opacity: 1 - progress,
                                      child: Transform.scale(
                                        scale: 1 - 0.25 * progress,
                                        child: const Icon(
                                          Icons.arrow_upward_rounded,
                                        ),
                                      ),
                                    ),
                                    Opacity(
                                      opacity: progress,
                                      child: Transform.scale(
                                        scale: 0.75 + 0.25 * progress,
                                        child: const Icon(Icons.stop_rounded),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return widget.modelPickerBuilder?.call(
                    conversation,
                    state,
                    layout,
                  ) ??
                  layout(null, const SizedBox.shrink());
            },
          ),
        ),
      ),
    );
  }
}

class _AgentComposerActions extends StatelessWidget {
  const _AgentComposerActions({
    super.key,
    required this.permission,
    required this.send,
    required this.wrap,
    this.attachment,
    this.picker,
    this.continuation,
  });

  final Widget? attachment;
  final Widget? continuation;
  final Widget permission;
  final Widget? picker;
  final Widget send;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final leading = [?attachment, permission, ?continuation];
    final trailing = [
      if (picker case final picker?) ...[
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: picker,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ] else
        const Spacer(),
      send,
    ];
    if (wrap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(spacing: 4, runSpacing: 4, children: leading),
          const SizedBox(height: 4),
          Row(children: trailing),
        ],
      );
    }
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachment case final attachment?) ...[
              attachment,
              const SizedBox(width: 4),
            ],
            permission,
            if (continuation case final continuation?) ...[
              const SizedBox(width: 4),
              continuation,
            ],
          ],
        ),
        const SizedBox(width: 4),
        ...trailing,
      ],
    );
  }
}

class _SendAgentMessageIntent extends Intent {
  const _SendAgentMessageIntent();
}

class _EditHistoryDialog extends StatefulWidget {
  const _EditHistoryDialog({
    required this.text,
    required this.hasAttachments,
    required this.onChanged,
  });
  final String text;
  final bool hasAttachments;
  final ValueChanged<String> onChanged;
  @override
  State<_EditHistoryDialog> createState() => _EditHistoryDialogState();
}

class _EditHistoryDialogState extends State<_EditHistoryDialog> {
  late final _controller = TextEditingController(text: widget.text);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.agentEditAndRedo),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.agentRedoExplanation),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('agent-redo-input'),
                controller: _controller,
                minLines: 3,
                maxLines: 10,
                maxLength: 128 * 1024,
                autofocus: true,
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  filled: true,
                  labelText: l.agentYou,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            key: const ValueKey('agent-confirm-redo'),
            onPressed: _controller.text.trim().isEmpty && !widget.hasAttachments
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            child: Text(l.agentEditAndRedo),
          ),
        ),
      ],
    );
  }
}

class _RenameConversationDialog extends StatefulWidget {
  const _RenameConversationDialog({required this.title});
  final String title;
  @override
  State<_RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<_RenameConversationDialog> {
  late final _controller = TextEditingController(text: widget.title);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.agentRenameConversation),
      content: TextField(
        key: const ValueKey('agent-rename-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 256,
        decoration: InputDecoration(filled: true, labelText: l.name),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.of(context).pop(value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text.trim()),
            child: Text(l.save),
          ),
        ),
      ],
    );
  }
}

/// Only the operation's live observation can rebuild this card. Conversation
/// input, scroll ownership, and persisted tool messages stay outside the update.
class _ObservedOperationReceipt extends StatefulWidget {
  const _ObservedOperationReceipt({
    super.key,
    required this.receipt,
    required this.builder,
    this.changes,
    this.describe,
  });

  final Map<String, Object?> receipt;
  final Widget Function(Map<String, Object?> receipt) builder;
  final Listenable? changes;
  final Map<String, Object?> Function(Map<String, Object?> receipt)? describe;

  Listenable? get source =>
      describe != null &&
          receipt['status'] == 'committed' &&
          receipt['kind'] != 'external'
      ? changes
      : null;

  @override
  State<_ObservedOperationReceipt> createState() =>
      _ObservedOperationReceiptState();
}

class _ObservedOperationReceiptState extends State<_ObservedOperationReceipt> {
  late Map<String, Object?> _receipt;

  Map<String, Object?> _read() =>
      widget.describe?.call(widget.receipt) ?? widget.receipt;

  @override
  void initState() {
    super.initState();
    _receipt = _read();
    widget.source?.addListener(_changed);
  }

  @override
  void didUpdateWidget(_ObservedOperationReceipt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) {
      oldWidget.source?.removeListener(_changed);
      widget.source?.addListener(_changed);
    }
    _receipt = _read();
  }

  void _changed() {
    final next = _read();
    final before = _receipt['notificationEffect'];
    final after = next['notificationEffect'];
    if (before is Map && after is Map
        ? mapEquals(before, after)
        : before == after) {
      return;
    }
    if (mounted) setState(() => _receipt = next);
  }

  @override
  void dispose() {
    widget.source?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_receipt);
}

String? _queuedInput(ConversationMessage message) {
  if (message.role != ConversationRole.notice) return null;
  try {
    final value = jsonDecode(message.text);
    if (value is Map &&
        value['kind'] == 'agent_pending_input' &&
        value['text'] is String) {
      return value['text'] as String;
    }
  } on FormatException {
    // Ordinary user-visible notices are not queue records.
  }
  return null;
}

bool _isInternalHostOperation(ConversationMessage message) {
  if (message.role != ConversationRole.notice) return false;
  try {
    final value = jsonDecode(message.text);
    return value is Map && value['kind'] == 'agent_host_operation';
  } on FormatException {
    return false;
  }
}

String _modeLabel(AppLocalizations l, AgentPermissionMode mode) =>
    switch (mode) {
      AgentPermissionMode.plan => l.agentModePlan,
      AgentPermissionMode.ask => l.agentModeAsk,
      AgentPermissionMode.full => l.agentModeFull,
    };

String _modeDescription(AppLocalizations l, AgentPermissionMode mode) =>
    switch (mode) {
      AgentPermissionMode.plan => l.agentModePlanDescription,
      AgentPermissionMode.ask => l.agentModeAskDescription,
      AgentPermissionMode.full => l.agentModeFullDescription,
    };
