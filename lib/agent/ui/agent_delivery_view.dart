import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/desktop_context_menu.dart';
import '../../widgets/sked_popup_menu.dart';
import '../bridge/generated/api/file_contracts.dart';
import '../delivery/agent_delivery.dart';
import '../files/agent_file_actions.dart';
import 'agent_selectable_text.dart';

class AgentDeliveryView extends StatelessWidget {
  const AgentDeliveryView({
    super.key,
    required this.delivery,
    required this.isSourceCurrent,
  });

  final AgentDelivery delivery;
  final bool Function() isSourceCurrent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final file in delivery.files)
        _FileDeliveryRow(
          key: ValueKey(('delivery-file', file.id)),
          file: file,
          isSourceCurrent: isSourceCurrent,
        ),
      for (final source in delivery.sources)
        _SourceDeliveryRow(
          key: ValueKey(('delivery-source', source.id)),
          source: source,
          isSourceCurrent: isSourceCurrent,
        ),
    ],
  );
}

class _FileDeliveryRow extends StatefulWidget {
  const _FileDeliveryRow({
    super.key,
    required this.file,
    required this.isSourceCurrent,
  });

  final AgentDeliveryFile file;
  final bool Function() isSourceCurrent;

  @override
  State<_FileDeliveryRow> createState() => _FileDeliveryRowState();
}

class _FileDeliveryRowState extends State<_FileDeliveryRow> {
  static const _actions = AgentFileActions();
  bool _busy = false;
  bool _copied = false;
  String? _error;

  List<DesktopAction> _menu([DesktopActionContext? invocation]) {
    final file = widget.file;
    final l = AppLocalizations.of(context);
    bool current() =>
        mounted &&
        widget.file.id == file.id &&
        widget.isSourceCurrent() &&
        invocation?.isCurrent() != false;
    DesktopAction action(
      String id,
      String label,
      IconData icon,
      Future<void> Function() run,
    ) => DesktopAction(
      id: id,
      label: label,
      icon: icon,
      enabled: !_busy && current(),
      onInvoke: () async {
        if (_busy || !current()) return;
        setState(() {
          _busy = true;
          _copied = false;
          _error = null;
        });
        try {
          await run();
          if (current() && id == 'copy-location') {
            setState(() => _copied = true);
          }
        } catch (error) {
          if (current()) {
            setState(() {
              _error =
                  error is PlatformException && error.code == 'noApplication'
                  ? l.agentDeliveryNoViewer
                  : l.desktopFileActionFailed;
            });
          }
        } finally {
          if (mounted && widget.file.id == file.id) {
            setState(() => _busy = false);
          }
        }
      },
    );
    return [
      if (AgentFileActions.supportsOpen(file.resource))
        action(
          'open',
          file.resource.kind == FileResourceKind.androidPath
              ? l.agentDeliveryOpenCopy
              : l.desktopOpenFile,
          Icons.open_in_new,
          () => _actions.open(
            resource: file.resource,
            name: file.name,
            mediaType: file.mediaType,
          ),
        ),
      if (AgentFileActions.supportsReveal(file.resource))
        action(
          'reveal',
          l.desktopRevealFile,
          Icons.folder_open_outlined,
          () => _actions.reveal(file.resource),
        ),
      action(
        'copy-location',
        l.desktopCopyFilePath,
        Icons.copy_outlined,
        () => _actions.copyLocation(file.resource),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final file = widget.file;
    final theme = Theme.of(context);
    final menu = _menu();
    final open = menu.where((action) => action.id == 'open').firstOrNull;
    final label = switch (file.state) {
      AgentDeliveryFileState.saved => l.agentDeliverySaved,
      AgentDeliveryFileState.observed => l.agentDeliveryObserved,
      AgentDeliveryFileState.recovery => l.agentDeliveryRecovery,
    };
    return DesktopContextMenuRegion(
      target: file.id,
      isOwnerCurrent: widget.isSourceCurrent,
      actionsBuilder: _menu,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsetsDirectional.only(top: 8, end: 8),
                  child: Icon(Icons.insert_drive_file_outlined, size: 20),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (open != null)
                        TextButton(
                          onPressed: open.enabled ? open.onInvoke : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: AlignmentDirectional.centerStart,
                          ),
                          child: Text(file.name),
                        )
                      else
                        Text(file.name, style: theme.textTheme.titleSmall),
                      Text(label, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                SkedPopupMenuButton<DesktopAction>(
                  tooltip: l.more,
                  enabled: !_busy && widget.isSourceCurrent(),
                  itemBuilder: (_) => [
                    for (final action in _menu())
                      SkedPopupMenuItem(
                        value: action,
                        enabled: action.enabled,
                        child: Text(action.label),
                      ),
                  ],
                  onSelected: (action) => action.onInvoke?.call(),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_horiz),
                ),
              ],
            ),
            AgentSelectableText(
              file.resource.value,
              style: theme.textTheme.bodySmall,
            ),
            if (_copied)
              Text(l.copiedToClipboard, style: theme.textTheme.bodySmall),
            if (_error case final error?)
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
    );
  }
}

class _SourceDeliveryRow extends StatefulWidget {
  const _SourceDeliveryRow({
    super.key,
    required this.source,
    required this.isSourceCurrent,
  });
  final AgentDeliverySource source;
  final bool Function() isSourceCurrent;

  @override
  State<_SourceDeliveryRow> createState() => _SourceDeliveryRowState();
}

class _SourceDeliveryRowState extends State<_SourceDeliveryRow> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _open() async {
    if (_busy || !widget.isSourceCurrent()) return;
    final source = widget.source;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      if (!await launchUrl(source.url, mode: LaunchMode.externalApplication)) {
        throw StateError('The system could not open the source.');
      }
    } catch (_) {
      if (mounted &&
          widget.isSourceCurrent() &&
          widget.source.id == source.id) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && widget.source.id == source.id) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final source = widget.source;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  source.title ?? l.agentSourceMaterial,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l.agentDeliveryOpenSource,
                onPressed: _busy || !widget.isSourceCurrent() ? null : _open,
                icon: const Icon(Icons.open_in_new, size: 20),
              ),
            ],
          ),
          AgentSelectableText(
            source.url.toString(),
            style: theme.textTheme.bodySmall,
          ),
          if (source.originalUrl case final original?
              when original != source.url)
            AgentSelectableText(
              original.toString(),
              style: theme.textTheme.bodySmall,
            ),
          for (final publication in source.publications)
            Text(
              l.agentDeliverySourceDate(publication.value),
              style: theme.textTheme.bodySmall,
            ),
          if (source.fetchedAt case final fetched?)
            Text(
              l.agentDeliveryFetchedAt(
                DateFormat.yMd(l.localeName).add_Hm().format(fetched.toLocal()),
              ),
              style: theme.textTheme.bodySmall,
            ),
          if (_failed)
            Text(
              l.agentOperationFailed,
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }
}
