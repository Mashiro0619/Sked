import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/sked_popup_menu.dart';
import '../../widgets/sked_task_session.dart';
import '../conversations/conversation_repository.dart';

/// The same local history is used by the full workspace and compact picker.
class AgentConversationList extends StatefulWidget {
  const AgentConversationList({
    super.key,
    required this.repository,
    required this.onSelected,
    this.onNewConversation,
    this.onRestore,
    this.header,
    this.shrinkWrap = false,
    this.active = true,
    this.interactive = true,
  });

  final ConversationRepository repository;
  final ValueChanged<String> onSelected;
  final VoidCallback? onNewConversation;
  final ValueChanged<String>? onRestore;
  final Widget? header;
  final bool shrinkWrap;
  final bool active;
  final bool interactive;

  @override
  State<AgentConversationList> createState() => _AgentConversationListState();
}

class _AgentConversationListState extends State<AgentConversationList> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  final _scrollOffsets = <bool, double>{false: 0, true: 0};
  bool _archived = false;
  bool _searchOpen = false;
  int _generation = 0;
  int _newActionGeneration = 0;
  int _restoreActionGeneration = 0;
  (bool, double)? _pendingScrollRestore;
  bool _scrollRestoreScheduled = false;
  SkedTaskSession? _menu;

  String get _query => _search.text.trim().toLowerCase();
  bool get _enabled => mounted && widget.active && widget.interactive;

  @override
  void didUpdateWidget(AgentConversationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onNewConversation != null &&
        widget.onNewConversation == null) {
      _newActionGeneration++;
    }
    if (oldWidget.onRestore != null && widget.onRestore == null) {
      _restoreActionGeneration++;
    }
    if (!identical(oldWidget.repository, widget.repository)) {
      _pendingScrollRestore = null;
    }
    if (!identical(oldWidget.repository, widget.repository) ||
        (oldWidget.active && !widget.active) ||
        (oldWidget.interactive && !widget.interactive)) {
      _invalidateInteraction();
    }
    _menu?.check();
  }

  void _invalidateInteraction() {
    _generation++;
    _menu?.dispose();
    _menu = null;
    _searchFocus.unfocus();
  }

  @override
  void deactivate() {
    _invalidateInteraction();
    super.deactivate();
  }

  @override
  void dispose() {
    _menu?.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _sameOwner(int generation, ConversationRepository repository) =>
      _enabled &&
      generation == _generation &&
      identical(repository, widget.repository);

  bool _current(int generation, ConversationRepository repository) =>
      _sameOwner(generation, repository) &&
      ModalRoute.of(context)?.isCurrent != false;

  bool _visibleConversation(String id) => widget.repository.conversations.any(
    (conversation) =>
        conversation.id == id &&
        conversation.archived == _archived &&
        conversation.title.toLowerCase().contains(_query),
  );

  void _toggleSearch(int generation, ConversationRepository repository) {
    if (!_current(generation, repository)) return;
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _searchFocus.unfocus();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current(generation, repository) && _searchOpen) {
        _searchFocus.requestFocus();
      }
    });
  }

  List<PopupMenuEntry<_HistoryArchiveChoice>> _archiveItems(
    BuildContext context,
  ) {
    if (!_current(_generation, widget.repository)) return const [];
    final repository = widget.repository;
    final generation = _generation;
    _menu?.dispose();
    final session = _menu = SkedTaskSession(
      ownerRoute: ModalRoute.of(this.context),
      isOwnerActive: () => _enabled,
      isTargetCurrent: () => _sameOwner(generation, repository),
    );
    return [
      SkedCheckedPopupMenuItem(
        key: const ValueKey('agent-history-archived'),
        value: _HistoryArchiveChoice(!_archived, session),
        checked: _archived,
        label: AppLocalizations.of(context).agentArchivedConversations,
        leading: const Icon(Icons.archive_outlined),
      ),
    ];
  }

  void _chooseArchive(_HistoryArchiveChoice choice) {
    final session = choice.session;
    final current =
        identical(session, _menu) &&
        session.isCurrent &&
        _enabled &&
        session.ownerRoute?.isCurrent == true;
    if (identical(session, _menu)) _menu = null;
    session.dispose();
    if (!current) return;
    if (_pendingScrollRestore case final pending?
        when pending.$1 == _archived) {
      _scrollOffsets[_archived] = pending.$2;
    } else if (_scroll.hasClients) {
      _scrollOffsets[_archived] = _scroll.offset;
    }
    final offset = _scrollOffsets[choice.archived] ?? 0;
    _pendingScrollRestore = (choice.archived, offset);
    setState(() => _archived = choice.archived);
    _scheduleScrollRestore();
  }

  void _scheduleScrollRestore() {
    final pending = _pendingScrollRestore;
    if (pending == null ||
        _scrollRestoreScheduled ||
        !_current(_generation, widget.repository))
      return;
    final generation = _generation;
    final repository = widget.repository;
    _scrollRestoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollRestoreScheduled = false;
      if (_current(generation, repository) &&
          _pendingScrollRestore == pending &&
          _archived == pending.$1 &&
          _scroll.hasClients) {
        _scroll.jumpTo(
          pending.$2
              .clamp(
                _scroll.position.minScrollExtent,
                _scroll.position.maxScrollExtent,
              )
              .toDouble(),
        );
        _pendingScrollRestore = null;
      } else if (mounted &&
          _pendingScrollRestore != null &&
          _current(_generation, widget.repository)) {
        _scheduleScrollRestore();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _cancelMenu(int generation) {
    if (generation != _generation) return;
    _menu?.dispose();
    _menu = null;
  }

  bool _newLabelFits(BuildContext context, String label, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width + 48 <= width;
    painter.dispose();
    return fits;
  }

  Widget _actions(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final generation = _generation;
    final repository = widget.repository;
    final onNew = widget.onNewConversation;
    final newGeneration = _newActionGeneration;
    final iconStyle = IconButton.styleFrom(
      minimumSize: const Size.square(48),
      fixedSize: const Size.square(48),
      padding: EdgeInsets.zero,
    );
    void newConversation() {
      if (_current(generation, repository) &&
          widget.onNewConversation != null &&
          newGeneration == _newActionGeneration) {
        onNew?.call();
      }
    }

    Widget newAction(bool showLabel) => showLabel
        ? Tooltip(
            message: l.agentNewConversation,
            child: TextButton.icon(
              key: const ValueKey('agent-history-new'),
              onPressed: _enabled ? newConversation : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.add_comment_outlined, size: 20),
              label: Text(l.agentNewConversation, maxLines: 1),
            ),
          )
        : IconButton(
            key: const ValueKey('agent-history-new'),
            tooltip: l.agentNewConversation,
            style: iconStyle,
            icon: Icon(
              Icons.add_comment_outlined,
              size: 20,
              semanticLabel: l.agentNewConversation,
            ),
            onPressed: _enabled ? newConversation : null,
          );
    final search = IconButton(
      key: const ValueKey('agent-history-search-toggle'),
      style: iconStyle,
      tooltip: _searchOpen
          ? MaterialLocalizations.of(context).closeButtonTooltip
          : _query.isEmpty
          ? l.agentSearchConversations
          : '${l.agentSearchConversations}: ${_search.text}',
      isSelected: _searchOpen || _query.isNotEmpty,
      icon: Icon(_searchOpen ? Icons.close : Icons.search, size: 20),
      onPressed: _enabled ? () => _toggleSearch(generation, repository) : null,
    );
    final more = SizedBox.square(
      key: const ValueKey('agent-history-more'),
      dimension: 48,
      child: SkedPopupMenuButton<_HistoryArchiveChoice>(
        // Retiring the source also retires its popup route. Results still carry
        // their original session when a callback arrives after replacement.
        key: ValueKey(('agent-history-menu', generation)),
        tooltip: _archived
            ? '${l.more}: ${l.agentArchivedConversations}'
            : l.more,
        enabled: _enabled,
        style: iconStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(
            _archived ? colors.secondaryContainer : null,
          ),
          foregroundColor: WidgetStatePropertyAll(
            _archived ? colors.onSecondaryContainer : null,
          ),
        ),
        icon: const Icon(Icons.more_horiz, size: 20),
        itemBuilder: _archiveItems,
        onSelected: _chooseArchive,
        onCanceled: () => _cancelMenu(generation),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final newWidth = constraints.maxWidth - 104;
        if (constraints.maxWidth < (onNew == null ? 104 : 152)) {
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [if (onNew != null) newAction(false), search, more],
          );
        }
        return Row(
          children: [
            Expanded(
              child: onNew == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: newAction(
                        _newLabelFits(
                          context,
                          l.agentNewConversation,
                          newWidth,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 4),
            search,
            const SizedBox(width: 4),
            more,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return FocusScope(
      canRequestFocus: _enabled,
      descendantsAreFocusable: _enabled,
      descendantsAreTraversable: _enabled,
      child: IgnorePointer(
        ignoring: !_enabled,
        child: ExcludeSemantics(
          excluding: !_enabled,
          child: ListenableBuilder(
            listenable: widget.repository,
            builder: (context, _) {
              final repository = widget.repository;
              final generation = _generation;
              final onSelected = widget.onSelected;
              final onRestore = widget.onRestore;
              final restoreGeneration = _restoreActionGeneration;
              _scheduleScrollRestore();
              final entries =
                  repository.conversations
                      .where(
                        (item) =>
                            item.archived == _archived &&
                            item.title.toLowerCase().contains(_query),
                      )
                      .toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              return LayoutBuilder(
                builder: (context, constraints) {
                  final controls = widget.onNewConversation == null ? 2 : 3;
                  final columns = ((constraints.maxWidth - 20) / 52).floor();
                  final safeColumns = columns < 1
                      ? 1
                      : columns > controls
                      ? controls
                      : columns;
                  final rows = (controls / safeColumns).ceil();
                  final actionsHeight = rows * 48.0 + (rows - 1) * 4 + 8;
                  return CustomScrollView(
                    key: const PageStorageKey('agent-conversation-list'),
                    controller: _scroll,
                    primary: false,
                    shrinkWrap: widget.shrinkWrap,
                    physics: widget.shrinkWrap
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    slivers: [
                      if (widget.header case final header?)
                        SliverToBoxAdapter(child: header),
                      SliverPersistentHeader(
                        pinned:
                            !widget.shrinkWrap &&
                            constraints.hasBoundedHeight &&
                            constraints.maxHeight >= actionsHeight + 48,
                        delegate: _HistoryActionsHeader(
                          height: actionsHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                            child: _actions(context),
                          ),
                        ),
                      ),
                      if (_searchOpen)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: TextField(
                              key: const ValueKey('agent-history-search'),
                              controller: _search,
                              focusNode: _searchFocus,
                              enabled: _enabled,
                              decoration: InputDecoration(
                                hintText: l.agentSearchConversations,
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: l.clear,
                                        onPressed: _enabled
                                            ? () {
                                                if (_current(
                                                  generation,
                                                  repository,
                                                )) {
                                                  _search.clear();
                                                  setState(() {});
                                                }
                                              }
                                            : null,
                                        icon: const Icon(Icons.clear),
                                      ),
                              ),
                              onChanged: (_) {
                                if (_current(generation, repository))
                                  setState(() {});
                              },
                            ),
                          ),
                        ),
                      if (entries.isEmpty)
                        if (widget.shrinkWrap)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                _query.isEmpty
                                    ? l.agentEmptyHistory
                                    : l.agentConversationSearchEmpty,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
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
                                  conversation.id ==
                                  widget.repository.selectedId;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: ListTile(
                                  key: ValueKey(
                                    'agent-history-${conversation.id}',
                                  ),
                                  selected: selected,
                                  shape: skedShapeSchemeOf(context).control,
                                  selectedTileColor: colors.secondaryContainer,
                                  selectedColor: colors.onSecondaryContainer,
                                  minTileHeight: 48,
                                  title: Text(
                                    conversation.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle:
                                      conversation.status ==
                                          ConversationStatus.waitingApproval
                                      ? Text(l.agentApprovalRequired)
                                      : conversation.status ==
                                            ConversationStatus.running
                                      ? Text(l.agentRunning)
                                      : null,
                                  onTap: !_enabled
                                      ? null
                                      : () {
                                          if (_current(
                                                generation,
                                                repository,
                                              ) &&
                                              _visibleConversation(
                                                conversation.id,
                                              )) {
                                            onSelected(conversation.id);
                                          }
                                        },
                                  trailing: conversation.archived
                                      ? IconButton(
                                          key: ValueKey(
                                            'agent-restore-${conversation.id}',
                                          ),
                                          tooltip: l.agentRestoreConversation,
                                          onPressed:
                                              !_enabled || onRestore == null
                                              ? null
                                              : () {
                                                  if (_current(
                                                        generation,
                                                        repository,
                                                      ) &&
                                                      widget.onRestore !=
                                                          null &&
                                                      _archived &&
                                                      restoreGeneration ==
                                                          _restoreActionGeneration &&
                                                      _visibleConversation(
                                                        conversation.id,
                                                      )) {
                                                    onRestore?.call(
                                                      conversation.id,
                                                    );
                                                  }
                                                },
                                          style: IconButton.styleFrom(
                                            minimumSize: const Size.square(48),
                                          ),
                                          icon: const Icon(
                                            Icons.unarchive_outlined,
                                          ),
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
            },
          ),
        ),
      ),
    );
  }
}

class _HistoryArchiveChoice {
  const _HistoryArchiveChoice(this.archived, this.session);
  final bool archived;
  final SkedTaskSession session;
}

class _HistoryActionsHeader extends SliverPersistentHeaderDelegate {
  const _HistoryActionsHeader({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(color: Theme.of(context).scaffoldBackgroundColor, child: child);
  @override
  bool shouldRebuild(_HistoryActionsHeader oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}
