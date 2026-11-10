part of 'agent_conversation_view.dart';

extension _AgentComposerClipboard on _AgentConversationViewState {
  bool _hasClipboardInputFocus(String id) =>
      _uiActive &&
      _repository.selectedId == id &&
      _composerFocus.hasFocus &&
      !(_composer.value.composing.isValid &&
          !_composer.value.composing.isCollapsed);

  Widget _desktopClipboardScope(
    AgentConversation conversation,
    Widget child,
  ) => Actions(
    actions: {
      PasteTextIntent: AgentDesktopPasteAction(
        shouldRead: () =>
            agentDesktopClipboardSupported &&
            widget.binaryAttachments is AgentAttachmentInputOwner &&
            _hasClipboardInputFocus(conversation.id) &&
            (_busy.contains('clipboard-${conversation.id}') ||
                (_desktopInputBatch == null &&
                    _canModifyBinaryAttachments(conversation.id) &&
                    !_busy.contains('attachment-${conversation.id}') &&
                    !widget.binaryAttachments!.hasPending(conversation.id) &&
                    !widget.binaryAttachments!.isImporting(conversation.id))),
        onPaste: (intent) => _pasteDesktopClipboard(conversation.id, intent),
      ),
    },
    child: child,
  );

  Future<void> _pasteDesktopClipboard(String id, PasteTextIntent intent) async {
    if (_busy.contains('clipboard-$id') || !_hasClipboardInputFocus(id)) return;
    final repository = _repository;
    final service = widget.binaryAttachments;
    final uiGeneration = _uiGeneration;
    final dataGeneration = widget.readDatasetGeneration?.call();
    final conversation = repository.find(id);
    if (conversation == null) return;
    final runId = conversation.runId;
    final queuedInputId = conversation.queuedInputs.lastOrNull?.id;
    final cancellation = AttachmentCancellation();
    _clipboardReadCancellation = cancellation;
    bool current() {
      final currentConversation = _repository.find(id);
      return !cancellation.isCancelled &&
          _uiSessionCurrent(uiGeneration, id) &&
          _hasClipboardInputFocus(id) &&
          _canModifyBinaryAttachments(id) &&
          identical(repository, _repository) &&
          identical(service, widget.binaryAttachments) &&
          dataGeneration == widget.readDatasetGeneration?.call() &&
          currentConversation != null &&
          currentConversation.runId == runId &&
          currentConversation.queuedInputs.lastOrNull?.id == queuedInputId;
    }

    AgentDesktopClipboardPayload? pendingFiles;
    await _perform('clipboard-$id', () async {
      _updateFileInputState(() => _clipboardReadFailed = false);
      try {
        final payload = await cancellation.guard(
          readAgentDesktopClipboard(isCurrent: current),
        );
        if (!current()) return;
        if (payload.files.isNotEmpty) {
          pendingFiles = payload;
          return;
        }
        final text = payload.text;
        final inputContext = _composerFocus.context;
        final value = _composer.value;
        if (text == null ||
            inputContext == null ||
            !inputContext.mounted ||
            !value.selection.isValid) {
          return;
        }
        // Use EditableText's native edit action for formatting, selection and
        // undo. The clipboard was already read, so this cannot start a second
        // async text paste that might finish in a different conversation.
        final selection = value.selection;
        final collapsed = value.copyWith(
          selection: TextSelection.collapsed(
            offset: math.max(selection.baseOffset, selection.extentOffset),
          ),
        );
        Actions.invoke(
          inputContext,
          ReplaceTextIntent(collapsed, text, selection, intent.cause),
        );
      } catch (_) {
        if (current()) {
          _updateFileInputState(() => _clipboardReadFailed = true);
        }
      } finally {
        if (identical(_clipboardReadCancellation, cancellation)) {
          _clipboardReadCancellation = null;
        }
      }
    }, isCurrent: current);
    final payload = pendingFiles;
    if (payload != null && current()) {
      await _acceptDesktopFiles(id, payload.files);
    }
  }

  void _clipboardFocusChanged() {
    if (!_composerFocus.hasFocus) _clipboardReadCancellation?.cancel();
  }
}
