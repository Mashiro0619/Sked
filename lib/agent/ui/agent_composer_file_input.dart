part of 'agent_conversation_view.dart';

class _AgentDesktopInputBatch {
  _AgentDesktopInputBatch({
    required this.conversationId,
    required this.repository,
    required this.service,
    required this.uiGeneration,
    required this.dataGeneration,
    required this.runId,
    required this.queuedInputId,
    required this.files,
  });

  final String conversationId;
  final ConversationViewRepository repository;
  final AgentAttachmentController service;
  final int uiGeneration;
  final String? dataGeneration;
  final String? runId;
  final String? queuedInputId;
  final List<AgentDesktopFile> files;
  AgentAttachmentInput? input;
  int next = 0;
  bool cancelled = false;
}

extension _AgentComposerFileInput on _AgentConversationViewState {
  void _discardStaleDesktopInput() {
    final batch = _desktopInputBatch;
    if (batch == null) return;
    final conversation = _repository.find(batch.conversationId);
    if (!identical(_repository, batch.repository) ||
        !identical(widget.binaryAttachments, batch.service) ||
        widget.readDatasetGeneration?.call() != batch.dataGeneration ||
        conversation == null ||
        conversation.runId != batch.runId ||
        conversation.queuedInputs.lastOrNull?.id != batch.queuedInputId) {
      _retireDesktopInput();
    }
  }

  bool _desktopInputOwnerCurrent(_AgentDesktopInputBatch batch) {
    final conversation = _repository.find(batch.conversationId);
    return identical(_desktopInputBatch, batch) &&
        mounted &&
        widget.active &&
        widget.interactive &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.of(context)?.isActive != false &&
        batch.uiGeneration == _uiGeneration &&
        _repository.selectedId == batch.conversationId &&
        identical(_repository, batch.repository) &&
        identical(widget.binaryAttachments, batch.service) &&
        widget.readDatasetGeneration?.call() == batch.dataGeneration &&
        conversation != null &&
        !conversation.archived &&
        conversation.runId == batch.runId &&
        conversation.queuedInputs.lastOrNull?.id == batch.queuedInputId;
  }

  bool _desktopInputCurrent(_AgentDesktopInputBatch batch) =>
      !batch.cancelled &&
      _desktopInputOwnerCurrent(batch) &&
      _repository.canWrite &&
      _runtime.enabled &&
      !_runtime.maintenance &&
      !_busy.contains('restore-queued-${batch.conversationId}');

  Future<void> _acceptDesktopFiles(
    String conversationId,
    List<AgentDesktopFile> files,
  ) async {
    final service = widget.binaryAttachments;
    final conversation = _repository.find(conversationId);
    if (service == null ||
        service is! AgentAttachmentInputOwner ||
        conversation == null ||
        files.isEmpty ||
        _desktopInputBatch != null ||
        !_canModifyBinaryAttachments(conversationId) ||
        _busy.contains('attachment-$conversationId') ||
        service.hasPending(conversationId) ||
        service.isImporting(conversationId)) {
      return;
    }
    final batch = _AgentDesktopInputBatch(
      conversationId: conversationId,
      repository: _repository,
      service: service,
      uiGeneration: _uiGeneration,
      dataGeneration: widget.readDatasetGeneration?.call(),
      runId: conversation.runId,
      queuedInputId: conversation.queuedInputs.lastOrNull?.id,
      files: List.unmodifiable(files),
    );
    _updateFileInputState(() {
      _desktopInputBatch = batch;
      _desktopDropFolderRejected = false;
    });
    await _continueDesktopInput(batch);
  }

  Future<void> _continueDesktopInput(_AgentDesktopInputBatch batch) =>
      _binaryAction(batch.conversationId, (service) async {
        if (!identical(_desktopInputBatch, batch) ||
            !identical(service, batch.service)) {
          return;
        }
        batch.cancelled = false;
        try {
          if (!batch.repository.canWrite) {
            if (widget.recoverConversations case final recover?) {
              await recover();
            } else {
              await batch.repository.load();
            }
          }
          if (!_desktopInputCurrent(batch)) {
            throw const AttachmentException(AttachmentError.conflict);
          }
          batch.input ??= await (service as AgentAttachmentInputOwner)
              .captureInput(
                batch.conversationId,
                canModify: () => _desktopInputCurrent(batch),
              );
          while (batch.next < batch.files.length) {
            if (!_desktopInputCurrent(batch)) {
              throw const AttachmentException(AttachmentError.conflict);
            }
            final source = batch.files[batch.next];
            if (service.hasPending(batch.conversationId)) {
              await service.retry(
                batch.conversationId,
                canModify: () => _desktopInputCurrent(batch),
              );
            } else if (await source.isDirectory) {
              if (!_desktopInputCurrent(batch)) {
                throw const AttachmentException(AttachmentError.conflict);
              }
              _updateFileInputState(() => _desktopDropFolderRejected = true);
            } else {
              await source.read(
                (file) => batch.input!.attach(
                  file,
                  canModify: () => _desktopInputCurrent(batch),
                ),
              );
            }
            batch.next++;
          }
          if (mounted && identical(_desktopInputBatch, batch)) {
            _updateFileInputState(() => _desktopInputBatch = null);
          }
        } catch (_) {
          if (!identical(_desktopInputBatch, batch)) return;
          if (batch.cancelled) {
            throw const AttachmentException(AttachmentError.cancelled);
          }
          rethrow;
        }
      }, isOwnerCurrent: () => _desktopInputOwnerCurrent(batch));

  void _cancelDesktopInput(_AgentDesktopInputBatch batch) {
    if (!identical(_desktopInputBatch, batch)) return;
    batch.cancelled = true;
    batch.service.cancelImport(batch.conversationId);
  }

  Future<void> _discardDesktopInput(String conversationId) =>
      _binaryAction(conversationId, (service) async {
        final batch = _desktopInputBatch;
        if (batch?.conversationId == conversationId) {
          batch!.cancelled = true;
        }
        await service.discardPending(conversationId);
        if (mounted && identical(_desktopInputBatch, batch)) {
          _updateFileInputState(() => _desktopInputBatch = null);
        }
      });

  void _retireDesktopInput() {
    _desktopDropFolderRejected = false;
    final batch = _desktopInputBatch;
    if (batch == null) return;
    _cancelDesktopInput(batch);
    _desktopInputBatch = null;
    _binaryAttachmentError = null;
  }
}
