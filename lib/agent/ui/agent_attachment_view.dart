import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/expressive_dialog.dart';
import '../../widgets/sked_popup_menu.dart';
import '../attachments/attachment_repository.dart';

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
class AgentAttachmentList extends StatelessWidget {
  const AgentAttachmentList({
    super.key,
    required this.attachments,
    required this.ids,
    required this.repository,
    this.delivery = AttachmentDelivery.local,
    this.onRemove,
    this.onUseAgain,
  });

  final List<ConversationAttachment> attachments;
  final List<String> ids;
  final AttachmentRepository repository;
  final AttachmentDelivery delivery;
  final ValueChanged<String>? onRemove;
  final ValueChanged<String>? onUseAgain;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final byId = {
      for (final attachment in attachments) attachment.id: attachment,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in ids)
          Padding(
            key: ValueKey('agent-attachment-$id'),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Card.outlined(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Icon(_icon(byId[id]?.mediaType), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            byId[id]?.name ?? l.agentFileMissing,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (byId[id] case final attachment?)
                            Text(
                              '${_size(attachment.byteLength)} · ${attachment.mediaType}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Text(
                            agentAttachmentStatus(l, delivery),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SkedPopupMenuButton<String>(
                      key: ValueKey('agent-attachment-menu-$id'),
                      tooltip: l.agentFilePreview,
                      itemBuilder: (context) => [
                        if (byId[id] != null)
                          PopupMenuItem(
                            value: 'preview',
                            child: Text(l.agentFilePreview),
                          ),
                        if (onUseAgain != null)
                          PopupMenuItem(
                            value: 'reuse',
                            child: Text(l.agentFileUseAgain),
                          ),
                        if (onRemove != null)
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(l.agentRemoveAttachment),
                          ),
                      ],
                      onSelected: (action) async {
                        switch (action) {
                          case 'preview':
                            if (byId[id] case final attachment?) {
                              await showExpressiveDialog<void>(
                                context: context,
                                builder: (_) => _AttachmentPreview(
                                  attachment: attachment,
                                  repository: repository,
                                ),
                              );
                            }
                          case 'reuse':
                            onUseAgain?.call(id);
                          case 'remove':
                            onRemove?.call(id);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (delivery == AttachmentDelivery.accepted && ids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.agentFileReceivedHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
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
  });
  final ConversationAttachment attachment;
  final AttachmentRepository repository;
  @override
  State<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<_AttachmentPreview> {
  final _cancellation = AttachmentCancellation();
  late final Future<Uint8List?> _content = _read();
  bool get _image => const {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  }.contains(widget.attachment.mediaType);

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
    _cancellation.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            SelectableText(
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

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
