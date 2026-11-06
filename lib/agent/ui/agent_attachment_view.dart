import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/expressive_dialog.dart';
import '../../widgets/sked_popup_menu.dart';
import '../../widgets/sked_task_session.dart';
import '../attachments/attachment_repository.dart';
import 'agent_selectable_text.dart';

String agentAttachmentError(AppLocalizations l, AttachmentError error) =>
    switch (error) {
      AttachmentError.tooLarge => l.agentFileTooLarge,
      AttachmentError.changed => l.agentFileChanged,
      AttachmentError.missing => l.agentFileMissing,
      AttachmentError.corrupt => l.agentFileCorrupt,
      AttachmentError.cancelled => l.agentFileCancelled,
      AttachmentError.unsupported => l.agentFileUnsupported,
      AttachmentError.conflict => l.agentFileConflict,
      AttachmentError.invalidMetadata ||
      AttachmentError.unavailable => l.agentFileUnavailable,
    };

String agentAttachmentStatus(AppLocalizations l, AttachmentDelivery delivery) =>
    switch (delivery) {
      AttachmentDelivery.local => l.agentFileLocal,
      AttachmentDelivery.saving => l.agentFileSaving,
      AttachmentDelivery.preparing => l.agentFilePreparing,
      AttachmentDelivery.sending => l.agentFileSending,
      AttachmentDelivery.accepted => l.agentFileAccepted,
      AttachmentDelivery.failed => l.agentFileFailed,
      AttachmentDelivery.cancelled => l.agentFileCancelled,
      AttachmentDelivery.unknown => l.agentFileUnknown,
    };

/// File cards contain local metadata. Preview reads the private repository only
/// after a user action; neither filenames nor model Markdown trigger a network
/// request, external app, or original-device path lookup.
class AgentAttachmentList extends StatefulWidget {
  const AgentAttachmentList({
    super.key,
    required this.conversationId,
    required this.attachments,
    required this.ids,
    required this.repository,
    this.active = true,
    this.interactive = true,
    this.delivery = AttachmentDelivery.local,
    this.onRemove,
    this.onUseAgain,
  });

  final String conversationId;
  final List<ConversationAttachment> attachments;
  final List<String> ids;
  final AttachmentRepository repository;
  final bool active;
  final bool interactive;
  final AttachmentDelivery delivery;
  final ValueChanged<String>? onRemove;
  final ValueChanged<String>? onUseAgain;

  @override
  State<AgentAttachmentList> createState() => _AgentAttachmentListState();
}

class _AgentAttachmentListState extends State<AgentAttachmentList> {
  final _menus = <String, SkedTaskSession>{};
  final _previews = <SkedTaskSession>{};
  int _generation = 0;

  bool get _enabled => mounted && widget.active && widget.interactive;

  ConversationAttachment? _attachment(String id) =>
      widget.attachments.where((attachment) => attachment.id == id).firstOrNull;

  @override
  void didUpdateWidget(AgentAttachmentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.repository != widget.repository ||
        (oldWidget.active && !widget.active) ||
        (oldWidget.interactive && !widget.interactive)) {
      _generation++;
    }
    // Check at the unavailable boundary itself. Returning to the same chat or
    // restoring interaction must never revive a previously opened menu.
    for (final session in [..._menus.values, ..._previews]) {
      session.check();
    }
  }

  @override
  void dispose() {
    for (final session in _menus.values) {
      session.dispose();
    }
    _menus.clear();
    for (final session in _previews) {
      session.invalidate();
    }
    super.dispose();
  }

  void _openMenu(String id, int generation) {
    if (!_enabled || generation != _generation) return;
    _menus.remove(id)?.dispose();
    final conversationId = widget.conversationId;
    final repository = widget.repository;
    final attachment = _attachment(id);
    _menus[id] = SkedTaskSession(
      ownerRoute: ModalRoute.of(context),
      parent: SkedTaskSessionScope.maybeOf(context)?.session,
      isOwnerActive: () => _enabled,
      isTargetCurrent: () =>
          conversationId == widget.conversationId &&
          identical(repository, widget.repository) &&
          widget.ids.contains(id) &&
          _sameAttachment(attachment, _attachment(id)),
    );
  }

  void _cancelMenu(String id, int generation) {
    if (generation != _generation) return;
    _menus.remove(id)?.dispose();
  }

  Future<void> _select(String id, String action, int generation) async {
    if (!_enabled || generation != _generation) return;
    final session = _menus.remove(id);
    if (session == null) return;
    try {
      if (!session.isCurrent) return;
      switch (action) {
        case 'preview':
          if (_attachment(id) case final attachment?) {
            final repository = widget.repository;
            _previews.add(session);
            await showExpressiveDialog<void>(
              context: context,
              session: session,
              builder: (_) => _AttachmentPreview(
                attachment: attachment,
                repository: repository,
                session: session,
              ),
            );
          }
        case 'reuse':
          widget.onUseAgain?.call(id);
        case 'remove':
          widget.onRemove?.call(id);
      }
    } finally {
      _previews.remove(session);
      session.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final byId = {
      for (final attachment in widget.attachments) attachment.id: attachment,
    };
    final generation = _generation;
    return FocusScope(
      canRequestFocus: _enabled,
      descendantsAreFocusable: _enabled,
      descendantsAreTraversable: _enabled,
      child: IgnorePointer(
        ignoring: !_enabled,
        child: ExcludeSemantics(
          excluding: !_enabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final id in widget.ids)
                Padding(
                  key: ValueKey('agent-attachment-$id'),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Card.outlined(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        8,
                        4,
                        8,
                      ),
                      child: Row(
                        children: [
                          Icon(_icon(byId[id]?.mediaType), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tooltip(
                                  message: byId[id]?.name ?? l.agentFileMissing,
                                  excludeFromSemantics: true,
                                  child: Text(
                                    byId[id]?.name ?? l.agentFileMissing,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (byId[id] case final attachment?)
                                      Text(
                                        _size(attachment.byteLength),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    Text(
                                      agentAttachmentStatus(l, widget.delivery),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SkedPopupMenuButton<String>(
                            key: ValueKey('agent-attachment-menu-$id'),
                            tooltip: l.agentFilePreview,
                            enabled:
                                _enabled &&
                                (byId[id] != null ||
                                    widget.onUseAgain != null ||
                                    widget.onRemove != null),
                            onOpened: () => _openMenu(id, generation),
                            onCanceled: () => _cancelMenu(id, generation),
                            itemBuilder: (context) => [
                              if (byId[id] != null)
                                SkedPopupMenuItem(
                                  value: 'preview',
                                  child: Text(l.agentFilePreview),
                                ),
                              if (widget.onUseAgain != null)
                                SkedPopupMenuItem(
                                  value: 'reuse',
                                  child: Text(l.agentFileUseAgain),
                                ),
                              if (widget.onRemove != null)
                                SkedPopupMenuItem(
                                  value: 'remove',
                                  child: Text(l.agentRemoveAttachment),
                                ),
                            ],
                            onSelected: (action) =>
                                _select(id, action, generation),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.delivery == AttachmentDelivery.accepted &&
                  widget.ids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l.agentFileReceivedHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AgentAttachmentProgress extends StatelessWidget {
  const AgentAttachmentProgress({
    super.key,
    required this.progress,
    this.onCancel,
  });
  final AttachmentProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(agentAttachmentStatus(l, progress.delivery)),
              ),
              if (onCancel != null)
                IconButton(
                  key: const ValueKey('agent-cancel-attachment'),
                  tooltip: l.cancel,
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          LinearProgressIndicator(
            value: progress.totalBytes > 0
                ? (progress.completedBytes / progress.totalBytes).clamp(
                    0.0,
                    1.0,
                  )
                : null,
            semanticsLabel: agentAttachmentStatus(l, progress.delivery),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatefulWidget {
  const _AttachmentPreview({
    required this.attachment,
    required this.repository,
    required this.session,
  });
  final ConversationAttachment attachment;
  final AttachmentRepository repository;
  final SkedTaskSession session;
  @override
  State<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<_AttachmentPreview> {
  final _cancellation = AttachmentCancellation();
  late final Future<Uint8List?> _content = _read();
  ModalRoute<dynamic>? _route;
  bool get _image => const {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  }.contains(widget.attachment.mediaType);

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_checkSession);
    _checkSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  void _checkSession() {
    if (!widget.session.isCurrent) _cancellation.cancel();
  }

  Future<Uint8List?> _read() async {
    if (_image) {
      return widget.repository.readBytes(
        widget.attachment,
        cancellation: _cancellation,
      );
    }
    await widget.repository.verify(
      widget.attachment,
      cancellation: _cancellation,
    );
    return null;
  }

  @override
  void dispose() {
    widget.session.removeListener(_checkSession);
    _cancellation.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.session.isCurrent) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return AlertDialog(
      key: const ValueKey('agent-attachment-preview'),
      scrollable: true,
      title: Text(widget.attachment.name),
      content: SizedBox(
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AgentSelectableText(
              '${_size(widget.attachment.byteLength)} · ${widget.attachment.mediaType}',
            ),
            const SizedBox(height: 16),
            FutureBuilder<Uint8List?>(
              future: _content,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return Text(
                    agentAttachmentError(
                      l,
                      error is AttachmentException
                          ? error.code
                          : AttachmentError.unavailable,
                    ),
                  );
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data case final bytes?) {
                  return Image.memory(
                    bytes,
                    cacheWidth: 1200,
                    fit: BoxFit.contain,
                    semanticLabel: widget.attachment.name,
                    errorBuilder: (_, _, _) => Text(l.agentFilePreviewFailed),
                  );
                }
                return Text(l.agentFileNoPreview);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted &&
                widget.session.isCurrent &&
                _route?.isCurrent == true) {
              _route!.navigator?.pop();
            }
          },
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

bool _sameAttachment(
  ConversationAttachment? first,
  ConversationAttachment? second,
) =>
    identical(first, second) ||
    (first != null &&
        second != null &&
        first.id == second.id &&
        first.name == second.name &&
        first.mediaType == second.mediaType &&
        first.byteLength == second.byteLength &&
        first.digest == second.digest);

IconData _icon(String? mediaType) => mediaType?.startsWith('image/') == true
    ? Icons.image_outlined
    : mediaType?.startsWith('audio/') == true
    ? Icons.audio_file_outlined
    : mediaType?.startsWith('video/') == true
    ? Icons.video_file_outlined
    : Icons.insert_drive_file_outlined;

String _size(int bytes) => bytes >= 1000 * 1000
    ? '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB'
    : bytes >= 1000
    ? '${(bytes / 1000).toStringAsFixed(1)} kB'
    : '$bytes B';
