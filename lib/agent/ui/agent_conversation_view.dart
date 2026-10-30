import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/operation_contracts.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/sked_surface.dart';
import '../conversations/conversation_repository.dart';
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
}

/// Shared content for a desktop panel or a phone route. The host owns routing,
/// runtime lifetime and feature visibility; hiding this widget never stops a run.
class AgentConversationView extends StatefulWidget {
  const AgentConversationView({
    super.key,
    required this.repository,
    required this.delegate,
    this.showTitle = true,
    this.onUndoOperation,
    this.onOpenResource,
    this.onExportConversation,
    this.readDatasetGeneration,
    this.recoverConversations,
    this.pickAttachment = ConversationFileAttachments.pickFile,
  });
  final ConversationRepository repository;
  final AgentUiDelegate delegate;
  final bool showTitle;
  final Future<void> Function(String conversationId, String operationId)?
  onUndoOperation;
  final Future<void> Function(Map<String, Object?> ref)? onOpenResource;
  final Future<bool> Function(String conversationId)? onExportConversation;
  final String Function()? readDatasetGeneration;
  final Future<void> Function()? recoverConversations;
  final Future<PickedTextFile?> Function() pickAttachment;

  @override
  State<AgentConversationView> createState() => _AgentConversationViewState();
}

class _AgentConversationViewState extends State<AgentConversationView> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  late _AgentDraftBuffer _draftBuffer = _draftBuffers[_repository] ??=
      _AgentDraftBuffer();
  Map<String, String> get _drafts => _draftBuffer.drafts;
  Map<String, String> get _savedDrafts => _draftBuffer.saved;
  Map<String, Future<void>> get _draftWrites => _draftBuffer.writes;
  final _scrolls = <String, ScrollController>{};
  final _busy = <String>{};
  bool _failed = false;
  bool _loading = false;
  String? _shownId;
  String? _exportedId;
  bool _attachmentTooLarge = false;
  bool _attachmentFailed = false;
  ConversationFileAttachments get _attachments =>
      _fileAttachments[_repository] ??= ConversationFileAttachments(
        _repository,
      );

  bool _canModifyAttachments(String id) {
    final conversation = _repository.find(id);
    return mounted &&
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
    setState(() {
      _attachmentTooLarge = false;
      _attachmentFailed = false;
    });
    try {
      final file = await widget.pickAttachment();
      if (file == null || !mounted || !identical(repository, _repository)) {
        return;
      }
      await _attachments.attach(
        id,
        file,
        generation: widget.readDatasetGeneration!(),
        locale: Localizations.localeOf(context).toLanguageTag(),
        canModify: () =>
            identical(repository, _repository) && _canModifyAttachments(id),
      );
    } on TextFileTooLargeException {
      if (mounted) setState(() => _attachmentTooLarge = true);
    } catch (_) {
      if (mounted) setState(() => _attachmentFailed = true);
    }
  });

  Future<void> _retryAttachment(String id) =>
      _perform('attachment-$id', () async {
        final repository = _repository;
        if (widget.recoverConversations != null) {
          await widget.recoverConversations!();
        } else {
          await repository.load();
        }
        if (!mounted || !identical(repository, _repository)) return;
        await _attachments.retry(
          id,
          generation: widget.readDatasetGeneration!(),
          canModify: () => _canModifyAttachments(id),
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
    _synchronizeDraft();
    if (!_repository.isLoaded) unawaited(_load());
  }

  @override
  void didUpdateWidget(AgentConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != _repository) {
      oldWidget.repository.removeListener(_changed);
      _repository.addListener(_changed);
      _draftBuffer = _draftBuffers[_repository] ??= _AgentDraftBuffer();
      _shownId = null;
      _synchronizeDraft();
      if (!_repository.isLoaded) unawaited(_load());
    }
    if (oldWidget.delegate.state != widget.delegate.state) {
      oldWidget.delegate.state.removeListener(_changed);
      widget.delegate.state.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_changed);
    widget.delegate.state.removeListener(_changed);
    _composer.dispose();
    _composerFocus.dispose();
    for (final scroll in _scrolls.values) {
      scroll.dispose();
    }
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
    for (final conversation in _repository.conversations) {
      final id = conversation.id;
      if (!_drafts.containsKey(id) || _drafts[id] == _savedDrafts[id]) {
        _drafts[id] = conversation.draft;
        _savedDrafts[id] = conversation.draft;
      }
    }
    final selected = _repository.selected;
    if (_shownId != selected?.id) {
      _attachmentTooLarge = false;
      _attachmentFailed = false;
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
    final id = _repository.selectedId;
    final scroll = id == null ? null : _scrolls[id];
    final nearEnd =
        scroll == null ||
        !scroll.hasClients ||
        scroll.position.maxScrollExtent - scroll.offset < 100;
    setState(_synchronizeDraft);
    if (nearEnd) _scrollToEnd(id);
  }

  void _scrollToEnd(String? id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _repository.selectedId != id) return;
      final scroll = _scrolls[id];
      if (scroll != null && scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
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
    }
  }

  Future<void> _perform(
    String action,
    Future<void> Function() operation,
  ) async {
    if (_busy.contains(action)) return;
    setState(() {
      _busy.add(action);
      _failed = false;
    });
    try {
      await operation();
    } catch (_) {
      // Runtime-specific details arrive separately through its redacted state.
      if (mounted) setState(() => _failed = true);
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

  Future<void> _newConversation() => _perform('new', () async {
    final repository = _repository;
    final title = AppLocalizations.of(context).agentNewConversation;
    await _flushDraft(_repository.selectedId);
    if (!mounted || !identical(repository, _repository)) return;
    await repository.create(title: title, mode: _runtime.defaultMode);
    if (mounted) _composerFocus.requestFocus();
  });

  Future<void> _select(String id) => _perform('select', () async {
    final repository = _repository;
    await _flushDraft(_repository.selectedId);
    if (!mounted || !identical(repository, _repository)) return;
    await repository.select(id);
  });

  Future<void> _send(AgentConversation conversation) async {
    final repository = _repository;
    final delegate = widget.delegate;
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    await _perform('send-${conversation.id}', () async {
      await _flushDraft(conversation.id);
      if (!identical(repository, _repository)) return;
      await delegate.send(conversation.id, text);
    });
  }

  Future<void> _queue(
    AgentConversation conversation, {
    required bool steering,
  }) async {
    final repository = _repository;
    final delegate = widget.delegate;
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    await _perform('queue-${conversation.id}', () async {
      await _flushDraft(conversation.id);
      if (!identical(repository, _repository)) return;
      if (steering) {
        await delegate.steer(conversation.id, text);
      } else {
        await delegate.queueFollowUp(conversation.id, text);
      }
    });
  }

  Future<void> _rename(AgentConversation conversation) async {
    final repository = _repository;
    final title = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameConversationDialog(title: conversation.title),
    );
    if (title == null || !mounted || !identical(repository, _repository)) {
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
    final repository = _repository;
    final delegate = widget.delegate;
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true || !mounted || !identical(repository, _repository)) {
      return;
    }
    await _perform('delete', () async {
      await delegate.stop(conversation.id);
      if (!identical(repository, _repository)) return;
      await repository.delete(conversation.id);
      _drafts.remove(conversation.id);
      _savedDrafts.remove(conversation.id);
      unawaited(_draftWrites.remove(conversation.id));
    });
  }

  Future<void> _showHistory() async {
    final l = AppLocalizations.of(context);
    var showArchived = false;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, updateHistory) => AlertDialog(
          title: Text(l.agentConversations),
          content: SizedBox(
            width: 420,
            child: ListenableBuilder(
              listenable: _repository,
              builder: (context, _) => ListView(
                shrinkWrap: true,
                children: [
                  SwitchListTile(
                    key: const ValueKey('agent-history-archived'),
                    title: Text(l.agentArchivedConversations),
                    value: showArchived,
                    onChanged: (value) =>
                        updateHistory(() => showArchived = value),
                  ),
                  for (final conversation
                      in _repository.conversations.reversed.where(
                        (item) => item.archived == showArchived,
                      ))
                    ListTile(
                      key: ValueKey('agent-history-${conversation.id}'),
                      title: Text(conversation.title),
                      selected: conversation.id == _repository.selectedId,
                      onTap: () => Navigator.of(context).pop(conversation.id),
                      trailing: conversation.archived
                          ? IconButton(
                              key: ValueKey('agent-restore-${conversation.id}'),
                              tooltip: l.agentRestoreConversation,
                              onPressed:
                                  _repository.canWrite &&
                                      _runtime.enabled &&
                                      !_runtime.maintenance
                                  ? () => _perform(
                                      'archive-${conversation.id}',
                                      () => widget.delegate.setArchived(
                                        conversation.id,
                                        false,
                                      ),
                                    )
                                  : null,
                              icon: const Icon(Icons.unarchive_outlined),
                            )
                          : null,
                    ),
                  if (!_repository.conversations.any(
                    (item) => item.archived == showArchived,
                  ))
                    Text(l.agentEmptyHistory),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.cancel),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) await _select(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final conversation = _repository.selected;
    final runtime = _runtime;
    final writable =
        _repository.canWrite && runtime.enabled && !runtime.maintenance;
    final state = conversation == null
        ? const AgentUiRunState()
        : runtime.runFor(conversation.id);
    return SkedSurface(
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final smallHeight =
                constraints.maxHeight < 520 ||
                (MediaQuery.textScalerOf(context).scale(14) > 22 &&
                    (constraints.maxHeight < 740 ||
                        constraints.maxWidth < 600));
            final header = _header(l, conversation, writable);
            final body = <Widget>[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_failed || (!_repository.canWrite && !_loading))
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.agentOperationFailed,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                _notice(l.agentConfigureFirst),
              if (conversation == null || conversation.messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.agentEmptyConversation),
                ),
              if (conversation != null) ..._messageWidgets(conversation, l),
              if (state.streamingText.isNotEmpty)
                _messageText(
                  l.agentAssistant,
                  state.streamingText,
                  key: const ValueKey('agent-streaming-text'),
                ),
              if (state.phase == AgentUiPhase.running) _notice(l.agentRunning),
              if (state.phase == AgentUiPhase.stopped ||
                  (state.phase == AgentUiPhase.idle &&
                      conversation?.status == ConversationStatus.interrupted))
                _notice(l.agentStopped),
              if (state.phase == AgentUiPhase.failed ||
                  state.errorMessage != null)
                _notice(_errorMessage(state.errorMessage, l), error: true),
              if (conversation != null && state.pendingApproval != null)
                _approval(conversation.id, state.pendingApproval!, writable, l),
            ];
            final composer = conversation == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: writable && !_busy.contains('new')
                          ? _newConversation
                          : null,
                      icon: const Icon(Icons.add),
                      label: Text(l.agentNewConversation),
                    ),
                  )
                : _composerWidget(
                    conversation,
                    state,
                    writable && runtime.configured && !conversation.archived,
                    l,
                  );
            final scroll = _scrolls.putIfAbsent(
              conversation?.id ?? '',
              ScrollController.new,
            );
            if (smallHeight) {
              return SingleChildScrollView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, ...body, composer],
                ),
              );
            }
            return Column(
              children: [
                header,
                Expanded(
                  child: ListView(
                    controller: scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: body,
                  ),
                ),
                composer,
              ],
            );
          },
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
    AppLocalizations l,
    AgentConversation? conversation,
    bool writable,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: widget.showTitle
                    ? Text(
                        l.agentTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      )
                    : const SizedBox.shrink(),
              ),
              IconButton(
                key: const ValueKey('agent-new'),
                tooltip: l.agentNewConversation,
                onPressed: writable && !_busy.contains('new')
                    ? _newConversation
                    : null,
                icon: const Icon(Icons.add),
              ),
              IconButton(
                key: const ValueKey('agent-history'),
                tooltip: l.agentConversations,
                onPressed: _repository.isLoaded ? _showHistory : null,
                icon: const Icon(Icons.history),
              ),
              IconButton(
                key: const ValueKey('agent-settings'),
                tooltip: l.agentModelSettings,
                onPressed: _runtime.maintenance
                    ? null
                    : widget.delegate.openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          if (conversation != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    conversation.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('agent-conversation-menu'),
                  tooltip: l.agentConversationActions,
                  enabled:
                      writable &&
                      !_busy.contains('delete') &&
                      !_busy.contains('rename'),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        unawaited(_rename(conversation));
                      case 'delete':
                        unawaited(_delete(conversation));
                      case 'archive':
                        unawaited(
                          _perform(
                            'archive-${conversation.id}',
                            () => widget.delegate.setArchived(
                              conversation.id,
                              !conversation.archived,
                            ),
                          ),
                        );
                      case 'export':
                        unawaited(
                          _perform('export-${conversation.id}', () async {
                            final saved = await widget.onExportConversation!(
                              conversation.id,
                            );
                            if (mounted) {
                              setState(
                                () => _exportedId = saved
                                    ? conversation.id
                                    : null,
                              );
                            }
                          }),
                        );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'rename', child: Text(l.rename)),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(
                        conversation.archived
                            ? l.agentRestoreConversation
                            : l.agentArchiveConversation,
                      ),
                    ),
                    if (widget.onExportConversation != null)
                      PopupMenuItem(
                        value: 'export',
                        child: Text(l.agentExportConversation),
                      ),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final mode in AgentPermissionMode.values)
                  ChoiceChip(
                    key: ValueKey('agent-mode-${mode.name}'),
                    label: Text(_modeLabel(l, mode)),
                    selected: conversation.mode == mode,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected:
                        !writable ||
                            conversation.archived ||
                            _busy.contains('mode-${conversation.id}')
                        ? null
                        : (_) => _perform(
                            'mode-${conversation.id}',
                            () =>
                                widget.delegate.setMode(conversation.id, mode),
                          ),
                  ),
              ],
            ),
            Text(
              _modeDescription(l, conversation.mode),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _messageWidgets(
    AgentConversation conversation,
    AppLocalizations l,
  ) {
    final toolNames = {
      for (final message in conversation.messages)
        for (final call in message.toolCalls) call.id: call.name,
    };
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
            SelectableText(source.text),
          ],
        ),
      for (final message in conversation.messages.where(
        (message) => !_isInternalHostOperation(message),
      ))
        if (_queuedInput(message) case final String text)
          _messageText(
            l.agentQueuedMessages(1),
            text,
            key: ValueKey('agent-message-${message.id}'),
          )
        else if (message.role == ConversationRole.tool &&
            AgentOperationCard.parse(message.text) != null)
          AgentOperationCard(
            key: ValueKey('agent-message-${message.id}'),
            receipt: AgentOperationCard.parse(message.text)!,
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
                      AgentOperationCard.parse(message.text)!['operationId']
                          as String,
                    ),
                  )
                : null,
            onOpenResource: widget.onOpenResource == null
                ? null
                : (ref) => _perform(
                    'view-${message.id}',
                    () => widget.onOpenResource!(ref),
                  ),
          )
        else if (message.role == ConversationRole.tool)
          ExpansionTile(
            key: ValueKey('agent-message-${message.id}'),
            title: Text(l.agentToolResponse),
            subtitle: Text(
              toolNames[message.toolCallId] ?? message.toolCallId ?? '',
            ),
            childrenPadding: const EdgeInsets.all(16),
            children: [SelectableText(_prettyJson(message.text))],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message.text.isNotEmpty)
                _messageText(
                  switch (message.role) {
                    ConversationRole.user => l.agentYou,
                    ConversationRole.assistant => l.agentAssistant,
                    _ => l.agentNotice,
                  },
                  message.text,
                  key: ValueKey('agent-message-${message.id}'),
                ),
              for (final call in message.toolCalls)
                ExpansionTile(
                  key: ValueKey('agent-tool-${call.id}'),
                  title: Text(call.name),
                  subtitle: Text(l.agentToolArguments),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [SelectableText(_prettyJson(call.arguments))],
                ),
            ],
          ),
    ];
  }

  Widget _messageText(String role, String text, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SelectableText(text),
      ],
    ),
  );

  String _errorMessage(String? code, AppLocalizations l) {
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
    if (code?.startsWith('provider.') ?? false) return l.agentRequestFailed;
    return l.agentRunFailed;
  }

  Widget _approval(
    String id,
    AgentUiApproval plan,
    bool writable,
    AppLocalizations l,
  ) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          plan.details['kind'] == 'httpTransport'
              ? l.agentHttpTransportApproval
              : l.agentApprovalRequired,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        AgentPlanPreview(details: plan.details),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('agent-approve'),
              onPressed: writable && !_busy.contains('approval-$id')
                  ? () => _perform(
                      'approval-$id',
                      () => widget.delegate.approve(id, plan.id),
                    )
                  : null,
              child: Text(
                plan.details['kind'] == 'httpTransport'
                    ? l.confirm
                    : l.agentApprove,
              ),
            ),
            OutlinedButton(
              key: const ValueKey('agent-reject'),
              onPressed: writable && !_busy.contains('approval-$id')
                  ? () => _perform(
                      'approval-$id',
                      () => widget.delegate.reject(id, plan.id),
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
  );

  Widget _composerWidget(
    AgentConversation conversation,
    AgentUiRunState state,
    bool canSend,
    AppLocalizations l,
  ) {
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter, control: true):
              _SendAgentMessageIntent(),
        },
        child: Actions(
          actions: {
            _SendAgentMessageIntent: CallbackAction<_SendAgentMessageIntent>(
              onInvoke: (_) {
                if (canSend && !sending) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('agent-composer'),
                controller: _composer,
                focusNode: _composerFocus,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 128 * 1024,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  filled: true,
                  labelText: l.agentMessageHint,
                  counterText: '',
                ),
                onChanged: (value) => _draftChanged(conversation.id, value),
              ),
              const SizedBox(height: 8),
              if (widget.delegate.pendingInputCount(conversation.id) > 0)
                Text(
                  l.agentQueuedMessages(
                    widget.delegate.pendingInputCount(conversation.id),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (widget.readDatasetGeneration != null)
                      IconButton(
                        key: const ValueKey('agent-attach-file'),
                        tooltip: l.agentAttachFile,
                        icon: const Icon(Icons.attach_file),
                        onPressed:
                            _canModifyAttachments(conversation.id) &&
                                _attachments.pending(conversation.id) == null &&
                                !_busy.contains('attachment-${conversation.id}')
                            ? () => _attachFile(conversation.id)
                            : null,
                      ),
                    if (active && _composer.text.trim().isNotEmpty) ...[
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
                    if (!active &&
                        (state.phase == AgentUiPhase.stopped ||
                            conversation.status ==
                                ConversationStatus.interrupted ||
                            widget.delegate.pendingInputCount(conversation.id) >
                                0))
                      OutlinedButton(
                        key: const ValueKey('agent-continue'),
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
                        child: Text(l.agentContinue),
                      ),
                    if (active)
                      OutlinedButton.icon(
                        key: const ValueKey('agent-stop'),
                        onPressed: _busy.contains('stop-${conversation.id}')
                            ? null
                            : () => _perform(
                                'stop-${conversation.id}',
                                () => widget.delegate.stop(conversation.id),
                              ),
                        icon: const Icon(Icons.stop),
                        label: Text(l.agentStop),
                      )
                    else
                      FilledButton.icon(
                        key: const ValueKey('agent-send'),
                        onPressed:
                            canSend &&
                                !sending &&
                                _composer.text.trim().isNotEmpty
                            ? () => _send(conversation)
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                        label: Text(l.agentSend),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendAgentMessageIntent extends Intent {
  const _SendAgentMessageIntent();
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

String _prettyJson(String text) {
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
  } on FormatException {
    return text;
  }
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
