import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/sked_popup_menu.dart';
import '../../widgets/sked_task_session.dart';
import '../../widgets/workbench_chrome_metrics.dart';
import '../conversations/conversation_repository.dart';

/// The same local history is used by the full workspace and compact picker.
class AgentConversationList extends StatefulWidget {
  const AgentConversationList({
    super.key,
    required this.repository,
    required this.onSelected,
    this.onNewConversation,
    this.onRestore,
    this.onRecover,
    this.header,
    this.shrinkWrap = false,
    this.active = true,
    this.interactive = true,
    this.interactionRevision = 0,
    this.isOwnerCurrent,
  });

  final ConversationRepository repository;
  final ValueChanged<String> onSelected;
  final VoidCallback? onNewConversation;
  final FutureOr<void> Function(String)? onRestore;
  final Future<void> Function()? onRecover;
  final Widget? header;
  final bool shrinkWrap;
  final bool active;
  final bool interactive;
  final int interactionRevision;
  final bool Function()? isOwnerCurrent;

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
  Object? _restoreToken;
  String? _restoringId;
  bool _restoreFailed = false;
  (bool, double)? _pendingScrollRestore;
  bool _scrollRestoreScheduled = false;
  SkedTaskSession? _menu;

  String get _query => _search.text.trim().toLowerCase();
  bool get _enabled =>
      mounted &&
      widget.active &&
      widget.interactive &&
      (widget.isOwnerCurrent?.call() ?? true);

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
      _restoreToken = null;
      _restoringId = null;
    }
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.interactionRevision != widget.interactionRevision ||
        (oldWidget.active && !widget.active) ||
        (oldWidget.interactive && !widget.interactive)) {
      _invalidateInteraction();
    }
    _menu?.check();
  }

  void _invalidateInteraction() {
    _generation++;
    _restoreFailed = false;
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

  Future<void> _restore(
    String id,
    int generation,
    int actionGeneration,
    ConversationRepository repository,
  ) async {
    bool targetCurrent() =>
        _current(generation, repository) &&
        _archived &&
        _visibleConversation(id);
    if (!targetCurrent() ||
        actionGeneration != _restoreActionGeneration ||
        widget.onRestore == null ||
        _restoreToken != null) {
      return;
    }
    final token = Object();
    setState(() {
      _restoreToken = token;
      _restoringId = id;
      _restoreFailed = false;
    });
    try {
      if (!repository.canWrite) {
        final recover = widget.onRecover;
        if (!repository.blocked || recover == null) {
          throw const ConversationStorageException('History is unavailable.');
        }
        await recover();
        if (!targetCurrent()) return;
        // Recovery temporarily disables runtime requests. Let its restored
        // availability reach the current list before reading the callback.
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!targetCurrent()) return;
      final restore = widget.onRestore;
      if (!repository.canWrite || restore == null) {
        throw const ConversationStorageException('History is unavailable.');
      }
      // Once accepted, this persistent operation belongs to its delegate.
      // Hiding history only retires feedback, and never cancels the save.
      await restore(id);
    } catch (_) {
      if (targetCurrent()) setState(() => _restoreFailed = true);
    } finally {
      if (mounted && identical(_restoreToken, token)) {
        setState(() {
          _restoreToken = null;
          _restoringId = null;
        });
      }
    }
  }

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
        !_current(_generation, widget.repository)) {
      return;
    }
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
    final metrics = WorkbenchChromeMetrics.of(context);
    final generation = _generation;
    final repository = widget.repository;
    final onNew = widget.onNewConversation;
    final newGeneration = _newActionGeneration;
    final extent = metrics.iconTarget;
    final iconSize = metrics.desktop ? 18.0 : 20.0;
    final iconStyle = metrics.iconStyle.copyWith(
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
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
                minimumSize: Size(extent, extent),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: Icon(Icons.add_comment_outlined, size: iconSize),
              label: Text(l.agentNewConversation, maxLines: 1),
            ),
          )
        : IconButton(
            key: const ValueKey('agent-history-new'),
            tooltip: l.agentNewConversation,
            style: iconStyle,
            icon: Icon(
              Icons.add_comment_outlined,
              size: iconSize,
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
      icon: Icon(_searchOpen ? Icons.close : Icons.search, size: iconSize),
      onPressed: _enabled ? () => _toggleSearch(generation, repository) : null,
    );
    final more = SizedBox.square(
      key: const ValueKey('agent-history-more'),
      dimension: extent,
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
        icon: Icon(Icons.more_horiz, size: iconSize),
        itemBuilder: _archiveItems,
        onSelected: _chooseArchive,
        onCanceled: () => _cancelMenu(generation),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingWidth = extent * 2 + 8;
        final newWidth = constraints.maxWidth - trailingWidth;
        if (constraints.maxWidth <
            (onNew == null ? trailingWidth : extent * 3 + 8)) {
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
                        !metrics.desktop &&
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
    final metrics = WorkbenchChromeMetrics.of(context);
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
                  final columns =
                      ((constraints.maxWidth - 20) / (metrics.iconTarget + 4))
                          .floor();
                  final safeColumns = columns < 1
                      ? 1
                      : columns > controls
                      ? controls
                      : columns;
                  final rows = (controls / safeColumns).ceil();
                  final actionsHeight =
                      rows * metrics.iconTarget + (rows - 1) * 4 + 8;
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
                            constraints.maxHeight >=
                                actionsHeight + metrics.resourceRowHeight,
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
                                if (_current(generation, repository)) {
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ),
                      if (_restoreFailed)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: Material(
                              key: const ValueKey('agent-history-error'),
                              color: colors.errorContainer,
                              shape: skedShapeSchemeOf(context).control,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  l.agentOperationFailed,
                                  style: TextStyle(
                                    color: colors.onErrorContainer,
                                  ),
                                ),
                              ),
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
                                padding: EdgeInsets.only(
                                  bottom: metrics.desktop ? 2 : 4,
                                ),
                                child: ListTile(
                                  key: ValueKey(
                                    'agent-history-${conversation.id}',
                                  ),
                                  selected: selected,
                                  shape: metrics.desktop
                                      ? skedShapeSchemeOf(context).compact
                                      : skedShapeSchemeOf(context).control,
                                  selectedTileColor: colors.secondaryContainer,
                                  selectedColor: colors.onSecondaryContainer,
                                  minTileHeight: metrics.resourceRowHeight,
                                  minVerticalPadding: metrics.desktop
                                      ? 4
                                      : null,
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
                                              !_enabled ||
                                                  onRestore == null ||
                                                  (!repository.canWrite &&
                                                      (!repository.blocked ||
                                                          widget.onRecover ==
                                                              null)) ||
                                                  _restoreToken != null
                                              ? null
                                              : () => unawaited(
                                                  _restore(
                                                    conversation.id,
                                                    generation,
                                                    restoreGeneration,
                                                    repository,
                                                  ),
                                                ),
                                          style: metrics.iconStyle,
                                          icon: _restoringId == conversation.id
                                              ? SizedBox.square(
                                                  dimension: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    semanticsLabel: l
                                                        .agentRestoreConversation,
                                                    semanticsValue:
                                                        l.agentSaving,
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.unarchive_outlined,
                                                  semanticLabel: l
                                                      .agentRestoreConversation,
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
