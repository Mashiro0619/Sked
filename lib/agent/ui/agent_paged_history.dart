import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../attachments/agent_attachment_controller.dart';
import '../conversations/conversation_browse_repository.dart';
import '../conversations/conversation_models.dart';
import '../history/conversation_history.dart';
import '../references/agent_composer_reference.dart';
import 'agent_attachment_view.dart';
import 'agent_selectable_text.dart';

class AgentPagedHistory extends StatefulWidget {
  const AgentPagedHistory({
    super.key,
    required this.repository,
    required this.conversationId,
    required this.isCurrent,
    required this.referencesBuilder,
    this.attachments,
  });

  final ConversationBrowseRepository repository;
  final String conversationId;
  final bool Function() isCurrent;
  final AgentAttachmentController? attachments;
  final Widget Function(List<AgentComposerReference>, Key) referencesBuilder;

  @override
  State<AgentPagedHistory> createState() => _AgentPagedHistoryState();
}

class _AgentPagedHistoryState extends State<AgentPagedHistory> {
  final _entries = <bool, List<ConversationHistoryEntry>>{false: [], true: []};
  final _next = <bool, int?>{false: 0, true: 0};
  final _loading = <bool>{};
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(false));
    unawaited(_load(true));
  }

  Future<void> _load(bool replies) async {
    final offset = _next[replies];
    if (offset == null || !_loading.add(replies)) return;
    try {
      final page = await widget.repository.readHistoryCatalog(
        widget.conversationId,
        replies: replies,
        offset: offset,
      );
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _entries[replies]!.addAll(page.entries);
        _next[replies] = page.nextOffset;
        _failed = false;
      });
    } catch (_) {
      if (mounted && widget.isCurrent()) setState(() => _failed = true);
    } finally {
      _loading.remove(replies);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final entries = [..._entries[false]!, ..._entries[true]!];
    return SizedBox(
      width: 600,
      height: MediaQuery.sizeOf(context).height * .6,
      child: ListView.builder(
        itemCount: entries.length + 1,
        itemBuilder: (context, index) {
          if (index < entries.length) {
            final entry = entries[index];
            return _HistoryEntry(
              key: ValueKey((entry.isReply, entry.id)),
              owner: widget,
              entry: entry,
            );
          }
          return Column(
            children: [
              if (_failed) Text(l.agentOperationFailed),
              if (_loading.isNotEmpty) const LinearProgressIndicator(),
              for (final replies in [false, true])
                if (_next[replies] != null)
                  TextButton(
                    key: ValueKey(('agent-history-more', replies)),
                    onPressed: _loading.contains(replies)
                        ? null
                        : () => _load(replies),
                    child: Text(l.agentLoadEarlierMessages),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryEntry extends StatefulWidget {
  const _HistoryEntry({super.key, required this.owner, required this.entry});
  final AgentPagedHistory owner;
  final ConversationHistoryEntry entry;

  @override
  State<_HistoryEntry> createState() => _HistoryEntryState();
}

class _HistoryEntryState extends State<_HistoryEntry> {
  final _messages = <ConversationMessage>[];
  final _attachments = <String, ConversationAttachment>{};
  ConversationReplyRevision? _reply;
  String? _before;
  bool _expanded = false;
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  Future<void> _load() async {
    if (_loading) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      if (widget.entry.isReply) {
        final reply = await widget.owner.repository.readReplyVersion(
          widget.owner.conversationId,
          widget.entry.id,
        );
        if (!mounted ||
            generation != _generation ||
            !widget.owner.isCurrent()) {
          return;
        }
        if (reply == null) throw StateError('Reply version does not exist.');
        _reply = reply;
      } else {
        final page = await widget.owner.repository.readHistoryPage(
          widget.owner.conversationId,
          widget.entry.id,
          beforeMessageId: _before,
        );
        if (!mounted ||
            generation != _generation ||
            !widget.owner.isCurrent()) {
          return;
        }
        final ids = _messages.map((message) => message.id).toSet();
        _messages.insertAll(
          0,
          page.messages.where((message) => ids.add(message.id)),
        );
        for (final attachment in page.attachments) {
          _attachments[attachment.id] = attachment;
        }
        _before = page.nextBeforeMessageId;
      }
      _failed = false;
    } catch (_) {
      if (mounted && generation == _generation) _failed = true;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExpansionTile(
      key: ValueKey('agent-history-entry-${widget.entry.id}'),
      title: Text(widget.entry.createdAt.toLocal().toString()),
      onExpansionChanged: (expanded) {
        setState(() {
          _expanded = expanded;
          _generation++;
          _loading = false;
          _failed = false;
          _messages.clear();
          _attachments.clear();
          _reply = null;
          _before = null;
        });
        if (expanded) unawaited(_load());
      },
      children: [
        if (_expanded) ...[
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            TextButton(onPressed: _load, child: Text(l.agentOperationFailed)),
          if (_reply != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: AgentSelectableText(_reply!.text),
            ),
          if (_messages.isNotEmpty)
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _messages.length + (_before == null ? 0 : 1),
                itemBuilder: (context, index) {
                  if (_before != null && index == 0) {
                    return TextButton(
                      onPressed: _loading ? null : _load,
                      child: Text(l.agentLoadEarlierMessages),
                    );
                  }
                  final message = _messages[index - (_before == null ? 0 : 1)];
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (message.text.isNotEmpty)
                          AgentSelectableText(message.text),
                        if (message.contextReferences.isNotEmpty)
                          widget.owner.referencesBuilder(
                            message.contextReferences,
                            ValueKey((
                              'history-reference',
                              widget.entry.id,
                              message.id,
                            )),
                          ),
                        if (message.attachmentIds.isNotEmpty)
                          if (widget.owner.attachments != null)
                            AgentAttachmentList(
                              conversationId: widget.owner.conversationId,
                              attachments: _attachments.values.toList(),
                              ids: message.attachmentIds,
                              repository: widget.owner.attachments!.repository,
                              delivery: message.attachmentDelivery,
                            )
                          else ...[
                            for (final id in message.attachmentIds)
                              Text(
                                _attachments[id]?.name ?? l.agentFileMissing,
                              ),
                            Text(l.agentFileUnavailable),
                          ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

class AgentPagedSource extends StatefulWidget {
  const AgentPagedSource({
    super.key,
    required this.source,
    required this.load,
    this.contextIdentity,
    this.trailing,
  });
  final ConversationSource source;
  final Future<ConversationSource?> Function() load;
  final Object? contextIdentity;
  final Widget? trailing;

  @override
  State<AgentPagedSource> createState() => _AgentPagedSourceState();
}

class _AgentPagedSourceState extends State<AgentPagedSource> {
  ConversationSource? _source;
  bool _expanded = false;
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void didUpdateWidget(AgentPagedSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextIdentity != widget.contextIdentity ||
        oldWidget.source.id != widget.source.id) {
      _generation++;
      _source = null;
      _expanded = false;
      _loading = false;
      _failed = false;
    }
  }

  Future<void> _load() async {
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final source = await widget.load();
      if (!mounted || generation != _generation) return;
      if (source == null) throw StateError('Source does not exist.');
      setState(() {
        _source = source;
        _failed = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExpansionTile(
      key: ValueKey((widget.source.id, widget.contextIdentity)),
      title: Text(
        widget.source.provenance?.title.isNotEmpty == true
            ? widget.source.provenance!.title
            : l.agentSourceMaterial,
      ),
      trailing: widget.trailing,
      onExpansionChanged: (expanded) {
        setState(() {
          _expanded = expanded;
          _generation++;
          _source = null;
          _failed = false;
          _loading = false;
        });
        if (expanded) unawaited(_load());
      },
      childrenPadding: const EdgeInsets.all(16),
      children: [
        if (_expanded) ...[
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            TextButton(onPressed: _load, child: Text(l.agentOperationFailed)),
          if (_source != null) ...[
            if (_source!.truncated) Text(l.agentSourceTruncated),
            AgentSelectableText(_source!.text),
          ],
        ],
      ],
    );
  }
}
