import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../conversations/conversation_repository.dart';

/// The same local history is used by the full workspace and compact picker.
class AgentConversationList extends StatefulWidget {
  const AgentConversationList({
    super.key,
    required this.repository,
    required this.onSelected,
    this.onRestore,
    this.header,
  });

  final ConversationRepository repository;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onRestore;
  final Widget? header;

  @override
  State<AgentConversationList> createState() => _AgentConversationListState();
}

class _AgentConversationListState extends State<AgentConversationList> {
  String _query = '';
  bool _archived = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final entries =
            widget.repository.conversations
                .where(
                  (item) =>
                      item.archived == _archived &&
                      item.title.toLowerCase().contains(_query),
                )
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return CustomScrollView(
          key: const PageStorageKey('agent-conversation-list'),
          slivers: [
            if (widget.header case final header?)
              SliverToBoxAdapter(child: header),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  key: const ValueKey('agent-history-search'),
                  decoration: InputDecoration(
                    hintText: l.agentSearchConversations,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilterChip(
                    key: const ValueKey('agent-history-archived'),
                    avatar: const Icon(Icons.archive_outlined, size: 18),
                    label: Text(l.agentArchivedConversations),
                    selected: _archived,
                    onSelected: (value) => setState(() => _archived = value),
                  ),
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _query.isEmpty
                          ? l.agentEmptyHistory
                          : l.agentConversationSearchEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final conversation = entries[index];
                    final selected =
                        conversation.id == widget.repository.selectedId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        key: ValueKey('agent-history-${conversation.id}'),
                        selected: selected,
                        shape: skedShapeSchemeOf(context).control,
                        selectedTileColor: colors.secondaryContainer,
                        selectedColor: colors.onSecondaryContainer,
                        title: Text(
                          conversation.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            conversation.status ==
                                ConversationStatus.waitingApproval
                            ? Text(l.agentApprovalRequired)
                            : conversation.status == ConversationStatus.running
                            ? Text(l.agentRunning)
                            : null,
                        onTap: () => widget.onSelected(conversation.id),
                        trailing: conversation.archived
                            ? IconButton(
                                key: ValueKey(
                                  'agent-restore-${conversation.id}',
                                ),
                                tooltip: l.agentRestoreConversation,
                                onPressed: widget.onRestore == null
                                    ? null
                                    : () => widget.onRestore!(conversation.id),
                                icon: const Icon(Icons.unarchive_outlined),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
